// lib/game/game_engine.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math' show Random, min, max;

import 'core.dart'
    show Card, Deck, GamePhase, ActionType, Suit, Rank, rankValue;
import 'hand_evaluator.dart' show HandRank, HandEvaluator, HandCategory;
import 'models.dart'
    show
        BotSkill,
        BotTemperament,
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
import 'bot/advisor.dart';
import 'bot/memory.dart';

// Re-exports for convenience
export 'core.dart' show Card, GamePhase, ActionType, Suit, Rank, rankValue;
export 'hand_evaluator.dart' show HandCategory, HandRank, HandEvaluator;
export 'models.dart'
    show
        BotSkill,
        BotTemperament,
        BlindLevel,
        BlindSchedule,
        GameConfig,
        Player,
        Payout,
        PotSlice,
        GameSnapshot,
        PlayerSnapshot;
export 'events.dart' show ActionResult;
export 'bot/advisor.dart' show BotAdvisor, GameEngineBotLogic;
export 'bot/think_time.dart' show BotThinkTime;
export 'bot/memory.dart'
    show
        BotDecisionLogEntry,
        BotMood,
        BotMoodLabel,
        BotOpponentMemory,
        BotStyleState;

const int _kRaiseIncrement = 10; // enforce bet/raise granularity

/// Public expose of bet/raise increment so UI can snap slider values.
const int kRaiseIncrement = _kRaiseIncrement;

class GameEngineTiming {
  final int skipActionDelayMs;
  final int skipBoardBaseDelayMs;
  final int skipBoardPerCardDelayMs;

  const GameEngineTiming({
    this.skipActionDelayMs = 70,
    this.skipBoardBaseDelayMs = 40,
    this.skipBoardPerCardDelayMs = 70,
  });

  int skipBoardDelayMs(int cards) {
    final int count = cards.clamp(1, 5).toInt();
    return skipBoardBaseDelayMs + skipBoardPerCardDelayMs * count;
  }
}

class GameEngine {
  final GameConfig config;
  final GameEngineTiming timing;

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
  Pcg32 get handRng => _handRng;
  static final BigInt _mask64 = BigInt.parse('0xFFFFFFFFFFFFFFFF');
  BigInt _lastHandSeed = BigInt.zero;
  BigInt get lastHandSeed => _lastHandSeed;
  BigInt _tableSeed = BigInt.zero;
  BigInt get tableSeed => _tableSeed;
  final Map<String, BotOpponentMemory> _botMemories =
      <String, BotOpponentMemory>{};
  final Map<String, BotStyleState> _botStyleStates = <String, BotStyleState>{};
  final Map<String, BotHandTracker> _botHandTrackers =
      <String, BotHandTracker>{};
  final List<BotDecisionLogEntry> _botDecisionLog = <BotDecisionLogEntry>[];
  String? _preflopAggressorId;
  String? _streetVoluntaryAggressorId;
  String? _previousStreetAggressorId;
  final Map<int, int> _lastActedAtBet = <int, int>{};
  final Map<String, int> _handStartingChips = <String, int>{};
  ({
    int seat,
    int handNumber,
    GamePhase phase,
    int currentBet,
    int playerBet,
    int playerChips,
    int pot,
    ActionType action,
    int toAmount,
    double confidence,
    double strength,
  })? _preparedBotDecision;

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
  bool _actionInProgress = false;

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
  int? get lastAggressorIndex => _lastAggressor;
  int _lastRaiseSize = 0;

  /// Calculates a bot action once for the current immutable turn state.
  ///
  /// Presentation code may call this to choose a think delay. The actual bot
  /// tick reuses the same result, so pausing or rebuilding the UI cannot
  /// consume gameplay RNG again and silently change the decision.
  ({
    ActionType action,
    int toAmount,
    double confidence,
    double strength,
  }) prepareBotDecision(int seat) {
    if (seat < 0 || seat >= players.length) {
      throw RangeError.index(seat, players, 'seat');
    }
    final Player player = players[seat];
    final cached = _preparedBotDecision;
    if (cached != null &&
        cached.seat == seat &&
        cached.handNumber == handNumber &&
        cached.phase == phase &&
        cached.currentBet == currentBet &&
        cached.playerBet == player.betThisStreet &&
        cached.playerChips == player.chips &&
        cached.pot == pot) {
      return (
        action: cached.action,
        toAmount: cached.toAmount,
        confidence: cached.confidence,
        strength: cached.strength,
      );
    }

    final advice = BotAdvisor.suggest(this, seat);
    _preparedBotDecision = (
      seat: seat,
      handNumber: handNumber,
      phase: phase,
      currentBet: currentBet,
      playerBet: player.betThisStreet,
      playerChips: player.chips,
      pot: pot,
      action: advice.action,
      toAmount: advice.toAmount,
      confidence: advice.confidence,
      strength: advice.strength,
    );
    return advice;
  }

  // Output from last hand
  List<Payout> lastPayouts = const [];

  // Tournament over flag
  bool _tournamentOver = false;
  bool get isTournamentOver => _tournamentOver;

  GameEngine({
    this.config = const GameConfig(),
    this.timing = const GameEngineTiming(),
  }) {
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
    // If the hand is in pure board-runout mode, SHOW can resolve it immediately.
    if (_earlyAllInClosed()) return true;
    // If only one live player remains, the hand will auto-award, but SHOW now is also safe.
    final live = players.where(_isLiveInHand).length;
    return live <= 1;
  }

  bool wasAggressorPreviousStreet(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= players.length) return false;
    final String id = players[seatIndex].id;
    if (id.isEmpty) return false;
    return _previousStreetAggressorId == id;
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

  bool _seatCanAct(int index) {
    if (index < 0 || index >= players.length) return false;
    final p = players[index];
    return !p.folded && !p.allIn && !p.sittingOut && !p.isOut;
  }

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
    final bool transitioningToHeadsUp = _eligibleCount() == 2 &&
        dealerIndex >= 0 &&
        smallBlindIndex >= 0 &&
        smallBlindIndex != dealerIndex;
    final bool priorBigBlindSurvives = bigBlindIndex >= 0 &&
        bigBlindIndex < players.length &&
        _isEligibleForHand(players[bigBlindIndex]);

    // When a ring game becomes heads-up, the surviving player who most
    // recently paid the big blind becomes the button/small blind. This keeps
    // the other survivor from taking the big blind twice in succession.
    dealerIndex = transitioningToHeadsUp && priorBigBlindSurvives
        ? bigBlindIndex
        : _nextEligibleSeatFrom(dealerIndex);

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
    _memoryForPlayerId(p.id);
    if (p.isBot) {
      _styleForPlayerId(p.id);
    }
    return true;
  }

  void removePlayer(String id) {
    final idx = players.indexWhere((p) => p.id == id);
    if (idx >= 0) {
      players.removeAt(idx);
      _botMemories.remove(id);
      _botStyleStates.remove(id);
      _botHandTrackers.remove(id);
      if (players.isEmpty) _resetTable();
    }
  }

  BotOpponentMemory opponentMemoryForSeat(int seat) {
    return _memoryForPlayerId(players[seat].id);
  }

  BotStyleState styleStateForSeat(int seat) {
    return _styleForPlayerId(players[seat].id);
  }

  final Map<int, double> _botDecisionDifficulty = <int, double>{};

  /// How genuinely close the most recent decision computed for [seat] was:
  /// 0.0 trivial, 1.0 agonising. Written by [BotAdvisor] at the point where
  /// it works out the equity a spot actually requires, and read by the UI
  /// to pace think time.
  ///
  /// This is a presentation signal, so it lives beside the decision rather
  /// than inside the decision record — which every layer between the
  /// advisor and the screen would otherwise have to thread through.
  /// See lib/game/bot/think_time.dart for what consumes it.
  double botDecisionDifficultyForSeat(int seat) =>
      (_botDecisionDifficulty[seat] ?? 0.30).clamp(0.0, 1.0).toDouble();

  void recordBotDecisionDifficulty(int seat, double difficulty) {
    _botDecisionDifficulty[seat] = difficulty.clamp(0.0, 1.0).toDouble();
  }

  List<BotDecisionLogEntry> get botDecisionLog =>
      List.unmodifiable(_botDecisionLog);

  void clearBotDecisionLog() {
    _botDecisionLog.clear();
  }

  String exportBotDecisionLogJson({bool pretty = true}) {
    final payload = _botDecisionLog.map((entry) => entry.toJson()).toList();
    if (pretty) {
      return const JsonEncoder.withIndent('  ').convert(payload);
    }
    return jsonEncode(payload);
  }

  String exportBotDecisionLogJsonLines() {
    return _botDecisionLog
        .map((entry) => jsonEncode(entry.toJson()))
        .join('\n');
  }

  void recordBotDecision({
    required int seat,
    required ActionType action,
    required int toAmount,
    required double confidence,
    required double strength,
  }) {
    if (seat < 0 || seat >= players.length) return;
    final p = players[seat];
    final style = _styleForPlayerId(p.id);
    final int toCall = toCallFor(seat);
    final int liveOpponents = players
        .asMap()
        .entries
        .where((entry) =>
            entry.key != seat &&
            !entry.value.folded &&
            !entry.value.sittingOut &&
            !entry.value.isOut)
        .length;
    final bool hasToCall = toCall > 0;
    final bool multiway = liveOpponents >= 2;
    final double stack = p.chips.toDouble();
    final double stackFrac =
        stack > 0 ? (toCall / stack).clamp(0.0, 1.0).toDouble() : 1.0;
    final bool betIsAllIn = players.any(
      (other) => other.allIn && other.betThisStreet == currentBet,
    );
    final int? aggressor = _lastAggressor;
    final BotOpponentMemory? aggressorMemory = aggressor != null &&
            aggressor >= 0 &&
            aggressor < players.length &&
            aggressor != seat
        ? _memoryForPlayerId(players[aggressor].id)
        : null;
    final bool revengeSpot = aggressor != null &&
        aggressor >= 0 &&
        aggressor < players.length &&
        aggressor != seat &&
        players[aggressor].id == style.revengeTargetId;
    _botDecisionLog.add(
      BotDecisionLogEntry(
        handNumber: handNumber,
        seat: seat,
        playerId: p.id,
        playerName: p.name,
        phase: phase,
        temperament: p.temperament,
        skill: p.skill,
        aura: p.aura,
        pot: pot,
        currentBet: currentBet,
        toCall: toCall,
        stack: p.chips,
        liveOpponents: liveOpponents,
        hasToCall: hasToCall,
        multiway: multiway,
        facingAllIn: hasToCall &&
            betIsAllIn &&
            (stackFrac >= 0.50 || toCall >= bigBlind * 5),
        revengeSpot: revengeSpot,
        fieldFoldRate: _fieldFoldRateForSeat(seat),
        fieldAggression: _fieldAggressionForSeat(seat),
        aggressorAggression: aggressorMemory?.aggressionIndex ?? 0.5,
        aggressorSolidity: aggressorMemory?.showdownStrength ?? 0.5,
        action: action,
        toAmount: toAmount,
        confidence: confidence,
        strength: strength,
        aggressionHeat: style.aggressionHeat,
        bluffAppetite: style.bluffAppetite,
        caution: style.caution,
        styleConfidence: style.confidence,
      ),
    );
    if (_botDecisionLog.length > 2500) {
      _botDecisionLog.removeRange(0, _botDecisionLog.length - 2500);
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
    _resetBotLearningState();
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
    _lastActedAtBet.clear();
    _handStartingChips.clear();
    _preparedBotDecision = null;
    _preflopAggressorId = null;
    _streetVoluntaryAggressorId = null;
    _previousStreetAggressorId = null;
    _botHandTrackers.clear();
    if (players.isEmpty) {
      _resetBotLearningState();
    }
  }

  BotOpponentMemory _memoryForPlayerId(String id) {
    return _botMemories.putIfAbsent(id, () => BotOpponentMemory());
  }

  BotStyleState _styleForPlayerId(String id) {
    return _botStyleStates.putIfAbsent(id, () => BotStyleState());
  }

  BotHandTracker _trackerForPlayerId(String id) {
    return _botHandTrackers.putIfAbsent(id, () => BotHandTracker());
  }

  void _resetBotLearningState() {
    _botMemories.clear();
    _botStyleStates.clear();
    _botHandTrackers.clear();
    _botDecisionLog.clear();
    _preflopAggressorId = null;
    _streetVoluntaryAggressorId = null;
    _previousStreetAggressorId = null;
  }

  void _prepareBotLearningStateForHand() {
    _preflopAggressorId = null;
    _streetVoluntaryAggressorId = null;
    _previousStreetAggressorId = null;
    _botHandTrackers.clear();
    for (final p in players) {
      if (!_isEligibleForHand(p)) continue;
      _memoryForPlayerId(p.id).observeNewHand();
      _trackerForPlayerId(p.id);
      if (p.isBot) {
        // Aura governs how fast the mood resets: a disciplined bot shakes
        // off a bad hand in ~10 hands, a low-aura one stays rattled for
        // most of a session.
        _styleForPlayerId(p.id)
            .decayTowardNeutral(0.06, p.aura.clamp(0, 100) / 100.0);
      }
    }
  }

  double _fieldFoldRateForSeat(int seat) {
    double total = 0.0;
    int seen = 0;
    for (int i = 0; i < players.length; i++) {
      if (i == seat) continue;
      final p = players[i];
      if (p.sittingOut || p.isOut) continue;
      total += _memoryForPlayerId(p.id).foldPressure;
      seen += 1;
    }
    if (seen == 0) return 0.5;
    return (total / seen).clamp(0.0, 1.0).toDouble();
  }

  double _fieldAggressionForSeat(int seat) {
    double total = 0.0;
    int seen = 0;
    for (int i = 0; i < players.length; i++) {
      if (i == seat) continue;
      final p = players[i];
      if (p.sittingOut || p.isOut) continue;
      total += _memoryForPlayerId(p.id).aggressionIndex;
      seen += 1;
    }
    if (seen == 0) return 0.5;
    return (total / seen).clamp(0.0, 1.0).toDouble();
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
    _lastActedAtBet.clear();
    _preparedBotDecision = null;
    _streetVoluntaryAggressorId = null;
    _previousStreetAggressorId = null;
    lastPayouts = const [];
    for (final p in players) {
      p.resetForNewHand(); // clears folded/allIn/bets/best/hole
    }
    _captureHandStartingChips();
    _prepareBotLearningStateForHand();
    final List<int> dealOrder = _eligibleDealOrder();

    _postAntesIfAny();
    _postBlinds(); // sets SB/BB based on dealer & eligibility
    if (config.allowButtonStraddle) _postStraddleIfAny();
    _dealHoleCardsInstant(dealOrder); // emits CardDealt immediately per card

    phase = GamePhase.preflop;
    _setFirstToActPreflop(); // HU: SB/dealer acts first; else left of BB

    // IMPORTANT: HandStarted signature assumed to be HandStarted(dealerIndex)
    _emit(HandStarted(dealerIndex));
    _resolveClosedStateIfNeeded();
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
    _lastActedAtBet.clear();
    _preparedBotDecision = null;
    _streetVoluntaryAggressorId = null;
    _previousStreetAggressorId = null;
    lastPayouts = const [];
    for (final p in players) {
      p.resetForNewHand();
    }
    _captureHandStartingChips();
    _prepareBotLearningStateForHand();
    final List<int> dealOrder = _eligibleDealOrder();

    // Antes
    _postAntesIfAny();

    // Establish and post positions before any hole-card event. Capturing the
    // deal order above ensures an all-in ante/blind still receives cards.
    _postBlinds();
    if (config.allowButtonStraddle) _postStraddleIfAny();

    // Shuffle animation
    await _animateShuffle(
      totalMs: shuffleMsTotal,
      ticks: shuffleTicks,
    );

    // Deal hole cards with animation
    await _dealHoleCardsAnimated(
      dealOrder: dealOrder,
      msPerCard: msPerHoleCard,
      msBetweenPlayers: msBetweenPlayers,
    );

    // Move to preflop
    phase = GamePhase.preflop;
    _setFirstToActPreflop();

    // IMPORTANT: HandStarted signature assumed to be HandStarted(dealerIndex)
    _emit(HandStarted(dealerIndex));
    _resolveClosedStateIfNeeded();

    return ActionResult.ok;
  }

  /// True when the rest of the hand is only a board runout.
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

  List<int> _eligibleDealOrder() {
    if (players.isEmpty || dealerIndex < 0) return const <int>[];
    final List<int> order = <int>[];
    for (int hop = 1; hop <= players.length; hop++) {
      final int index = (dealerIndex + hop) % players.length;
      if (_isEligibleForHand(players[index])) order.add(index);
    }
    return order;
  }

  void _captureHandStartingChips() {
    _handStartingChips
      ..clear()
      ..addEntries(
        players
            .where(_isEligibleForHand)
            .map((Player player) => MapEntry(player.id, player.chips)),
      );
  }

  void _dealHoleCardsInstant(List<int> dealOrder) {
    if (dealOrder.isEmpty) return;
    _emit(const DealingStarted("hole"));

    // Two hole cards, round-robin from left of dealer
    for (int r = 0; r < 2; r++) {
      for (final int idx in dealOrder) {
        final p = players[idx];
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
    required List<int> dealOrder,
    required int msPerCard,
    required int msBetweenPlayers,
  }) async {
    if (dealOrder.isEmpty) return;
    _emit(const DealingStarted("hole"));

    for (int r = 0; r < 2; r++) {
      for (int n = 0; n < dealOrder.length; n++) {
        final idx = dealOrder[n];
        final p = players[idx];

        final c = _deck.draw();
        if (p.hole.isEmpty) {
          p.hole = [c];
        } else {
          p.hole = [...p.hole, c];
        }

        _emit(CardDealt(seatIndex: idx, card: c, isBoard: false));
        await Future.delayed(Duration(milliseconds: msPerCard));

        // Slight travel time to next player
        if (n != dealOrder.length - 1) {
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
    _beginStreetAt(actingIndex);
  }

  void _setFirstToActPostflop() {
    // Reset street state
    currentBet = 0;
    for (final p in players) {
      p.betThisStreet = 0;
    }
    _lastAggressor = null;
    _lastRaiseSize = bigBlind;

    // First to act postflop is left of the dealer (works for HU and ring)
    actingIndex = _nextEligibleSeatFrom(dealerIndex);
    _beginStreetAt(actingIndex);
  }

  void _beginStreetAt(int index) {
    actingIndex = index;
    if (!_skipToNextEligible()) {
      actingIndex = -1;
      _firstActorThisStreet = -1;
      _actedThisStreet.clear();
      _lastActedAtBet.clear();
      return;
    }
    _firstActorThisStreet = actingIndex;
    _actedThisStreet.clear();
    _lastActedAtBet.clear();
    _emit(NextToActChanged(actingIndex));
  }

  void _advanceFirstActorPastIneligible(int seatIndex) {
    if (_firstActorThisStreet != seatIndex) return;
    final nextActor = _nextActingSeatFrom(seatIndex);
    _firstActorThisStreet = nextActor;
  }

  void _recordActed(int index) {
    if (index >= 0 && index < players.length) {
      _actedThisStreet.add(index);
      _lastActedAtBet[index] = currentBet;
    }
  }

  bool _raiseActionIsOpenFor(int index) {
    final int? lastActedAt = _lastActedAtBet[index];
    if (lastActedAt == null) return true;
    return currentBet - lastActedAt >= minRaiseSize();
  }

  bool _allLivePlayersActed(List<int> seats) {
    if (_firstActorThisStreet < 0) return true;
    for (final idx in seats) {
      if (!_actedThisStreet.contains(idx)) return false;
    }
    return true;
  }

  bool _skipToNextEligible() {
    if (_seatCanAct(actingIndex)) return true;
    final int nextActor = _nextActingSeatFrom(actingIndex);
    actingIndex = nextActor;
    return nextActor >= 0;
  }

  int _nextActingSeatFrom(int start) {
    if (players.isEmpty) return -1;
    var idx = start;
    for (int hops = 0; hops < players.length; hops++) {
      idx = (idx + 1) % players.length;
      if (_seatCanAct(idx)) return idx;
    }
    return -1;
  }

  List<int> _liveSeatIndices() {
    final out = <int>[];
    for (int i = 0; i < players.length; i++) {
      if (_isLiveInHand(players[i])) out.add(i);
    }
    return out;
  }

  List<int> _liveBettingSeatIndices() {
    final out = <int>[];
    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      if (_isLiveInHand(p) && !p.allIn) out.add(i);
    }
    return out;
  }

  bool _runoutReady() {
    if (phase == GamePhase.handOver || phase == GamePhase.showdown)
      return false;
    final live = _liveSeatIndices();
    if (live.length < 2) return false;

    final bettingSeats = _liveBettingSeatIndices();
    if (bettingSeats.isEmpty) return true;
    if (bettingSeats.length > 1) return false;

    final onlySeat = bettingSeats.first;
    return players[onlySeat].betThisStreet == currentBet;
  }

  void _closeClosedRound() {
    if (_runoutReady()) {
      if (_skipFastForwardActive) {
        _skipRunoutPending = true;
      } else {
        _dealOutRemainingBoardToShowdownAnimatedIfWanted();
      }
      return;
    }
    _goNextStreetAnimatedIfWanted();
  }

  bool _resolveClosedStateIfNeeded() {
    if (phase == GamePhase.handOver || phase == GamePhase.showdown)
      return false;

    final live = _liveSeatIndices();
    if (live.length <= 1) {
      final winnerIdx = live.isNotEmpty ? live.first : null;
      _awardAllTo(winnerIdx);
      _finalizeHandAndEmit();
      return true;
    }

    if (!_bettingRoundComplete()) return false;
    _closeClosedRound();
    return true;
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
    final int shoveTo = p.betThisStreet + p.chips;
    final bool shoveWouldReopen = shoveTo > currentBet;
    final bool raiseActionOpen = _raiseActionIsOpenFor(index);

    if (p.betThisStreet == currentBet) {
      out.add(ActionType.check);
      if (raiseActionOpen && currentBet == 0) {
        final bounds = raiseBoundsTo(index);
        if (bounds.minTo <= bounds.maxTo) out.add(ActionType.bet);
      } else if (raiseActionOpen) {
        final bounds = raiseBoundsTo(index);
        if (bounds.minTo <= bounds.maxTo && (bounds.minTo > currentBet)) {
          out.add(ActionType.raise);
        }
      }
    } else {
      out.add(ActionType.fold);
      if (toCall > 0) out.add(ActionType.call);
      if (raiseActionOpen) {
        final bounds = raiseBoundsTo(index);
        if (bounds.minTo <= bounds.maxTo &&
            (bounds.minTo > currentBet) &&
            canMatch) {
          out.add(ActionType.raise);
        }
      }
    }

    if (!shoveWouldReopen || raiseActionOpen) {
      out.add(ActionType.allIn);
    }
    return out;
  }

  /* ==================== Actions ==================== */

  void _recordBehaviorSignal({
    required int actorIndex,
    required ActionType type,
    required int toCallBefore,
    required int currentBetBefore,
    int actionTo = 0,
  }) {
    final p = players[actorIndex];
    final memory = _memoryForPlayerId(p.id);
    final tracker = _trackerForPlayerId(p.id);
    final style = _styleForPlayerId(p.id);
    final bool aggressiveAction = type == ActionType.bet ||
        type == ActionType.raise ||
        type == ActionType.allIn;
    if (aggressiveAction) {
      final int wager = max(0, actionTo - p.betThisStreet);
      final int largeThreshold = max(bigBlind * 3, (pot * 0.55).round());
      memory.observeAggression(
        largePressure: type == ActionType.allIn || wager >= largeThreshold,
        allIn: type == ActionType.allIn,
      );
    }
    final bool facingPressure = toCallBefore > 0;
    bool facingRaise = facingPressure && p.betThisStreet > 0;
    if (phase == GamePhase.preflop &&
        _preflopAggressorId == null &&
        currentBetBefore == bigBlind) {
      facingRaise = false;
    }

    if (phase == GamePhase.preflop &&
        type != ActionType.check &&
        type != ActionType.fold &&
        !tracker.sawVpip) {
      tracker.sawVpip = true;
      memory.vpipHands += 1;
    }

    if (phase == GamePhase.preflop &&
        aggressiveAction &&
        !tracker.sawPreflopRaise) {
      tracker.sawPreflopRaise = true;
      memory.preflopRaiseHands += 1;
      _preflopAggressorId = p.id;
    }

    if (phase == GamePhase.flop &&
        p.id == _preflopAggressorId &&
        currentBetBefore == 0) {
      if (!tracker.sawFlopCBetOpportunity) {
        tracker.sawFlopCBetOpportunity = true;
        memory.flopCBetOpportunities += 1;
      }
      if (aggressiveAction && !tracker.sawFlopCBet) {
        tracker.sawFlopCBet = true;
        memory.flopCBetCount += 1;
      }
    }

    if (phase == GamePhase.turn &&
        p.id == _preflopAggressorId &&
        tracker.sawFlopCBet &&
        currentBetBefore == 0) {
      if (!tracker.sawTurnBarrelOpportunity) {
        tracker.sawTurnBarrelOpportunity = true;
        memory.turnBarrelOpportunities += 1;
      }
      if (aggressiveAction && !tracker.sawTurnBarrel) {
        tracker.sawTurnBarrel = true;
        memory.turnBarrelCount += 1;
      }
    }

    if (phase == GamePhase.river) {
      if (!tracker.sawRiverActionOpportunity) {
        tracker.sawRiverActionOpportunity = true;
        memory.riverActionOpportunities += 1;
      }
      if (aggressiveAction && !tracker.sawRiverAggression) {
        tracker.sawRiverAggression = true;
        memory.riverAggressionCount += 1;
      }
    }

    if (facingPressure) {
      if (facingRaise) {
        if (!tracker.sawFacedRaise) {
          tracker.sawFacedRaise = true;
          memory.facedRaiseSpots += 1;
        }
        if (type == ActionType.fold && !tracker.sawFoldToRaise) {
          tracker.sawFoldToRaise = true;
          memory.foldToRaiseCount += 1;
        }
      } else {
        if (!tracker.sawFacedBet) {
          tracker.sawFacedBet = true;
          memory.facedBetSpots += 1;
        }
        if (type == ActionType.fold && !tracker.sawFoldToBet) {
          tracker.sawFoldToBet = true;
          memory.foldToBetCount += 1;
        }
      }
    }

    if (!p.isBot) return;

    final double styleAuraSkill = p.aura.clamp(0, 100) / 100.0;

    if (aggressiveAction) {
      style.aggressionHeat += phase == GamePhase.river ? 0.05 : 0.035;
      style.bluffAppetite +=
          (phase == GamePhase.turn || phase == GamePhase.river) ? 0.02 : 0.01;
      style.caution -= 0.01;
      // Momentum: taking the aggressive line feeds on itself, more so on
      // later streets where the commitment is real.
      style.applyFearGreed(
          phase == GamePhase.river ? 0.030 : 0.020, styleAuraSkill);
    }

    if (type == ActionType.call && facingPressure) {
      style.confidence += 0.01;
      style.caution -= 0.01;
      style.applyFearGreed(0.012, styleAuraSkill);
    }

    if (type == ActionType.fold && facingPressure) {
      style.caution += 0.045;
      style.confidence -= 0.02;
      // Getting moved off a hand stings in proportion to what was in the
      // middle: laying down to a min-bet is a shrug, laying down a big
      // pot is what actually makes a player play scared afterwards.
      final double potPressure =
          (pot / max(1, p.chips)).clamp(0.0, 1.0).toDouble();
      style.applyFearGreed(-0.035 - 0.030 * potPressure, styleAuraSkill);
      final int? aggressor = _lastAggressor;
      if (aggressor != null &&
          aggressor >= 0 &&
          aggressor < players.length &&
          aggressor != actorIndex) {
        style.revengeTargetId = players[aggressor].id;
      }
    }

    style.normalize();
  }

  double _handStrengthForStyle(HandRank rank) {
    final double catScore =
        rank.category.index / (HandCategory.values.length - 1);
    final double kickerScore =
        rank.tiebreakers.isEmpty ? 0.0 : rank.tiebreakers.first / 14.0;
    return (catScore * 0.8 + kickerScore * 0.2).clamp(0.0, 1.0).toDouble();
  }

  void _updateBotStyleAfterHand({
    required List<int> bustedNow,
    required Set<int> winners,
  }) {
    final Map<int, int> receivedBySeat = <int, int>{};
    for (final payout in lastPayouts) {
      receivedBySeat[payout.playerIndex] =
          (receivedBySeat[payout.playerIndex] ?? 0) + payout.amount;
    }

    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      if (!p.isBot) continue;
      final style = _styleForPlayerId(p.id);
      final bool won = winners.contains(i);
      final bool busted = bustedNow.contains(i);
      final bool reachedShowdown = !p.folded && p.best != null;

      if (won) {
        style.confidence += 0.08;
        style.caution -= 0.03;
        style.aggressionHeat += 0.02;
      } else if (reachedShowdown) {
        style.confidence -= 0.05;
        style.caution += 0.035;
      }

      if (busted) {
        style.confidence -= 0.14;
        style.caution += 0.10;
        style.aggressionHeat = (style.aggressionHeat * 0.7) + 0.15;
      }

      // Mood moves with the size of the swing, not merely its sign.
      // Chips are already credited here, so the pre-hand stack is
      // recovered by backing the swing out. Direction is taken from the
      // net swing rather than the `won` flag, because a split pot can
      // "win" and still cost chips.
      final double auraSkill = p.aura.clamp(0, 100) / 100.0;
      final int netSwing = (receivedBySeat[i] ?? 0) - p.contributedThisHand;
      final int preHandStack = max(1, p.chips - netSwing);
      final double swingRatio =
          (netSwing / preHandStack).clamp(-1.0, 2.0).toDouble();

      if (netSwing > 0) {
        // Scraping a blind barely registers; doubling up feels invincible.
        style.applyFearGreed(0.05 + 0.15 * min(1.0, swingRatio), auraSkill);
      } else if (netSwing < 0 && reachedShowdown) {
        // Losing a showdown you paid off is the classic tilt trigger.
        style.applyFearGreed(-0.05 + 0.17 * max(-1.0, swingRatio), auraSkill);
      }
      if (busted) {
        style.applyFearGreed(-0.10, auraSkill);
      }

      style.normalize();
    }
  }

  ActionResult act(ActionType type, {int amount = 0}) {
    if (_actionInProgress) {
      return ActionResult.notYourTurn;
    }
    if (phase == GamePhase.predeal ||
        phase == GamePhase.handOver ||
        phase == GamePhase.showdown) {
      return ActionResult.illegalAtThisPhase;
    }
    if (actingIndex < 0 || actingIndex >= players.length) {
      return ActionResult.illegalAtThisPhase;
    }

    final actorIndex = actingIndex;
    final p = players[actorIndex];
    final int toCallBefore = toCallFor(actorIndex);
    final int currentBetBefore = currentBet;
    if (p.folded || p.allIn || p.sittingOut || p.isOut) {
      return ActionResult.alreadyFoldedOrAllIn;
    }

    _actionInProgress = true;
    try {
      switch (type) {
        case ActionType.fold:
          _recordBehaviorSignal(
            actorIndex: actorIndex,
            type: type,
            toCallBefore: toCallBefore,
            currentBetBefore: currentBetBefore,
          );
          p.folded = true;
          _advanceFirstActorPastIneligible(actorIndex);
          _recordActed(actorIndex);
          _emit(ActionTaken(actorIndex, type, 0));
          return _afterActionAdvance();

        case ActionType.check:
          if (p.betThisStreet != currentBet)
            return ActionResult.cannotCheckFacingBet;
          _recordBehaviorSignal(
            actorIndex: actorIndex,
            type: type,
            toCallBefore: toCallBefore,
            currentBetBefore: currentBetBefore,
          );
          _recordActed(actorIndex);
          _emit(ActionTaken(actorIndex, type, 0));
          return _afterActionAdvance();

        case ActionType.call:
          {
            final need = toCallFor(actorIndex);
            if (need <= 0) return ActionResult.nothingToCall;
            _recordBehaviorSignal(
              actorIndex: actorIndex,
              type: type,
              toCallBefore: toCallBefore,
              currentBetBefore: currentBetBefore,
            );
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
    } finally {
      _actionInProgress = false;
    }
  }

  ActionResult _afterActionAdvance() {
    _advanceTurnOrStreet();

    // If the hand is now in pure runout mode, auto-resolve it.
    if (_earlyAllInClosed()) {
      _closeClosedRound();
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
    final int toCallBefore = toCallFor(idx);
    final int currentBetBefore = currentBet;
    final Set<ActionType> legal = legalActionsFor(idx);
    if (!legal.contains(type)) {
      return currentBet == 0
          ? ActionResult.invalidBetAmount
          : ActionResult.invalidRaiseAmount;
    }

    final bool forceAllIn = type == ActionType.allIn;
    if (forceAllIn) {
      toAmount = p.betThisStreet + p.chips; // shove to total
    }

    int delta = toAmount - p.betThisStreet;
    if (delta <= 0) return ActionResult.invalidBetAmount;

    if (delta > p.chips) {
      if (!forceAllIn) {
        return currentBet == 0
            ? ActionResult.invalidBetAmount
            : ActionResult.invalidRaiseAmount;
      }
      delta = p.chips;
      toAmount = p.betThisStreet + delta;
    }

    final bool isAllIn = forceAllIn || (delta == p.chips);
    bool _aligned(int amt) => amt % _kRaiseIncrement == 0;
    final bool increasesBet = toAmount > currentBet;

    if (increasesBet && !_raiseActionIsOpenFor(idx)) {
      return ActionResult.invalidRaiseAmount;
    }
    if (!isAllIn && currentBet > 0 && !increasesBet) {
      return ActionResult.invalidRaiseAmount;
    }

    if (!isAllIn && !_aligned(toAmount)) {
      return currentBet == 0
          ? ActionResult.invalidBetAmount
          : ActionResult.invalidRaiseAmount;
    }

    if (currentBet == 0) {
      // Opening bet
      final minBetTo = bigBlind;
      if (!isAllIn && toAmount < minBetTo) return ActionResult.invalidBetAmount;

      _recordBehaviorSignal(
        actorIndex: idx,
        type: type,
        toCallBefore: toCallBefore,
        currentBetBefore: currentBetBefore,
        actionTo: toAmount,
      );
      _payIntoPot(p, delta);
      _registerAggression(
        raiseTo: p.betThisStreet,
        isAllIn: isAllIn,
        isNewBet: true,
        isFullRaise: p.betThisStreet >= minBetTo,
      );
      _recordActed(idx);
      _emit(ActionTaken(idx, type, toAmount));
      return _afterActionAdvance();
    }

    // Raise case
    final previousBet = currentBet;
    final minRaiseTo = currentBet + minRaiseSize();

    if (!isAllIn && toAmount < minRaiseTo) {
      return ActionResult.invalidRaiseAmount;
    }

    _recordBehaviorSignal(
      actorIndex: idx,
      type: type,
      toCallBefore: toCallBefore,
      currentBetBefore: currentBetBefore,
      actionTo: toAmount,
    );
    _payIntoPot(p, delta);

    final reachedOrExceeded = p.betThisStreet >= minRaiseTo;
    if (p.betThisStreet > previousBet && reachedOrExceeded) {
      _registerAggression(
        raiseTo: p.betThisStreet,
        isAllIn: isAllIn,
        isNewBet: false,
        isFullRaise: true,
      );
    } else {
      // Call that doesn't reach min raise (or all-in short raise)
      currentBet = max(currentBet, p.betThisStreet);
    }
    _recordActed(idx);

    _emit(ActionTaken(idx, type, toAmount));
    return _afterActionAdvance();
  }

  void _registerAggression({
    required int raiseTo,
    required bool isAllIn,
    required bool isNewBet,
    required bool isFullRaise,
  }) {
    final previousBet = currentBet;
    currentBet = max(currentBet, raiseTo);
    if (isNewBet && isFullRaise) {
      _lastRaiseSize = currentBet;
    } else if (!isNewBet && isFullRaise) {
      final inc = currentBet - previousBet;
      if (inc > 0) {
        _lastRaiseSize = inc;
      }
    }
    _lastAggressor = actingIndex;
    if (actingIndex >= 0 && actingIndex < players.length) {
      final actor = players[actingIndex];
      _streetVoluntaryAggressorId = actor.id;
    }
  }

  void _captureStreetAggressorForNextStreet() {
    _previousStreetAggressorId = _streetVoluntaryAggressorId;
    _streetVoluntaryAggressorId = null;
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
      _closeClosedRound();
      return;
    }

    final int nextActor = _nextActingSeatFrom(actingIndex);
    if (nextActor < 0) {
      actingIndex = -1;
      _resolveClosedStateIfNeeded();
      return;
    }
    actingIndex = nextActor;
    if (_bettingRoundComplete()) {
      _closeClosedRound();
      return;
    }
    _emit(NextToActChanged(actingIndex));
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
      if (idx < 0 || idx >= players.length) {
        _resolveClosedStateIfNeeded();
        return;
      }
      final p = players[idx];
      if (p.folded || p.allIn || p.sittingOut || p.isOut) {
        if (!_nextActor()) {
          _resolveClosedStateIfNeeded();
          return;
        }
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
          _advanceFirstActorPastIneligible(idx);
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

  bool _nextActor() {
    final int nextActor = _nextActingSeatFrom(actingIndex);
    if (nextActor < 0) {
      actingIndex = -1;
      return false;
    }
    actingIndex = nextActor;
    _emit(NextToActChanged(actingIndex));
    return true;
  }

  /* ---------- Burn helper ---------- */
  void _burn() {
    // Standard Hold'em burn: discard top card of the deck
    // (Deck.draw() already advances the deck; we don't need the card.)
    _deck.draw();
  }

  /* ---------- Street progression (instant) ---------- */

  void _goNextStreet() {
    _captureStreetAggressorForNextStreet();
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
  bool _skipFastForwardActive = false;
  bool get skipFastForwardActive => _skipFastForwardActive;
  bool _skipRunoutPending = false;

  void _goNextStreetAnimatedIfWanted() {
    if (!animateStreets) {
      _goNextStreet();
      return;
    }
    unawaited(_goNextStreetAnimated());
  }

  Future<void> _goNextStreetAnimated() async {
    _captureStreetAggressorForNextStreet();
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

  /// Fast-forward the remainder of the hand to the winner quickly.
  /// Auto-plays actions so the pot evolves naturally, then runs out the board.
  void requestSkipToWinner() {
    if (phase == GamePhase.handOver || phase == GamePhase.showdown) return;
    if (_skipFastForwardActive) return;
    unawaited(_fastForwardToWinner());
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
    return _runoutReady();
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

  int _skipBoardDelayMs(int cards) {
    return timing.skipBoardDelayMs(cards);
  }

  Future<void> _dealOutRemainingBoardToShowdownAnimatedWithDelay() async {
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
          await Future.delayed(Duration(milliseconds: _skipBoardDelayMs(3)));
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
          await Future.delayed(Duration(milliseconds: _skipBoardDelayMs(1)));
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
          await Future.delayed(Duration(milliseconds: _skipBoardDelayMs(1)));
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

  Future<void> _fastForwardToWinner() async {
    _skipFastForwardActive = true;
    _skipRunoutPending = false;
    final prevAnimate = animateStreets;
    animateStreets = true;

    int safety = players.length * 200;
    int lastCommunity = community.length;

    try {
      _forceHeroFoldForSkipIfNeeded();
      while (phase != GamePhase.handOver &&
          phase != GamePhase.showdown &&
          safety-- > 0) {
        if (_skipRunoutPending) {
          _skipRunoutPending = false;
          await _dealOutRemainingBoardToShowdownAnimatedWithDelay();
          break;
        }

        final idx = actingIndex;
        if (idx < 0 || idx >= players.length) {
          if (!_nextActor()) {
            _resolveClosedStateIfNeeded();
          }
          continue;
        }
        final p = players[idx];
        if (p.folded || p.allIn || p.sittingOut || p.isOut) {
          if (!_nextActor()) {
            _resolveClosedStateIfNeeded();
          }
          continue;
        }

        final advice = prepareBotDecision(idx);
        recordBotDecision(
          seat: idx,
          action: advice.action,
          toAmount: advice.toAmount,
          confidence: advice.confidence,
          strength: advice.strength,
        );
        if (act(advice.action, amount: advice.toAmount) != ActionResult.ok) {
          if (canCheck(idx)) {
            act(ActionType.check);
          } else if (toCallFor(idx) > 0) {
            act(ActionType.fold);
          } else {
            act(ActionType.check);
          }
        }

        if (_skipRunoutPending) {
          _skipRunoutPending = false;
          await _dealOutRemainingBoardToShowdownAnimatedWithDelay();
          break;
        }

        if (phase == GamePhase.handOver || phase == GamePhase.showdown) {
          break;
        }

        final int newCommunity = community.length;
        final int delta = newCommunity - lastCommunity;
        lastCommunity = newCommunity;

        if (delta > 0) {
          await Future.delayed(
              Duration(milliseconds: _skipBoardDelayMs(delta)));
        } else {
          await Future.delayed(
              Duration(milliseconds: timing.skipActionDelayMs));
        }
      }

      if (safety <= 0 &&
          phase != GamePhase.handOver &&
          phase != GamePhase.showdown) {
        _dealOutRemainingBoardToShowdown();
        _showdownAndPayout();
        _finalizeHandAndEmit();
      }
    } finally {
      animateStreets = prevAnimate;
      _skipFastForwardActive = false;
      _skipRunoutPending = false;
    }
  }

  void _forceHeroFoldForSkipIfNeeded() {
    if (heroIndex < 0 || heroIndex >= players.length) return;
    final p = players[heroIndex];
    if (p.folded || p.allIn || p.sittingOut || p.isOut) return;

    if (actingIndex == heroIndex) {
      final prevPhase = phase;
      final bool heroWasFirst = _firstActorThisStreet == heroIndex;
      act(ActionType.fold);
      if (heroWasFirst &&
          phase == prevPhase &&
          _firstActorThisStreet == heroIndex &&
          actingIndex >= 0) {
        _firstActorThisStreet = actingIndex;
      }
      return;
    }

    p.folded = true;
    _advanceFirstActorPastIneligible(heroIndex);
    _emit(ActionTaken(heroIndex, ActionType.fold, 0));
    _resolveClosedStateIfNeeded();
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

  /// Public accessor for the configured payout at a given 1-based finish
  /// rank (1 = first place). Used by the ICM/tournament-standings layer in
  /// `lib/game/bot/tournament_context.dart` and `lib/game/bot/icm_guard.dart`
  /// so bot decisions can reason about live prize equity instead of only
  /// chip stacks. Returns 0 when no payout table/callback is configured or
  /// `rank` is outside the paid places — safe to call at any time.
  int payoutForRank(int rank) => _cfgPayoutForRank(rank);

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
    bustedNow.sort((int a, int b) {
      final int aStart = _handStartingChips[players[a].id] ?? 0;
      final int bStart = _handStartingChips[players[b].id] ?? 0;
      final int byStack = aStart.compareTo(bStart);
      if (byStack != 0) return byStack;

      // Equal starting stacks use table position relative to the button,
      // rather than raw seat index. Closest to the dealer's left ranks higher.
      int leftDistance(int seat) {
        if (players.isEmpty || dealerIndex < 0) return players.length;
        return ((seat - dealerIndex - 1) % players.length) + 1;
      }

      return leftDistance(b).compareTo(leftDistance(a));
    });

    for (int i = 0; i < players.length; i++) {
      final p = players[i];
      if (p.folded || p.best == null) continue;
      final memory = _memoryForPlayerId(p.id);
      memory.showdowns += 1;
      memory.showdownStrengthTotal += _handStrengthForStyle(p.best!);
    }

    // Optional tournament winner (only one alive seat remains overall)
    final alive = _aliveSeats();
    int? tournamentChampion;
    int tournamentPrize = 0;
    if (alive.length == 1 && !_tournamentOver) {
      tournamentChampion = alive.first;
      tournamentPrize = _cfgPayoutForRank(1);
      _tournamentOver = true;
    }

    // Build winners set (anyone who received > 0 in lastPayouts)
    final winners = lastPayouts.map((p) => p.playerIndex).toSet();
    _updateBotStyleAfterHand(bustedNow: bustedNow, winners: winners);

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

    // Emit the tournament terminal signal only after every eliminated player
    // has received an exact rank. UI/economy listeners can then settle the
    // hero's actual result instead of guessing from the table size.
    if (tournamentChampion != null) {
      _eventLog.add(WinnerDeclared(tournamentChampion, tournamentPrize));
      _emit(TournamentEnded(tournamentChampion, tournamentPrize));
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
      return !p.folded && !p.sittingOut && p.best != null;
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
