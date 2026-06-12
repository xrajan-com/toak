import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

eng.GameEngine _engineWithPlayers(int count) {
  final e = eng.GameEngine(
    config: eng.GameConfig(
      tableSeed: 17,
      smallBlind: 50,
      bigBlind: 100,
      maxPlayers: count,
    ),
  );
  e.animateStreets = false;
  for (int i = 0; i < count; i++) {
    e.addPlayer(eng.Player(
      id: 'P$i',
      name: 'P$i',
      chips: 5000,
    ));
  }
  expect(e.startNewHand(seed: 99), eng.ActionResult.ok);
  return e;
}

void _checkOrCall(eng.GameEngine e) {
  final int actor = e.actingIndex;
  final int toCall = e.toCallFor(actor);
  final eng.ActionResult result =
      e.act(toCall == 0 ? eng.ActionType.check : eng.ActionType.call);
  expect(result, eng.ActionResult.ok);
}

void main() {
  test(
      'three-handed order is button first preflop and small blind first postflop',
      () {
    final e = _engineWithPlayers(3);

    expect(e.dealerIndex, 0);
    expect(e.smallBlindIndex, 1);
    expect(e.bigBlindIndex, 2);

    expect(e.actingIndex, 0, reason: 'left of the big blind opens preflop');
    _checkOrCall(e);
    expect(e.actingIndex, 1);
    _checkOrCall(e);
    expect(e.actingIndex, 2);
    _checkOrCall(e);

    expect(e.phase, eng.GamePhase.flop);
    expect(
      e.actingIndex,
      1,
      reason: 'postflop action starts left of the dealer',
    );
    _checkOrCall(e);
    expect(e.actingIndex, 2);
    _checkOrCall(e);
    expect(e.actingIndex, 0, reason: 'the button acts last postflop');
  });

  test(
      'when the button folds preflop and only blinds remain, small blind acts first on the flop',
      () {
    final e = _engineWithPlayers(3);

    expect(e.actingIndex, 0);
    expect(e.act(eng.ActionType.fold), eng.ActionResult.ok);
    expect(e.actingIndex, 1);
    _checkOrCall(e);
    expect(e.actingIndex, 2);
    _checkOrCall(e);

    expect(e.phase, eng.GamePhase.flop);
    expect(
      e.actingIndex,
      1,
      reason:
          'in a ring hand reduced to blinds only, action is still left of the dealer',
    );
    _checkOrCall(e);
    expect(
      e.actingIndex,
      2,
      reason: 'the big blind is last when the button is no longer in the hand',
    );
  });

  test('heads-up uses dealer small blind preflop and big blind postflop', () {
    final e = _engineWithPlayers(2);

    expect(e.dealerIndex, 0);
    expect(e.smallBlindIndex, 0);
    expect(e.bigBlindIndex, 1);

    expect(
      e.actingIndex,
      0,
      reason: 'heads-up preflop starts with the dealer in the small blind',
    );
    _checkOrCall(e);
    expect(e.actingIndex, 1);
    _checkOrCall(e);

    expect(e.phase, eng.GamePhase.flop);
    expect(
      e.actingIndex,
      1,
      reason: 'heads-up postflop starts with the big blind',
    );
    _checkOrCall(e);
    expect(e.actingIndex, 0);
  });
}
