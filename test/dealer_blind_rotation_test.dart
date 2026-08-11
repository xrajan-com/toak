import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/events.dart' as events;
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

eng.GameEngine _engineWithPlayers(
  int count, {
  int chips = 5000,
}) {
  final eng.GameEngine engine = eng.GameEngine(
    config: eng.GameConfig(
      tableSeed: 71,
      smallBlind: 50,
      bigBlind: 100,
      maxPlayers: count,
    ),
  );
  engine.animateStreets = false;
  for (int index = 0; index < count; index++) {
    engine.addPlayer(
      eng.Player(
        id: 'P$index',
        name: 'P$index',
        chips: chips,
      ),
    );
  }
  return engine;
}

void _expectPositions(
  eng.GameEngine engine, {
  required int dealer,
  required int smallBlind,
  required int bigBlind,
}) {
  expect(engine.dealerIndex, dealer);
  expect(engine.smallBlindIndex, smallBlind);
  expect(engine.bigBlindIndex, bigBlind);
}

void main() {
  test('button and blinds rotate clockwise and skip ineligible seats', () {
    final eng.GameEngine engine = _engineWithPlayers(4);

    expect(engine.startNewHand(seed: 1), eng.ActionResult.ok);
    _expectPositions(engine, dealer: 0, smallBlind: 1, bigBlind: 2);

    expect(engine.startNewHand(seed: 2), eng.ActionResult.ok);
    _expectPositions(engine, dealer: 1, smallBlind: 2, bigBlind: 3);

    engine.players[2].isOut = true;
    expect(engine.startNewHand(seed: 3), eng.ActionResult.ok);
    _expectPositions(engine, dealer: 3, smallBlind: 0, bigBlind: 1);

    final List<events.DealerButtonMoved> moves =
        engine.eventLog.whereType<events.DealerButtonMoved>().toList();
    expect(moves, hasLength(3));
    expect(
      (moves.last.dealerIndex, moves.last.sbIndex, moves.last.bbIndex),
      (3, 0, 1),
    );
  });

  test('heads-up button and blinds alternate on consecutive hands', () {
    final eng.GameEngine engine = _engineWithPlayers(2);

    expect(engine.startNewHand(seed: 11), eng.ActionResult.ok);
    _expectPositions(engine, dealer: 0, smallBlind: 0, bigBlind: 1);

    expect(engine.startNewHand(seed: 12), eng.ActionResult.ok);
    _expectPositions(engine, dealer: 1, smallBlind: 1, bigBlind: 0);

    expect(engine.startNewHand(seed: 13), eng.ActionResult.ok);
    _expectPositions(engine, dealer: 0, smallBlind: 0, bigBlind: 1);
  });

  test('three-handed to heads-up never repeats a surviving big blind', () {
    const List<
        ({
          int busted,
          int dealer,
          int smallBlind,
          int bigBlind,
        })> cases = [
      (busted: 0, dealer: 2, smallBlind: 2, bigBlind: 1),
      (busted: 1, dealer: 2, smallBlind: 2, bigBlind: 0),
      (busted: 2, dealer: 1, smallBlind: 1, bigBlind: 0),
    ];

    for (final scenario in cases) {
      final eng.GameEngine engine = _engineWithPlayers(3);
      expect(engine.startNewHand(seed: 21), eng.ActionResult.ok);
      _expectPositions(engine, dealer: 0, smallBlind: 1, bigBlind: 2);

      engine.players[scenario.busted].isOut = true;
      expect(engine.startNewHand(seed: 22), eng.ActionResult.ok);
      _expectPositions(
        engine,
        dealer: scenario.dealer,
        smallBlind: scenario.smallBlind,
        bigBlind: scenario.bigBlind,
      );

      if (scenario.busted != 2) {
        expect(
          engine.bigBlindIndex,
          isNot(2),
          reason:
              'the surviving prior big blind must become the heads-up button',
        );
      }
    }
  });

  test('instant hand emits position and blind events before hole cards', () {
    final eng.GameEngine engine = _engineWithPlayers(3);
    expect(engine.startNewHand(seed: 31), eng.ActionResult.ok);

    final int moved = engine.eventLog.indexWhere(
      (events.EngineEvent event) => event is events.DealerButtonMoved,
    );
    final int posted = engine.eventLog.indexWhere(
      (events.EngineEvent event) => event is events.BlindsPosted,
    );
    final int firstHole = engine.eventLog.indexWhere(
      (events.EngineEvent event) => event is events.CardDealt && !event.isBoard,
    );

    expect(moved, isNonNegative);
    expect(posted, greaterThan(moved));
    expect(firstHole, greaterThan(posted));
  });

  test('animated hand emits position and blind events before hole cards',
      () async {
    final eng.GameEngine engine = _engineWithPlayers(3);
    expect(
      await engine.startNewHandAnimated(
        seed: 41,
        shuffleMsTotal: 0,
        shuffleTicks: 0,
        msPerHoleCard: 0,
        msBetweenPlayers: 0,
      ),
      eng.ActionResult.ok,
    );

    final int moved = engine.eventLog.indexWhere(
      (events.EngineEvent event) => event is events.DealerButtonMoved,
    );
    final int posted = engine.eventLog.indexWhere(
      (events.EngineEvent event) => event is events.BlindsPosted,
    );
    final int firstHole = engine.eventLog.indexWhere(
      (events.EngineEvent event) => event is events.CardDealt && !event.isBoard,
    );

    expect(moved, isNonNegative);
    expect(posted, greaterThan(moved));
    expect(firstHole, greaterThan(posted));
  });

  test('an all-in blind still receives both cards after blinds post first', () {
    final eng.GameEngine engine = _engineWithPlayers(3);
    engine.players[1].chips = 50;
    engine.players[2].chips = 25;

    expect(engine.startNewHand(seed: 51), eng.ActionResult.ok);
    expect(engine.players[1].allIn, isTrue);
    expect(engine.players[2].allIn, isTrue);
    expect(engine.players[1].hole, hasLength(2));
    expect(engine.players[2].hole, hasLength(2));
  });
}
