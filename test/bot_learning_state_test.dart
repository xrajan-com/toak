import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

void main() {
  test('tracks opponent memory for vpip, pfr, c-bet, and fold-to-raise', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 9,
        smallBlind: 50,
        bigBlind: 100,
        maxPlayers: 3,
      ),
    );

    for (int i = 0; i < 3; i++) {
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: 'P$i',
        chips: 6000,
        aura: 70,
        isBot: true,
      ));
    }

    e.startNewHand(seed: 21);

    expect(e.actingIndex, 0);
    expect(e.act(eng.ActionType.raise, amount: 300), eng.ActionResult.ok);
    expect(e.act(eng.ActionType.fold), eng.ActionResult.ok);
    expect(e.act(eng.ActionType.call), eng.ActionResult.ok);

    expect(e.phase, eng.GamePhase.flop);
    expect(e.actingIndex, 2);
    expect(e.act(eng.ActionType.check), eng.ActionResult.ok);
    expect(e.act(eng.ActionType.bet, amount: 200), eng.ActionResult.ok);

    final opener = e.opponentMemoryForSeat(0);
    final smallBlindFolder = e.opponentMemoryForSeat(1);

    expect(opener.handsSeen, 1);
    expect(opener.vpipHands, 1);
    expect(opener.preflopRaiseHands, 1);
    expect(opener.flopCBetOpportunities, 1);
    expect(opener.flopCBetCount, 1);

    expect(smallBlindFolder.facedRaiseSpots, 1);
    expect(smallBlindFolder.foldToRaiseCount, 1);
  });

  test('style state shifts after a pressure fold and a cheap win', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 4,
        smallBlind: 50,
        bigBlind: 100,
        maxPlayers: 2,
      ),
    );

    for (int i = 0; i < 2; i++) {
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: 'P$i',
        chips: 4000,
        aura: 70,
        isBot: true,
      ));
    }

    e.startNewHand(seed: 3);
    expect(e.actingIndex, 0);
    expect(e.act(eng.ActionType.fold), eng.ActionResult.ok);
    expect(e.phase, eng.GamePhase.handOver);

    final loser = e.styleStateForSeat(0);
    final winner = e.styleStateForSeat(1);

    expect(loser.caution, greaterThan(0.5));
    expect(loser.confidence, lessThan(0.5));
    expect(winner.confidence, greaterThan(0.5));
    expect(winner.aggressionHeat, greaterThan(0.5));
  });

  test('sticky field suppresses a maniac river bluff with busted draw', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 2,
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
        aura: i == 0 ? 72 : 88,
        isBot: true,
      ));
    }

    final hero = e.players[0];
    final villain = e.players[1];
    hero.temperament = eng.BotTemperament.aggressive;
    hero.skill = eng.BotSkill.killer;
    villain.temperament = eng.BotTemperament.worldChamp;
    villain.skill = eng.BotSkill.killer;

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

    final stickyVillain = e.opponentMemoryForSeat(1)
      ..handsSeen = 30
      ..vpipHands = 22
      ..preflopRaiseHands = 14
      ..flopCBetOpportunities = 14
      ..flopCBetCount = 12
      ..turnBarrelOpportunities = 10
      ..turnBarrelCount = 8
      ..facedBetSpots = 16
      ..foldToBetCount = 1
      ..facedRaiseSpots = 10
      ..foldToRaiseCount = 0
      ..riverActionOpportunities = 12
      ..riverAggressionCount = 8;
    expect(stickyVillain.foldPressure, lessThan(0.2));

    final heroStyle = e.styleStateForSeat(0)
      ..aggressionHeat = 0.40
      ..bluffAppetite = 0.28
      ..caution = 0.82
      ..confidence = 0.42;
    heroStyle.normalize();

    final advice = eng.BotAdvisor.suggest(e, 0);
    expect(advice.action, eng.ActionType.check);
  });
}
