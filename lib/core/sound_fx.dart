import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../config/.env.dart';
import '../config/assets.dart';

/// Lightweight helper that manages short poker table sound effects.
class SoundFx {
  SoundFx._();

  static final SoundFx instance = SoundFx._();
  final Random _rand = Random();

  final Map<String, List<AudioPlayer>> _players = <String, List<AudioPlayer>>{};
  final Set<AudioPlayer> _busyPlayers = <AudioPlayer>{};
  AudioPlayer? _callCoinPlayer;
  int _queuedCallCoins = 0;
  bool _drainingCallCoins = false;
  bool _muted = false;
  bool _unlocked = !kIsWeb;
  DateTime? _lastHandWinAt;
  DateTime? _lastShuffleAt;
  bool _shufflePlaying = false;

  bool get _enabled => Env.soundEnabled && !_muted && _unlocked;
  bool get needsUnlock => !_unlocked;

  /// Toggle sounds at runtime in addition to the compile-time Env flag.
  void setMuted(bool value) => _muted = value;

  Future<void> unlock() async {
    if (_unlocked) return;
    _unlocked = true;
    await preloadDefaults();
  }

  Future<void> preloadDefaults() async {
    if (!_enabled) return;
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
      AppAssets.heroTurnSound,
      AppAssets.applauseSound,
      AppAssets.doorKnockSound,
      AppAssets.knock1Sound,
    };
    await Future.wait(assets.map(_ensurePlayer));
  }

  Future<void> playDeal() => _play(AppAssets.dealCardSound, volume: 0.85);
  Future<void> playFold() => _play(AppAssets.foldSound, volume: 0.75);
  Future<void> playCheck() {
    // 15% door knock, 85% knock1 to mix variety on checks.
    final bool useDoor = _rand.nextDouble() < 0.15;
    final String clip =
        useDoor ? AppAssets.doorKnockSound : AppAssets.knock1Sound;
    return _play(clip, volume: 0.75);
  }

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
      _play(AppAssets.playerAllInSound, volume: 0.9, allowOverlap: false);
  Future<void> playHeroBust() =>
      _play(AppAssets.heroBustSound, volume: 0.92, allowOverlap: false);
  Future<void> playRaiseAtm() => _play(AppAssets.raiseSound, volume: 0.95);
  Future<void> playCallCoin() => _playCallCoin();
  Future<void> playPotIncrease() =>
      _play(AppAssets.potIncreaseSound, volume: 0.9);
  Future<void> playHeroTurn() => _maybePlayHeroTurn();
  Future<void> playApplause() =>
      _play(AppAssets.applauseSound, volume: 0.4, allowOverlap: false);

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
    await _callCoinPlayer?.stop();
    await _callCoinPlayer?.dispose();
    _callCoinPlayer = null;
  }

  Future<void> _play(String asset,
      {double volume = 1.0, bool allowOverlap = true}) async {
    if (!_enabled) return;
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
        }),
      );
    } catch (err, stack) {
      debugPrint('🔇 SoundFx error for $asset → $err');
      debugPrint('$stack');
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

  Future<void> _playCallCoin() async {
    if (!_enabled) return;
    _queuedCallCoins++;
    if (_drainingCallCoins) return;
    _drainingCallCoins = true;
    try {
      final player = await _ensureCallCoinPlayer();
      while (_queuedCallCoins > 0) {
        _queuedCallCoins--;
        try {
          await player.stop();
        } catch (_) {}
        await player.setVolume(0.11875);
        await player.seek(Duration.zero);
        await player.play().catchError((_) {});
      }
    } catch (err, stack) {
      debugPrint('🔇 Call coin sound error → $err');
      debugPrint('$stack');
    } finally {
      _drainingCallCoins = false;
    }
  }

  Future<AudioPlayer> _ensureCallCoinPlayer() async {
    if (_callCoinPlayer != null) return _callCoinPlayer!;
    final player = AudioPlayer();
    await player.setAsset(AppAssets.callCoinSound);
    _callCoinPlayer = player;
    return player;
  }

  Future<void> _maybePlayHeroTurn() async {
    // Always play the turn notification when requested; no cooldown.
    await _play(
      AppAssets.heroTurnSound,
      volume: 0.90,
      allowOverlap: false,
    );
  }

  Future<void> _stopPlayers(String asset) async {
    final pool = _players[asset];
    if (pool == null) return;
    for (final player in List<AudioPlayer>.from(pool)) {
      try {
        await player.stop();
      } catch (_) {}
      _busyPlayers.remove(player);
    }
  }
}
