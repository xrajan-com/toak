import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

import 'package:ten_of_a_kind_poker/config/.env.dart';
import 'package:ten_of_a_kind_poker/config/kingdom_scenes.dart';

/// A moment at the table the scene behind it can react to.
enum AmbienceMoment {
  /// Anyone goes all-in.
  allIn,

  /// The player wins a big pot.
  heroBigWin,
}

/// The sound of the scene behind the table: a quiet loop of the place (waves,
/// a pub, a stadium; one of [AmbienceBed]) and, now and then, the place
/// reacting to a big moment: a war horn on an all-in, the crowd when the
/// player takes a big pot.
///
/// Files live in `assets/sounds/ambience/`: `bed_<bed>.m4a` loops and
/// `react_<name>.m4a` one-shots, made by `tools/sounds/build_ambience.py`.
/// A file that is missing is skipped, so a scene without its sound is quiet.
///
/// Two players take turns on the loop and cross-fade at the seam, so a loop
/// never clicks or gaps on any platform.
class AmbienceService extends WidgetsBindingObserver {
  AmbienceService._();

  static final AmbienceService instance = AmbienceService._();

  static const String folder = 'assets/sounds/ambience/';

  static String bedAsset(AmbienceBed bed) => '${folder}bed_${bed.name}.m4a';

  static String reactionAsset(String name) => '${folder}react_$name.m4a';

  /// Every file is levelled like the table effects (about -20 dBFS RMS; see
  /// SoundMix), so the bed sits about 18 dB under the file, well beneath the
  /// cards and chips and a little under the lounge music. Reactions sit just
  /// under the chips. (Both were turned down by a fifth, Nov 2026.)
  static const double bedVolume = 0.128;
  static const double reactionVolume = 0.336;

  /// While the dealer speaks, the bed drops to this share of its level.
  static const double duckFactor = 0.35;
  static const Duration duckHold = Duration(milliseconds: 1600);

  static const Duration fadeIn = Duration(seconds: 5);
  static const Duration fadeOut = Duration(milliseconds: 1500);
  static const Duration crossfade = Duration(seconds: 3);

  /// The same reaction plays at most once in this window: all-ins come in
  /// clusters late in a game, and a horn on every one of them is noise.
  static const Duration reactionGap = Duration(seconds: 75);

  /// Every reaction [reactionFor] can name.
  static const List<String> reactionNames = <String>[
    'horn',
    'ooh',
    'cheer',
    'toast',
    'fireworks',
  ];

  /// Which reaction, if any, [scene] plays for [moment]; the name of a
  /// `react_<name>.m4a` file.
  static String? reactionFor(KingdomScene scene, AmbienceMoment moment) {
    switch (moment) {
      case AmbienceMoment.allIn:
        if (scene.kind == SceneKind.history) return 'horn';
        if (scene.bed == AmbienceBed.stadium) return 'ooh';
        return null;
      case AmbienceMoment.heroBigWin:
        switch (scene.bed) {
          case AmbienceBed.stadium:
          case AmbienceBed.concert:
            return 'cheer';
          case AmbienceBed.pub:
          case AmbienceBed.casino:
            return 'toast';
          case AmbienceBed.festival:
            return 'fireworks';
          default:
            return null;
        }
    }
  }

  /// Test seam: when set, every sound that would start is reported here
  /// (asset and volume) instead of reaching an audio player.
  @visibleForTesting
  void Function(String asset, double volume)? debugOnPlay;

  /// Test seam: the assets the app ships, instead of the asset manifest.
  @visibleForTesting
  Set<String>? debugAssets;

  final List<AudioPlayer?> _bedPlayers = <AudioPlayer?>[null, null];
  AudioPlayer? _reactionPlayer;
  int _active = 0;
  KingdomScene? _scene;
  Set<String>? _assets;
  final Map<String, DateTime> _lastReaction = <String, DateTime>{};
  Timer? _seamTimer;
  Timer? _unduckTimer;
  int _revision = 0;
  bool _muted = false;
  bool _unlocked = !kIsWeb;
  bool _appActive = true;
  bool _ducked = false;
  bool _observing = false;

  bool get _enabled => Env.soundEnabled && !_muted && _unlocked && _appActive;

  double get _bedTarget => bedVolume * (_ducked ? duckFactor : 1);

  @visibleForTesting
  KingdomScene? get scene => _scene;

  /// Settings: the "Scene sounds" switch.
  void setMuted(bool value) {
    if (_muted == value) return;
    _muted = value;
    if (value) {
      unawaited(_stopBed());
      unawaited(_reactionPlayer?.stop());
    } else {
      unawaited(_startBed());
    }
  }

  /// On the web, sound may start only after the player has touched the page.
  Future<void> unlock() async {
    if (_unlocked) return;
    _unlocked = true;
    await _startBed();
  }

  /// Starts the sound of [scene] at the table; null stops it.
  Future<void> play(KingdomScene? scene) async {
    if (scene?.id == _scene?.id && _bedPlayers[_active]?.playing == true) {
      return;
    }
    _scene = scene;
    _lastReaction.clear();
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    await _stopBed();
    await _startBed();
  }

  /// Leaving the table.
  Future<void> stop() async {
    _scene = null;
    await _stopBed();
    await _reactionPlayer?.stop();
  }

  /// The dealer is about to speak: the bed steps back for a moment.
  void duck() {
    _unduckTimer?.cancel();
    _unduckTimer = Timer(duckHold, () {
      _ducked = false;
      _setBedVolume();
    });
    if (_ducked) return;
    _ducked = true;
    _setBedVolume();
  }

  /// The place reacts to [moment], if this scene has a reaction for it.
  Future<void> react(AmbienceMoment moment) async {
    final KingdomScene? scene = _scene;
    if (scene == null || !_enabled) return;
    final String? name = reactionFor(scene, moment);
    if (name == null) return;
    final DateTime now = DateTime.now();
    final DateTime? last = _lastReaction[name];
    if (last != null && now.difference(last) < reactionGap) return;
    final String asset = reactionAsset(name);
    if (!await _has(asset)) return;
    _lastReaction[name] = now;
    final void Function(String, double)? onPlay = debugOnPlay;
    if (onPlay != null) {
      onPlay(asset, reactionVolume);
      return;
    }
    try {
      final AudioPlayer player = _reactionPlayer ??= _newPlayer();
      await player.stop();
      await player.setAsset(asset);
      await player.setVolume(reactionVolume);
      unawaited(player.play().catchError((_) {}));
    } catch (error) {
      debugPrint('Ambience reaction $asset failed: $error');
    }
  }

  /// The scene's sound never takes the phone's audio focus: a player's own
  /// music keeps playing, and the bed simply sits underneath it.
  AudioPlayer _newPlayer() => AudioPlayer(handleAudioSessionActivation: false);

  Future<void> _startBed() async {
    final KingdomScene? scene = _scene;
    if (scene == null || !_enabled) return;
    final String asset = bedAsset(scene.bed);
    if (!await _has(asset)) return;
    final int revision = ++_revision;
    final void Function(String, double)? onPlay = debugOnPlay;
    if (onPlay != null) {
      onPlay(asset, bedVolume);
      return;
    }
    try {
      final AudioPlayer player = _bedPlayers[_active] ??= _newPlayer();
      final Duration? length = await player.setAsset(asset);
      if (revision != _revision) return;
      await player.setVolume(0);
      unawaited(player.play().catchError((_) {}));
      unawaited(_fade(player, 0, _bedTarget, fadeIn, revision));
      _scheduleSeam(asset, length, revision);
    } catch (error) {
      debugPrint('Ambience bed $asset failed: $error');
    }
  }

  /// Before the loop ends, the other player starts it again from the top and
  /// the two cross-fade.
  void _scheduleSeam(String asset, Duration? length, int revision) {
    _seamTimer?.cancel();
    if (length == null || length <= crossfade * 2) return;
    _seamTimer = Timer(length - crossfade, () async {
      if (revision != _revision || !_enabled) return;
      final AudioPlayer outgoing = _bedPlayers[_active]!;
      _active = 1 - _active;
      final AudioPlayer incoming = _bedPlayers[_active] ??= _newPlayer();
      try {
        final Duration? next = await incoming.setAsset(asset);
        if (revision != _revision) return;
        await incoming.setVolume(0);
        unawaited(incoming.play().catchError((_) {}));
        unawaited(_fade(incoming, 0, _bedTarget, crossfade, revision));
        unawaited(_fade(outgoing, outgoing.volume, 0, crossfade, revision)
            .then((_) => outgoing.stop()));
        _scheduleSeam(asset, next ?? length, revision);
      } catch (error) {
        debugPrint('Ambience loop $asset failed: $error');
      }
    });
  }

  Future<void> _stopBed() async {
    final int revision = ++_revision;
    _seamTimer?.cancel();
    final List<Future<void>> fades = <Future<void>>[];
    for (final AudioPlayer? player in _bedPlayers) {
      if (player == null || !player.playing) continue;
      fades.add(_fade(player, player.volume, 0, fadeOut, revision, force: true)
          .then((_) => player.stop()));
    }
    await Future.wait(fades);
  }

  void _setBedVolume() {
    final AudioPlayer? player = _bedPlayers[_active];
    if (player == null || !player.playing) return;
    unawaited(_fade(player, player.volume, _bedTarget,
        const Duration(milliseconds: 250), _revision));
  }

  Future<void> _fade(
    AudioPlayer player,
    double from,
    double to,
    Duration duration,
    int revision, {
    bool force = false,
  }) async {
    const int steps = 20;
    final Duration step = duration ~/ steps;
    for (int i = 1; i <= steps; i++) {
      if (!force && revision != _revision) return;
      await Future<void>.delayed(step);
      try {
        await player.setVolume((from + (to - from) * i / steps).clamp(0, 1));
      } catch (_) {
        return;
      }
    }
  }

  Future<bool> _has(String asset) async {
    final Set<String>? known = debugAssets ?? _assets;
    if (known != null) return known.contains(asset);
    try {
      final AssetManifest manifest =
          await AssetManifest.loadFromAssetBundle(rootBundle);
      _assets = manifest
          .listAssets()
          .where((String a) => a.startsWith(folder))
          .toSet();
    } catch (error) {
      debugPrint('Ambience: no asset manifest ($error)');
      _assets = <String>{};
    }
    return _assets!.contains(asset);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bool active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    if (active) {
      unawaited(_startBed());
    } else {
      unawaited(_stopBed());
      unawaited(_reactionPlayer?.stop());
    }
  }
}
