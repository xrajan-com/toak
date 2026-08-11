import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart';
import 'package:ten_of_a_kind_poker/core/venue_time.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/action_bar.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/cards.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/models.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/players.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/renoir_ui.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/table.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/table_ui.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/ui.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/viewport.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/slash_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(VenueTime.initialize);

  setUp(() {
    SoundFx.instance.setMuted(true);
    CardVisibilityGate.show();
    ActionGate.enable();
    RenoirSignals.holeCardsVisible.value = true;
    RenoirSignals.canAct.value = true;
    RenoirSignals.dealingActive.value = false;
  });

  tearDown(() {
    CardVisibilityGate.hide();
    ActionGate.disable();
    RenoirSignals.holeCardsVisible.value = false;
    RenoirSignals.canAct.value = false;
    RenoirSignals.dealingActive.value = false;
  });

  testWidgets(
    'responsive table fills phone and web safely with proportional contents',
    (WidgetTester tester) async {
      Future<
          ({
            Rect scene,
            Rect table,
            Rect card,
            Rect heroSeat,
            Rect actionBar,
            Rect venueLabel,
          })> renderAt(
        Size viewport, {
        FakeViewPadding viewPadding = FakeViewPadding.zero,
      }) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport;
        tester.view.viewPadding = viewPadding;
        await tester.pumpWidget(_staticGame());
        await tester.pump();

        CardVisibilityGate.show();
        ActionGate.enable();
        RenoirSignals.holeCardsVisible.value = true;
        RenoirSignals.canAct.value = true;
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump(const Duration(milliseconds: 180));
        await tester.pump();

        expect(find.byType(GameTableLayer), findsOneWidget);
        expect(find.byKey(const ValueKey<String>('seat-hole-0-0')),
            findsOneWidget);
        final Finder heroSeatFinder = find.byWidgetPredicate(
          (Widget widget) => widget is SeatWidget && widget.seat.isHero,
        );
        expect(heroSeatFinder, findsOneWidget);
        expect(find.byType(ActionBar), findsOneWidget);
        expect(find.text('Britain'), findsOneWidget);

        return (
          scene: _globalPaintRect(
            tester,
            find.byKey(GameViewport.designSurfaceKey),
          ),
          table: _globalPaintRect(tester, find.byType(GameTableLayer)),
          card: _globalPaintRect(
            tester,
            find.byKey(const ValueKey<String>('seat-hole-0-0')),
          ),
          heroSeat: _globalPaintRect(tester, heroSeatFinder),
          actionBar: _globalPaintRect(tester, find.byType(ActionBar)),
          venueLabel: _globalPaintRect(tester, find.text('Britain')),
        );
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);

      final chrome = await renderAt(const Size(1024, 576));
      final phone = await renderAt(
        const Size(784, 384),
        viewPadding: const FakeViewPadding(
          left: 48,
          right: 24,
          bottom: 21,
        ),
      );

      for (final layout in <({
        Rect scene,
        Rect table,
        Rect card,
        Rect heroSeat,
        Rect actionBar,
        Rect venueLabel,
      })>[chrome, phone]) {
        _expectRectInside(layout.scene, layout.table, label: 'table');
        _expectRectInside(layout.scene, layout.actionBar, label: 'action bar');
        _expectRectInside(layout.scene, layout.venueLabel, label: 'venue pill');
        _expectRectInside(layout.table, layout.card, label: 'hero card');
        _expectRectInside(layout.table, layout.heroSeat, label: 'hero seat');
        expect(
          layout.table.width / layout.scene.width,
          greaterThan(0.94),
          reason: 'the table should use nearly all safe landscape width',
        );
        expect(
          layout.table.height / layout.scene.height,
          greaterThan(0.61),
          reason: 'the table should dominate the game vertically',
        );
        expect(
          layout.actionBar.top - layout.table.bottom,
          greaterThanOrEqualTo(2),
          reason: 'the table must not cover normal action controls',
        );
      }

      _expectRatioSame(
        chrome.card.height / chrome.table.height,
        phone.card.height / phone.table.height,
        label: 'hero card height',
      );
      _expectRatioSame(
        chrome.heroSeat.height / chrome.table.height,
        phone.heroSeat.height / phone.table.height,
        label: 'hero seat height',
      );
      _expectRatioSame(
        chrome.actionBar.height / chrome.scene.height,
        phone.actionBar.height / phone.scene.height,
        label: 'action bar height',
      );
      expect(phone.scene.width, closeTo(712, 0.01));
      expect(phone.scene.height, closeTo(363, 0.01));
      expect(
        phone.card.height,
        greaterThan(60),
        reason: 'the 41.8px degraded mobile hero card must never return',
      );

      await tester.tap(find.textContaining('RAISE').first);
      await tester.pump();
      expect(find.text('CONFIRM'), findsOneWidget);
      final Rect expandedActionBar =
          _globalPaintRect(tester, find.byType(ActionBar));
      _expectRectInside(
        phone.scene,
        expandedActionBar,
        label: 'expanded raise controls',
      );
      expect(
        expandedActionBar.top - phone.table.bottom,
        greaterThanOrEqualTo(1),
        reason: 'the enlarged table must not cover the raise slider',
      );

      // Let Renoir's one untracked initial-delay callback fire, then dispose
      // the scene so its owned shuffle/action timers are cancelled normally.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('enlarged ten-seat table remains contained on a safe-area phone',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(844, 390);
    tester.view.viewPadding = const FakeViewPadding(
      left: 59,
      right: 59,
      bottom: 21,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(_staticGame(seatCount: 10));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();

    final Rect table = _globalPaintRect(tester, find.byType(GameTableLayer));
    final Finder seats = find.byWidgetPredicate((Widget widget) {
      return widget is SeatWidget;
    });
    expect(seats, findsNWidgets(10));
    for (final Element seat in seats.evaluate()) {
      final RenderBox box = seat.renderObject! as RenderBox;
      final Rect rect = Rect.fromPoints(
        box.localToGlobal(Offset.zero),
        box.localToGlobal(Offset(box.size.width, box.size.height)),
      );
      _expectRectInside(table, rect, label: 'ten-seat avatar');
    }
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Widget _staticGame({int seatCount = 6}) {
  final List<Seat> seats = <Seat>[
    Seat(
      name: 'Hero',
      chips: 9900,
      startChips: 10000,
      bet: 100,
      isHero: true,
      hole: const <GCard>[
        GCard('A', '♥'),
        GCard('K', '♠'),
      ],
    ),
    for (int index = 1; index < seatCount; index++)
      Seat(
        name: 'Bot $index',
        chips: 10000,
        startChips: 10000,
        bet: index == 2 ? 200 : 0,
        hole: const <GCard>[
          GCard('7', '♣'),
          GCard('9', '♦'),
        ],
      ),
  ];

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GameViewport(
      backgroundColor: Colors.black,
      child: GameScreenUI(
        bg: Colors.black,
        venueName: 'Britain',
        flagPath: 'assets/images/flags/euro/britain.png',
        onShowHandExamples: _noop,
        onShowHandRankings: _noop,
        onShowBotLearning: _noop,
        showBotLearning: false,
        felt: const Color(0xFF232574),
        wood: WoodType.redwood,
        monumentPath: null,
        renoirAsset: null,
        dealerAvatarStyle: DealerAvatarStyle.slash,
        defaultProfileAsset: 'assets/images/default_profile.png',
        cardBackAsset: 'assets/images/card_back.png',
        pot: 300,
        board: const <GCard>[],
        seats: seats,
        activeBloodStains: const <int>{},
        currentTurn: 0,
        dealerIndex: 1,
        sbIndex: 2,
        bbIndex: 3,
        heroIndex: 0,
        recentActions: const <SeatActionSnapshot>[],
        isHeroTurn: true,
        paused: false,
        onTogglePause: _noop,
        toCall: 100,
        showShuffle: false,
        showDeckPile: false,
        showToggleVisible: false,
        heroShow: true,
        potPulse: const AlwaysStoppedAnimation<double>(1),
        raiseAmount: 400,
        minRaise: 400,
        maxRaise: 9900,
        onRaiseAmountChanged: _ignoreDouble,
        onCheckOrCall: _noop,
        onFold: _noop,
        onBetOrRaise: _noop,
        onAllIn: _noop,
        onToggleShow: _noop,
        startingStack: 10000,
        venueTimeZoneId: 'Europe/London',
        engineEvents: const Stream.empty(),
        playIntroWelcome: false,
      ),
    ),
  );
}

Rect _globalPaintRect(WidgetTester tester, Finder finder) {
  final RenderBox box = tester.renderObject<RenderBox>(finder);
  return Rect.fromPoints(
    box.localToGlobal(Offset.zero),
    box.localToGlobal(Offset(box.size.width, box.size.height)),
  );
}

void _expectRectInside(
  Rect outer,
  Rect inner, {
  required String label,
}) {
  expect(
    inner.left,
    greaterThanOrEqualTo(outer.left - 0.01),
    reason: '$label crossed the left safe edge',
  );
  expect(
    inner.top,
    greaterThanOrEqualTo(outer.top - 0.01),
    reason: '$label crossed the top safe edge',
  );
  expect(
    inner.right,
    lessThanOrEqualTo(outer.right + 0.01),
    reason: '$label crossed the right safe edge',
  );
  expect(
    inner.bottom,
    lessThanOrEqualTo(outer.bottom + 0.01),
    reason: '$label crossed the bottom safe edge',
  );
}

void _expectRatioSame(
  double first,
  double second, {
  required String label,
}) {
  expect(
    first,
    closeTo(second, 0.001),
    reason: '$label should scale with the table group',
  );
}

void _noop() {}

void _ignoreDouble(double _) {}
