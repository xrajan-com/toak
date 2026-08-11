import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

eng.GameEngine _headsUpEngine({
  eng.GamePhase phase = eng.GamePhase.preflop,
  int pot = 0,
}) {
  final e = eng.GameEngine(
    config: const eng.GameConfig(
      tableSeed: 91,
      smallBlind: 100,
      bigBlind: 200,
      maxPlayers: 2,
    ),
  );
  e.addPlayer(eng.Player(
    id: 'hero',
    name: 'You',
    chips: 10000,
    aura: 0,
    isBot: false,
  ));
  e.addPlayer(eng.Player(
    id: 'bot',
    name: 'Bot',
    chips: 10000,
    aura: 90,
    isBot: true,
  ));
  e.players[1]
    ..temperament = eng.BotTemperament.worldChamp
    ..skill = eng.BotSkill.killer;
  e.phase = phase;
  e.pot = pot;
  e.currentBet = phase == eng.GamePhase.preflop ? 200 : 0;
  e.actingIndex = 0;
  return e;
}

void _establishRepeatShove(eng.GameEngine e) {
  // One recent large action plus the live shove is enough for the table to
  // recognize a repeated pressure pattern.
  e.opponentMemoryForSeat(0).observeAggression(
        largePressure: true,
        allIn: true,
      );
  expect(e.act(eng.ActionType.allIn), eng.ActionResult.ok);
  expect(e.lastAggressorIndex, 0);
  expect(e.opponentMemoryForSeat(0).appliesRepeatPressure, isTrue);
}

void _establishRepeatRiverBet(eng.GameEngine e) {
  e.opponentMemoryForSeat(0).observeAggression(
        largePressure: true,
        allIn: false,
      );
  expect(
    e.act(eng.ActionType.bet, amount: 4000),
    eng.ActionResult.ok,
  );
  expect(e.lastAggressorIndex, 0);
  expect(e.players[0].allIn, isFalse);
  expect(e.opponentMemoryForSeat(0).appliesRepeatPressure, isTrue);
}

void _openThenMakeBotFold(eng.GameEngine e, int seed) {
  expect(e.startNewHand(seed: seed), eng.ActionResult.ok);
  if (e.actingIndex == 1) {
    expect(e.toCallFor(1), greaterThan(0));
    expect(e.act(eng.ActionType.call), eng.ActionResult.ok);
  }
  expect(e.actingIndex, 0);
  final ({int minTo, int maxTo}) bounds = e.raiseBoundsTo(0);
  expect(bounds.minTo, lessThanOrEqualTo(bounds.maxTo));
  expect(
    e.act(eng.ActionType.raise, amount: bounds.minTo),
    eng.ActionResult.ok,
  );
  expect(e.actingIndex, 1);
  expect(e.act(eng.ActionType.fold), eng.ActionResult.ok);
  expect(e.phase, eng.GamePhase.handOver);
}

void main() {
  test('rock bluff-catches a repeated heads-up preflop shove with AJo', () {
    final e = _headsUpEngine();
    e.players[1].hole = const <eng.Card>[
      eng.Card(eng.Rank.ace, eng.Suit.hearts),
      eng.Card(eng.Rank.jack, eng.Suit.diamonds),
    ];

    _establishRepeatShove(e);
    final advice = eng.BotAdvisor.suggest(e, 1);

    expect(advice.action, eng.ActionType.call);
  });

  test('all bot temperaments defend playable hands from repeat shoves', () {
    for (final temperament in eng.BotTemperament.values) {
      final e = _headsUpEngine();
      e.players[1]
        ..temperament = temperament
        ..hole = const <eng.Card>[
          eng.Card(eng.Rank.ace, eng.Suit.hearts),
          eng.Card(eng.Rank.jack, eng.Suit.diamonds),
        ];

      _establishRepeatShove(e);
      final advice = eng.BotAdvisor.suggest(e, 1);

      expect(
        advice.action,
        isNot(eng.ActionType.fold),
        reason: '$temperament should resist a recognized repeat shove',
      );
    }
  });

  test('rock calls repeated postflop pressure with top pair', () {
    final e = _headsUpEngine(phase: eng.GamePhase.river, pot: 5000);
    e.community.addAll(const <eng.Card>[
      eng.Card(eng.Rank.king, eng.Suit.spades),
      eng.Card(eng.Rank.nine, eng.Suit.clubs),
      eng.Card(eng.Rank.five, eng.Suit.diamonds),
      eng.Card(eng.Rank.three, eng.Suit.hearts),
      eng.Card(eng.Rank.two, eng.Suit.clubs),
    ]);
    e.players[1].hole = const <eng.Card>[
      eng.Card(eng.Rank.king, eng.Suit.hearts),
      eng.Card(eng.Rank.queen, eng.Suit.diamonds),
    ];

    _establishRepeatShove(e);
    final advice = eng.BotAdvisor.suggest(e, 1);

    expect(advice.action, eng.ActionType.call);
  });

  test('rock calls a repeated large river bet with top pair', () {
    final e = _headsUpEngine(phase: eng.GamePhase.river, pot: 5000);
    e.community.addAll(const <eng.Card>[
      eng.Card(eng.Rank.king, eng.Suit.spades),
      eng.Card(eng.Rank.nine, eng.Suit.clubs),
      eng.Card(eng.Rank.five, eng.Suit.diamonds),
      eng.Card(eng.Rank.three, eng.Suit.hearts),
      eng.Card(eng.Rank.two, eng.Suit.clubs),
    ]);
    e.players[1].hole = const <eng.Card>[
      eng.Card(eng.Rank.king, eng.Suit.hearts),
      eng.Card(eng.Rank.queen, eng.Suit.diamonds),
    ];

    _establishRepeatRiverBet(e);
    final advice = eng.BotAdvisor.suggest(e, 1);

    expect(advice.action, eng.ActionType.call);
  });

  test('three ordinary raises activate repeat-pressure defense', () {
    final e = _headsUpEngine();
    final memory = e.opponentMemoryForSeat(0);

    for (int i = 0; i < 3; i++) {
      memory.observeAggression(
        largePressure: false,
        allIn: false,
      );
    }

    expect(memory.largePressureActions, 0);
    expect(memory.aggressiveActions, 3);
    expect(memory.appliesRepeatPressure, isTrue);
  });

  test('ordinary pressure learned through real hands changes shove defense',
      () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 91,
        smallBlind: 100,
        bigBlind: 200,
        maxPlayers: 2,
      ),
    )..animateStreets = false;
    e.addPlayer(eng.Player(
      id: 'hero',
      name: 'You',
      chips: 100000,
      aura: 0,
      isBot: false,
    ));
    e.addPlayer(eng.Player(
      id: 'bot',
      name: 'Bot',
      chips: 100000,
      aura: 90,
      isBot: true,
    ));
    e.players[1]
      ..temperament = eng.BotTemperament.worldChamp
      ..skill = eng.BotSkill.killer;

    for (int hand = 0; hand < 3; hand++) {
      _openThenMakeBotFold(e, 700 + hand);
    }
    expect(e.opponentMemoryForSeat(0).aggressiveActions, 3);
    expect(e.opponentMemoryForSeat(0).appliesRepeatPressure, isTrue);

    expect(e.startNewHand(seed: 704), eng.ActionResult.ok);
    e.players[1].hole = const <eng.Card>[
      eng.Card(eng.Rank.ace, eng.Suit.hearts),
      eng.Card(eng.Rank.jack, eng.Suit.diamonds),
    ];
    if (e.actingIndex == 1) {
      expect(e.act(eng.ActionType.call), eng.ActionResult.ok);
    }
    expect(e.actingIndex, 0);
    expect(e.act(eng.ActionType.allIn), eng.ActionResult.ok);
    expect(e.opponentMemoryForSeat(0).appliesRepeatPressure, isTrue);

    final advice = eng.BotAdvisor.suggest(e, 1);
    expect(
      advice.action,
      isNot(eng.ActionType.fold),
      reason:
          'the bot should bluff-catch a repeat shover learned from actual actions',
    );
  });

  test('repeat-pressure adaptation still folds genuine trash', () {
    final e = _headsUpEngine();
    e.players[1].hole = const <eng.Card>[
      eng.Card(eng.Rank.seven, eng.Suit.hearts),
      eng.Card(eng.Rank.two, eng.Suit.diamonds),
    ];

    _establishRepeatShove(e);
    final advice = eng.BotAdvisor.suggest(e, 1);

    expect(advice.action, eng.ActionType.fold);
  });
}
