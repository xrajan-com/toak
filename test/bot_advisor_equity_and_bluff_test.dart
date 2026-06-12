import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

eng.GameEngine _seededHeadsUpEngine({
  required int tableSeed,
  required int handSeed,
}) {
  final e = eng.GameEngine(
    config: eng.GameConfig(
      tableSeed: tableSeed,
      smallBlind: 100,
      bigBlind: 200,
      maxPlayers: 2,
    ),
  );

  for (int i = 0; i < 2; i++) {
    e.addPlayer(eng.Player(
      id: 'P$i',
      name: 'P$i',
      chips: 8000,
      aura: i == 0 ? 92 : 60,
      isBot: true,
    ));
  }

  e.players[0].temperament = eng.BotTemperament.worldChamp;
  e.players[0].skill = eng.BotSkill.killer;
  e.players[1].temperament = eng.BotTemperament.stoic;
  e.players[1].skill = eng.BotSkill.killer;

  e.startNewHand(seed: handSeed);
  for (final p in e.players) {
    p.folded = false;
    p.allIn = false;
    p.isOut = false;
    p.sittingOut = false;
    p.best = null;
  }

  return e;
}

void main() {
  test('Calling station calls turn draw when equity clears the price', () {
    final e = _seededHeadsUpEngine(tableSeed: 1, handSeed: 17);
    final hero = e.players[0];
    final villain = e.players[1];
    hero.temperament = eng.BotTemperament.stoic;

    e.phase = eng.GamePhase.turn;
    e.pot = 4000;
    e.currentBet = 1000;
    hero.betThisStreet = 0;
    villain.betThisStreet = 1000;

    e.community
      ..clear()
      ..addAll(const [
        eng.Card(eng.Rank.king, eng.Suit.spades),
        eng.Card(eng.Rank.seven, eng.Suit.hearts),
        eng.Card(eng.Rank.two, eng.Suit.clubs),
        eng.Card(eng.Rank.queen, eng.Suit.hearts),
      ]);

    hero.hole = const [
      eng.Card(eng.Rank.ace, eng.Suit.hearts),
      eng.Card(eng.Rank.five, eng.Suit.hearts),
    ];
    villain.hole = const [
      eng.Card(eng.Rank.nine, eng.Suit.clubs),
      eng.Card(eng.Rank.nine, eng.Suit.diamonds),
    ];

    final advice = eng.BotAdvisor.suggest(e, 0);
    expect(advice.action, eng.ActionType.call);
  });

  test('Maniac bluffs a checked-to river busted draw in some spots', () {
    final e = _seededHeadsUpEngine(tableSeed: 2, handSeed: 11);
    final hero = e.players[0];
    final villain = e.players[1];
    hero.temperament = eng.BotTemperament.aggressive;

    e.phase = eng.GamePhase.river;
    e.pot = 3000;
    e.currentBet = 0;
    hero.betThisStreet = 0;
    villain.betThisStreet = 0;

    e.community
      ..clear()
      ..addAll(const [
        eng.Card(eng.Rank.king, eng.Suit.hearts),
        eng.Card(eng.Rank.seven, eng.Suit.hearts),
        eng.Card(eng.Rank.two, eng.Suit.clubs),
        eng.Card(eng.Rank.queen, eng.Suit.spades),
        eng.Card(eng.Rank.jack, eng.Suit.diamonds),
      ]);

    hero.hole = const [
      eng.Card(eng.Rank.ace, eng.Suit.hearts),
      eng.Card(eng.Rank.five, eng.Suit.hearts),
    ];
    villain.hole = const [
      eng.Card(eng.Rank.nine, eng.Suit.clubs),
      eng.Card(eng.Rank.nine, eng.Suit.diamonds),
    ];

    final advice = eng.BotAdvisor.suggest(e, 0);
    expect(advice.action, eng.ActionType.bet);
  });

  test('Rock checks a checked-to river busted draw', () {
    final e = _seededHeadsUpEngine(tableSeed: 1, handSeed: 11);
    final hero = e.players[0];
    final villain = e.players[1];
    hero.temperament = eng.BotTemperament.worldChamp;

    e.phase = eng.GamePhase.river;
    e.pot = 3000;
    e.currentBet = 0;
    hero.betThisStreet = 0;
    villain.betThisStreet = 0;

    e.community
      ..clear()
      ..addAll(const [
        eng.Card(eng.Rank.king, eng.Suit.hearts),
        eng.Card(eng.Rank.seven, eng.Suit.hearts),
        eng.Card(eng.Rank.two, eng.Suit.clubs),
        eng.Card(eng.Rank.queen, eng.Suit.spades),
        eng.Card(eng.Rank.jack, eng.Suit.diamonds),
      ]);

    hero.hole = const [
      eng.Card(eng.Rank.ace, eng.Suit.hearts),
      eng.Card(eng.Rank.five, eng.Suit.hearts),
    ];
    villain.hole = const [
      eng.Card(eng.Rank.nine, eng.Suit.clubs),
      eng.Card(eng.Rank.nine, eng.Suit.diamonds),
    ];

    final advice = eng.BotAdvisor.suggest(e, 0);
    expect(advice.action, eng.ActionType.check);
  });
}
