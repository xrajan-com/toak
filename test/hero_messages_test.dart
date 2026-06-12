import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/core.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/hero_messages.dart';

void main() {
  test('visible win probability drops as live player count increases', () {
    final headsUp = estimateVisibleHeroWinProbability(
      livePlayers: 2,
      heroHole: const <Card>[
        Card(Rank.ace, Suit.spades),
        Card(Rank.ace, Suit.hearts),
      ],
      revealedBoard: const <Card>[],
    );
    final fourWay = estimateVisibleHeroWinProbability(
      livePlayers: 4,
      heroHole: const <Card>[
        Card(Rank.ace, Suit.spades),
        Card(Rank.ace, Suit.hearts),
      ],
      revealedBoard: const <Card>[],
    );

    expect(headsUp, isNotNull);
    expect(fourWay, isNotNull);
    expect(headsUp!, greaterThan(fourWay!));
    expect(
      estimateVisibleHeroWinProbability(
        livePlayers: 1,
        heroHole: const <Card>[
          Card(Rank.ace, Suit.spades),
          Card(Rank.ace, Suit.hearts),
        ],
        revealedBoard: const <Card>[],
      ),
      1.0,
    );
  });

  test('visible win probability respects only the revealed board', () {
    final prob = estimateVisibleHeroWinProbability(
      livePlayers: 5,
      heroHole: const <Card>[
        Card(Rank.ace, Suit.spades),
        Card(Rank.king, Suit.spades),
      ],
      revealedBoard: const <Card>[
        Card(Rank.queen, Suit.spades),
        Card(Rank.jack, Suit.spades),
        Card(Rank.ten, Suit.spades),
        Card(Rank.two, Suit.diamonds),
        Card(Rank.three, Suit.clubs),
      ],
    );

    expect(prob, 1.0);
  });

  test('hero guidance message uses compact chance hand action format', () {
    final message = buildVisibleHeroGuidanceMessage(
      livePlayers: 4,
      canCheck: false,
      winProbability: 0.21,
      revealedBoardCount: 3,
      variantSeed: 0,
      aggressorName: 'Riya',
      aggressorAllIn: false,
      handName: 'FLUSH DRAW',
    );

    expect(message, '21% CHANCE, FLUSH DRAW, CALL');
  });

  test('hero guidance points to raise when action is free and equity is high',
      () {
    final message = buildVisibleHeroGuidanceMessage(
      livePlayers: 3,
      canCheck: true,
      winProbability: 0.72,
      revealedBoardCount: 3,
      variantSeed: 0,
      aggressorName: null,
      aggressorAllIn: false,
      handName: 'FLUSH',
    );

    expect(message, '72% CHANCE, FLUSH, RAISE');
  });

  test('hero guidance uses call when facing pressure with a strong river hand',
      () {
    final message = buildVisibleHeroGuidanceMessage(
      livePlayers: 3,
      canCheck: false,
      winProbability: 0.71,
      revealedBoardCount: 5,
      variantSeed: 0,
      aggressorName: 'Vik',
      aggressorAllIn: true,
      handName: 'TWO PAIR',
      improvementHint: null,
      heroRecentActionLabel: 'Raise to 800',
    );

    expect(message, '71% CHANCE, TWO PAIR, CALL');
  });

  test('hero guidance uses check for modest equity when checking is free', () {
    final message = buildVisibleHeroGuidanceMessage(
      livePlayers: 5,
      canCheck: true,
      winProbability: 0.34,
      revealedBoardCount: 4,
      variantSeed: 0,
      aggressorName: null,
      aggressorAllIn: false,
      handName: 'PAIR',
      improvementHint: null,
    );

    expect(message, '34% CHANCE, PAIR, CHECK');
  });

  test('hero guidance does not fold medium-low equity by default', () {
    final message = buildVisibleHeroGuidanceMessage(
      livePlayers: 5,
      canCheck: false,
      winProbability: 0.18,
      revealedBoardCount: 3,
      variantSeed: 0,
      aggressorName: 'Riya',
      aggressorAllIn: true,
      handName: 'STRAIGHT DRAW',
      heroRecentActionLabel: 'Call 200',
    );

    expect(message, '18% CHANCE, STRAIGHT DRAW, CALL');
  });

  test('hero guidance uses rotating caution labels in clearly bad all-in spots',
      () {
    final message0 = buildVisibleHeroGuidanceMessage(
      livePlayers: 5,
      canCheck: false,
      winProbability: 0.07,
      revealedBoardCount: 3,
      variantSeed: 0,
      aggressorName: 'Riya',
      aggressorAllIn: true,
      handName: 'HIGH CARD',
      heroRecentActionLabel: 'Call 200',
    );
    final message1 = buildVisibleHeroGuidanceMessage(
      livePlayers: 5,
      canCheck: false,
      winProbability: 0.07,
      revealedBoardCount: 3,
      variantSeed: 1,
      aggressorName: 'Riya',
      aggressorAllIn: true,
      handName: 'HIGH CARD',
      heroRecentActionLabel: 'Call 200',
    );
    final message2 = buildVisibleHeroGuidanceMessage(
      livePlayers: 5,
      canCheck: false,
      winProbability: 0.07,
      revealedBoardCount: 3,
      variantSeed: 2,
      aggressorName: 'Riya',
      aggressorAllIn: true,
      handName: 'HIGH CARD',
      heroRecentActionLabel: 'Call 200',
    );

    expect(message0, '7% CHANCE, HIGH CARD, CAUTION');
    expect(message1, '7% CHANCE, HIGH CARD, TOO THIN');
    expect(message2, '7% CHANCE, HIGH CARD, DANGER');
  });

  test(
      'hero guidance calls when probability is unknown instead of auto-folding',
      () {
    final message = buildVisibleHeroGuidanceMessage(
      livePlayers: 4,
      canCheck: false,
      winProbability: null,
      revealedBoardCount: 3,
      variantSeed: 0,
      aggressorName: 'Riya',
      aggressorAllIn: true,
      handName: 'FLUSH DRAW',
    );

    expect(message, '--% CHANCE, FLUSH DRAW, CALL');
  });
}
