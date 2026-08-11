import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/core.dart';
import 'package:ten_of_a_kind_poker/game/equity/hero_action_guidance.dart';
import 'package:ten_of_a_kind_poker/game/equity/preflop_equity_table.dart';

void main() {
  const List<Card> jackNineSuited = <Card>[
    Card(Rank.jack, Suit.clubs),
    Card(Rank.nine, Suit.clubs),
  ];
  const List<Card> jackNineOffsuit = <Card>[
    Card(Rank.jack, Suit.clubs),
    Card(Rank.nine, Suit.hearts),
  ];

  test('cheap J9 suited call gets deep-stack implied-odds credit', () {
    final PreflopEquityValue estimate = lookupPreflopEquity(jackNineSuited, 5)!;
    final HeroActionRecommendation recommendation = recommendHeroAction(
      equity: estimate.equity,
      marginOfError95: estimate.marginOfError95,
      potBeforeCall: 600,
      toCall: 300,
      heroStack: 9700,
      livePlayers: 5,
      heroHole: jackNineSuited,
      revealedBoard: const <Card>[],
    );

    expect(recommendation.action, HeroRecommendedAction.call);
    expect(recommendation.strategicAdjustmentApplied, isTrue);
    expect(recommendation.requiredCallEquity, lessThan(estimate.equity));
  });

  test('J9 suited above the weak threshold is not labeled fold', () {
    final PreflopEquityValue estimate = lookupPreflopEquity(jackNineSuited, 5)!;
    final HeroActionRecommendation recommendation = recommendHeroAction(
      equity: estimate.equity,
      marginOfError95: estimate.marginOfError95,
      potBeforeCall: 600,
      toCall: 2000,
      heroStack: 9700,
      startingStack: 10000,
      livePlayers: 5,
      heroHole: jackNineSuited,
      revealedBoard: const <Card>[],
    );

    expect(recommendation.action, HeroRecommendedAction.call);
    expect(recommendation.strategicAdjustmentApplied, isFalse);
  });

  test('offsuit J9 does not receive the suited connector discount', () {
    final PreflopEquityValue estimate =
        lookupPreflopEquity(jackNineOffsuit, 5)!;
    final HeroActionRecommendation recommendation = recommendHeroAction(
      equity: estimate.equity,
      marginOfError95: estimate.marginOfError95,
      potBeforeCall: 600,
      toCall: 300,
      heroStack: 9700,
      livePlayers: 5,
      heroHole: jackNineOffsuit,
      revealedBoard: const <Card>[],
    );

    expect(recommendation.action, HeroRecommendedAction.call);
    expect(recommendation.strategicAdjustmentApplied, isFalse);
  });

  test('a real straight-flush draw gets call credit after the flop', () {
    final HeroActionRecommendation recommendation = recommendHeroAction(
      equity: 0.30,
      marginOfError95: 0,
      potBeforeCall: 600,
      toCall: 300,
      heroStack: 9700,
      livePlayers: 3,
      heroHole: const <Card>[
        Card(Rank.jack, Suit.hearts),
        Card(Rank.nine, Suit.hearts),
      ],
      revealedBoard: const <Card>[
        Card(Rank.ten, Suit.hearts),
        Card(Rank.eight, Suit.hearts),
        Card(Rank.two, Suit.clubs),
      ],
    );

    expect(recommendation.action, HeroRecommendedAction.call);
    expect(recommendation.strategicAdjustmentApplied, isTrue);
  });

  test('multiway premium equity raises but does not auto-shove', () {
    const List<Card> aces = <Card>[
      Card(Rank.ace, Suit.spades),
      Card(Rank.ace, Suit.hearts),
    ];
    final PreflopEquityValue estimate = lookupPreflopEquity(aces, 5)!;
    final HeroActionRecommendation recommendation = recommendHeroAction(
      equity: estimate.equity,
      marginOfError95: estimate.marginOfError95,
      potBeforeCall: 600,
      toCall: 0,
      heroStack: 10000,
      livePlayers: 5,
      heroHole: aces,
      revealedBoard: const <Card>[],
    );

    expect(recommendation.action, HeroRecommendedAction.raise);
  });

  test('QJ offsuit opens from the button in an unopened six-max pot', () {
    const List<Card> queenJackOffsuit = <Card>[
      Card(Rank.queen, Suit.hearts),
      Card(Rank.jack, Suit.clubs),
    ];
    final PreflopEquityValue estimate =
        lookupPreflopEquity(queenJackOffsuit, 6)!;
    final HeroActionRecommendation recommendation = recommendHeroAction(
      equity: estimate.equity,
      marginOfError95: estimate.marginOfError95,
      potBeforeCall: 300,
      toCall: 100,
      heroStack: 9900,
      livePlayers: 6,
      heroHole: queenJackOffsuit,
      revealedBoard: const <Card>[],
      tablePosition: HeroTablePosition.button,
      facingAggression: false,
    );

    expect(estimate.equity, closeTo(0.226, 0.001));
    expect(recommendation.action, HeroRecommendedAction.raise);
  });

  test('QJ offsuit stays playable above the weak-hand threshold', () {
    const List<Card> queenJackOffsuit = <Card>[
      Card(Rank.queen, Suit.hearts),
      Card(Rank.jack, Suit.clubs),
    ];
    final PreflopEquityValue estimate =
        lookupPreflopEquity(queenJackOffsuit, 6)!;

    final HeroActionRecommendation smallPrice = recommendHeroAction(
      equity: estimate.equity,
      marginOfError95: estimate.marginOfError95,
      potBeforeCall: 300,
      toCall: 100,
      heroStack: 9900,
      livePlayers: 6,
      heroHole: queenJackOffsuit,
      revealedBoard: const <Card>[],
      tablePosition: HeroTablePosition.button,
      facingAggression: true,
    );
    final HeroActionRecommendation heavyPressure = recommendHeroAction(
      equity: estimate.equity,
      marginOfError95: estimate.marginOfError95,
      potBeforeCall: 300,
      toCall: 400,
      heroStack: 9600,
      startingStack: 10000,
      livePlayers: 6,
      heroHole: queenJackOffsuit,
      revealedBoard: const <Card>[],
      tablePosition: HeroTablePosition.early,
      facingAggression: true,
    );

    expect(smallPrice.action, HeroRecommendedAction.call);
    expect(heavyPressure.action, HeroRecommendedAction.call);
  });

  test('fold is reserved for sub-20-percent equity or a low stack', () {
    const List<Card> sevenTwoOffsuit = <Card>[
      Card(Rank.seven, Suit.clubs),
      Card(Rank.two, Suit.hearts),
    ];
    final HeroActionRecommendation weakHand = recommendHeroAction(
      equity: 0.19,
      marginOfError95: 0,
      potBeforeCall: 100,
      toCall: 400,
      heroStack: 9600,
      startingStack: 10000,
      livePlayers: 6,
      heroHole: sevenTwoOffsuit,
      revealedBoard: const <Card>[],
      tablePosition: HeroTablePosition.early,
      facingAggression: true,
    );
    final HeroActionRecommendation thresholdHand = recommendHeroAction(
      equity: heroFoldWeakEquityThreshold,
      marginOfError95: 0,
      potBeforeCall: 100,
      toCall: 400,
      heroStack: 9600,
      startingStack: 10000,
      livePlayers: 6,
      heroHole: sevenTwoOffsuit,
      revealedBoard: const <Card>[],
      tablePosition: HeroTablePosition.early,
      facingAggression: true,
    );
    final HeroActionRecommendation lowStack = recommendHeroAction(
      equity: 0.30,
      marginOfError95: 0,
      potBeforeCall: 100,
      toCall: 400,
      heroStack: 1800,
      startingStack: 10000,
      livePlayers: 6,
      heroHole: sevenTwoOffsuit,
      revealedBoard: const <Card>[],
      tablePosition: HeroTablePosition.early,
      facingAggression: true,
    );

    expect(weakHand.action, HeroRecommendedAction.fold);
    expect(thresholdHand.action, HeroRecommendedAction.call);
    expect(lowStack.action, HeroRecommendedAction.fold);
  });
}
