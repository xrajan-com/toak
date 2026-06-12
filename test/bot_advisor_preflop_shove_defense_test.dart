import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

void main() {
  eng.GameEngine _engineWithPreflopShove({required int shoverIndex}) {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 1,
        smallBlind: 100,
        bigBlind: 200,
        maxPlayers: 10,
      ),
    );

    for (int i = 0; i < 10; i++) {
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: 'P$i',
        chips: 10000,
        aura: 62,
        isBot: true,
      ));
    }
    for (final p in e.players) {
      p.temperament = eng.BotTemperament.worldChamp;
      p.skill = eng.BotSkill.killer;
    }

    e.phase = eng.GamePhase.preflop;
    e.currentBet = 10000; // 50bb shove
    e.pot = 10300; // blinds + shove (approx; exact value not critical)

    final shover = e.players[shoverIndex];
    shover.betThisStreet = e.currentBet;
    shover.contributedThisHand = e.currentBet;
    shover.chips = 0;
    shover.allIn = true;

    return e;
  }

  test('Brutal bot folds AJo facing deep preflop shove multiway', () {
    final e = _engineWithPreflopShove(shoverIndex: 0);

    final p = e.players[1];
    p.hole = const [
      eng.Card(eng.Rank.ace, eng.Suit.hearts),
      eng.Card(eng.Rank.jack, eng.Suit.diamonds),
    ];

    final advice = eng.BotAdvisor.suggest(e, 1);
    expect(advice.action, eng.ActionType.fold);
  });

  test('Brutal bot continues with AA facing deep preflop shove', () {
    final e = _engineWithPreflopShove(shoverIndex: 0);

    final p = e.players[2];
    p.hole = const [
      eng.Card(eng.Rank.ace, eng.Suit.hearts),
      eng.Card(eng.Rank.ace, eng.Suit.diamonds),
    ];

    final advice = eng.BotAdvisor.suggest(e, 2);
    expect(advice.action, isNot(eng.ActionType.fold));
  });

  test('Maniac continues with AKs facing heads-up all-in', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 1,
        smallBlind: 1000,
        bigBlind: 2000,
        maxPlayers: 10,
      ),
    );

    for (int i = 0; i < 10; i++) {
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: 'P$i',
        chips: 10000,
        aura: 62,
        isBot: true,
      ));
    }

    e.phase = eng.GamePhase.preflop;
    e.currentBet = 10000; // 5bb all-in
    e.pot = 12000;

    final shover = e.players[0];
    shover.betThisStreet = e.currentBet;
    shover.contributedThisHand = e.currentBet;
    shover.chips = 0;
    shover.allIn = true;

    // Make it heads-up to reduce variance.
    for (int i = 2; i < e.players.length; i++) {
      e.players[i].folded = true;
      e.players[i].isOut = true;
    }

    final hero = e.players[1];
    hero.temperament = eng.BotTemperament.aggressive;
    hero.skill = eng.BotSkill.killer;
    hero.hole = const [
      eng.Card(eng.Rank.ace, eng.Suit.spades),
      eng.Card(eng.Rank.king, eng.Suit.spades),
    ];

    final aggressive = eng.BotAdvisor.suggest(e, 1);
    expect(aggressive.action, isNot(eng.ActionType.fold));
  });

  test('Bot folds premium broadway when many players are already all-in', () {
    final e = _engineWithPreflopShove(shoverIndex: 0);

    // With 10 bots, cap is floor(10 * 0.30) = 3.
    // Mark two more bots as already all-in so the next bot must not pile in.
    for (final i in [3, 4]) {
      final p = e.players[i];
      p.betThisStreet = e.currentBet;
      p.contributedThisHand = e.currentBet;
      p.chips = 0;
      p.allIn = true;
    }

    final caller = e.players[5];
    caller.hole = const [
      eng.Card(eng.Rank.ace, eng.Suit.spades),
      eng.Card(eng.Rank.king, eng.Suit.clubs),
    ];

    final advice = eng.BotAdvisor.suggest(e, 5);
    expect(advice.action, eng.ActionType.fold);
  });
}
