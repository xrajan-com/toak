import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import 'package:ten_of_a_kind_poker/config/.env.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';

/// The four reserved X Lounge tracks that are tied to game events.
enum XMusicEvent {
  gameOverNoPrize,
  gameOverWithPrize,
  heroInBottomHalf,
  heroSecuresPrize,
}

enum _XMusicMode { stopped, homepage, career, quickGameplay }

enum _PlaybackWait { elapsed, finished, interrupted }

/// Owns the new X Poker music layer.
///
/// It intentionally uses one [AudioPlayer], so homepage, circuit, lounge, and
/// event tracks can never overlap one another. The existing SoundFx layer has
/// its own players and remains free to play at the same time.
class XMusicService extends WidgetsBindingObserver {
  XMusicService._();

  static final XMusicService instance = XMusicService._();

  static const String _homepageAsset = 'assets/sounds/x_music/homepage.mp3';
  static const String _loungePrefix = 'assets/sounds/x lounge/';
  static const double maxVolume = 0.30;
  static const Duration _fadeInDuration = Duration(seconds: 3);
  static const Duration _fadeOutDuration = Duration(seconds: 4);
  static const Duration _transitionFadeDuration = Duration(milliseconds: 900);
  static const Duration _fallbackTrackDuration = Duration(seconds: 31);

  static const Map<XMusicEvent, String> _eventAssets = <XMusicEvent, String>{
    XMusicEvent.gameOverNoPrize: '${_loungePrefix}game over with no prize.mp3',
    XMusicEvent.gameOverWithPrize: '${_loungePrefix}game over with prize.mp3',
    XMusicEvent.heroInBottomHalf:
        '${_loungePrefix}user is in bottom half of chips.mp3',
    XMusicEvent.heroSecuresPrize: '${_loungePrefix}user secures prize.mp3',
  };

  static const Set<String> _supportedExtensions = <String>{
    '.aac',
    '.flac',
    '.m4a',
    '.mp3',
    '.ogg',
    '.wav',
  };

  final AudioPlayer _player = AudioPlayer();
  final math.Random _random = math.Random();
  final Queue<XMusicEvent> _eventQueue = Queue<XMusicEvent>();
  final Set<String> _unplayableAssets = <String>{};

  _XMusicMode _mode = _XMusicMode.stopped;
  VenueGroup? _careerGroup;
  bool _includeLoungeInCareer = false;
  // Lounge music is opt-in. AppSettingsService restores the user's saved
  // preference after startup, but keeping the player muted here also prevents
  // audio from starting during that asynchronous load.
  bool _muted = true;
  bool _appActive = true;
  bool _unlocked = !kIsWeb;
  bool _runnerActive = false;
  bool _playingEvent = false;
  bool _observingLifecycle = false;
  int _revision = 0;
  int _careerSequenceIndex = 0;
  double _currentVolume = 0;
  Completer<void>? _interrupt;
  List<String>? _loungeAssets;
  List<String> _loungeDeck = <String>[];
  String? _lastLoungeAsset;

  bool get _enabled => Env.soundEnabled && !_muted && _unlocked && _appActive;

  bool get needsUnlock => !_unlocked;

  /// Returns every non-event audio asset directly or recursively contained in
  /// the X Lounge library. This manifest-based discovery means adding or
  /// deleting ordinary lounge files requires no Dart code change.
  @visibleForTesting
  static List<String> loungeAssetsFromManifest(Iterable<String> assets) {
    final Set<String> reserved = _eventAssets.values.toSet();
    final List<String> result = assets.where((String asset) {
      if (!asset.startsWith(_loungePrefix) || reserved.contains(asset)) {
        return false;
      }
      final String lower = asset.toLowerCase();
      return _supportedExtensions.any(lower.endsWith);
    }).toList(growable: false)
      ..sort();
    return result;
  }

  @visibleForTesting
  static String circuitAssetFor(VenueGroup group) => switch (group) {
        VenueGroup.euro => 'assets/sounds/x_music/euro_circuit.mp3',
        VenueGroup.india => 'assets/sounds/x_music/india_circuit.mp3',
        VenueGroup.international =>
          'assets/sounds/x_music/international_circuit.mp3',
        // The supplied Asia theme is used for the app's Micro/Oceania circuit.
        VenueGroup.oceania => 'assets/sounds/x_music/asia_circuit.mp3',
        VenueGroup.northAmerica => 'assets/sounds/x_music/us_circuit.mp3',
      };

  Future<void> unlock() async {
    if (_unlocked) return;
    _unlocked = true;
    _ensureRunner();
  }

  void setMuted(bool value) {
    if (_muted == value) return;
    _muted = value;
    if (value) {
      _eventQueue.clear();
      _revision++;
      _signalInterrupt();
    } else {
      _ensureRunner();
    }
  }

  void playHomepage() {
    _setMode(_XMusicMode.homepage);
  }

  /// Plays only the selected circuit while the player browses Career.
  void playCareerCircuit(VenueGroup group) {
    _setMode(
      _XMusicMode.career,
      group: group,
      includeLoungeInCareer: false,
    );
  }

  /// Alternates the selected circuit theme with the dynamic lounge library
  /// during Career gameplay.
  void playCareerGameplay(VenueGroup group) {
    _setMode(
      _XMusicMode.career,
      group: group,
      includeLoungeInCareer: true,
    );
  }

  /// Shuffles the dynamic lounge library during Quick Game gameplay.
  void playQuickGameplay() {
    _setMode(_XMusicMode.quickGameplay);
  }

  void stop() {
    _setMode(_XMusicMode.stopped);
  }

  /// Gives an event cue priority. The current new-layer track fades out first,
  /// then this cue plays; the interrupted context resumes afterward.
  void queueEvent(XMusicEvent event) {
    // Muted event cues are intentionally discarded so opting in later cannot
    // replay sounds for moments that have already passed.
    if (_muted) return;
    if (_eventQueue.contains(event)) return;
    _eventQueue.add(event);
    if (!_playingEvent) {
      _revision++;
      _signalInterrupt();
    }
    _ensureRunner();
  }

  void _setMode(
    _XMusicMode mode, {
    VenueGroup? group,
    bool includeLoungeInCareer = false,
  }) {
    final bool changed = _mode != mode ||
        _careerGroup != group ||
        _includeLoungeInCareer != includeLoungeInCareer;
    if (!changed) {
      _ensureRunner();
      return;
    }

    _mode = mode;
    _careerGroup = group;
    _includeLoungeInCareer = includeLoungeInCareer;
    _careerSequenceIndex = 0;
    _eventQueue.clear();
    _unplayableAssets.clear();
    _revision++;
    _signalInterrupt();
    _ensureRunner();
  }

  void _ensureRunner() {
    if (!_enabled || _mode == _XMusicMode.stopped || _runnerActive) return;
    if (!_observingLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
    _runnerActive = true;
    unawaited(_run().whenComplete(() => _runnerActive = false));
  }

  Future<void> _run() async {
    while (_enabled && _mode != _XMusicMode.stopped) {
      final XMusicEvent? event =
          _eventQueue.isEmpty ? null : _eventQueue.removeFirst();
      _playingEvent = event != null;
      final String? asset =
          event == null ? await _nextContextAsset() : _eventAssets[event];
      if (asset == null || _unplayableAssets.contains(asset)) break;

      final int revision = _revision;
      try {
        await _playAsset(asset, revision: revision);
      } catch (error, stack) {
        _unplayableAssets.add(asset);
        debugPrint('X Music could not play $asset: $error\n$stack');
      } finally {
        _playingEvent = false;
      }
    }
  }

  Future<String?> _nextContextAsset() async {
    switch (_mode) {
      case _XMusicMode.stopped:
        return null;
      case _XMusicMode.homepage:
        return _unplayableAssets.contains(_homepageAsset)
            ? null
            : _homepageAsset;
      case _XMusicMode.quickGameplay:
        return _nextLoungeAsset();
      case _XMusicMode.career:
        final VenueGroup? group = _careerGroup;
        if (group == null) return null;
        final String circuit = circuitAssetFor(group);
        if (!_includeLoungeInCareer) {
          return _unplayableAssets.contains(circuit) ? null : circuit;
        }

        // Keep the selected circuit identifiable while mixing in soothing
        // lounge variety: circuit, lounge, lounge, then repeat.
        final int position = _careerSequenceIndex++ % 3;
        if (position == 0 && !_unplayableAssets.contains(circuit)) {
          return circuit;
        }
        return await _nextLoungeAsset() ??
            (_unplayableAssets.contains(circuit) ? null : circuit);
    }
  }

  Future<List<String>> _loadLoungeAssets() async {
    final List<String>? cached = _loungeAssets;
    if (cached != null) return cached;
    final AssetManifest manifest =
        await AssetManifest.loadFromAssetBundle(rootBundle);
    final List<String> discovered =
        loungeAssetsFromManifest(manifest.listAssets());
    _loungeAssets = discovered;
    return discovered;
  }

  Future<String?> _nextLoungeAsset() async {
    final List<String> assets = (await _loadLoungeAssets())
        .where((String asset) => !_unplayableAssets.contains(asset))
        .toList(growable: false);
    if (assets.isEmpty) return null;
    if (_loungeDeck.isEmpty ||
        _loungeDeck.any((String asset) => !assets.contains(asset))) {
      _loungeDeck = List<String>.from(assets)..shuffle(_random);
      if (_loungeDeck.length > 1 && _loungeDeck.last == _lastLoungeAsset) {
        final String first = _loungeDeck.first;
        _loungeDeck[0] = _loungeDeck.last;
        _loungeDeck[_loungeDeck.length - 1] = first;
      }
    }
    final String next = _loungeDeck.removeLast();
    _lastLoungeAsset = next;
    return next;
  }

  Future<void> _playAsset(String asset, {required int revision}) async {
    await _player.stop();
    final Duration duration =
        await _player.setAsset(asset) ?? _fallbackTrackDuration;
    if (!_enabled || revision != _revision) return;

    await _player.setVolume(0);
    _currentVolume = 0;
    await _player.seek(Duration.zero);
    final Completer<void> interrupt = Completer<void>();
    _interrupt = interrupt;
    final Future<void> playback = _player.play().then<void>(
          (_) {},
          onError: (Object _, StackTrace __) {},
        );

    try {
      final Duration fadeIn = _boundedFade(_fadeInDuration, duration, 0.20);
      final Duration fadeOut = _boundedFade(_fadeOutDuration, duration, 0.25);
      _PlaybackWait result = await _fadeTo(
        maxVolume,
        fadeIn,
        playback: playback,
        interrupt: interrupt.future,
      );
      if (result == _PlaybackWait.interrupted) {
        await _fadeOutAndStop(playback);
        return;
      }
      if (result == _PlaybackWait.finished) return;

      final Duration hold = duration - fadeIn - fadeOut;
      if (hold > Duration.zero) {
        result = await _wait(
          hold,
          playback: playback,
          interrupt: interrupt.future,
        );
        if (result == _PlaybackWait.interrupted) {
          await _fadeOutAndStop(playback);
          return;
        }
        if (result == _PlaybackWait.finished) return;
      }

      result = await _fadeTo(
        0,
        fadeOut,
        playback: playback,
        interrupt: interrupt.future,
      );
      if (result == _PlaybackWait.interrupted) {
        await _fadeOutAndStop(playback);
        return;
      }
      if (result != _PlaybackWait.finished) await playback;
    } finally {
      if (identical(_interrupt, interrupt)) _interrupt = null;
    }
  }

  Duration _boundedFade(
    Duration preferred,
    Duration trackDuration,
    double maximumFraction,
  ) {
    final int maxMilliseconds =
        (trackDuration.inMilliseconds * maximumFraction).round();
    return Duration(
      milliseconds: math.max(
        1,
        math.min(preferred.inMilliseconds, maxMilliseconds),
      ),
    );
  }

  Future<_PlaybackWait> _fadeTo(
    double target,
    Duration duration, {
    required Future<void> playback,
    Future<void>? interrupt,
  }) async {
    final double start = _currentVolume;
    final int steps = math.max(1, duration.inMilliseconds ~/ 100);
    final Duration stepDuration = Duration(
      milliseconds: math.max(1, duration.inMilliseconds ~/ steps),
    );
    for (int step = 1; step <= steps; step++) {
      final double progress = step / steps;
      _currentVolume = start + ((target - start) * progress);
      await _player.setVolume(_currentVolume.clamp(0, maxVolume));
      final _PlaybackWait result = await _wait(
        stepDuration,
        playback: playback,
        interrupt: interrupt,
      );
      if (result != _PlaybackWait.elapsed) return result;
    }
    return _PlaybackWait.elapsed;
  }

  Future<_PlaybackWait> _wait(
    Duration duration, {
    required Future<void> playback,
    Future<void>? interrupt,
  }) {
    return Future.any<_PlaybackWait>(<Future<_PlaybackWait>>[
      Future<void>.delayed(duration).then((_) => _PlaybackWait.elapsed),
      playback.then((_) => _PlaybackWait.finished),
      if (interrupt != null) interrupt.then((_) => _PlaybackWait.interrupted),
    ]);
  }

  Future<void> _fadeOutAndStop(Future<void> playback) async {
    await _fadeTo(
      0,
      _transitionFadeDuration,
      playback: playback,
    );
    await _player.stop();
    _currentVolume = 0;
  }

  void _signalInterrupt() {
    final Completer<void>? interrupt = _interrupt;
    if (interrupt != null && !interrupt.isCompleted) interrupt.complete();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool active = state == AppLifecycleState.resumed;
    if (_appActive == active) return;
    _appActive = active;
    if (!active) {
      _revision++;
      _signalInterrupt();
    } else {
      _ensureRunner();
    }
  }
}
