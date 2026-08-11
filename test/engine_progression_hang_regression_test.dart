import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

int _totalPayout(eng.GameEngine e) {
  return e.lastPayouts.fold<int>(0, (sum, payout) => sum + payout.amount);
}

void main() {
  test('heads-up blind all-ins resolve immediately at hand start', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 701,
        smallBlind: 50,
        bigBlind: 100,
        maxPlayers: 2,
      ),
    );
    e.animateStreets = false;

    e.addPlayer(eng.Player(id: 'A', name: 'A', chips: 50, isBot: true));
    e.addPlayer(eng.Player(id: 'B', name: 'B', chips: 100, isBot: true));

    expect(e.startNewHand(seed: 17), eng.ActionResult.ok);
    expect(e.phase, eng.GamePhase.handOver);
    expect(e.community.length, 5);
    expect(_totalPayout(e), 150);
  });

  test('all-in big blind stays live against a raise and tables its cards', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 704,
        smallBlind: 50,
        bigBlind: 100,
        maxPlayers: 3,
      ),
    );
    e.animateStreets = false;

    e.addPlayer(eng.Player(id: 'hero', name: 'Hero', chips: 1000));
    e.addPlayer(eng.Player(id: 'sb', name: 'SB', chips: 1000));
    e.addPlayer(eng.Player(id: 'bb', name: 'BB', chips: 100));

    expect(e.startNewHand(seed: 31), eng.ActionResult.ok);
    expect(e.bigBlindIndex, 2);
    expect(e.players[2].allIn, isTrue);
    expect(e.act(eng.ActionType.raise, amount: 500), eng.ActionResult.ok);
    expect(e.act(eng.ActionType.fold), eng.ActionResult.ok);

    expect(e.phase, eng.GamePhase.handOver);
    expect(e.community, hasLength(5));
    expect(e.players[2].folded, isFalse);
    expect(e.players[2].contributedThisHand, 100);

    final snapshot = e.snapshotForViewer(viewerIndex: 0);
    expect(snapshot.players[2].hole, hasLength(2));
    expect(_totalPayout(e), greaterThan(0));
  });

  test('all-in side pots with unmatched live bets still run out immediately',
      () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 702,
        smallBlind: 50,
        bigBlind: 100,
        maxPlayers: 3,
      ),
    );
    e.animateStreets = false;

    e.addPlayer(eng.Player(id: 'P0', name: 'P0', chips: 150));
    e.addPlayer(eng.Player(id: 'P1', name: 'P1', chips: 50));
    e.addPlayer(eng.Player(id: 'P2', name: 'P2', chips: 100));

    expect(e.startNewHand(seed: 23), eng.ActionResult.ok);
    expect(e.phase, eng.GamePhase.preflop);
    expect(e.actingIndex, 0);
    expect(e.currentBet, 100);

    expect(e.act(eng.ActionType.allIn), eng.ActionResult.ok);

    expect(e.phase, eng.GamePhase.handOver);
    expect(e.community.length, 5);
    expect(_totalPayout(e), 300);
  });

  test('last player with chips auto-runs the board after calling all-ins', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 703,
        smallBlind: 50,
        bigBlind: 100,
        maxPlayers: 3,
      ),
    );
    e.animateStreets = false;

    e.addPlayer(eng.Player(id: 'P0', name: 'P0', chips: 1000));
    e.addPlayer(eng.Player(id: 'P1', name: 'P1', chips: 50));
    e.addPlayer(eng.Player(id: 'P2', name: 'P2', chips: 100));

    expect(e.startNewHand(seed: 29), eng.ActionResult.ok);
    expect(e.phase, eng.GamePhase.preflop);
    expect(e.actingIndex, 0);
    expect(e.currentBet, 100);

    expect(e.act(eng.ActionType.call), eng.ActionResult.ok);

    expect(e.phase, eng.GamePhase.handOver);
    expect(e.community.length, 5);
    expect(_totalPayout(e), 250);
  });

  test('short-stacked bot tables still finish hands without stalling', () {
    const stackSets = <List<int>>[
      [50, 100, 100, 400],
      [50, 50, 100, 250],
      [75, 125, 200, 350],
      [50, 100, 150, 1000],
    ];

    for (int hand = 0; hand < stackSets.length; hand++) {
      final e = eng.GameEngine(
        config: eng.GameConfig(
          tableSeed: 750 + hand,
          smallBlind: 50,
          bigBlind: 100,
          maxPlayers: stackSets[hand].length,
        ),
      );
      e.animateStreets = false;

      for (int i = 0; i < stackSets[hand].length; i++) {
        e.addPlayer(eng.Player(
          id: 'H${hand}P$i',
          name: 'H${hand}P$i',
          chips: stackSets[hand][i],
          aura: 70,
          isBot: true,
        ));
      }

      expect(e.startNewHand(seed: 800 + hand), eng.ActionResult.ok);

      int safety = 0;
      while (e.phase != eng.GamePhase.handOver && safety++ < 50) {
        e.tickBots(maxSteps: 40);
      }

      expect(
        e.phase,
        eng.GamePhase.handOver,
        reason: 'short-stack bot hand $hand stalled instead of resolving',
      );
    }
  });
}
