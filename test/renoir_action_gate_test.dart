import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/core.dart' as game;
import 'package:ten_of_a_kind_poker/game/events.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/cards.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/players.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/renoir_ui.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/table.dart';

void main() {
  testWidgets('community-card flight closes action immediately',
      (tester) async {
    final StreamController<EngineEvent> events =
        StreamController<EngineEvent>.broadcast();
    final List<Seat> seats = List<Seat>.generate(
      2,
      (int index) => Seat(
        name: index == 0 ? 'You' : 'Bot',
        chips: 5000,
        startChips: 5000,
        bet: 0,
        isHero: index == 0,
        avatarKey: 'bot',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: 800,
            height: 500,
            child: RenoirLayer(
              renoirAsset: null,
              playIntroWelcome: false,
              showDealerBadge: false,
              renoirRadius: 40,
              renoirLiftPx: 0,
              railWidth: 24,
              feltColor: Colors.green,
              wood: WoodType.redwood,
              origin: const Offset(400, 20),
              seatTargets: const <Offset>[
                Offset(400, 430),
                Offset(400, 70),
              ],
              seatPanelPositions: const <Offset>[
                Offset(360, 400),
                Offset(360, 40),
              ],
              seatPanelWidth: 80,
              seatPanelHeight: 80,
              boardTarget: const Offset(400, 190),
              cardBackAsset: '',
              cardW: 50,
              cardH: 70,
              seats: seats,
              board: const [],
              heroIndex: 0,
              hiddenSeats: const <int>{},
              showToggleVisible: false,
              heroShow: true,
              engineEvents: events.stream,
              showWelcomeOnInit: false,
              cardsOnly: true,
            ),
          ),
        ),
      ),
    );

    RenoirSignals.holeCardsVisible.value = true;
    RenoirSignals.canAct.value = true;
    ActionGate.enable();

    events.add(
      const CardDealt(
        seatIndex: -1,
        card: game.Card(game.Rank.ace, game.Suit.spades),
        isBoard: true,
      ),
    );
    await tester.pump();

    expect(RenoirSignals.canAct.value, isFalse);
    expect(ActionGate.enabled.value, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    await events.close();
    RenoirSignals.holeCardsVisible.value = false;
    RenoirSignals.canAct.value = false;
    ActionGate.disable();
  });

  testWidgets('blocking pause freezes and resumes a card flight',
      (tester) async {
    final StreamController<EngineEvent> events =
        StreamController<EngineEvent>.broadcast();
    final GlobalKey<State<RenoirLayer>> layerKey =
        GlobalKey<State<RenoirLayer>>();
    final List<Seat> seats = List<Seat>.generate(
      2,
      (int index) => Seat(
        name: index == 0 ? 'You' : 'Bot',
        chips: 5000,
        startChips: 5000,
        bet: 0,
        isHero: index == 0,
        avatarKey: 'bot',
      ),
    );

    Widget scene(bool paused) => MaterialApp(
          home: Material(
            child: SizedBox(
              width: 800,
              height: 500,
              child: RenoirLayer(
                key: layerKey,
                renoirAsset: null,
                playIntroWelcome: false,
                showDealerBadge: false,
                renoirRadius: 40,
                renoirLiftPx: 0,
                railWidth: 24,
                feltColor: Colors.green,
                wood: WoodType.redwood,
                origin: const Offset(400, 20),
                seatTargets: const <Offset>[
                  Offset(400, 430),
                  Offset(400, 70),
                ],
                seatPanelPositions: const <Offset>[
                  Offset(360, 400),
                  Offset(360, 40),
                ],
                seatPanelWidth: 80,
                seatPanelHeight: 80,
                boardTarget: const Offset(400, 190),
                cardBackAsset: '',
                cardW: 50,
                cardH: 70,
                seats: seats,
                board: const [],
                heroIndex: 0,
                hiddenSeats: const <int>{},
                showToggleVisible: false,
                heroShow: true,
                engineEvents: events.stream,
                showWelcomeOnInit: false,
                cardsOnly: true,
                paused: paused,
              ),
            ),
          ),
        );

    await tester.pumpWidget(scene(false));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();

    dynamic state = layerKey.currentState;
    expect(state.debugRevealAllowed, isTrue);
    for (int i = 0; i < 20 && state.debugDealAnimating == true; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(state.debugDealAnimating, isFalse);

    events.add(
      const CardDealt(
        seatIndex: -1,
        card: game.Card(game.Rank.king, game.Suit.hearts),
        isBoard: true,
      ),
    );
    for (int i = 0; i < 10 && state.debugDealAnimating != true; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(state.debugDealAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 35));
    final double pausedAt = state.debugDealProgress as double;
    expect(pausedAt, greaterThan(0));
    expect(pausedAt, lessThan(1));

    await tester.pumpWidget(scene(true));
    await tester.pump();
    state = layerKey.currentState;
    final double frozenAt = state.debugDealProgress as double;
    await tester.pump(const Duration(seconds: 1));
    expect(state.debugDealProgress, closeTo(frozenAt, 0.000001));
    expect(state.debugBoardCardCount, 0);

    await tester.pumpWidget(scene(false));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 1));
    expect(state.debugDealProgress, 1);
    expect(
      state.debugBoardCardCount,
      1,
      reason:
          'status=${state.debugDealStatus}, flights=${state.debugActiveFlightCount}',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await events.close();
    RenoirSignals.holeCardsVisible.value = false;
    RenoirSignals.canAct.value = false;
    ActionGate.disable();
  });
}
