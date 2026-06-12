import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

void main() {
  test('high-aura rock defends KQ in the big blind versus a min-open', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 73,
        smallBlind: 500,
        bigBlind: 1000,
        maxPlayers: 5,
      ),
    );

    for (int i = 0; i < 5; i++) {
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: 'P$i',
        chips: 10000,
        aura: 90,
        isBot: true,
      ));
    }

    e.phase = eng.GamePhase.preflop;
    e.smallBlindIndex = 0;
    e.bigBlindIndex = 1;
    e.actingIndex = 1;
    e.currentBet = 2000;
    e.pot = 3500;

    final opener = e.players[0];
    opener.betThisStreet = 2000;
    opener.contributedThisHand = 2000;

    final defender = e.players[1];
    defender.betThisStreet = 1000;
    defender.contributedThisHand = 1000;
    defender.temperament = eng.BotTemperament.worldChamp;
    defender.skill = eng.BotSkill.killer;
    defender.hole = const [
      eng.Card(eng.Rank.king, eng.Suit.hearts),
      eng.Card(eng.Rank.queen, eng.Suit.clubs),
    ];

    final advice = eng.BotAdvisor.suggest(e, 1);
    expect(advice.action, isNot(eng.ActionType.fold));
  });

  test('high-aura bot tables still reach the flop regularly', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 41,
        smallBlind: 100,
        bigBlind: 200,
        maxPlayers: 6,
      ),
    );
    e.animateStreets = false;

    final auras = <int>[95, 95, 94, 88, 83, 95];
    for (int i = 0; i < auras.length; i++) {
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: 'P$i',
        chips: 10000,
        aura: auras[i],
        isBot: true,
      ));
    }
    e.assignBotTraits(
      guaranteeWorldChampKiller: true,
      minAuraForGuarantee: 85,
      minWorldChampKiller: 2,
    );

    int flopsSeen = 0;
    for (int hand = 0; hand < 24; hand++) {
      expect(e.startNewHand(seed: 500 + hand), eng.ActionResult.ok);
      int safety = 0;
      while (e.phase != eng.GamePhase.handOver && safety++ < 20) {
        e.tickBots(maxSteps: 80);
      }

      expect(
        e.phase,
        eng.GamePhase.handOver,
        reason: 'bot-only hand $hand did not resolve cleanly',
      );
      if (e.community.length >= 3) flopsSeen++;
    }

    expect(
      flopsSeen,
      greaterThanOrEqualTo(6),
      reason: 'high-aura tables should not die preflop almost every hand',
    );
  });
}
