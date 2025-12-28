// lib/game/game_engine.dart
import 'dart:async';
import 'dart:math' show Random, min, max;

import 'core.dart'
    show Card, Deck, GamePhase, ActionType, Suit, Rank, rankValue;
import 'hand_evaluator.dart' show HandRank, HandEvaluator, HandCategory;
import 'models.dart'
    show
        BlindLevel,
        BlindSchedule,
        GameConfig,
        Player,
        PotSlice,
        Payout,
        GameSnapshot,
        PlayerSnapshot;
import 'events.dart';
import 'rng.dart';

// Re-exports for convenience
export 'core.dart' show Card, GamePhase, ActionType, Suit, Rank, rankValue;
export 'hand_evaluator.dart' show HandCategory, HandRank, HandEvaluator;
export 'models.dart'
    show
        BlindLevel,
        BlindSchedule,
        GameConfig,
        Player,
        Payout,
        PotSlice,
        GameSnapshot,
        PlayerSnapshot;

part 'bot_engine.dart';

const int _kRaiseIncrement = 10; // enforce bet/raise granularity

/// Public expose of bet/raise increment so UI can snap slider values.
const int kRaiseIncrement = _kRaiseIncrement;

class GameEngine {
  final GameConfig config;

  // Table state
  final List<Player> players = [];
  final List<Card> community = [];

  // Events
  final List<EngineEvent> _eventLog = [];
  List<EngineEvent> get eventLog => List.unmodifiable(_eventLog);

  final List<EngineListener> _listeners = [];
  void addListener(EngineListener l) => _listeners.add(l);
  void removeListener(EngineListener l) => _listeners.remove(l);

  // Emit concrete events to listeners (matches EngineListener = void Function(EngineEvent)).
  void _emit(EngineEvent e) {
    _eventLog.add(e);
    for (final l in _listeners) {
      l(e);
    }
  }

  // RNG context (table-wide + per-hand copy)
  final Pcg32 _tableRng = Pcg32();
  Pcg32 _handRng = Pcg32();
  static final BigInt _mask64 = BigInt.parse('0xFFFFFFFFFFFFFFFF');
  BigInt _lastHandSeed = BigInt.zero;
  BigInt get lastHandSeed => _lastHandSeed;
  BigInt _tableSeed = BigInt.zero;
  BigInt get tableSeed => _tableSeed;

  // Hand state
  Deck _deck = Deck();
  GamePhase phase = GamePhase.predeal;
  int dealerIndex = -1;
  int actingIndex = 0;
  int currentBet = 0; // current street’s bet-to-match
  int pot = 0;
  int handNumber = 0;

  // Tournament-style blinds (mutable across hands).
  late int _smallBlind;
  late int _bigBlind;
  int _completedOrbits = 0;
  int _blindLevelIndex = 0;
  // Optional: hero seat index for UI conveniences (action bar gating, skip button, etc.)
  int heroIndex = -1; // set from UI if you want precise skip logic
  int _firstActorThisStreet = -1;
  final Set<int> _actedThisStreet = <int>{};

  /// Set the hero index (seat of the human). UI can update this when seats change.
  void setHeroIndex(int index) {
    heroIndex = index;
  }

  /// True if a valid hero seat is set and that seat has folded this hand.
  bool get heroHasFolded {
    if (heroIndex < 0 || heroIndex >= players.length) return false;
    final p = players[heroIndex];
    // Back-compat: accept either `folded` or a dynamic `hasFolded` flag.
    final dynFolded = (() {
      try {
        return (p as dynamic).hasFolded == true;
      } catch (_) {
        return false;
      }
    })();
    return p.folded == true || dynFolded;
  }

  /// True when the hero has folded and the hand is still in progress.
  /// Useful for disabling all action buttons except a UI-level "Skip" button.
  bool get heroCanOnlySkip {
    if (phase == GamePhase.handOver || phase == GamePhase.showdown)
      return false;
    if (heroIndex < 0 || heroIndex >= players.length) return false;
    final p = players[heroIndex];
    if (p.isOut == true || p.sittingOut == true) return false;
    return heroHasFolded;
  }

  // Blinds for the current hand
  int smallBlindIndex = -1;
  int bigBlindIndex = -1;

  // Aggression/raise tracking
  int? _lastAggressor;
  int _lastRaiseSize = 0;

  // Output from last hand
  List<Payout> lastPayouts = const [];

  // Tournament over flag
  bool _tournamentOver = false;
  bool get isTournamentOver => _tournamentOver;

  GameEngine({this.config = const GameConfig()}) {
    _resetBlindsFromConfig();
    if (config.tableSeed != null) {
      _tableRng.reseed(
          seed: BigInt.from(config.tableSeed!), stream: _tableRng.streamBigInt);
      _tableSeed = _tableRng.seedBigInt;
    } else {
      _tableSeed = _tableRng.seedBigInt;
    }
  }

  /* ==================== Configuration / RNG ==================== */

  void _resetBlindsFromConfig() {
    _completedOrbits = 0;
    _blindLevelIndex = 0;
    final BlindSchedule? schedule = config.blindSchedule;
    if (schedule != null && schedule.levels.isNotEmpty) {
      final BlindLevel lvl = schedule.levels.first;
      _smallBlind = lvl.smallBlind;
      _bigBlind = lvl.bigBlind;
      return;
    }
    _smallBlind = config.smallBlind;
    _bigBlind = config.bigBlind;
  }

  int get completedOrbits => _completedOrbits;
  int get blindLevelIndex => _blindLevelIndex;

  void setBlinds({
    required int smallBlind,
    required int bigBlind,
  }) {
    if (smallBlind <= 0) {
      throw ArgumentError.value(smallBlind, 'smallBlind', 'must be > 0');
    }
    if (bigBlind <= 0) {
      throw ArgumentError.value(bigBlind, 'bigBlind', 'must be > 0');
    }
    if (bigBlind < smallBlind) {
      throw ArgumentError('bigBlind must be >= smallBlind');
    }
    _smallBlind = smallBlind;
    _bigBlind = bigBlind;
  }

  void setRandomSeed(int seed) {
    _tableRng.reseed(seed: BigInt.from(seed), stream: _tableRng.streamBigInt);
    _updateTableSeed();
  }

  void setRandom(Random rng) {
    _tableRng.reseed(
        seed: _seedFromRandom(rng), stream: _tableRng.streamBigInt);
    _updateTableSeed();
  }

  void _updateTableSeed() {
    _tableSeed = _tableRng.seedBigInt;
  }

  /* ==================== Convenience Getters ==================== */
  /// Yellow button logic (for UI)
  /// - canSkipToWinner: true if hand is still active (not over/showdown).
  ///   UI may choose to show the skip button only after hero folds.
  bool get canSkipToWinner => heroCanOnlySkip;

  bool get canShowNow {
    if (phase == GamePhase.handOver || phase == GamePhase.showdown)
      return false;
    // If all remaining players are all-in with matched action, we can run out immediately.
    if (_earlyAllInClosed()) return true;
    // If only one live player remains, the hand will auto-award, but SHOW now is also safe.
    final live = players.where(_isLiveInHand).length;
    return live <= 1;
  }

  BigInt _seedFromRandom(Random rng) {
    final BigInt hi = BigInt.from(rng.nextInt(0x100000000));
    final BigInt lo = BigInt.from(rng.nextInt(0x100000000));
    return ((hi << 32) | lo) & _mask64;
  }

  BigInt _nextHandSeed() {
    final BigInt hi = BigInt.from(_tableRng.nextUint32());
    final BigInt lo = BigInt.from(_tableRng.nextUint32());
    return ((hi << 32) | lo) & _mask64;
  }

  void _prepareHandRng({int? seed, Random? rng, Pcg32? pcg}) {
    if (pcg != null) {
      _handRng = pcg.copy();
    } else if (seed != null) {
      _handRng.reseed(seed: BigInt.from(seed));
    } else if (rng != null) {
      _handRng.reseed(seed: _seedFromRandom(rng));
    } else {
      _handRng.reseed(seed: _nextHandSeed());
    }
    _lastHandSeed = _handRng.seedBigInt;
  }

  int get streetBet => currentBet; // alias used by some UIs
  bool get bettingOpen => currentBet > 0;
  int get bigBlind => _bigBlind;
  int get smallBlind => _smallBlind;

  // Eligible to be dealt in the NEXT hand
  bool _isEligibleForHand(Player p) => !p.sittingOut && !p.isOut && p.chips > 0;

  // Live in the CURRENT hand (i.e., able to win some pot slice).
  bool _isLiveInHand(Player p) => !p.folded && !p.sittingOut && !p.isOut;

  int _eligibleCount() => players.where(_isEligibleForHand).length;

  Player get actingPlayer => players[actingIndex];
  String get smallBlindLabel => 'SB $smallBlind';
  String get bigBlindLabel => 'BB $bigBlind';

  /* ==================== Eligibility / Rotation ==================== */

  int _nextEligibleSeatFrom(int start) {
    if (players.isEmpty) return -1;
    var idx = start;
    for (int hops = 0; hops < players.length; hops++) {
      idx = (idx + 1) % players.length;
      final p = players[idx];
      if (_isEligibleForHand(p)) return idx;
    }
    return -1; // none eligible
  }

  void _maybeAdvanceBlindLevel() {
    final BlindSchedule? schedule = config.blindSchedule;
    if (schedule == null || schedule.levels.isEmpty) return;
    final int target = (_completedOrbits ~/ schedule.orbitsPerLevel)
        .clamp(0, schedule.levels.length - 1);
    if (target == _blindLevelIndex) return;

    final int prevSb = _smallBlind;
    final int prevBb = _bigBlind;

    _blindLevelIndex = target;
    final BlindLevel lvl = schedule.levels[_blindLevelIndex];
    _smallBlind = lvl.smallBlind;
    _bigBlind = lvl.bigBlind;

    _emit(BlindLevelChanged(
      levelIndex: _blindLevelIndex,
      completedOrbits: _completedOrbits,
      previousSmallBlind: prevSb,
      previousBigBlind: prevBb,
      smallBlind: _smallBlind,
      bigBlind: _bigBlind,
    ));
  }

  void _rotateButton() {
    // First hand: dealerIndex might be -1; pick the first eligible.
    final int prev = dealerIndex;
    dealerIndex = _nextEligibleSeatFrom(dealerIndex);

    // A completed orbit is when the dealer button wraps around the table.
    if (prev >= 0 && dealerIndex >= 0 && dealerIndex < prev) {
      _completedOrbits += 1;
      _maybeAdvanceBlindLevel();
    }
  }

  /* ==================== Table / Tournament Management ==================== */

  bool addPlayer(Player p) {
    if (players.length >= config.maxPlayers) return false;
    players.add(p);
    return true;
  }

  void removePlayer(String id) {
    final idx = players.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      players.removeAt(idx);
      if (players.isEmpty) _resetTable();
    }
  }

  void resetTournament({bool keepStacks = true, int? resetStackTo}) {
    for (final p in players) {
      p.isOut = false;
      p.folded = false;
      p.allIn = false;
      p.betThisStreet = 0;
      p.contributedThisHand = 0;
      p.hole = const [];
      p.best = null;
      if (!keepStacks) p.chips = resetStackTo ?? p.chips;
    }
    _resetTable();
  }

  void _resetTable() {
    _resetBlindsFromConfig();
    _tournamentOver = false;
    community.clear();
    phase = GamePhase.predeal;
    actingIndex = 0;
    dealerIndex = -1;
    currentBet = 0;
    pot = 0;
    _lastAggressor = null;
    _lastRaiseSize = 0;
    smallBlindIndex = -1;
    bigBlindIndex = -1;
    lastPayouts = const [];
    handNumber = 0;
    _firstActorThisStreet = -1;
    _actedThisStreet.clear();
  }

  /* ==================== Hand Lifecycle ==================== */

  /// Instant start (no delays). Emits per-card events synchronously.
  ActionResult startNewHand({int? seed, Random? rng, Pcg32? pcg}) {
    if (_eligibleCount() < config.minPlayersToStart) {
      return ActionResult.notEnoughPlayers;
    }
    if (_tournamentOver) return ActionResult.notEnoughPlayers;

    // Set RNG for hand if provided
    _prepareHandRng(seed: seed, rng: rng, pcg: pcg);

    handNumber++;

    // Rotate dealer button to next eligible
    _rotateButton();

    // Reset hand state
    _deck = Deck(rng: _handRng.copy())..shuffle();
    community.clear();
    pot = 0;
    currentBet = 0;
    phase = GamePhase.predeal;
    _lastAggressor = null;
    _lastRaiseSize = bigBlind;
    lastPayouts = const [];
    for (final p in players) {
      p.resetForNewHand(); // clears folded/allIn/bets/best/hole
    }

    _postAntesIfAny();
    _dealHoleCardsInstant(); // emits CardDealt immediately per card
    _postBlinds(); // sets SB/BB based on dealer & eligibility
    if (config.allowButtonStraddle) _postStraddleIfAny();

    phase = GamePhase.preflop;
    _setFirstToActPreflop(); // HU: SB/dealer acts first; else left of BB

    // IMPORTANT: HandStarted signature assumed to be HandStarted(dealerIndex)
    _emit(HandStarted(dealerIndex));
    return ActionResult.ok;
  }

  /// Animated start: emits Shuffle* and Dealing* with delays between cards.
  Future<ActionResult> startNewHandAnimated({
    int? seed,
    Random? rng,
    Pcg32? pcg,
    // Shuffle control
    int shuffleMsTotal = 700,
    int shuffleTicks = 7,
    // Hole dealing control
    int msPerHoleCard = 140,
    int msBetweenPlayers = 30,
    // Board dealing control
    int msBetweenBoardCards = 220,
  }) async {
    if (_eligibleCount() < config.minPlayersToStart) {
      return ActionResult.notEnoughPlayers;
    }
    if (_tournamentOver) return ActionResult.notEnoughPlayers;

    // RNG
    _prepareHandRng(seed: seed, rng: rng, pcg: pcg);

    handNumber++;

    // Button
    _rotateButton();

    // Reset hand state
    _deck = Deck(rng: _handRng.copy())..shuffle();
    community.clear();
    pot = 0;
    currentBet = 0;
    phase = GamePhase.predeal;
    _lastAggressor = null;
    _lastRaiseSize = bigBlind;
    lastPayouts = const [];
    for (final p in players) {
      p.resetForNewHand();
    }

    // Antes
    _postAntesIfAny();

    // Shuffle animation
    await _animateShuffle(
      totalMs: shuffleMsTotal,
      ticks: shuffleTicks,
    );

    // Deal hole cards with animation
    await _dealHoleCardsAnimated(
      msPerCard: msPerHoleCard,
      msBetweenPlayers: msBetweenPlayers,
    );

    // Blinds / straddle
    _postBlinds();
    if (config.allowButtonStraddle) _postStraddleIfAny();

    // Move to preflop
    phase = GamePhase.preflop;
    _setFirstToActPreflop();

    // IMPORTANT: HandStarted signature assumed to be HandStarted(dealerIndex)
    _emit(HandStarted(dealerIndex));

    return ActionResult.ok;
  }

  /// True if two or more live players are all-in and all live bets match.
  bool everyoneAllInMatched() => _earlyAllInClosed();

  void _postAntesIfAny() {
    if (config.ante <= 0) return;
    for (final p in players) {
      if (!_isEligibleForHand(p)) continue;
      final pay = min(config.ante, p.chips);
      _payIntoPot(p, pay);
    }
  }

  /* ==================== Dealing (Hole) ==================== */

  void _dealHoleCardsInstant() {
    final start = _nextEligibleSeatFrom(dealerIndex);
    if (start < 0) return;
    _emit(const DealingStarted("hole"));

    // Two hole cards, round-robin from left of dealer
    for (int r = 0; r < 2; r++) {
      for (int n = 0; n < players.length; n++) {
        final idx = (start + n) % players.length;
        final p = players[idx];
        if (!_isEligibleForHand(p)) continue;
        final c = _deck.draw();
        if (p.hole.isEmpty) {
          p.hole = [c];
        } else {
          p.hole = [...p.hole, c];
        }
        _emit(CardDealt(seatIndex: idx, card: c, isBoard: false));
      }
    }
    _emit(const DealingEnded("hole"));
  }

  Future<void> _dealHoleCardsAnimated({
    required int msPerCard,
    required int msBetweenPlayers,
  }) async {
    final start = _nextEligibleSeatFrom(dealerIndex);
    if (start < 0) return;
    _emit(const DealingStarted("hole"));

    for (int r = 0; r < 2; r++) {
      for (int n = 0; n < players.length; n++) {
        final idx = (start + n) % players.length;
        final p = players[idx];
        if (!_isEligibleForHand(p)) continue;

        final c = _deck.draw();
        if (p.hole.isEmpty) {
          p.hole = [c];
        } else {
          p.hole = [...p.hole, c];
        }

        _emit(CardDealt(seatIndex: idx, card: c, isBoard: false));
        await Future.delayed(Duration(milliseconds: msPerCard));

        // Slight travel time to next player
        if (n != players.length - 1) {
          await Future.delayed(Duration(milliseconds: msBetweenPlayers));
        }
      }
    }
    _emit(const DealingEnded("hole"));
  }

  /* ==================== Blinds / Straddles ==================== */

  void _postBlinds() {
    final elig = _eligibleCount();
    if (elig < 2) {
      smallBlindIndex = -1;
      bigBlindIndex = -1;
      currentBet = 0;
      return;
    }

    if (elig == 2) {
      // Heads-up rule: dealer = SB; BB is the other eligible
      smallBlindIndex = dealerIndex;
      bigBlindIndex = _nextEligibleSeatFrom(smallBlindIndex);
    } else {
      // Ring: SB is first eligible left of dealer; BB is next eligible
      smallBlindIndex = _nextEligibleSeatFrom(dealerIndex);
      bigBlindIndex = _nextEligibleSeatFrom(smallBlindIndex);
    }

    _emit(DealerButtonMoved(
      dealerIndex: dealerIndex,
      sbIndex: smallBlindIndex,
      bbIndex: bigBlindIndex,
    ));

    final sbPaid = _payBlind(smallBlindIndex, smallBlind);
    final bbPaid = _payBlind(bigBlindIndex, bigBlind);

    // The live bet to match must reflect what was actually posted (handles short stacks).
    currentBet = max(sbPaid, bbPaid);
    _lastAggressor = (currentBet > 0) ? bigBlindIndex : null;
    _lastRaiseSize = currentBet > 0 ? currentBet : bigBlind;

    _emit(BlindsPosted(
      sbIndex: smallBlindIndex,
      bbIndex: bigBlindIndex,
      sbAmount: sbPaid,
      bbAmount: bbPaid,
    ));
  }

  int _payBlind(int index, int blind) {
    if (index < 0 || index >= players.length) return 0;
    final p = players[index];
    if (!_isEligibleForHand(p)) return 0;
    final paid = min(blind, p.chips);
    _payIntoPot(p, paid);
    return paid;
  }

  void _postStraddleIfAny() {
    if (!config.allowButtonStraddle) return;
    final btn = dealerIndex;
    if (btn < 0) return;
    final p = players[btn];
    if (!_isEligibleForHand(p)) return;

    final to = min(2 * bigBlind, p.betThisStreet + p.chips);
    final delta = to - p.betThisStreet;
    if (delta > 0) {
      _payIntoPot(p, delta);
      currentBet = max(currentBet, p.betThisStreet);
      _lastAggressor = btn;
      _lastRaiseSize = max(_lastRaiseSize, currentBet);
    }
  }

  /* ==================== First to Act ==================== */

  void _setFirstToActPreflop() {
    if (_eligibleCount() == 2) {
      // HU: SB (dealer) acts first preflop
      actingIndex = smallBlindIndex;
    } else {
      // Ring: first to act is left of BB
      actingIndex = _nextEligibleSeatFrom(bigBlindIndex);
    }
    _skipToNextEligible();
    _beginStreetAt(actingIndex);
  }

  void _setFirstToActPostflop() {
    // First to act postflop is left of the dealer (works for HU and ring)
    actingIndex = _nextEligibleSeatFrom(dealerIndex);
    _skipToNextEligible();
    _beginStreetAt(actingIndex);

    // Reset street state
    currentBet = 0;
    for (final p in players) {
      p.betThisStreet = 0;
    }
    _lastAggressor = null;
    _lastRaiseSize = bigBlind;
  }

  void _beginStreetAt(int index) {
    _firstActorThisStreet = index;
    _actedThisStreet.clear();
    _emit(NextToActChanged(actingIndex));
  }

  void _recordActed(int index) {
    if (index >= 0 && index < players.length) {
      _actedThisStreet.add(index);
    }
  }

  bool _allLivePlayersActed(List<int> seats) {
    if (_firstActorThisStreet < 0) return true;
    for (final idx in seats) {
      if (!_actedThisStreet.contains(idx)) return false;
    }
    return true;
  }

  void _skipToNextEligible() {
    int hops = 0;
    while (hops < players.length) {
      final p = players[actingIndex];
      if (!p.folded && !p.allIn && !p.sittingOut && !p.isOut) return;
      actingIndex = (actingIndex + 1) % players.length;
      hops++;
    }
  }

  /* ==================== UI Helpers ==================== */

  int toCallFor(int index) {
    final p = players[index];
    return max(0, currentBet - p.betThisStreet);
  }

  bool canCheck(int index) {
    if (phase == GamePhase.handOver || phase == GamePhase.showdown)
      return false;
    final p = players[index];
    if (p.folded || p.allIn || p.sittingOut || p.isOut) return false;
    return p.betThisStreet == currentBet;
  }

  ({int minTo, int maxTo}) raiseBoundsTo(int index) {
    final p = players[index];
    final maxTo = p.betThisStreet + p.chips; // all-in total
    if (currentBet == 0) {
      return (minTo: bigBlind, maxTo: maxTo);
    } else {
      return (minTo: currentBet + minRaiseSize(), maxTo: maxTo);
    }
  }

  int minRaiseSize() {
    if (currentBet == 0) return bigBlind;
    return _lastRaiseSize > 0 ? _lastRaiseSize : bigBlind;
  }

  Set<ActionType> legalActionsFor(int index) {
    final out = <ActionType>{};
    if (phase == GamePhase.handOver || phase == GamePhase.showdown) return out;

    final p = players[index];
    if (p.folded || p.allIn || p.sittingOut || p.isOut) return out;

    final toCall = toCallFor(index);
    final canMatch = p.chips >= toCall;

    if (p.betThisStreet == currentBet) {
      out.add(ActionType.check);
      if (currentBet == 0) {
        final bounds = raiseBoundsTo(index);
        if (bounds.minTo <= bounds.maxTo) out.add(ActionType.bet);
      } else {
        final bounds = raiseBoundsTo(index);
        if (bounds.minTo <= bounds.maxTo && (bounds.minTo > currentBet)) {
          out.add(ActionType.raise);
        }
      }
    } else {
      out.add(ActionType.fold);
      if (toCall > 0) out.add(ActionType.call);
      final bounds = raiseBoundsTo(index);
      if (bounds.minTo <= bounds.maxTo &&
          (bounds.minTo > currentBet) &&
          canMatch) {
        out.add(ActionType.raise);
      }
    }

    out.add(ActionType.allIn);
    return out;
  }

  /* ==================== Actions ==================== */

  ActionResult act(ActionType type, {int amount = 0}) {
    if (phase == GamePhase.handOver || phase == GamePhase.showdown) {
      return ActionResult.illegalAtThisPhase;
    }

    final actorIndex = actingIndex;
    final p = players[actorIndex];
    if (p.folded || p.allIn || p.sittingOut || p.isOut) {
      return ActionResult.alreadyFoldedOrAllIn;
    }

    switch (type) {
      case ActionType.fold:
        p.folded = true;
        _recordActed(actorIndex);
        _emit(ActionTaken(actorIndex, type, 0));
        return _afterActionAdvance();

      case ActionType.check:
        if (p.betThisStreet != currentBet)
          return ActionResult.cannotCheckFacingBet;
        _recordActed(actorIndex);
        _emit(ActionTaken(actorIndex, type, 0));
        return _afterActionAdvance();

      case ActionType.call:
        {
          final need = toCallFor(actorIndex);
          if (need <= 0) return ActionResult.nothingToCall;
          final pay = min(need, p.chips);
          _payIntoPot(p, pay);
          _recordActed(actorIndex);
          _emit(ActionTaken(actorIndex, type, pay));
          return _afterActionAdvance();
        }

      case ActionType.bet:
      case ActionType.raise:
      case ActionType.allIn:
        return _doBetOrRaise(type, amount);
    }
  }

  ActionResult _afterActionAdvance() {
    _advanceTurnOrStreet();

    // If betting is closed and all remaining players are all-in, auto-run out
    if (_earlyAllInClosed()) {
      _dealOutRemainingBoardToShowdownAnimatedIfWanted(); // respects phase; instant by default
    }
    return ActionResult.ok;
  }

  void _payIntoPot(Player p, int delta) {
    p.chips -= delta;
    p.betThisStreet += delta;
    p.contributedThisHand += delta;
    pot += delta;
    if (p.chips == 0) p.allIn = true; // IMPORTANT: all-in, not out
  }

  ActionResult _doBetOrRaise(ActionType type, int toAmount) {
    final idx = actingIndex;
    final p = players[idx];

    final bool forceAllIn = type == ActionType.allIn;
    if (forceAllIn) {
      toAmount = p.betThisStreet + p.chips; // shove to total
    }

    int delta = toAmount - p.betThisStreet;
    if (delta <= 0) return ActionResult.invalidBetAmount;

    if (delta > p.chips) {
      delta = p.chips;
      toAmount = p.betThisStreet + delta;
    }

    final bool isAllIn = forceAllIn || (delta == p.chips);
    bool _aligned(int amt) => amt % _kRaiseIncrement == 0;

    if (!isAllIn && !_aligned(toAmount)) {
      return currentBet == 0
          ? ActionResult.invalidBetAmount
          : ActionResult.invalidRaiseAmount;
    }

    if (currentBet == 0) {
      // Opening bet
      final minBetTo = bigBlind;
      if (!isAllIn && toAmount < minBetTo) return ActionResult.invalidBetAmount;

      _recordActed(idx);
      _payIntoPot(p, delta);
      _registerAggression(
          raiseTo: p.betThisStreet, isAllIn: isAllIn, isNewBet: true);
      _emit(ActionTaken(idx, type, toAmount));
      return _afterActionAdvance();
    }

    // Raise case
    final previousBet = currentBet;
    final minRaiseTo = currentBet + minRaiseSize();

    if (!isAllIn && toAmount < minRaiseTo) {
      return ActionResult.invalidRaiseAmount;
    }

    _recordActed(idx);
    _payIntoPot(p, delta);

    final reachedOrExceeded = p.betThisStreet >= minRaiseTo;
    if (p.betThisStreet > previousBet && reachedOrExceeded) {
      _registerAggression(
          raiseTo: p.betThisStreet, isAllIn: isAllIn, isNewBet: false);
    } else {
      // Call that doesn't reach min raise (or all-in short raise)
      currentBet = max(currentBet, p.betThisStreet);
    }

    _emit(ActionTaken(idx, type, toAmount));
    return _afterActionAdvance();
  }

  void _registerAggression({
    required int raiseTo,
    required bool isAllIn,
    required bool isNewBet,
  }) {
    final previousBet = currentBet;
    currentBet = max(currentBet, raiseTo);
    if (isNewBet) {
      _lastRaiseSize = currentBet;
    } else {
      final inc = currentBet - previousBet;
      if (!isAllIn && inc > 0) {
        _lastRaiseSize = inc;
      }
    }
    _lastAggressor = actingIndex;
  }

  /* ==================== Turn / Street Advancement ==================== */

  void _advanceTurnOrStreet() {
    // If only one player remains live (not folded/sittingOut/isOut), award immediately
    final live = players.where(_isLiveInHand).toList();

    if (live.length <= 1) {
      final winnerIdx = (live.isNotEmpty ? players.indexOf(live.first) : null);
      _awardAllTo(winnerIdx);
      _finalizeHandAndEmit(); // emits HandSettled with bust list
      return;
    }

    if (_bettingRoundComplete()) {
      _goNextStreetAnimatedIfWanted(); // instant by default
      return;
    }

    _nextActor();
    if (_bettingRoundComplete()) {
      _goNextStreetAnimatedIfWanted(); // instant by default
      return;
    }
  }

  bool _bettingRoundComplete() {
    final contenders = <int>[];
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      if (!p.folded && !p.allIn && !p.sittingOut && !p.isOut) {
        contenders.add(i);
      }
    }
    if (contenders.isEmpty) return true;

    final allMatched =
        contenders.every((i) => players[i].betThisStreet == currentBet);
    if (!allMatched) return false;

    if (_lastAggressor == null) {
      if (!_allLivePlayersActed(contenders)) return false;
      if (_firstActorThisStreet < 0) return true;
      return actingIndex == _firstActorThisStreet;
    }

    final laIndex = _lastAggressor!;
    final la = players[laIndex];
    if (la.allIn || la.folded || la.sittingOut || la.isOut) return true;
    if (!_actedThisStreet.contains(laIndex)) return false;

    return actingIndex == laIndex;
  }

  void _forceCloseBettingRound() {
    int safety = players.length * 4;
    while (!_bettingRoundComplete() && safety-- > 0) {
      final idx = actingIndex;
      final p = players[idx];
      if (p.folded || p.allIn || p.sittingOut || p.isOut) {
        _nextActor();
        continue;
      }

      final need = toCallFor(idx);
      if (need > 0) {
        final pay = min(need, p.chips);
        if (pay > 0) {
          _payIntoPot(p, pay);
          _recordActed(idx);
          final bool wentAllIn = p.allIn;
          _emit(ActionTaken(idx, wentAllIn ? ActionType.allIn : ActionType.call,
              p.betThisStreet));
        } else {
          p.folded = true;
          _recordActed(idx);
          _emit(ActionTaken(idx, ActionType.fold, 0));
        }
      } else {
        _recordActed(idx);
        _emit(ActionTaken(idx, ActionType.check, 0));
      }

      _advanceTurnOrStreet();
      if (phase == GamePhase.handOver || phase == GamePhase.showdown) return;
    }
  }

  void _nextActor() {
    int hops = 0;
    do {
      actingIndex = (actingIndex + 1) % players.length;
      hops++;
      if (hops > players.length) break; // safety
    } while (players[actingIndex].folded ||
        players[actingIndex].allIn ||
        players[actingIndex].sittingOut ||
        players[actingIndex].isOut);
    _emit(NextToActChanged(actingIndex));
  }

  /* ---------- Burn helper ---------- */
  void _burn() {
    // Standard Hold'em burn: discard top card of the deck
    // (Deck.draw() already advances the deck; we don't need the card.)
    _deck.draw();
  }

  /* ---------- Street progression (instant) ---------- */

  void _goNextStreet() {
    // Reset per-street numbers (but DO NOT touch `isOut` mid-hand)
    for (final p in players) {
      p.betThisStreet = 0;
    }
    currentBet = 0;
    _lastAggressor = null;
    _lastRaiseSize = bigBlind;

    switch (phase) {
      case GamePhase.preflop:
        _burn();
        community
          ..clear()
          ..addAll([_deck.draw(), _deck.draw(), _deck.draw()]);
        phase = GamePhase.flop;
        _setFirstToActPostflop();
        _emit(StreetDealt(phase));
        break;

      case GamePhase.flop:
        _burn();
        community.add(_deck.draw());
        phase = GamePhase.turn;
        _setFirstToActPostflop();
        _emit(StreetDealt(phase));
        break;

      case GamePhase.turn:
        _burn();
        community.add(_deck.draw());
        phase = GamePhase.river;
        _setFirstToActPostflop();
        _emit(StreetDealt(phase));
        break;

      case GamePhase.river:
        // Betting closed on river -> showdown
        phase = GamePhase.showdown;
        _showdownAndPayout();
        _finalizeHandAndEmit();
        break;

      default:
        break;
    }
  }

  /* ---------- Street progression (animated helper) ---------- */

  // Toggle these to make streets animate on advance() and early runouts.
  // If you want full-table animation for streets, set true before calling.
  bool animateStreets = true;
  int msBetweenBoardCards = 220;

  void _goNextStreetAnimatedIfWanted() {
    if (!animateStreets) {
      _goNextStreet();
      return;
    }
    unawaited(_goNextStreetAnimated());
  }

  Future<void> _goNextStreetAnimated() async {
    // Reset per-street numbers
    for (final p in players) {
      p.betThisStreet = 0;
    }
    currentBet = 0;
    _lastAggressor = null;
    _lastRaiseSize = bigBlind;

    switch (phase) {
      case GamePhase.preflop:
        _burn();
        _emit(const DealingStarted("flop"));
        final flopCards = <Card>[
          _deck.draw(),
          _deck.draw(),
          _deck.draw(),
        ];
        community
          ..clear()
          ..addAll(flopCards);
        for (final c in flopCards) {
          _emit(CardDealt(seatIndex: -1, card: c, isBoard: true));
        }
        _emit(const DealingEnded("flop"));

        phase = GamePhase.flop;
        _setFirstToActPostflop();
        _emit(StreetDealt(phase));
        break;

      case GamePhase.flop:
        _burn();
        _emit(const DealingStarted("turn"));
        final t = _deck.draw();
        community.add(t);
        _emit(CardDealt(seatIndex: -1, card: t, isBoard: true));
        _emit(const DealingEnded("turn"));

        phase = GamePhase.turn;
        _setFirstToActPostflop();
        _emit(StreetDealt(phase));
        break;

      case GamePhase.turn:
        _burn();
        _emit(const DealingStarted("river"));
        final r = _deck.draw();
        community.add(r);
        _emit(CardDealt(seatIndex: -1, card: r, isBoard: true));
        _emit(const DealingEnded("river"));

        phase = GamePhase.river;
        _setFirstToActPostflop();
        _emit(StreetDealt(phase));
        break;

      case GamePhase.river:
        phase = GamePhase.showdown;
        _showdownAndPayout();
        _finalizeHandAndEmit();
        break;

      default:
        break;
    }
  }

  /* ==================== Skip/Show: public triggers ==================== */

  /// Fast-forward the remainder of the hand to the winner immediately, regardless of hero state.
  /// Closes betting with minimal actions, deals out remaining streets instantly, and settles.
  void requestSkipToWinner() {
    if (phase == GamePhase.handOver) return;

    final prevAnimate = animateStreets;
    animateStreets = false; // Instant runout
    try {
      // Helper: who is still live
      bool isLive(int i) {
        final p = players[i];
        final bool folded = (p.folded == true) ||
            (() {
              try {
                return (p as dynamic).hasFolded == true;
              } catch (_) {
                return false;
              }
            })();
        final bool outish = (p.sittingOut == true) || (p.isOut == true);
        return !folded && !outish;
      }

      // 1) Close current betting minimally
      try {
        _forceCloseBettingRound();
      } catch (_) {}
      if (phase == GamePhase.handOver) return;

      // 2) If only one live player, award & finalize
      final liveIdx = <int>[];
      for (var i = 0; i < players.length; i++) {
        if (isLive(i)) liveIdx.add(i);
      }
      if (liveIdx.length <= 1) {
        final int? winnerIdx = liveIdx.isNotEmpty ? liveIdx.first : null;
        try {
          _awardAllTo(winnerIdx);
        } catch (_) {}
        try {
          _finalizeHandAndEmit();
        } catch (_) {}
        return;
      }

      // 3) Otherwise complete the board, showdown, and finalize
      try {
        _dealOutRemainingBoardToShowdown();
      } catch (_) {}
      try {
        _showdownAndPayout();
      } catch (_) {}
      try {
        _finalizeHandAndEmit();
      } catch (_) {}
    } finally {
      animateStreets = prevAnimate;
    }
  }

  /// Resolve immediately when showdown is logically determined (e.g., everyone is all-in
  /// with matched action, or we've effectively reached a state with only one live player).
  void requestShowNow() {
    if (!canShowNow) return;
    _dealOutRemainingBoardToShowdownAnimatedIfWanted();
    if (phase == GamePhase.showdown) {
      _showdownAndPayout();
      _finalizeHandAndEmit();
    }
  }

  /* ==================== Early All-in Runout ==================== */

  bool _earlyAllInClosed() {
    // If all remaining contenders are all-in and betting is matched, deal out
    if (phase == GamePhase.handOver || phase == GamePhase.showdown)
      return false;
    final live =
        players.where((p) => !p.folded && !p.sittingOut && !p.isOut).toList();
    if (live.length < 2) return false;
    final allAllIn = live.every((p) => p.allIn || p.chips == 0);
    if (!allAllIn) return false;
    final matched = live.every((p) => p.betThisStreet == currentBet);
    return matched;
  }

  void _dealOutRemainingBoardToShowdown() {
    while (phase != GamePhase.handOver && phase != GamePhase.showdown) {
      switch (phase) {
        case GamePhase.preflop:
          _burn();
          community
            ..clear()
            ..addAll([_deck.draw(), _deck.draw(), _deck.draw()]);
          phase = GamePhase.flop;
          _emit(StreetDealt(phase));
          continue;
        case GamePhase.flop:
          _burn();
          community.add(_deck.draw());
          phase = GamePhase.turn;
          _emit(StreetDealt(phase));
          continue;
        case GamePhase.turn:
          _burn();
          community.add(_deck.draw());
          phase = GamePhase.river;
          _emit(StreetDealt(phase));
          continue;
        case GamePhase.river:
          phase = GamePhase.showdown;
          _showdownAndPayout();
          _finalizeHandAndEmit();
          return;
        default:
          return;
      }
    }
  }

  void _dealOutRemainingBoardToShowdownAnimatedIfWanted() {
    if (!animateStreets) {
      _dealOutRemainingBoardToShowdown();
      return;
    }
    unawaited(_dealOutRemainingBoardToShowdownAnimated());
  }

  Future<void> _dealOutRemainingBoardToShowdownAnimated() async {
    while (phase != GamePhase.handOver && phase != GamePhase.showdown) {
      switch (phase) {
        case GamePhase.preflop:
          _burn();
          _emit(const DealingStarted("flop"));
          final flopCards = <Card>[
            _deck.draw(),
            _deck.draw(),
            _deck.draw(),
          ];
          community
            ..clear()
            ..addAll(flopCards);
          for (final c in flopCards) {
            _emit(CardDealt(seatIndex: -1, card: c, isBoard: true));
          }
          _emit(const DealingEnded("flop"));

          phase = GamePhase.flop;
          _emit(StreetDealt(phase));
          continue;

        case GamePhase.flop:
          _burn();
          _emit(const DealingStarted("turn"));
          final t = _deck.draw();
          community.add(t);
          _emit(CardDealt(seatIndex: -1, card: t, isBoard: true));
          _emit(const DealingEnded("turn"));

          phase = GamePhase.turn;
          _emit(StreetDealt(phase));
          continue;

        case GamePhase.turn:
          _burn();
          _emit(const DealingStarted("river"));
          final r = _deck.draw();
          community.add(r);
          _emit(CardDealt(seatIndex: -1, card: r, isBoard: true));
          _emit(const DealingEnded("river"));

          phase = GamePhase.river;
          _emit(StreetDealt(phase));
          continue;

        case GamePhase.river:
          phase = GamePhase.showdown;
          _showdownAndPayout();
          _finalizeHandAndEmit();
          return;

        default:
          return;
      }
    }
  }

  /* ==================== Awards / Showdown / Pots ==================== */

  void _awardAllTo(int? winnerIndex) {
    if (winnerIndex == null) return;
    final amt = pot;
    players[winnerIndex].chips += amt;
    lastPayouts = [Payout(playerIndex: winnerIndex, amount: amt, best: null)];
    pot = 0;
  }

  void _showdownAndPayout() {
    final contendersIdx = <int>[];
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      if (_isLiveInHand(p)) contendersIdx.add(i);
    }
    if (contendersIdx.isEmpty) return;

    // Evaluate best 5-card hands for all contenders
    for (final i in contendersIdx) {
      final p = players[i];
      final seven = [...p.hole, ...community];
      p.best = HandEvaluator.evaluate(seven);
    }

    final pots = _buildSidePots();
    final gains = <int, int>{};

    // Odd-chip distribution starts from the first seat to the left of the dealer
    int remainderSeatStart = _nextEligibleSeatFrom(dealerIndex);
    if (remainderSeatStart < 0) remainderSeatStart = 0;

    for (final ps in pots) {
      if (ps.amount <= 0 || ps.eligibles.isEmpty) continue;

      // Find best rank among eligibles
      HandRank? bestRank;
      for (final i in ps.eligibles) {
        final r = players[i].best!;
        if (bestRank == null || r.compareTo(bestRank) > 0) bestRank = r;
      }

      // Collect winners of this slice
      final winners = <int>[];
      for (final i in ps.eligibles) {
        if (players[i].best!.compareTo(bestRank!) == 0) winners.add(i);
      }

      // Split pot
      final share = ps.amount ~/ winners.length;
      int remainder = ps.amount % winners.length;

      for (final i in winners) {
        players[i].chips += share;
        gains[i] = (gains[i] ?? 0) + share;
      }

      // Distribute odd chips clockwise from remainderSeatStart among winners
      while (remainder > 0) {
        for (int step = 0; step < players.length && remainder > 0; step++) {
          final seat = (remainderSeatStart + step) % players.length;
          if (winners.contains(seat)) {
            players[seat].chips += 1;
            gains[seat] = (gains[seat] ?? 0) + 1;
            remainder--;
          }
        }
      }

      pot -= ps.amount;
    }

    if (pot < 0) pot = 0;

    lastPayouts = gains.entries
        .map((e) => Payout(
              playerIndex: e.key,
              amount: e.value,
              best: players[e.key].best,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  List<PotSlice> _buildSidePots() {
    // Contributions by seat
    final contrib = <int, int>{};
    for (int i = 0; i < players.length; i++) {
      contrib[i] = players[i].contributedThisHand;
    }

    // Levels are distinct contributed amounts > 0
    final levels = contrib.values.where((v) => v > 0).toSet().toList()..sort();
    if (levels.isEmpty) {
      // No contributions? Edge case: treat entire pot as one slice for live players
      return [
        PotSlice(
          pot,
          players.asMap().keys.where((i) => _isLiveInHand(players[i])).toSet(),
        )
      ];
    }

    final slices = <PotSlice>[];
    int prev = 0;

    for (final level in levels) {
      final layerSize = level - prev;
      if (layerSize <= 0) {
        prev = level;
        continue;
      }

      // All seats who contributed AT LEAST 'level' total are in this layer
      final layerContribIdx = <int>[];
      for (final e in contrib.entries) {
        if (e.value >= level) layerContribIdx.add(e.key);
      }
      if (layerContribIdx.isEmpty) {
        prev = level;
        continue;
      }

      final amount = layerSize * layerContribIdx.length;

      // Eligibles: not folded/sittingOut/isOut (all-in still eligible up to cap)
      final eligibles =
          layerContribIdx.where((i) => _isLiveInHand(players[i])).toSet();

      if (amount > 0 && eligibles.isNotEmpty) {
        slices.add(PotSlice(amount, eligibles));
      }

      prev = level;
    }

    // Attach any residual chips in pot as a final catch-all slice among current live players
    final sumSlices = slices.fold<int>(0, (a, b) => a + b.amount);
    if (sumSlices != pot) {
      final remainder = pot - sumSlices;
      if (remainder > 0) {
        slices.add(PotSlice(
          remainder,
          players.asMap().keys.where((i) => _isLiveInHand(players[i])).toSet(),
        ));
      }
    }

    return slices;
  }

  /* ==================== Hand Settlement / Eliminations ==================== */

  List<int> _aliveSeats() => List<int>.generate(players.length, (i) => i)
      .where((i) => !players[i].isOut && players[i].chips > 0)
      .toList();

  int _cfgPayoutForRank(int rank) {
    if (config.payoutTable != null) return config.payoutTable!.pays(rank);
    if (config.payoutForRank != null) return config.payoutForRank!(rank);
    return 0;
  }

  /// End-of-hand settlement: compute payouts (already in lastPayouts),
  /// mark eliminations (isOut), emit HandSettled with a timestamp, and
  /// reset phase to HandOver.
  void _finalizeHandAndEmit() {
    // Mark eliminations strictly NOW (not earlier).
    final bustedNow = <int>[];
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      // "Busted" iff 0 chips AFTER payouts and not previously out.
      if (!p.isOut && p.chips <= 0) {
        p.isOut = true;
        bustedNow.add(i);
      }
    }

    // Optional tournament winner (only one alive seat remains overall)
    final alive = _aliveSeats();
    if (alive.length == 1 && !_tournamentOver) {
      final champ = alive.first;
      final prize = _cfgPayoutForRank(1);
      _eventLog.add(WinnerDeclared(champ, prize));
      _tournamentOver = true;
      _emit(TournamentEnded(champ, prize));
    }

    // Build winners set (anyone who received > 0 in lastPayouts)
    final winners = lastPayouts.map((p) => p.playerIndex).toSet();

    // Transition to final hand state
    phase = GamePhase.handOver;
    _emit(PayoutsEvent(lastPayouts));

    // Emit the consolidated settlement event with timestamp for UI timing
    final endedAtMs = DateTime.now().millisecondsSinceEpoch;
    _emit(HandSettled(
      handNumber: handNumber,
      payouts: List<Payout>.from(lastPayouts),
      bustedThisHand: List<int>.from(bustedNow),
      winners: winners,
      endedAtMs: endedAtMs,
    ));

    // Emit per-player bust info for logs (optional)
    if (bustedNow.isNotEmpty) {
      int aliveBefore = _aliveSeats().length + bustedNow.length;
      for (int k = 0; k < bustedNow.length; k++) {
        final seat = bustedNow[k];
        final finalRank = aliveBefore - k; // e.g., 4, then 3…
        final prize = _cfgPayoutForRank(finalRank);
        _eventLog.add(PlayerBusted(seat, finalRank, prize));
      }
      // (No null _emit calls — the log was updated above.)
    }

    _emit(HandEnded());
  }
  /* ==================== Shuffle Animation ==================== */

  Future<void> _animateShuffle({
    required int totalMs,
    required int ticks,
  }) async {
    if (ticks <= 0 || totalMs <= 0) {
      // Still emit a minimal shuffle cycle for UI hooks
      _emit(const ShuffleStarted());
      _emit(const ShuffleEnded());
      return;
    }
    _emit(const ShuffleStarted());
    final step = (totalMs / ticks).round();
    for (int i = 1; i <= ticks; i++) {
      final progress = i / ticks;
      _emit(ShuffleTick(progress.clamp(0.0, 1.0)));
      await Future.delayed(Duration(milliseconds: step));
    }
    _emit(const ShuffleEnded());
  }

  /* ==================== Snapshot / Labels / Debug ==================== */

  /// Redacted snapshot for a specific viewer (typically the hero).
  /// - Shows the viewer's hole/best always.
  /// - At showdown/handOver, reveals hole/best for players who reached showdown.
  /// - Otherwise hides other players' private cards/best.
  GameSnapshot snapshotForViewer({
    int? viewerIndex,
    bool revealShowdown = true,
  }) {
    bool isViewer(int idx) =>
        viewerIndex != null && viewerIndex >= 0 && viewerIndex == idx;
    bool showAtShowdown(int idx) {
      if (!revealShowdown) return false;
      if (phase != GamePhase.showdown && phase != GamePhase.handOver) {
        return false;
      }
      final p = players[idx];
      return !p.folded && !p.sittingOut && !p.isOut;
    }

    return GameSnapshot(
      phase: phase,
      handNumber: handNumber,
      dealerIndex: dealerIndex,
      actingIndex: actingIndex,
      currentBet: currentBet,
      pot: pot,
      community: List.unmodifiable(community),
      players: [
        for (int i = 0; i < players.length; i++)
          () {
            final p = players[i];
            final bool reveal = isViewer(i) || showAtShowdown(i);
            return PlayerSnapshot(
              id: p.id,
              name: p.name,
              chips: p.chips,
              folded: p.folded,
              allIn: p.allIn,
              sittingOut: p.sittingOut,
              betThisStreet: p.betThisStreet,
              contributedThisHand: p.contributedThisHand,
              hole: reveal ? List.unmodifiable(p.hole) : const [],
              best: reveal ? p.best : null,
              enduranceMinutes: p.enduranceMinutes,
              aura: p.aura,
            );
          }(),
      ],
    );
  }

  /// Default snapshot redacts other seats, showing hero (if set).
  GameSnapshot snapshot() =>
      snapshotForViewer(viewerIndex: heroIndex >= 0 ? heroIndex : null);

  /// Unredacted snapshot for diagnostics/simulation.
  GameSnapshot snapshotFull() => GameSnapshot(
        phase: phase,
        handNumber: handNumber,
        dealerIndex: dealerIndex,
        actingIndex: actingIndex,
        currentBet: currentBet,
        pot: pot,
        community: List.unmodifiable(community),
        players: [
          for (final p in players)
            PlayerSnapshot(
              id: p.id,
              name: p.name,
              chips: p.chips,
              folded: p.folded,
              allIn: p.allIn,
              sittingOut: p.sittingOut,
              betThisStreet: p.betThisStreet,
              contributedThisHand: p.contributedThisHand,
              hole: List.unmodifiable(p.hole),
              best: p.best,
              enduranceMinutes: p.enduranceMinutes,
              aura: p.aura,
            ),
        ],
      );

  String phaseLabel() {
    switch (phase) {
      case GamePhase.predeal:
        return 'Dealing…';
      case GamePhase.preflop:
        return 'Preflop';
      case GamePhase.flop:
        return 'Flop';
      case GamePhase.turn:
        return 'Turn';
      case GamePhase.river:
        return 'River';
      case GamePhase.showdown:
        return 'Showdown';
      case GamePhase.handOver:
        return 'Hand Over';
    }
  }

  @override
  String toString() {
    final sb = StringBuffer();
    sb.writeln(
        'Hand#$handNumber  Phase:${phaseLabel()}  Pot:$pot  CurrentBet:$currentBet');
    sb.writeln('Blinds: $smallBlind/$bigBlind  '
        'Dealer:${dealerIndex >= 0 ? players[dealerIndex].name : '-'}  '
        'SB:${smallBlindIndex >= 0 ? players[smallBlindIndex].name : '-'}  '
        'BB:${bigBlindIndex >= 0 ? players[bigBlindIndex].name : '-'}');
    sb.writeln('Board: ${community.map((c) => c.toString()).join(' ')}');
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      final d = (i == dealerIndex) ? ' (D)' : '';
      final a = (i == actingIndex) ? ' <<' : '';
      String k = '';
      try {
        final dyn = (p as dynamic).kingdom;
        if (dyn is String && dyn.isNotEmpty) k = dyn;
      } catch (_) {}
      final kPart = k.isNotEmpty ? '  kingdom:$k' : '';
      sb.writeln(
          '${i + 1}. ${p.name}$d$a  chips:${p.chips} bet:${p.betThisStreet} '
          'state:${p.isOut ? 'OUT' : p.sittingOut ? 'SIT-OUT' : p.folded ? 'FOLDED' : p.allIn ? 'ALL-IN' : 'LIVE'} '
          'contrib:${p.contributedThisHand}$kPart '
          'hole:${p.hole.map((c) => c.toString()).join(' ')}');
    }
    if (lastPayouts.isNotEmpty) {
      sb.writeln('Last hand results:');
      for (final p in lastPayouts) {
        final n = players[p.playerIndex].name;
        final hand = p.best?.toString() ?? '—';
        sb.writeln('  $n +${p.amount}  ($hand)');
      }
    }
    return sb.toString();
  }
}

/* ------------------------------- Utilities ------------------------------- */

/// Make "fire-and-forget" futures explicit and analyzable.
void unawaited(Future<void> f) {}
