import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

void main() {
  test('Rock folds weak hand facing river all-in', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 1,
        smallBlind: 100,
        bigBlind: 200,
        maxPlayers: 6,
      ),
    );

    for (int i = 0; i < 6; i++) {
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: 'P$i',
        chips: 8000,
        aura: i == 1 ? 90 : 61,
        isBot: true,
      ));
    }
    e.players[1].temperament = eng.BotTemperament.worldChamp;
    e.players[1].skill = eng.BotSkill.killer;

    // River state: bot at seat 1 faces an all-in call for its whole stack.
    e.phase = eng.GamePhase.river;
    e.pot = 20000;
    e.currentBet = 8000;

    e.community
      ..clear()
      ..addAll(const [
        eng.Card(eng.Rank.jack, eng.Suit.spades),
        eng.Card(eng.Rank.ten, eng.Suit.clubs),
        eng.Card(eng.Rank.ten, eng.Suit.diamonds),
        eng.Card(eng.Rank.three, eng.Suit.hearts),
        eng.Card(eng.Rank.two, eng.Suit.clubs),
      ]);

    final p = e.players[1];
    p.hole = const [
      eng.Card(eng.Rank.ace, eng.Suit.hearts),
      eng.Card(eng.Rank.king, eng.Suit.diamonds),
    ];
    p.betThisStreet = 0;

    final advice = eng.BotAdvisor.suggest(e, 1);
    expect(advice.action, eng.ActionType.fold);
  });

  test('Rock calls flush facing river all-in', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 1,
        smallBlind: 100,
        bigBlind: 200,
        maxPlayers: 6,
      ),
    );

    for (int i = 0; i < 6; i++) {
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: 'P$i',
        chips: 8000,
        aura: i == 1 ? 90 : 61,
        isBot: true,
      ));
    }
    e.players[1].temperament = eng.BotTemperament.worldChamp;
    e.players[1].skill = eng.BotSkill.killer;

    e.phase = eng.GamePhase.river;
    e.pot = 20000;
    e.currentBet = 8000;

    e.community
      ..clear()
      ..addAll(const [
        eng.Card(eng.Rank.ten, eng.Suit.hearts),
        eng.Card(eng.Rank.seven, eng.Suit.hearts),
        eng.Card(eng.Rank.three, eng.Suit.hearts),
        eng.Card(eng.Rank.two, eng.Suit.hearts),
        eng.Card(eng.Rank.jack, eng.Suit.diamonds),
      ]);

    final p = e.players[1];
    p.hole = const [
      eng.Card(eng.Rank.ace, eng.Suit.hearts),
      eng.Card(eng.Rank.queen, eng.Suit.clubs),
    ];
    p.betThisStreet = 0;

    final advice = eng.BotAdvisor.suggest(e, 1);
    expect(advice.action, eng.ActionType.call);
  });
}
