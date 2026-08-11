import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../config/.env.dart';
import '../config/assets.dart';

/// Lightweight helper that manages short poker table sound effects.
class SoundFx {
  SoundFx._();

  static final SoundFx instance = SoundFx._();

  final Map<String, List<AudioPlayer>> _players = <String, List<AudioPlayer>>{};
  final Set<AudioPlayer> _busyPlayers = <AudioPlayer>{};
  final Set<String> _announcerAssets = <String>{
    AppAssets.renoirFemaleCheckAnnouncer,
    AppAssets.renoirFemaleCallAnnouncer,
    AppAssets.renoirFemaleRaiseAnnouncer,
    AppAssets.renoirFemaleAllInAnnouncer,
    AppAssets.renoirFemaleFoldAnnouncer,
  };
  final Map<AudioPlayer, DateTime> _activeAnnouncerPlayers =
      <AudioPlayer, DateTime>{};
  static const int _kMaxAnnouncerOverlap = 2;
  static const Duration _kDuplicateAnnouncerCooldown =
      Duration(milliseconds: 520);
  bool _soundEffectsMuted = false;
  bool _voiceMuted = false;
  bool _unlocked = !kIsWeb;
  DateTime? _lastHandWinAt;
  DateTime? _lastShuffleAt;
  DateTime? _lastAnnouncerAt;
  String? _lastAnnouncerAsset;
  bool _shufflePlaying = false;

  bool get _baseEnabled => Env.soundEnabled && _unlocked;
  bool get _soundEffectsEnabled => _baseEnabled && !_soundEffectsMuted;
  bool get _voiceEnabled => _baseEnabled && !_voiceMuted;
  bool get needsUnlock => !_unlocked;

  /// Legacy master mute used by tests and callers that want complete silence.
  void setMuted(bool value) {
    _soundEffectsMuted = value;
    _voiceMuted = value;
    if (value) unawaited(stopAll());
  }

  void setSoundEffectsMuted(bool value) {
    _soundEffectsMuted = value;
    if (value) {
      unawaited(_stopNonAnnouncerPlayers());
    }
  }

  void setVoiceMuted(bool value) {
    _voiceMuted = value;
    if (value) unawaited(stopAnnouncer());
  }

  Future<void> unlock() async {
    if (_unlocked) return;
    _unlocked = true;
    await preloadDefaults();
  }

  Future<void> preloadDefaults() async {
    if (!_baseEnabled) return;
    final assets = <String>{
      AppAssets.dealCardSound,
      AppAssets.foldSound,
      AppAssets.checkSound,
      AppAssets.welcomeSound,
      AppAssets.handWinSound,
      AppAssets.heroLeaderSound,
      AppAssets.gameWinSound,
      AppAssets.playerBustedSound,
      AppAssets.playerAllInSound,
      AppAssets.heroBustSound,
      AppAssets.raiseSound,
      AppAssets.callCoinSound,
      AppAssets.actionTapSound,
      AppAssets.heroTurnNotificationSound,
      AppAssets.applauseSound,
      AppAssets.doorKnockSound,
      AppAssets.knock1Sound,
      ..._announcerAssets,
    };
    await Future.wait(assets.map(_ensurePlayer));
  }

  Future<void> playDeal() => _play(AppAssets.dealCardSound, volume: 0.85);
  Future<void> playFold() =>
      _playAnnouncer(AppAssets.renoirFemaleFoldAnnouncer, volume: 0.46);
  Future<void> playCheck() =>
      _playAnnouncer(AppAssets.renoirFemaleCheckAnnouncer, volume: 0.54);

  Future<void> playShuffle() async {
    // Prevent accidental double-trigger (observed when shuffle fires twice).
    final now = DateTime.now();
    if (_shufflePlaying) return;
    if (_lastShuffleAt != null &&
        now.difference(_lastShuffleAt!).inMilliseconds < 700) {
      return;
    }
    _lastShuffleAt = now;
    _shufflePlaying = true;
    try {
      await _stopPlayers(AppAssets.shuffleSound);
      await _play(AppAssets.shuffleSound, volume: 0.45, allowOverlap: false);
    } finally {
      _shufflePlaying = false;
    }
  }

  Future<void> playWelcome() =>
      _play(AppAssets.welcomeSound, volume: 0.8, allowOverlap: false);
  Future<void> playHandWin() async {
    _lastHandWinAt = DateTime.now();
    await _play(AppAssets.handWinSound, volume: 0.95, allowOverlap: false);
  }

  Future<void> playHeroHandWin() =>
      _play(AppAssets.heroLeaderSound, volume: 0.95, allowOverlap: false);
  Future<void> playGameWin() =>
      _play(AppAssets.gameWinSound, volume: 0.95, allowOverlap: false);
  Future<void> playGameLost() =>
      _play(AppAssets.gameLostSound, volume: 0.85, allowOverlap: false);
  Future<void> playGameWinnerApplause() =>
      _play(AppAssets.applauseSound, volume: 0.48, allowOverlap: false);
  Future<void> playHeroLeader() async {
    // Temporarily disabled per product request.
  }
  Future<void> playHeroDanger() async {
    // Temporarily disabled per product request.
  }
  Future<void> playPlayerBusted() =>
      _play(AppAssets.playerBustedSound, volume: 0.85, allowOverlap: false);
  Future<void> playPlayerAllIn() =>
      _playAnnouncer(AppAssets.renoirFemaleAllInAnnouncer, volume: 0.47);
  Future<void> playHeroBust() =>
      _play(AppAssets.heroBustSound, volume: 0.92, allowOverlap: false);
  Future<void> playRaiseAtm() =>
      _playAnnouncer(AppAssets.renoirFemaleRaiseAnnouncer, volume: 0.46);
  Future<void> playActionTap() => _play(AppAssets.actionTapSound, volume: 0.7);
  Future<void> playHeroTurnNotification() => _play(
        AppAssets.heroTurnNotificationSound,
        volume: 0.9,
        allowOverlap: false,
      );
  Future<void> playCallCoin() =>
      _playAnnouncer(AppAssets.renoirFemaleCallAnnouncer, volume: 0.46);
  Future<void> playPotIncrease() =>
      _play(AppAssets.potIncreaseSound, volume: 0.9);
  Future<void> playApplause() =>
      _play(AppAssets.applauseSound, volume: 0.4, allowOverlap: false);

  Future<void> stopAnnouncer() async {
    for (final String announcerAsset in _announcerAssets) {
      await _stopPlayers(announcerAsset);
    }
    _activeAnnouncerPlayers.clear();
    _lastAnnouncerAsset = null;
    _lastAnnouncerAt = null;
  }

  Future<void> stopAll() async {
    for (final asset in _players.keys.toList(growable: false)) {
      await _stopPlayers(asset);
    }
    _busyPlayers.clear();
    _activeAnnouncerPlayers.clear();
    _lastAnnouncerAsset = null;
    _lastAnnouncerAt = null;
    _shufflePlaying = false;
  }

  Future<void> dispose() async {
    for (final pool in _players.values) {
      for (final player in pool) {
        try {
          await player.stop();
          await player.dispose();
        } catch (_) {}
      }
    }
    _players.clear();
    _busyPlayers.clear();
  }

  Future<void> _play(String asset,
      {double volume = 1.0, bool allowOverlap = true}) async {
    if (!_soundEffectsEnabled) return;
    try {
      final player = await _ensurePlayer(asset, allowOverlap: allowOverlap);
      if (player == null) return;
      _busyPlayers.add(player);
      try {
        await player.stop();
      } catch (_) {}
      await player.setVolume(volume.clamp(0, 1));
      await player.seek(Duration.zero);
      final playFuture = player.play();
      unawaited(
        playFuture.catchError((_) {}).whenComplete(() {
          _busyPlayers.remove(player);
          _activeAnnouncerPlayers.remove(player);
        }),
      );
    } catch (err, stack) {
      debugPrint('🔇 SoundFx error for $asset → $err');
      debugPrint('$stack');
    }
  }

  Future<void> _playAnnouncer(String asset, {double volume = 1.0}) async {
    if (!_voiceEnabled) return;
    final now = DateTime.now();
    if (_lastAnnouncerAsset == asset &&
        _lastAnnouncerAt != null &&
        now.difference(_lastAnnouncerAt!) < _kDuplicateAnnouncerCooldown) {
      return;
    }
    _lastAnnouncerAsset = asset;
    _lastAnnouncerAt = now;
    await _trimAnnouncerOverlap();
    final AudioPlayer? player = await _ensurePlayer(asset, allowOverlap: true);
    if (player == null) return;
    _activeAnnouncerPlayers[player] = now;
    _busyPlayers.add(player);
    try {
      await player.stop();
    } catch (_) {}
    await player.setVolume(volume.clamp(0, 1));
    await player.seek(Duration.zero);
    final playFuture = player.play();
    unawaited(
      playFuture.catchError((_) {}).whenComplete(() {
        _busyPlayers.remove(player);
        _activeAnnouncerPlayers.remove(player);
      }),
    );
  }

  Future<void> _trimAnnouncerOverlap() async {
    final List<MapEntry<AudioPlayer, DateTime>> active = _activeAnnouncerPlayers
        .entries
        .where((entry) => _busyPlayers.contains(entry.key))
        .toList()
      ..sort(
        (a, b) => a.value.compareTo(b.value),
      );
    while (active.length >= _kMaxAnnouncerOverlap) {
      final AudioPlayer player = active.removeAt(0).key;
      try {
        await player.stop();
      } catch (_) {}
      _busyPlayers.remove(player);
      _activeAnnouncerPlayers.remove(player);
    }
  }

  Future<void> _stopNonAnnouncerPlayers() async {
    for (final String asset in _players.keys.toList(growable: false)) {
      if (_announcerAssets.contains(asset)) continue;
      await _stopPlayers(asset);
    }
  }

  Future<AudioPlayer?> _ensurePlayer(String asset,
      {bool allowOverlap = true}) async {
    final pool = _players.putIfAbsent(asset, () => <AudioPlayer>[]);
    for (final player in pool) {
      if (!_busyPlayers.contains(player)) {
        return player;
      }
    }
    if (!allowOverlap && pool.isNotEmpty) {
      final player = pool.first;
      if (_busyPlayers.contains(player)) {
        try {
          await player.stop();
        } catch (_) {}
        _busyPlayers.remove(player);
      }
      return player;
    }
    final AudioPlayer player = AudioPlayer();
    await player.setAsset(asset);
    pool.add(player);
    return player;
  }

  Future<void> _stopPlayers(String asset) async {
    final pool = _players[asset];
    if (pool == null) return;
    for (final player in List<AudioPlayer>.from(pool)) {
      try {
        await player.stop();
      } catch (_) {}
      _busyPlayers.remove(player);
      _activeAnnouncerPlayers.remove(player);
    }
  }
}
