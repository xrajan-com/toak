import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

void _checkOrCall(eng.GameEngine e) {
  final int idx = e.actingIndex;
  final int toCall = e.toCallFor(idx);
  final result =
      e.act(toCall == 0 ? eng.ActionType.check : eng.ActionType.call);
  expect(result, eng.ActionResult.ok);
}

void main() {
  test('river closes after first actor folds and remaining players check', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 301,
        smallBlind: 50,
        bigBlind: 100,
        maxPlayers: 3,
      ),
    );
    e.animateStreets = false;
    e.setHeroIndex(1);

    for (int i = 0; i < 3; i++) {
      e.addPlayer(eng.Player(
        id: 'P$i',
        name: 'P$i',
        chips: 5000,
      ));
    }

    expect(e.startNewHand(seed: 99), eng.ActionResult.ok);

    int safety = 0;
    while (e.phase == eng.GamePhase.preflop && safety++ < 10) {
      _checkOrCall(e);
    }
    expect(e.phase, eng.GamePhase.flop);
    expect(e.actingIndex, 1, reason: 'hero should be first to act postflop');

    _checkOrCall(e);
    _checkOrCall(e);
    _checkOrCall(e);
    expect(e.phase, eng.GamePhase.turn);
    expect(e.actingIndex, 1);

    _checkOrCall(e);
    _checkOrCall(e);
    _checkOrCall(e);
    expect(e.phase, eng.GamePhase.river);
    expect(e.community.length, 5);
    expect(e.actingIndex, 1);

    expect(e.act(eng.ActionType.fold), eng.ActionResult.ok);
    expect(e.phase, eng.GamePhase.river);

    _checkOrCall(e);
    _checkOrCall(e);

    expect(e.phase, eng.GamePhase.handOver);
  });
}
