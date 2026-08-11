import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

eng.GameEngine _fourHanded(List<int> stacks) {
  final eng.GameEngine engine = eng.GameEngine(
    config: const eng.GameConfig(
      tableSeed: 17,
      smallBlind: 50,
      bigBlind: 100,
      maxPlayers: 4,
    ),
  )..animateStreets = false;
  for (int i = 0; i < stacks.length; i++) {
    engine.addPlayer(eng.Player(
      id: 'P$i',
      name: 'P$i',
      chips: stacks[i],
    ));
  }
  expect(engine.startNewHand(seed: 99), eng.ActionResult.ok);
  expect(engine.actingIndex, 3);
  return engine;
}

void main() {
  test('one short all-in does not reopen raising for prior actors', () {
    final eng.GameEngine engine = _fourHanded(<int>[5000, 400, 5000, 5000]);

    expect(
      engine.act(eng.ActionType.raise, amount: 300),
      eng.ActionResult.ok,
    );
    expect(engine.act(eng.ActionType.call), eng.ActionResult.ok);
    expect(engine.actingIndex, 1);
    expect(engine.act(eng.ActionType.allIn), eng.ActionResult.ok);
    expect(engine.currentBet, 400);
    expect(engine.actingIndex, 2);
    expect(engine.act(eng.ActionType.call), eng.ActionResult.ok);

    expect(engine.actingIndex, 3);
    final Set<eng.ActionType> openerActions =
        engine.legalActionsFor(engine.actingIndex);
    expect(
        openerActions,
        containsAll(<eng.ActionType>[
          eng.ActionType.call,
          eng.ActionType.fold,
        ]));
    expect(openerActions, isNot(contains(eng.ActionType.raise)));
    expect(openerActions, isNot(contains(eng.ActionType.allIn)));

    final int chipsBefore = engine.players[3].chips;
    final int eventsBefore = engine.eventLog.length;
    expect(
      engine.act(eng.ActionType.raise, amount: 600),
      eng.ActionResult.invalidRaiseAmount,
    );
    expect(engine.players[3].chips, chipsBefore);
    expect(engine.eventLog, hasLength(eventsBefore));
    expect(engine.actingIndex, 3);

    expect(engine.act(eng.ActionType.call), eng.ActionResult.ok);
    expect(engine.actingIndex, 0);
    expect(
      engine.legalActionsFor(0),
      isNot(contains(eng.ActionType.raise)),
    );
  });

  test('cumulative short all-ins reopen after one full raise increment', () {
    final eng.GameEngine engine = _fourHanded(<int>[5000, 400, 500, 5000]);

    expect(
      engine.act(eng.ActionType.raise, amount: 300),
      eng.ActionResult.ok,
    );
    expect(engine.act(eng.ActionType.call), eng.ActionResult.ok);
    expect(engine.act(eng.ActionType.allIn), eng.ActionResult.ok);
    expect(engine.currentBet, 400);
    expect(engine.act(eng.ActionType.allIn), eng.ActionResult.ok);
    expect(engine.currentBet, 500);

    expect(engine.actingIndex, 3);
    expect(
      engine.legalActionsFor(3),
      containsAll(<eng.ActionType>[
        eng.ActionType.raise,
        eng.ActionType.allIn,
      ]),
    );
    final ({int minTo, int maxTo}) bounds = engine.raiseBoundsTo(3);
    expect(bounds.minTo, 700);
    expect(bounds.maxTo, 5000);
  });

  test('short stack cannot submit an impossible non-all-in raise', () {
    final eng.GameEngine engine = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 12,
        smallBlind: 50,
        bigBlind: 100,
        maxPlayers: 3,
      ),
    )..animateStreets = false;
    for (final (int index, int chips) in <int>[150, 5000, 5000].indexed) {
      engine.addPlayer(eng.Player(
        id: 'P$index',
        name: 'P$index',
        chips: chips,
      ));
    }
    expect(engine.startNewHand(seed: 7), eng.ActionResult.ok);
    expect(engine.actingIndex, 0);
    expect(engine.raiseBoundsTo(0), (minTo: 200, maxTo: 150));
    expect(
      engine.legalActionsFor(0),
      isNot(contains(eng.ActionType.raise)),
    );
    expect(engine.legalActionsFor(0), contains(eng.ActionType.allIn));

    final int chipsBefore = engine.players[0].chips;
    final int eventsBefore = engine.eventLog.length;
    expect(
      engine.act(eng.ActionType.raise, amount: 200),
      eng.ActionResult.invalidRaiseAmount,
    );
    expect(engine.players[0].chips, chipsBefore);
    expect(engine.eventLog, hasLength(eventsBefore));
    expect(engine.actingIndex, 0);

    expect(engine.act(eng.ActionType.allIn), eng.ActionResult.ok);
    expect(engine.players[0].chips, 0);
  });
}
