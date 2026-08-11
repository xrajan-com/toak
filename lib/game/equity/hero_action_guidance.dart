import 'dart:math' as math;

import '../core.dart' show Card, Rank, Suit, rankValue;

const double heroFoldWeakEquityThreshold = 0.20;
const double heroLowStackFraction = 0.20;

enum HeroRecommendedAction {
  allIn,
  raise,
  check,
  call,
  fold,
}

enum HeroTablePosition {
  early,
  middle,
  late,
  button,
  smallBlind,
  bigBlind,
  unknown,
}

class HeroActionRecommendation {
  final HeroRecommendedAction action;
  final double handStrength;
  final double potOdds;
  final double requiredCallEquity;
  final bool strategicAdjustmentApplied;

  const HeroActionRecommendation({
    required this.action,
    required this.handStrength,
    this.potOdds = 0,
    this.requiredCallEquity = 0,
    this.strategicAdjustmentApplied = false,
  });
}

/// Produces conservative, visible-information action guidance.
///
/// Showdown equity remains the primary input. Hand shape only adjusts the
/// price of a call when stacks are deep enough for implied odds to matter; it
/// never turns a speculative holding into an automatic raise or all-in.
HeroActionRecommendation recommendHeroAction({
  required double equity,
  required double marginOfError95,
  required int potBeforeCall,
  required int toCall,
  required int heroStack,
  int startingStack = 0,
  required int livePlayers,
  required List<Card> heroHole,
  required List<Card> revealedBoard,
  HeroTablePosition tablePosition = HeroTablePosition.unknown,
  bool facingAggression = false,
}) {
  final double handStrength = equity.clamp(0.0, 1.0);
  final double conservativeEquity =
      (handStrength - marginOfError95.clamp(0.0, 0.25)).clamp(0.0, 1.0);
  final int safeCall = math.max(0, toCall);
  final int safePot = math.max(0, potBeforeCall);
  final int fieldSize = livePlayers.clamp(2, 10);
  final double fieldBaseline = 1 / fieldSize;
  final double potOdds =
      safeCall <= 0 ? 0 : safeCall / math.max(1, safePot + safeCall);
  final double stackPressure = heroStack <= 0
      ? (safeCall > 0 ? 1 : 0)
      : (safeCall / heroStack).clamp(0.0, 1.0);
  final int chipsAfterCall = math.max(0, heroStack - safeCall);
  final bool lowOnChips = startingStack > 0
      ? chipsAfterCall <= (startingStack * heroLowStackFraction).round()
      : stackPressure >= 0.25;

  final _HandPotential potential = _handPotential(
    heroHole: heroHole,
    revealedBoard: revealedBoard,
  );
  final bool preflop = revealedBoard.isEmpty;

  double handClassAdjustment = 0;
  if (preflop && potential.suitedConnected) {
    if (stackPressure <= 0.05) {
      handClassAdjustment = 0.09;
    } else if (stackPressure <= 0.10) {
      handClassAdjustment = 0.05;
    }
  } else if (preflop && potential.connectedBroadway) {
    if (stackPressure <= 0.05) {
      handClassAdjustment = 0.045;
    } else if (stackPressure <= 0.10) {
      handClassAdjustment = 0.025;
    }
  } else if (preflop && potential.pocketPair) {
    if (stackPressure <= 0.05) {
      handClassAdjustment = 0.05;
    } else if (stackPressure <= 0.10) {
      handClassAdjustment = 0.025;
    }
  } else if (!preflop && potential.comboDraw && stackPressure <= 0.12) {
    handClassAdjustment = 0.055;
  } else if (!preflop && potential.strongDraw && stackPressure <= 0.10) {
    handClassAdjustment = 0.035;
  }

  if (preflop && facingAggression) {
    handClassAdjustment *= 0.60;
  }

  double positionAdjustment = 0;
  if (preflop && stackPressure <= 0.10) {
    positionAdjustment = switch (tablePosition) {
      HeroTablePosition.button => 0.018,
      HeroTablePosition.late => 0.014,
      HeroTablePosition.bigBlind => 0.022,
      HeroTablePosition.middle => 0.004,
      HeroTablePosition.early => -0.015,
      HeroTablePosition.smallBlind => -0.004,
      HeroTablePosition.unknown => 0,
    };
  }

  final double callSafetyBuffer = preflop ? 0.005 : 0.015;
  final double requiredCallEquity =
      (potOdds + callSafetyBuffer - handClassAdjustment - positionAdjustment)
          .clamp(0.08, 0.62);
  final bool strategicAdjustmentApplied =
      handClassAdjustment > 0 || positionAdjustment.abs() > 0.0001;

  final bool highPressure = stackPressure >= 0.25;
  final bool lateStreet = revealedBoard.length >= 4;
  if (conservativeEquity >= 0.90 && (highPressure || lateStreet)) {
    return HeroActionRecommendation(
      action: HeroRecommendedAction.allIn,
      handStrength: handStrength,
      potOdds: potOdds,
      requiredCallEquity: requiredCallEquity,
      strategicAdjustmentApplied: strategicAdjustmentApplied,
    );
  }

  if (preflop &&
      !facingAggression &&
      stackPressure <= 0.05 &&
      _isOpeningRaiseCandidate(potential, tablePosition)) {
    return HeroActionRecommendation(
      action: HeroRecommendedAction.raise,
      handStrength: handStrength,
      potOdds: potOdds,
      requiredCallEquity: requiredCallEquity,
      strategicAdjustmentApplied: strategicAdjustmentApplied,
    );
  }

  final double raiseThreshold = math.max(
    fieldBaseline + (preflop ? 0.13 : 0.11),
    safeCall > 0 ? potOdds + 0.14 : fieldBaseline + (preflop ? 0.13 : 0.11),
  );
  if (conservativeEquity >= raiseThreshold ||
      (conservativeEquity >= 0.76 && stackPressure < 0.25)) {
    return HeroActionRecommendation(
      action: HeroRecommendedAction.raise,
      handStrength: handStrength,
      potOdds: potOdds,
      requiredCallEquity: requiredCallEquity,
      strategicAdjustmentApplied: strategicAdjustmentApplied,
    );
  }

  if (safeCall <= 0) {
    return HeroActionRecommendation(
      action: HeroRecommendedAction.check,
      handStrength: handStrength,
      potOdds: potOdds,
      requiredCallEquity: requiredCallEquity,
      strategicAdjustmentApplied: strategicAdjustmentApplied,
    );
  }

  final bool handIsReallyWeak = handStrength < heroFoldWeakEquityThreshold;
  final bool foldIsAllowed = handIsReallyWeak || lowOnChips;
  return HeroActionRecommendation(
    action: conservativeEquity >= requiredCallEquity || !foldIsAllowed
        ? HeroRecommendedAction.call
        : HeroRecommendedAction.fold,
    handStrength: handStrength,
    potOdds: potOdds,
    requiredCallEquity: requiredCallEquity,
    strategicAdjustmentApplied: strategicAdjustmentApplied,
  );
}

class _HandPotential {
  final bool suitedConnected;
  final bool connectedBroadway;
  final bool pocketPair;
  final bool broadway;
  final int highRank;
  final int lowRank;
  final bool strongDraw;
  final bool comboDraw;

  const _HandPotential({
    required this.suitedConnected,
    required this.connectedBroadway,
    required this.pocketPair,
    required this.broadway,
    required this.highRank,
    required this.lowRank,
    required this.strongDraw,
    required this.comboDraw,
  });
}

_HandPotential _handPotential({
  required List<Card> heroHole,
  required List<Card> revealedBoard,
}) {
  bool suitedConnected = false;
  bool connectedBroadway = false;
  bool pocketPair = false;
  bool broadway = false;
  int highRank = 0;
  int lowRank = 0;
  if (heroHole.length >= 2) {
    final Card first = heroHole[0];
    final Card second = heroHole[1];
    final int firstRank = rankValue(first.rank);
    final int secondRank = rankValue(second.rank);
    highRank = math.max(firstRank, secondRank);
    lowRank = math.min(firstRank, secondRank);
    final int gap = highRank - lowRank;
    pocketPair = first.rank == second.rank;
    broadway = lowRank >= rankValue(Rank.ten);
    connectedBroadway = broadway && !pocketPair && gap == 1;
    suitedConnected = first.suit == second.suit &&
        !pocketPair &&
        gap <= 2 &&
        lowRank >= rankValue(Rank.five);
  }

  if (revealedBoard.length < 3 || revealedBoard.length >= 5) {
    return _HandPotential(
      suitedConnected: suitedConnected,
      connectedBroadway: connectedBroadway,
      pocketPair: pocketPair,
      broadway: broadway,
      highRank: highRank,
      lowRank: lowRank,
      strongDraw: false,
      comboDraw: false,
    );
  }

  final List<Card> cards = <Card>[...heroHole, ...revealedBoard];
  final Map<Suit, int> suitCounts = <Suit, int>{};
  final Set<Suit> heroSuits = heroHole.map((card) => card.suit).toSet();
  for (final Card card in cards) {
    suitCounts[card.suit] = (suitCounts[card.suit] ?? 0) + 1;
  }
  final bool flushDraw = suitCounts.entries.any(
    (entry) => entry.value == 4 && heroSuits.contains(entry.key),
  );

  final Set<int> ranks = <int>{};
  final Set<int> heroRanks = <int>{};
  for (final Card card in cards) {
    final int value = rankValue(card.rank);
    ranks.add(value);
    if (heroHole.contains(card)) heroRanks.add(value);
    if (value == rankValue(Rank.ace)) {
      ranks.add(1);
      if (heroHole.contains(card)) heroRanks.add(1);
    }
  }
  bool straightDraw = false;
  for (int high = 5; high <= 14; high++) {
    final List<int> sequence = <int>[
      high,
      high - 1,
      high - 2,
      high - 3,
      high - 4,
    ];
    if (sequence.where(ranks.contains).length == 4 &&
        sequence.any(heroRanks.contains)) {
      straightDraw = true;
      break;
    }
  }

  return _HandPotential(
    suitedConnected: suitedConnected,
    connectedBroadway: connectedBroadway,
    pocketPair: pocketPair,
    broadway: broadway,
    highRank: highRank,
    lowRank: lowRank,
    strongDraw: flushDraw || straightDraw,
    comboDraw: flushDraw && straightDraw,
  );
}

bool _isOpeningRaiseCandidate(
  _HandPotential hand,
  HeroTablePosition position,
) {
  final bool strongBroadway = hand.broadway &&
      hand.highRank >= rankValue(Rank.queen) &&
      hand.lowRank >= rankValue(Rank.jack);
  final bool premiumBroadway = hand.broadway &&
      ((hand.highRank == rankValue(Rank.ace) &&
              hand.lowRank >= rankValue(Rank.jack)) ||
          (hand.highRank >= rankValue(Rank.king) &&
              hand.lowRank >= rankValue(Rank.queen)));
  final bool mediumPair =
      hand.pocketPair && hand.highRank >= rankValue(Rank.six);

  return switch (position) {
    HeroTablePosition.button ||
    HeroTablePosition.late =>
      hand.broadway || hand.suitedConnected || hand.pocketPair,
    HeroTablePosition.middle => strongBroadway ||
        (hand.suitedConnected && hand.lowRank >= rankValue(Rank.eight)) ||
        mediumPair,
    HeroTablePosition.early => premiumBroadway ||
        (hand.pocketPair && hand.highRank >= rankValue(Rank.eight)),
    HeroTablePosition.smallBlind => strongBroadway || mediumPair,
    HeroTablePosition.bigBlind || HeroTablePosition.unknown => false,
  };
}
