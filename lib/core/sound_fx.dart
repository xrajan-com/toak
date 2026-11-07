import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../config/.env.dart';
import '../config/assets.dart';
import '../services/ambience_service.dart';
import '../services/x_music_service.dart';

/// Playback levels for the table.
///
/// Every effect file in assets/sounds was levelled to about -20 dBFS RMS
/// (Oct 2026), and the dealer voice clips sit near -13 dBFS, so these numbers
/// are the mix itself: cards and chips in front (about -28 dB), the dealer
/// voice just behind them (-23 dB), big moments a little louder, and music
/// (XMusicService.maxVolume) well underneath.
class SoundMix {
  SoundMix._();

  static const double shuffle = 0.56;
  static const double deal = 0.50;
  static const double boardCard = 0.53;
  static const double foldCards = 0.30;
  static const double checkKnock = 0.50;
  static const double potChips = 0.60;
  static const double raiseChips = 0.40;
  static const double allInChips = 0.55;
  static const double actionTap = 0.26;
  static const double heroTurn = 0.73;
  static const double rakeToHero = 0.66;
  static const double rakeToOther = 0.37;
  static const double bigPotFanfare = 0.76;
  static const double playerBusted = 0.46;
  static const double heroBust = 0.69;
  static const double gameWin = 1.0;
  static const double applause = 0.46;
  static const double welcome = 0.46;

  static const double voiceAllIn = 0.33;
  static const double voiceCall = 0.30;
  static const double voiceCheck = 0.38;
  static const double voiceFold = 0.34;
  static const double voiceRaise = 0.27;
}

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
  // Hole cards emit one CardDealt event each, 80 ms apart (kDealGapMs), so a
  // full round is ~1.6 s of events. shuffle.wav — which deals reuse — is
  // 1.56 s long, so one play already spans the whole round. Anything shorter
  // than this window either layers the sample on itself or restarts it every
  // 80 ms, which reads as a stutter.
  static const Duration _kDealRoundWindow = Duration(milliseconds: 1800);
  // The flop arrives as three CardDealt events at once; one card sound per
  // street reads as the dealer spreading it.
  static const Duration _kBoardCardWindow = Duration(milliseconds: 300);
  // Blinds and antes land in the pot together; one clink covers them.
  static const Duration _kPotChipsWindow = Duration(milliseconds: 150);
  // Sound effects are on by default, so they start unmuted and preload
  // ready to play immediately — settings load mutes them only if the user
  // has turned them off. Lounge/table music (XMusicService) is the one
  // audio layer that still starts muted, since it's ambient rather than
  // informational.
  bool _soundEffectsMuted = false;
  // The dealer voice is on by default too, so it starts unmuted — settings
  // load mutes it only if the user has turned it off. By default she calls
  // only all-ins, the way a live dealer does; calling every check, call,
  // raise and fold is an opt-in setting.
  bool _voiceMuted = false;
  bool _voiceEveryAction = false;
  bool _unlocked = !kIsWeb;
  DateTime? _lastShuffleAt;
  DateTime? _lastBoardCardAt;
  DateTime? _lastPotChipsAt;
  DateTime? _lastDealAt;
  DateTime? _lastAnnouncerAt;
  String? _lastAnnouncerAsset;
  bool _shufflePlaying = false;
  bool _dealPlaying = false;

  /// Test seam: when set, every sound that would play is reported here
  /// (asset and volume) instead of reaching an audio player.
  @visibleForTesting
  void Function(String asset, double volume)? debugOnPlay;

  bool get _baseEnabled => Env.soundEnabled && _unlocked;
  bool get _soundEffectsEnabled => _baseEnabled && !_soundEffectsMuted;
  bool get _voiceEnabled => _baseEnabled && !_voiceMuted;
  bool get needsUnlock => !_unlocked;

  /// Legacy master mute used by tests and callers that want complete silence.
  void setMuted(bool value) {
    _soundEffectsMuted = value;
    _voiceMuted = value;
    if (value) unawaited(stopAll());
    XMusicService.instance.setMuted(value);
    AmbienceService.instance.setMuted(value);
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

  /// When true the dealer voice calls every action; otherwise only all-ins.
  void setVoiceEveryAction(bool value) {
    _voiceEveryAction = value;
  }

  @visibleForTesting
  bool get voiceEveryAction => _voiceEveryAction;

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
      AppAssets.chipsRakeSound,
      AppAssets.heroLeaderSound,
      AppAssets.gameWinSound,
      AppAssets.playerBustedSound,
      AppAssets.heroBustSound,
      AppAssets.coinSound,
      AppAssets.betSound,
      AppAssets.actionTapSound,
      AppAssets.heroTurnNotificationSound,
      AppAssets.applauseSound,
      ..._announcerAssets,
    };
    await Future.wait(assets.map(_ensurePlayer));
  }

  Future<void> playDeal() async {
    // dealCardSound and shuffleSound are the same asset, so under
    // allowOverlap: false they share one player — and _play stops that player
    // before it restarts. A deal landing mid-shuffle would cut the shuffle off
    // and replay it from zero. Since it is the same 1.56 s sample either way,
    // a fresh shuffle already covers the deal: let it finish instead.
    if (_shufflePlaying || _dealPlaying) return;
    final now = DateTime.now();
    if (_lastDealAt != null &&
        now.difference(_lastDealAt!) < _kDealRoundWindow) {
      return;
    }
    if (_lastShuffleAt != null &&
        now.difference(_lastShuffleAt!) < _kDealRoundWindow) {
      return;
    }
    _lastDealAt = now;
    _dealPlaying = true;
    try {
      await _play(AppAssets.dealCardSound,
          volume: SoundMix.deal, allowOverlap: false);
    } finally {
      _dealPlaying = false;
    }
  }

  /// A player folds: the cards slide into the muck, quietly.
  Future<void> playFold() async {
    await _play(AppAssets.foldSound, volume: SoundMix.foldCards);
    if (_voiceEveryAction) {
      await _playAnnouncer(AppAssets.renoirFemaleFoldAnnouncer,
          volume: SoundMix.voiceFold);
    }
  }

  /// A community card is turned. The flop's three cards share one sound.
  Future<void> playBoardCard() async {
    final DateTime now = DateTime.now();
    if (_lastBoardCardAt != null &&
        now.difference(_lastBoardCardAt!) < _kBoardCardWindow) {
      return;
    }
    _lastBoardCardAt = now;
    await _play(AppAssets.foldSound, volume: SoundMix.boardCard);
  }

  /// A player checks: a knock on the felt.
  Future<void> playCheck() async {
    await _play(AppAssets.checkSound, volume: SoundMix.checkKnock);
    if (_voiceEveryAction) {
      await _playAnnouncer(AppAssets.renoirFemaleCheckAnnouncer,
          volume: SoundMix.voiceCheck);
    }
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
      await _play(AppAssets.shuffleSound,
          volume: SoundMix.shuffle, allowOverlap: false);
    } finally {
      _shufflePlaying = false;
    }
  }

  Future<void> playWelcome() => _play(AppAssets.welcomeSound,
      volume: SoundMix.welcome, allowOverlap: false);

  /// Chips swept to the winner of a hand. Only a big pot the player wins gets
  /// the fanfare; a pot a bot wins is just chips moving.
  Future<void> playChipsToWinner({
    required bool heroWon,
    bool bigPot = false,
  }) async {
    if (heroWon && bigPot) {
      await _play(AppAssets.heroLeaderSound,
          volume: SoundMix.bigPotFanfare, allowOverlap: false);
    }
    await _play(AppAssets.chipsRakeSound,
        volume: heroWon ? SoundMix.rakeToHero : SoundMix.rakeToOther,
        allowOverlap: false);
  }

  Future<void> playGameWin() => _play(AppAssets.gameWinSound,
      volume: SoundMix.gameWin, allowOverlap: false);
  Future<void> playGameWinnerApplause() => _play(AppAssets.applauseSound,
      volume: SoundMix.applause, allowOverlap: false);
  Future<void> playHeroLeader() async {
    // Temporarily disabled per product request.
  }
  Future<void> playHeroDanger() async {
    // Temporarily disabled per product request.
  }
  Future<void> playPlayerBusted() => _play(AppAssets.playerBustedSound,
      volume: SoundMix.playerBusted, allowOverlap: false);

  /// An all-in: the chips go in, and the dealer calls it.
  Future<void> playPlayerAllIn() async {
    await _play(AppAssets.betSound, volume: SoundMix.allInChips);
    await _playAnnouncer(AppAssets.renoirFemaleAllInAnnouncer,
        volume: SoundMix.voiceAllIn);
  }

  Future<void> playHeroBust() => _play(AppAssets.heroBustSound,
      volume: SoundMix.heroBust, allowOverlap: false);

  /// A bet or raise: a stack of chips pushed forward. The clink of the chips
  /// landing comes from [playPotIncrease].
  Future<void> playRaiseAtm() async {
    await _play(AppAssets.raiseSound, volume: SoundMix.raiseChips);
    if (_voiceEveryAction) {
      await _playAnnouncer(AppAssets.renoirFemaleRaiseAnnouncer,
          volume: SoundMix.voiceRaise);
    }
  }

  Future<void> playActionTap() =>
      _play(AppAssets.actionTapSound, volume: SoundMix.actionTap);
  Future<void> playHeroTurnNotification() => _play(
        AppAssets.heroTurnNotificationSound,
        volume: SoundMix.heroTurn,
        allowOverlap: false,
      );

  /// A call. Its chips clink through [playPotIncrease]; the voice is opt-in.
  Future<void> playCallCoin() async {
    if (_voiceEveryAction) {
      await _playAnnouncer(AppAssets.renoirFemaleCallAnnouncer,
          volume: SoundMix.voiceCall);
    }
  }

  /// Chips land in the pot (blinds, antes, calls, bets and raises).
  Future<void> playPotIncrease() async {
    final DateTime now = DateTime.now();
    if (_lastPotChipsAt != null &&
        now.difference(_lastPotChipsAt!) < _kPotChipsWindow) {
      return;
    }
    _lastPotChipsAt = now;
    await _play(AppAssets.potIncreaseSound, volume: SoundMix.potChips);
  }

  Future<void> playApplause() => _play(AppAssets.applauseSound,
      volume: SoundMix.applause, allowOverlap: false);

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
    _dealPlaying = false;
    _lastShuffleAt = null;
    _lastDealAt = null;
    _lastBoardCardAt = null;
    _lastPotChipsAt = null;
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
    final void Function(String, double)? onPlay = debugOnPlay;
    if (onPlay != null) {
      onPlay(asset, volume);
      return;
    }
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
    final void Function(String, double)? onPlay = debugOnPlay;
    if (onPlay != null) {
      onPlay(asset, volume);
      return;
    }
    await _trimAnnouncerOverlap();
    // The scene's own sound steps back while the dealer speaks.
    AmbienceService.instance.duck();
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
