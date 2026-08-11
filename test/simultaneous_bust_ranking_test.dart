import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/events.dart' as events;
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

int _prizeForRank(int rank) => switch (rank) {
      1 => 500,
      2 => 300,
      3 => 200,
      _ => 0,
    };

eng.GameEngine _playAllInHand(int seed) {
  final eng.GameEngine engine = eng.GameEngine(
    config: eng.GameConfig(
      tableSeed: 44,
      smallBlind: 50,
      bigBlind: 100,
      maxPlayers: 3,
      payoutForRank: _prizeForRank,
    ),
  )..animateStreets = false;
  for (final (int index, int chips) in <int>[300, 100, 200].indexed) {
    engine.addPlayer(eng.Player(
      id: 'P$index',
      name: 'P$index',
      chips: chips,
    ));
  }
  expect(engine.startNewHand(seed: seed), eng.ActionResult.ok);
  while (engine.phase != eng.GamePhase.handOver &&
      engine.phase != eng.GamePhase.showdown) {
    expect(
      engine.act(eng.ActionType.allIn),
      eng.ActionResult.ok,
      reason: 'all three stacks should be able to enter the pot',
    );
  }
  return engine;
}

void main() {
  test('simultaneous busts rank smaller starting stack below larger stack', () {
    eng.GameEngine? qualifying;
    for (int seed = 1; seed <= 500; seed++) {
      final eng.GameEngine candidate = _playAllInHand(seed);
      final List<events.PlayerBusted> busts =
          candidate.eventLog.whereType<events.PlayerBusted>().toList();
      if (busts.length == 2 &&
          busts.any((events.PlayerBusted event) => event.playerIndex == 1) &&
          busts.any((events.PlayerBusted event) => event.playerIndex == 2)) {
        qualifying = candidate;
        break;
      }
    }

    expect(
      qualifying,
      isNotNull,
      reason: 'the deterministic seed search should find a P0 scoop',
    );
    final List<events.PlayerBusted> busts =
        qualifying!.eventLog.whereType<events.PlayerBusted>().toList();
    expect(
      busts
          .map((events.PlayerBusted event) =>
              (event.playerIndex, event.rank, event.winnings))
          .toList(),
      <(int, int, int)>[
        (1, 3, 200),
        (2, 2, 300),
      ],
      reason:
          'the shorter stack must receive the worse finish and its matching reward',
    );
    final int tournamentEndedIndex = qualifying.eventLog.indexWhere(
      (events.EngineEvent event) => event is events.TournamentEnded,
    );
    expect(tournamentEndedIndex, greaterThanOrEqualTo(0));
    for (final events.PlayerBusted bust in busts) {
      expect(
        qualifying.eventLog.indexOf(bust),
        lessThan(tournamentEndedIndex),
        reason:
            'placement events must be visible before the terminal settlement event',
      );
    }
  });
}
