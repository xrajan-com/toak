import 'dart:async';
import 'dart:math' as math;

import '../core.dart' show Card, Rank, Suit, rankValue;
import '../hand_evaluator.dart' show HandCategory, HandEvaluator, HandRank;
import 'preflop_equity_table.dart' show lookupPreflopEquity;

/// A visible-action description of one opponent's likely holdings.
///
/// This deliberately contains no hole cards. The estimator is safe to use in
/// live play because its only opponent input is information already shown at
/// the table: the latest action and whether the player is all-in.
class VisibleOpponentRange {
  final String publicAction;
  final double strengthBias;

  const VisibleOpponentRange._({
    required this.publicAction,
    required this.strengthBias,
  });

  const VisibleOpponentRange.neutral()
      : publicAction = '',
        strengthBias = 0;

  factory VisibleOpponentRange.fromPublicAction(
    String? action, {
    bool allIn = false,
  }) {
    final String label = (action ?? '').trim().toUpperCase();
    if (allIn || label.startsWith('ALL-IN') || label.startsWith('ALL IN')) {
      return VisibleOpponentRange._(
        publicAction: label.isEmpty ? 'ALL-IN' : label,
        strengthBias: 1,
      );
    }
    if (label.startsWith('RAISE') || label.startsWith('BET')) {
      return VisibleOpponentRange._(
        publicAction: label,
        strengthBias: 0.76,
      );
    }
    if (label.startsWith('CALL')) {
      return VisibleOpponentRange._(
        publicAction: label,
        strengthBias: 0.48,
      );
    }
    if (label.startsWith('CHECK')) {
      return VisibleOpponentRange._(
        publicAction: label,
        strengthBias: 0.14,
      );
    }
    return const VisibleOpponentRange.neutral();
  }

  bool get isNeutral => strengthBias <= 0;

  String get cacheKey => '${strengthBias.toStringAsFixed(2)}:$publicAction';

  double weightFor(List<Card> hole, List<Card> visibleBoard) {
    if (isNeutral) return 1;
    final double strength = _visibleComboStrength(hole, visibleBoard);
    final double concentration = 0.75 + strengthBias * 4.25;
    // Keep every legal holding possible. An aggressive action narrows the
    // distribution substantially but never turns this into a perfect-read
    // oracle.
    return 0.025 + 0.975 * math.pow(strength, concentration).toDouble();
  }
}

class HeroEquitySeat {
  final int seatIndex;
  final bool active;
  final bool allIn;
  final int contribution;
  final VisibleOpponentRange range;

  const HeroEquitySeat({
    required this.seatIndex,
    required this.active,
    required this.allIn,
    required this.contribution,
    this.range = const VisibleOpponentRange.neutral(),
  });
}

class HeroEquityRequest {
  final int heroSeatIndex;
  final List<Card> heroHole;
  final List<Card> revealedBoard;
  final List<HeroEquitySeat> seats;
  final double visiblePot;

  const HeroEquityRequest({
    required this.heroSeatIndex,
    required this.heroHole,
    required this.revealedBoard,
    required this.seats,
    required this.visiblePot,
  });

  List<HeroEquitySeat> get activeSeats =>
      seats.where((seat) => seat.active).toList(growable: false);

  String get cacheKey {
    final List<String> hole = heroHole.take(2).map(_cardKey).toList()..sort();
    final List<String> board = revealedBoard.take(5).map(_cardKey).toList()
      ..sort();
    final List<String> seatState = seats
        .map((seat) => <String>[
              '${seat.seatIndex}',
              seat.active ? '1' : '0',
              seat.allIn ? '1' : '0',
              '${seat.contribution}',
              seat.range.cacheKey,
            ].join(':'))
        .toList()
      ..sort();
    return <String>[
      'hero:$heroSeatIndex',
      'h:${hole.join(',')}',
      'b:${board.join(',')}',
      'p:${visiblePot.round()}',
      ...seatState,
    ].join('|');
  }
}

class HeroEquityEstimate {
  /// Probability that hero is the unique best hand.
  final double winProbability;

  /// Probability that hero ties for the best hand with at least one opponent.
  final double tieProbability;

  /// Expected showdown share of a common pot, with ties split fractionally.
  final double equity;

  /// Expected fraction of all current chips in the pot after side-pot caps.
  final double expectedPotShare;
  final int samples;
  final double marginOfError95;
  final bool exact;
  final bool sidePotAware;
  final String method;

  const HeroEquityEstimate({
    required this.winProbability,
    required this.tieProbability,
    required this.equity,
    required this.expectedPotShare,
    required this.samples,
    required this.marginOfError95,
    required this.exact,
    required this.sidePotAware,
    required this.method,
  });
}

/// Hybrid visible-information Hold'em estimator.
///
/// - bundled preflop lookup for neutral, ordinary pots;
/// - exact weighted enumeration heads-up on the turn and river;
/// - stratified, adaptive Monte Carlo for all other postflop states;
/// - public-action opponent ranges and exact engine-style side-pot layers.
class HeroEquityEngine {
  static const int defaultMinimumSamples = 5000;
  static const int defaultMaximumSamples = 20000;
  static const double defaultTargetMargin95 = 0.008;

  final int minimumSamples;
  final int maximumSamples;
  final double targetMargin95;
  final int yieldEvery;

  static final Map<String, HeroEquityEstimate> _cache =
      <String, HeroEquityEstimate>{};

  const HeroEquityEngine({
    this.minimumSamples = defaultMinimumSamples,
    this.maximumSamples = defaultMaximumSamples,
    this.targetMargin95 = defaultTargetMargin95,
    this.yieldEvery = 250,
  });

  HeroEquityEstimate? immediateEstimate(HeroEquityRequest request) {
    final String key = request.cacheKey;
    final HeroEquityEstimate? cached = _cache[key];
    if (cached != null) return cached;

    final List<HeroEquitySeat> active = request.activeSeats;
    if (request.heroHole.length < 2 || active.isEmpty) return null;
    if (active.length == 1) {
      return const HeroEquityEstimate(
        winProbability: 1,
        tieProbability: 0,
        equity: 1,
        expectedPotShare: 1,
        samples: 1,
        marginOfError95: 0,
        exact: true,
        sidePotAware: false,
        method: 'No opponents',
      );
    }

    final List<HeroEquitySeat> opponents = active
        .where((seat) => seat.seatIndex != request.heroSeatIndex)
        .toList(growable: false);
    final bool neutralRanges = opponents.every((seat) => seat.range.isNeutral);
    final bool sidePotAware = _hasActiveSidePot(request);
    if (request.revealedBoard.isEmpty && neutralRanges && !sidePotAware) {
      final value = lookupPreflopEquity(request.heroHole, active.length);
      if (value != null) {
        final estimate = HeroEquityEstimate(
          winProbability: value.winProbability,
          tieProbability: value.tieProbability,
          equity: value.equity,
          expectedPotShare: value.equity,
          samples: value.samples,
          marginOfError95: value.marginOfError95,
          exact: false,
          sidePotAware: false,
          method: 'Bundled preflop lookup',
        );
        _remember(key, estimate);
        return estimate;
      }
    }
    return null;
  }

  /// Returns a small deterministic simulation immediately for UI display.
  ///
  /// The bundled preflop table and completed cache remain the preferred fast
  /// paths. This preview fills the gap when public actions, board cards, or a
  /// side pot require the more expensive estimator, so the HUD never has to
  /// replace useful percentages with placeholders while that work runs.
  HeroEquityEstimate? previewEstimate(
    HeroEquityRequest request, {
    int maximumSamples = 320,
  }) {
    final HeroEquityEstimate? immediate = immediateEstimate(request);
    if (immediate != null) return immediate;
    if (maximumSamples <= 0 || !_isValid(request)) return null;

    final List<HeroEquitySeat> opponents = request.activeSeats
        .where((seat) => seat.seatIndex != request.heroSeatIndex)
        .toList(growable: false);
    if (opponents.isEmpty) return null;

    final List<Card> hero = request.heroHole.take(2).toList(growable: false);
    final List<Card> board =
        request.revealedBoard.take(5).toList(growable: false);
    final List<Card> remaining = _remainingDeck(<Card>[...hero, ...board]);
    final int boardNeeded = 5 - board.length;
    final int sampleBudget =
        (maximumSamples / (1 + math.max(0, opponents.length - 1) * 0.20))
            .round()
            .clamp(math.min(120, maximumSamples), maximumSamples);
    final math.Random rng =
        math.Random(_stableSeed('${request.cacheKey}|preview'));
    final bool sidePotAware = _hasActiveSidePot(request);
    final List<_PotSlice> pots = _potSlices(request, sidePotAware);
    final _Accumulator total = _Accumulator();
    final bool stratifyRunouts = boardNeeded <= 2;

    for (int sample = 0; sample < sampleBudget; sample++) {
      final Set<String> unavailable = <String>{
        ...hero.map(_cardKey),
        ...board.map(_cardKey),
      };
      final Map<int, List<Card>> holes = <int, List<Card>>{};
      for (final HeroEquitySeat opponent in opponents) {
        final List<Card>? sampled = _sampleWeightedHole(
          remaining,
          unavailable,
          opponent.range,
          board,
          rng,
        );
        if (sampled == null) return null;
        holes[opponent.seatIndex] = sampled;
        unavailable.addAll(sampled.map(_cardKey));
      }

      final List<Card> legalRunoutDeck = remaining
          .where((card) => !unavailable.contains(_cardKey(card)))
          .toList(growable: false);
      if (legalRunoutDeck.length < boardNeeded) return null;
      final List<Card> runout = stratifyRunouts
          ? _stratifiedRunout(
              legalRunoutDeck,
              boardNeeded,
              sample,
              sampleBudget,
              rng,
            )
          : ((List<Card>.from(legalRunoutDeck)..shuffle(rng))
              .take(boardNeeded)
              .toList(growable: false));

      _scoreOutcome(
        request: request,
        board: <Card>[...board, ...runout],
        opponentHoles: holes,
        accumulator: total,
        pots: pots,
        weight: 1,
      );
    }

    if (total.weight <= 0) return null;
    return total.toEstimate(
      exact: false,
      sidePotAware: sidePotAware,
      method: 'Quick deterministic preview',
    );
  }

  Future<HeroEquityEstimate?> estimate(
    HeroEquityRequest request, {
    bool Function()? shouldCancel,
  }) async {
    final HeroEquityEstimate? immediate = immediateEstimate(request);
    if (immediate != null) return immediate;
    if (!_isValid(request)) return null;

    final List<HeroEquitySeat> opponents = request.activeSeats
        .where((seat) => seat.seatIndex != request.heroSeatIndex)
        .toList(growable: false);
    if (opponents.length == 1 && request.revealedBoard.length >= 4) {
      final exact = await _enumerateHeadsUp(
        request,
        opponents.single,
        shouldCancel: shouldCancel,
      );
      if (exact != null) _remember(request.cacheKey, exact);
      return exact;
    }

    final estimate = await _simulateAdaptive(
      request,
      opponents,
      shouldCancel: shouldCancel,
    );
    if (estimate != null) _remember(request.cacheKey, estimate);
    return estimate;
  }

  static void clearCacheForTests() => _cache.clear();

  static void _remember(String key, HeroEquityEstimate estimate) {
    _cache[key] = estimate;
    while (_cache.length > 96) {
      _cache.remove(_cache.keys.first);
    }
  }

  bool _isValid(HeroEquityRequest request) {
    if (request.heroHole.length < 2 || request.revealedBoard.length > 5) {
      return false;
    }
    final Set<String> visible = <String>{};
    for (final card in <Card>[
      ...request.heroHole.take(2),
      ...request.revealedBoard.take(5),
    ]) {
      if (!visible.add(_cardKey(card))) return false;
    }
    final int opponents = request.activeSeats.length - 1;
    return opponents >= 0 &&
        52 - visible.length >= opponents * 2 + 5 - request.revealedBoard.length;
  }

  Future<HeroEquityEstimate?> _enumerateHeadsUp(
    HeroEquityRequest request,
    HeroEquitySeat opponent, {
    bool Function()? shouldCancel,
  }) async {
    final List<Card> hero = request.heroHole.take(2).toList(growable: false);
    final List<Card> board =
        request.revealedBoard.take(5).toList(growable: false);
    final List<Card> remaining = _remainingDeck(<Card>[...hero, ...board]);
    final _Accumulator total = _Accumulator();
    final bool sidePotAware = _hasActiveSidePot(request);
    final List<_PotSlice> pots = _potSlices(request, sidePotAware);
    int work = 0;

    for (int a = 0; a < remaining.length - 1; a++) {
      for (int b = a + 1; b < remaining.length; b++) {
        final List<Card> oppHole = <Card>[remaining[a], remaining[b]];
        final double weight = opponent.range.weightFor(oppHole, board);
        if (board.length == 5) {
          _scoreOutcome(
            request: request,
            board: board,
            opponentHoles: <int, List<Card>>{opponent.seatIndex: oppHole},
            accumulator: total,
            pots: pots,
            weight: weight,
          );
          work++;
        } else {
          for (int river = 0; river < remaining.length; river++) {
            if (river == a || river == b) continue;
            _scoreOutcome(
              request: request,
              board: <Card>[...board, remaining[river]],
              opponentHoles: <int, List<Card>>{opponent.seatIndex: oppHole},
              accumulator: total,
              pots: pots,
              weight: weight,
            );
            work++;
            if (work % yieldEvery == 0) {
              if (shouldCancel?.call() == true) return null;
              await Future<void>.delayed(Duration.zero);
            }
          }
        }
      }
      if (work % yieldEvery != 0 && a.isEven) {
        if (shouldCancel?.call() == true) return null;
        await Future<void>.delayed(Duration.zero);
      }
    }
    if (shouldCancel?.call() == true || total.weight <= 0) return null;
    return total.toEstimate(
      exact: true,
      sidePotAware: sidePotAware,
      method: board.length == 5
          ? 'Exact heads-up river enumeration'
          : 'Exact heads-up turn enumeration',
    );
  }

  Future<HeroEquityEstimate?> _simulateAdaptive(
    HeroEquityRequest request,
    List<HeroEquitySeat> opponents, {
    bool Function()? shouldCancel,
  }) async {
    final List<Card> hero = request.heroHole.take(2).toList(growable: false);
    final List<Card> board =
        request.revealedBoard.take(5).toList(growable: false);
    final List<Card> remaining = _remainingDeck(<Card>[...hero, ...board]);
    final int boardNeeded = 5 - board.length;
    final math.Random rng = math.Random(_stableSeed(request.cacheKey));
    final bool sidePotAware = _hasActiveSidePot(request);
    final List<_PotSlice> pots = _potSlices(request, sidePotAware);
    final _Accumulator total = _Accumulator();
    final bool stratifyRunouts = boardNeeded <= 2;

    for (int sample = 0; sample < maximumSamples; sample++) {
      if (shouldCancel?.call() == true) return null;
      final Set<String> unavailable = <String>{
        ...hero.map(_cardKey),
        ...board.map(_cardKey),
      };
      final Map<int, List<Card>> holes = <int, List<Card>>{};
      for (final opponent in opponents) {
        final List<Card>? sampled = _sampleWeightedHole(
          remaining,
          unavailable,
          opponent.range,
          board,
          rng,
        );
        if (sampled == null) return null;
        holes[opponent.seatIndex] = sampled;
        unavailable.addAll(sampled.map(_cardKey));
      }
      final List<Card> legalRunoutDeck = remaining
          .where((card) => !unavailable.contains(_cardKey(card)))
          .toList(growable: false);
      final List<Card> runout = stratifyRunouts
          ? _stratifiedRunout(
              legalRunoutDeck,
              boardNeeded,
              sample,
              math.max(1, yieldEvery),
              rng,
            )
          : ((List<Card>.from(legalRunoutDeck)..shuffle(rng))
              .take(boardNeeded)
              .toList(growable: false));

      _scoreOutcome(
        request: request,
        board: <Card>[...board, ...runout],
        opponentHoles: holes,
        accumulator: total,
        pots: pots,
        weight: 1,
      );

      final int count = sample + 1;
      if (count % yieldEvery == 0) {
        await Future<void>.delayed(Duration.zero);
        if (count >= minimumSamples &&
            total.marginOfError95 <= targetMargin95) {
          break;
        }
      }
    }
    if (shouldCancel?.call() == true || total.weight <= 0) return null;
    return total.toEstimate(
      exact: false,
      sidePotAware: sidePotAware,
      method: !stratifyRunouts
          ? 'Adaptive Monte Carlo'
          : 'Stratified adaptive Monte Carlo',
    );
  }
}

class _Accumulator {
  double weight = 0;
  double wins = 0;
  double ties = 0;
  double equityTotal = 0;
  double equitySquaredTotal = 0;
  double potShareTotal = 0;
  int outcomes = 0;

  double get marginOfError95 {
    if (weight <= 1) return 1;
    final double mean = equityTotal / weight;
    final double variance =
        math.max(0, equitySquaredTotal / weight - mean * mean);
    return 1.96 * math.sqrt(variance / weight);
  }

  HeroEquityEstimate toEstimate({
    required bool exact,
    required bool sidePotAware,
    required String method,
  }) {
    return HeroEquityEstimate(
      winProbability: (wins / weight).clamp(0, 1).toDouble(),
      tieProbability: (ties / weight).clamp(0, 1).toDouble(),
      equity: (equityTotal / weight).clamp(0, 1).toDouble(),
      expectedPotShare: (potShareTotal / weight).clamp(0, 1).toDouble(),
      samples: outcomes,
      marginOfError95: exact ? 0 : marginOfError95,
      exact: exact,
      sidePotAware: sidePotAware,
      method: method,
    );
  }
}

class _PotSlice {
  final double amount;
  final Set<int> eligible;

  const _PotSlice(this.amount, this.eligible);
}

void _scoreOutcome({
  required HeroEquityRequest request,
  required List<Card> board,
  required Map<int, List<Card>> opponentHoles,
  required _Accumulator accumulator,
  required List<_PotSlice> pots,
  required double weight,
}) {
  final List<Card> heroHole = request.heroHole.take(2).toList(growable: false);
  final HandRank heroRank =
      HandEvaluator.evaluate(<Card>[...heroHole, ...board]);
  final Map<int, HandRank> ranks = <int, HandRank>{
    request.heroSeatIndex: heroRank,
  };
  bool heroBest = true;
  int tieCount = 1;
  for (final entry in opponentHoles.entries) {
    final HandRank rank =
        HandEvaluator.evaluate(<Card>[...entry.value, ...board]);
    ranks[entry.key] = rank;
    final int cmp = rank.compareTo(heroRank);
    if (cmp > 0) {
      heroBest = false;
    } else if (cmp == 0) {
      tieCount++;
    }
  }
  final double equity = heroBest ? 1 / tieCount : 0;
  if (heroBest && tieCount == 1) accumulator.wins += weight;
  if (heroBest && tieCount > 1) accumulator.ties += weight;

  double heroPayout = 0;
  double totalPot = 0;
  for (final pot in pots) {
    totalPot += pot.amount;
    HandRank? best;
    final List<int> winners = <int>[];
    for (final seatIndex in pot.eligible) {
      final HandRank? rank = ranks[seatIndex];
      if (rank == null) continue;
      if (best == null || rank.compareTo(best) > 0) {
        best = rank;
        winners
          ..clear()
          ..add(seatIndex);
      } else if (rank.compareTo(best) == 0) {
        winners.add(seatIndex);
      }
    }
    if (winners.contains(request.heroSeatIndex)) {
      heroPayout += pot.amount / winners.length;
    }
  }
  final double potShare = totalPot > 0 ? heroPayout / totalPot : equity;
  accumulator
    ..weight += weight
    ..equityTotal += equity * weight
    ..equitySquaredTotal += equity * equity * weight
    ..potShareTotal += potShare * weight
    ..outcomes += 1;
}

bool _hasActiveSidePot(HeroEquityRequest request) {
  final List<HeroEquitySeat> active = request.activeSeats;
  if (!active.any((seat) => seat.allIn)) return false;
  final Set<int> positive = active
      .map((seat) => seat.contribution)
      .where((amount) => amount > 0)
      .toSet();
  return positive.length > 1;
}

List<_PotSlice> _potSlices(HeroEquityRequest request, bool sidePotAware) {
  final Set<int> active =
      request.activeSeats.map((seat) => seat.seatIndex).toSet();
  if (!sidePotAware) {
    final double amount = request.visiblePot > 0
        ? request.visiblePot
        : request.seats
            .map((seat) => seat.contribution)
            .fold<double>(0, (sum, value) => sum + value);
    return <_PotSlice>[_PotSlice(math.max(1, amount), active)];
  }

  final List<int> levels = request.seats
      .map((seat) => seat.contribution)
      .where((amount) => amount > 0)
      .toSet()
      .toList()
    ..sort();
  final List<_PotSlice> slices = <_PotSlice>[];
  int previous = 0;
  for (final int level in levels) {
    final int layer = level - previous;
    final List<HeroEquitySeat> contributors = request.seats
        .where((seat) => seat.contribution >= level)
        .toList(growable: false);
    final Set<int> eligible = contributors
        .where((seat) => seat.active)
        .map((seat) => seat.seatIndex)
        .toSet();
    if (layer > 0 && contributors.isNotEmpty && eligible.isNotEmpty) {
      slices.add(_PotSlice(layer * contributors.length.toDouble(), eligible));
    }
    previous = level;
  }
  if (slices.isEmpty) {
    return <_PotSlice>[
      _PotSlice(math.max(1, request.visiblePot), active),
    ];
  }
  return slices;
}

List<Card>? _sampleWeightedHole(
  List<Card> available,
  Set<String> unavailable,
  VisibleOpponentRange range,
  List<Card> visibleBoard,
  math.Random rng,
) {
  final List<Card> legal = available
      .where((card) => !unavailable.contains(_cardKey(card)))
      .toList(growable: false);
  if (legal.length < 2) return null;
  List<Card>? fallback;
  for (int attempt = 0; attempt < 96; attempt++) {
    final int a = rng.nextInt(legal.length);
    int b = rng.nextInt(legal.length - 1);
    if (b >= a) b++;
    final List<Card> candidate = <Card>[legal[a], legal[b]];
    fallback = candidate;
    if (range.isNeutral ||
        rng.nextDouble() <= range.weightFor(candidate, visibleBoard)) {
      return candidate;
    }
  }
  return fallback;
}

double _visibleComboStrength(List<Card> hole, List<Card> board) {
  if (hole.length < 2) return 0.5;
  if (board.length + hole.length >= 5) {
    final HandRank rank = HandEvaluator.evaluate(<Card>[...hole, ...board]);
    final double category = rank.category.index / HandCategory.values.length;
    double kicker = 0;
    double scale = 1;
    for (final value in rank.tiebreakers.take(5)) {
      scale *= 15;
      kicker += value / scale;
    }
    final double made = category + kicker / HandCategory.values.length;
    final double draw = _drawPotential(hole, board);
    return (made * 0.86 + draw * 0.14).clamp(0.02, 1).toDouble();
  }
  return _preflopComboStrength(hole);
}

double _preflopComboStrength(List<Card> hole) {
  final int a = rankValue(hole[0].rank);
  final int b = rankValue(hole[1].rank);
  final int high = math.max(a, b);
  final int low = math.min(a, b);
  final bool pair = high == low;
  final bool suited = hole[0].suit == hole[1].suit;
  final int gap = high - low;
  double score = ((high - 2) / 12) * 0.48 + ((low - 2) / 12) * 0.22;
  if (pair) score += 0.30 + ((high - 2) / 12) * 0.18;
  if (suited) score += 0.07;
  if (!pair && gap <= 1) score += 0.08;
  if (!pair && gap == 2) score += 0.04;
  if (high == 14 && low >= 10) score += 0.07;
  return score.clamp(0.02, 1).toDouble();
}

double _drawPotential(List<Card> hole, List<Card> board) {
  if (board.length >= 5) return 0;
  final List<Card> cards = <Card>[...hole, ...board];
  final Map<Suit, int> suits = <Suit, int>{};
  for (final card in cards) {
    suits[card.suit] = (suits[card.suit] ?? 0) + 1;
  }
  final bool flushDraw = suits.values.any((count) => count == 4) &&
      hole.any((card) => (suits[card.suit] ?? 0) == 4);
  final Set<int> ranks = cards.map((card) => rankValue(card.rank)).toSet();
  if (ranks.contains(14)) ranks.add(1);
  int bestWindow = 0;
  for (int start = 1; start <= 10; start++) {
    int count = 0;
    for (int value = start; value < start + 5; value++) {
      if (ranks.contains(value)) count++;
    }
    bestWindow = math.max(bestWindow, count);
  }
  final bool straightDraw = bestWindow >= 4;
  if (flushDraw && straightDraw) return 1;
  if (flushDraw) return 0.82;
  if (straightDraw) return 0.68;
  return 0;
}

List<Card> _stratifiedRunout(
  List<Card> deck,
  int needed,
  int sample,
  int strata,
  math.Random rng,
) {
  if (needed <= 0) return const <Card>[];
  final double quantile = ((sample % strata) + rng.nextDouble()) / strata;
  if (needed == 1) {
    final int index =
        (quantile * deck.length).floor().clamp(0, deck.length - 1);
    return <Card>[deck[index]];
  }

  final int combinations = deck.length * (deck.length - 1) ~/ 2;
  int target = (quantile * combinations).floor().clamp(0, combinations - 1);
  for (int first = 0; first < deck.length - 1; first++) {
    final int row = deck.length - first - 1;
    if (target < row) {
      return <Card>[deck[first], deck[first + 1 + target]];
    }
    target -= row;
  }
  return <Card>[deck[deck.length - 2], deck.last];
}

List<Card> _remainingDeck(List<Card> excludedCards) {
  final Set<String> excluded = excludedCards.map(_cardKey).toSet();
  return <Card>[
    for (final Suit suit in Suit.values)
      for (final Rank rank in Rank.values)
        if (!excluded.contains('${rank.index}:${suit.index}')) Card(rank, suit),
  ];
}

int _stableSeed(String value) {
  int hash = 0x811c9dc5;
  for (final int unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

String _cardKey(Card card) => '${card.rank.index}:${card.suit.index}';
