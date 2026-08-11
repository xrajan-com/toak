import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/events.dart' as events;
import 'package:ten_of_a_kind_poker/game/game_engine.dart' as eng;

eng.GameEngine _engineWithPlayers(
  int count, {
  List<int>? stacks,
  bool animateStreets = false,
}) {
  assert(stacks == null || stacks.length == count);
  final e = eng.GameEngine(
    config: eng.GameConfig(
      tableSeed: 17,
      smallBlind: 50,
      bigBlind: 100,
      maxPlayers: count,
    ),
  );
  e.animateStreets = animateStreets;
  for (int i = 0; i < count; i++) {
    e.addPlayer(eng.Player(
      id: 'P$i',
      name: 'P$i',
      chips: stacks?[i] ?? 5000,
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
      'six-handed hero small blind acts before big blind preflop and first on flop',
      () {
    final e = _engineWithPlayers(6);

    expect(e.dealerIndex, 0);
    expect(e.smallBlindIndex, 1);
    expect(e.bigBlindIndex, 2);

    final List<int> preflopOrder = <int>[];
    int finalPreflopEventStart = -1;
    while (e.phase == eng.GamePhase.preflop) {
      preflopOrder.add(e.actingIndex);
      if (e.actingIndex == e.bigBlindIndex) {
        finalPreflopEventStart = e.eventLog.length;
      }
      _checkOrCall(e);
    }

    expect(
      preflopOrder,
      <int>[3, 4, 5, 0, 1, 2],
      reason:
          'UTG opens preflop; the small blind acts before the big blind, whose unraised option is last',
    );
    expect(e.phase, eng.GamePhase.flop);
    expect(
      e.actingIndex,
      1,
      reason:
          'postflop action starts with the first live seat left of the button',
    );
    final List<int> turnEventsAfterBigBlind = e.eventLog
        .skip(finalPreflopEventStart)
        .whereType<events.NextToActChanged>()
        .map((events.NextToActChanged event) => event.playerIndex)
        .toList(growable: false);
    expect(
      turnEventsAfterBigBlind,
      <int>[1],
      reason:
          'a closed preflop round must not briefly hand action back to UTG before the flop',
    );

    _checkOrCall(e);
    expect(
      e.eventLog
          .whereType<events.ActionTaken>()
          .map((events.ActionTaken event) => event.playerIndex),
      <int>[3, 4, 5, 0, 1, 2, 1],
      reason:
          'with every seat active, the big blind separates the small blind preflop action from the small blind flop action',
    );
  });

  test('predeal rejects both direct and scheduled bot actions', () {
    final e = eng.GameEngine(
      config: const eng.GameConfig(
        tableSeed: 41,
        smallBlind: 50,
        bigBlind: 100,
        maxPlayers: 2,
      ),
    );
    for (int i = 0; i < 2; i++) {
      e.addPlayer(
        eng.Player(
          id: 'B$i',
          name: 'Bot $i',
          chips: 5000,
          isBot: true,
        ),
      );
    }

    expect(e.phase, eng.GamePhase.predeal);
    expect(
      e.act(eng.ActionType.check),
      eng.ActionResult.illegalAtThisPhase,
    );
    e.tickBots(maxSteps: 2);
    expect(e.eventLog.whereType<events.ActionTaken>(), isEmpty);
  });

  test('a synchronous event listener cannot submit the same turn twice', () {
    final e = _engineWithPlayers(6);
    eng.ActionResult? nestedResult;

    e.addListener((events.EngineEvent event) {
      if (event is! events.ActionTaken || nestedResult != null) return;
      nestedResult = e.act(eng.ActionType.check);
    });

    expect(e.actingIndex, 3);
    expect(e.act(eng.ActionType.call), eng.ActionResult.ok);
    expect(nestedResult, eng.ActionResult.notYourTurn);
    expect(
      e.eventLog
          .whereType<events.ActionTaken>()
          .map((events.ActionTaken event) => event.playerIndex),
      <int>[3],
    );
    expect(
      e.actingIndex,
      4,
      reason: 'the rejected nested action must not skip the next player',
    );
  });

  test('the flop deal is emitted before the first postflop turn', () {
    final e = _engineWithPlayers(6, animateStreets: true);

    while (
        e.phase == eng.GamePhase.preflop && e.actingIndex != e.bigBlindIndex) {
      _checkOrCall(e);
    }
    expect(e.actingIndex, e.bigBlindIndex);

    final int boundaryEventStart = e.eventLog.length;
    _checkOrCall(e);
    final List<events.EngineEvent> boundaryEvents =
        e.eventLog.skip(boundaryEventStart).toList(growable: false);

    final int dealingStartedOffset = boundaryEvents.indexWhere(
      (events.EngineEvent event) =>
          event is events.DealingStarted && event.target == 'flop',
    );
    final List<int> boardCardOffsets = <int>[
      for (int i = 0; i < boundaryEvents.length; i++)
        if (boundaryEvents[i] is events.CardDealt &&
            (boundaryEvents[i] as events.CardDealt).isBoard)
          i,
    ];
    final int nextActorOffset = boundaryEvents.indexWhere(
      (events.EngineEvent event) =>
          event is events.NextToActChanged && event.playerIndex == 1,
    );

    expect(dealingStartedOffset, greaterThanOrEqualTo(0));
    expect(boardCardOffsets, hasLength(3));
    expect(boardCardOffsets.first, greaterThan(dealingStartedOffset));
    expect(
      boardCardOffsets.last,
      lessThan(nextActorOffset),
      reason:
          'listeners must see the complete flop deal before the postflop actor is announced',
    );
  });

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
    final int boundaryEventStart = e.eventLog.length;
    _checkOrCall(e);

    expect(e.phase, eng.GamePhase.flop);
    expect(
      e.actingIndex,
      1,
      reason: 'heads-up postflop starts with the big blind',
    );
    _checkOrCall(e);
    expect(e.actingIndex, 0);

    final List<events.EngineEvent> boundaryEvents =
        e.eventLog.skip(boundaryEventStart).toList(growable: false);
    final List<int> repeatedActionOffsets = <int>[
      for (int i = 0; i < boundaryEvents.length; i++)
        if (boundaryEvents[i] is events.ActionTaken &&
            (boundaryEvents[i] as events.ActionTaken).playerIndex == 1)
          i,
    ];
    final int flopOffset = boundaryEvents.indexWhere(
      (events.EngineEvent event) =>
          event is events.StreetDealt && event.phase == eng.GamePhase.flop,
    );
    expect(repeatedActionOffsets, hasLength(2));
    expect(
      repeatedActionOffsets.first,
      lessThan(flopOffset),
      reason: 'the big blind closes preflop before the flop is dealt',
    );
    expect(
      repeatedActionOffsets.last,
      greaterThan(flopOffset),
      reason:
          'the same big blind may act first postflop, but only after the new street is dealt',
    );
  });

  test(
      'small blind can legally act on both sides of flop only when big blind cannot act',
      () {
    final e = _engineWithPlayers(
      6,
      stacks: <int>[5000, 5000, 100, 5000, 5000, 5000],
    );

    expect(e.smallBlindIndex, 1);
    expect(e.bigBlindIndex, 2);
    expect(e.players[2].allIn, isTrue);

    final List<int> preflopOrder = <int>[];
    int boundaryEventStart = -1;
    while (e.phase == eng.GamePhase.preflop) {
      preflopOrder.add(e.actingIndex);
      if (e.actingIndex == e.smallBlindIndex) {
        boundaryEventStart = e.eventLog.length;
      }
      _checkOrCall(e);
    }

    expect(
      preflopOrder,
      <int>[3, 4, 5, 0, 1],
      reason: 'an all-in big blind has no action and is skipped',
    );
    expect(e.phase, eng.GamePhase.flop);
    expect(e.actingIndex, 1);

    _checkOrCall(e);

    final List<events.EngineEvent> boundaryEvents =
        e.eventLog.skip(boundaryEventStart).toList(growable: false);
    final List<int> repeatedActionOffsets = <int>[
      for (int i = 0; i < boundaryEvents.length; i++)
        if (boundaryEvents[i] is events.ActionTaken &&
            (boundaryEvents[i] as events.ActionTaken).playerIndex == 1)
          i,
    ];
    final int flopOffset = boundaryEvents.indexWhere(
      (events.EngineEvent event) =>
          event is events.StreetDealt && event.phase == eng.GamePhase.flop,
    );
    expect(repeatedActionOffsets, hasLength(2));
    expect(repeatedActionOffsets.first, lessThan(flopOffset));
    expect(repeatedActionOffsets.last, greaterThan(flopOffset));
  });
}
