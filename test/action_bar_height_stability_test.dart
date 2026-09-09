import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/game/equity/hero_action_guidance.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/action_bar.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/viewport.dart';

void main() {
  const callButtonKey = ValueKey<String>('action-call-button');
  const raiseButtonKey = ValueKey<String>('action-raise-button');
  const allInButtonKey = ValueKey<String>('action-all-in-button');
  const yellowButtonKey = ValueKey<String>('action-yellow-button');
  const frameKey = ValueKey<String>('action-area-frame');
  const guidanceKey = ValueKey<String>('action-guidance');
  const handExamplesButtonKey = ValueKey<String>('action-hand-examples-button');
  const scoreboardButtonKey = ValueKey<String>('action-scoreboard-button');
  const tipsButtonKey = ValueKey<String>('action-tips-button');
  const pauseButtonKey = ValueKey<String>('action-pause-button');
  const settingsButtonKey = ValueKey<String>('action-settings-button');

  Widget _wrap(ActionBar bar) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: bar),
      ),
    );
  }

  ActionBar _bar({
    required bool winnerOverlayVisible,
    required bool compact,
    bool canAct = false,
    String idleMessage = '',
    double? guidanceEquity,
    HeroRecommendedAction guidanceAction = HeroRecommendedAction.check,
    int pot = 0,
    int callAmount = 0,
    int minRaiseTo = 0,
    int maxRaiseTo = 0,
    int sliderTo = 0,
    bool canRaise = true,
    ValueChanged<int>? onRaiseToChanged,
    VoidCallback? onBetOrRaise,
    VoidCallback? onSettings,
  }) {
    return ActionBar(
      pot: pot,
      callAmount: callAmount,
      minRaiseTo: minRaiseTo,
      maxRaiseTo: maxRaiseTo,
      sliderTo: sliderTo,
      canAct: canAct,
      canRaise: canRaise,
      onHandExamples: () {},
      onBotLearning: () {},
      showBotLearning: false,
      onScoreboard: () {},
      onCall: () {},
      onFold: () {},
      onAllIn: () {},
      onRaiseToChanged: onRaiseToChanged ?? (_) {},
      onBetOrRaise: onBetOrRaise ?? () {},
      onTips: () {},
      onSettings: onSettings,
      onTogglePause: () {},
      paused: false,
      canSkipToWinner: false,
      canSkipNow: false,
      canShowdown: false,
      everyoneElseFolded: false,
      onSkipToWinner: () {},
      onShowdown: () {},
      compact: compact,
      winnerOverlayVisible: winnerOverlayVisible,
      winnerName: 'Rani',
      winnerAbout:
          'A long winner about line that should not change the bar height when toggled.',
      winnerIsHero: false,
      winnerGlow: const AlwaysStoppedAnimation<double>(0.0),
      callButtonKey: callButtonKey,
      raiseButtonKey: raiseButtonKey,
      allInButtonKey: allInButtonKey,
      yellowButtonKey: yellowButtonKey,
      idleMessage: idleMessage,
      guidanceRecommendation: guidanceEquity == null
          ? null
          : HeroActionRecommendation(
              action: guidanceAction,
              handStrength: guidanceEquity,
            ),
    );
  }

  testWidgets('ActionBar height is stable when winner overlay toggles',
      (tester) async {
    await tester
        .pumpWidget(_wrap(_bar(winnerOverlayVisible: false, compact: false)));
    final h1 = tester.getSize(find.byType(ActionBar)).height;

    await tester
        .pumpWidget(_wrap(_bar(winnerOverlayVisible: true, compact: false)));
    final h2 = tester.getSize(find.byType(ActionBar)).height;

    expect(h2, h1);
  });

  testWidgets('ActionBar height is stable in compact mode', (tester) async {
    await tester
        .pumpWidget(_wrap(_bar(winnerOverlayVisible: false, compact: true)));
    final h1 = tester.getSize(find.byType(ActionBar)).height;

    await tester
        .pumpWidget(_wrap(_bar(winnerOverlayVisible: true, compact: true)));
    final h2 = tester.getSize(find.byType(ActionBar)).height;

    expect(h2, h1);
  });

  testWidgets('action area has no outline around the hero action buttons',
      (tester) async {
    Container frameContainer() {
      final frameFinder = find.byKey(frameKey);
      final frameWidget = tester.widget<Widget>(frameFinder);
      if (frameWidget is Container) return frameWidget;
      return tester.widget<Container>(
        find
            .descendant(
              of: frameFinder,
              matching: find.byType(Container),
            )
            .first,
      );
    }

    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
    )));
    final idleSize = tester.getSize(find.byKey(frameKey));
    final idleFrame = frameContainer();
    final idleDecoration = idleFrame.decoration! as BoxDecoration;

    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      canAct: true,
    )));
    final activeSize = tester.getSize(find.byKey(frameKey));
    final activeFrame = frameContainer();
    final activeDecoration = activeFrame.decoration! as BoxDecoration;

    expect(activeSize, idleSize);
    expect(activeDecoration.borderRadius, idleDecoration.borderRadius);
    expect(idleDecoration.border, isNull);
    expect(activeDecoration.border, isNull);
    expect(find.text('CHECK'), findsOneWidget);
    expect(find.textContaining('RAISE'), findsOneWidget);
    expect(find.text('ALL-IN'), findsOneWidget);
    expect(find.text('FOLD'), findsOneWidget);
  });

  testWidgets('hero buttons sit lower inside the action area', (tester) async {
    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      canAct: true,
    )));

    final Rect frame = tester.getRect(find.byKey(frameKey));
    final Rect firstButton = tester.getRect(find.byKey(allInButtonKey));
    final Rect lastButton = tester.getRect(find.byKey(yellowButtonKey));
    final double topInset = firstButton.top - frame.top;
    final double bottomInset = frame.bottom - firstButton.bottom;
    final double leftInset = firstButton.left - frame.left;
    final double rightInset = frame.right - lastButton.right;

    expect(topInset, greaterThan(bottomInset));
    expect(leftInset, closeTo(rightInset, 0.01));
  });

  testWidgets('side controls are shorter white circles with black icons',
      (tester) async {
    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      canAct: true,
    )));

    final double frameHeight = tester.getSize(find.byKey(frameKey)).height;
    for (final Key key in <Key>[
      handExamplesButtonKey,
      scoreboardButtonKey,
      tipsButtonKey,
      pauseButtonKey,
    ]) {
      final Finder button = find.byKey(key);
      final Size size = tester.getSize(button);
      final AnimatedContainer container = tester.widget(button);
      final ShapeDecoration decoration =
          container.decoration! as ShapeDecoration;

      expect(size.width, closeTo(size.height, 0.01));
      expect(size.height, closeTo(frameHeight * 0.612, 0.01));
      expect(decoration.color, Colors.white);
      expect(decoration.shape, isA<CircleBorder>());
      final Icon icon = tester.widget<Icon>(
        find.descendant(of: button, matching: find.byType(Icon)),
      );
      expect(icon.color, Colors.black);
      expect(
        tester.getCenter(button).dy,
        closeTo(tester.getCenter(find.byKey(allInButtonKey)).dy, 0.01),
      );
    }
  });

  testWidgets('action buttons stay in all-in raise check-call fold order',
      (tester) async {
    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      canAct: true,
    )));

    final List<double> centers = <Key>[
      allInButtonKey,
      raiseButtonKey,
      callButtonKey,
      yellowButtonKey,
    ].map((key) => tester.getCenter(find.byKey(key)).dx).toList();

    expect(centers[0], lessThan(centers[1]));
    expect(centers[1], lessThan(centers[2]));
    expect(centers[2], lessThan(centers[3]));
    expect(find.text('ALL-IN'), findsOneWidget);
    expect(find.textContaining('RAISE'), findsOneWidget);
    expect(find.text('CHECK'), findsOneWidget);
    expect(find.text('FOLD'), findsOneWidget);
    expect(tester.widget<Text>(find.text('FOLD')).style?.color, Colors.black);

    for (final ({Key key, String label}) item in <({Key key, String label})>[
      (key: allInButtonKey, label: 'ALL-IN'),
      (key: raiseButtonKey, label: 'RAISE-0'),
      (key: callButtonKey, label: 'CHECK'),
      (key: yellowButtonKey, label: 'FOLD'),
    ]) {
      final Rect buttonRect = tester.getRect(find.byKey(item.key));
      final Rect labelRect = tester.getRect(find.text(item.label));
      expect(buttonRect.contains(labelRect.topLeft), isTrue);
      expect(buttonRect.contains(labelRect.bottomRight), isTrue);
    }
  });

  testWidgets('off-turn action buttons stay fully visible with guidance',
      (tester) async {
    const actionKeys = <Key>[
      allInButtonKey,
      raiseButtonKey,
      callButtonKey,
      yellowButtonKey,
    ];

    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
    )));

    for (final Key key in actionKeys) {
      final Finder button = find.byKey(key);
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.byType(Opacity)),
        findsNothing,
      );
    }

    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      guidanceEquity: 0.50,
    )));

    for (final Key key in actionKeys) {
      final Finder button = find.byKey(key);
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.byType(Opacity)),
        findsNothing,
      );
    }
    expect(find.byKey(guidanceKey), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('action-safety-meter')),
      findsNothing,
    );
  });

  testWidgets('guidance label stays in its own strip above the action button',
      (tester) async {
    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      guidanceEquity: 0.70,
      guidanceAction: HeroRecommendedAction.raise,
    )));
    await tester.pumpAndSettle();

    for (final Key key in <Key>[
      allInButtonKey,
      raiseButtonKey,
      callButtonKey,
      yellowButtonKey,
    ]) {
      expect(find.byKey(key), findsOneWidget);
    }
    final Rect guidance = tester.getRect(find.byKey(guidanceKey));
    final Rect frame = tester.getRect(find.byKey(frameKey));
    final Rect raiseButton = tester.getRect(find.byKey(raiseButtonKey));
    expect(guidance.center.dx, closeTo(raiseButton.center.dx, 0.01));
    expect(guidance.width, closeTo(raiseButton.width, 0.01));
    expect(guidance.top, greaterThanOrEqualTo(frame.top));
    expect(guidance.bottom, lessThanOrEqualTo(raiseButton.top));
    final Semantics semantics =
        tester.widget<Semantics>(find.byKey(guidanceKey));
    expect(
      semantics.properties.label,
      'Recommended RAISE, hand strength 70 percent',
    );
    expect(
      find.text(
        'RAISE  •  HAND STRENGTH: 70%',
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      canAct: true,
      guidanceEquity: 0.70,
      guidanceAction: HeroRecommendedAction.raise,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(guidanceKey), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(guidanceKey)).dx,
      closeTo(tester.getCenter(find.byKey(raiseButtonKey)).dx, 0.01),
    );
    expect(find.byKey(allInButtonKey), findsOneWidget);
    expect(find.byKey(raiseButtonKey), findsOneWidget);
    expect(find.byKey(callButtonKey), findsOneWidget);
    expect(find.byKey(yellowButtonKey), findsOneWidget);
  });

  testWidgets('guidance text animates from all-in toward fold as equity falls',
      (tester) async {
    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      guidanceEquity: 0.90,
      guidanceAction: HeroRecommendedAction.allIn,
      pot: 800,
      callAmount: 200,
    )));
    await tester.pumpAndSettle();
    final double allInX = tester.getCenter(find.byKey(guidanceKey)).dx;
    final double allInButtonX = tester.getCenter(find.byKey(allInButtonKey)).dx;
    final double foldButtonX = tester.getCenter(find.byKey(yellowButtonKey)).dx;
    Semantics semantics = tester.widget<Semantics>(find.byKey(guidanceKey));
    expect(allInX, closeTo(allInButtonX, 0.01));
    expect(
      semantics.properties.label,
      'Recommended ALL-IN, hand strength 90 percent',
    );

    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      guidanceEquity: 0.10,
      guidanceAction: HeroRecommendedAction.fold,
      pot: 800,
      callAmount: 200,
    )));
    await tester.pump(const Duration(milliseconds: 230));
    final double movingX = tester.getCenter(find.byKey(guidanceKey)).dx;
    expect(movingX, greaterThan(allInX));
    expect(movingX, lessThan(foldButtonX));

    await tester.pumpAndSettle();
    final double foldX = tester.getCenter(find.byKey(guidanceKey)).dx;
    semantics = tester.widget<Semantics>(find.byKey(guidanceKey));

    expect(foldX, greaterThan(allInX));
    expect(foldX, closeTo(foldButtonX, 0.01));
    expect(
      semantics.properties.label,
      'Recommended FOLD, hand strength 10 percent',
    );
  });

  testWidgets('check and call guidance share the check-call button position',
      (tester) async {
    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      guidanceEquity: 0.40,
      guidanceAction: HeroRecommendedAction.check,
      pot: 900,
    )));
    await tester.pumpAndSettle();
    final double checkX = tester.getCenter(find.byKey(guidanceKey)).dx;
    final double checkCallButtonX =
        tester.getCenter(find.byKey(callButtonKey)).dx;
    Semantics semantics = tester.widget<Semantics>(find.byKey(guidanceKey));
    expect(checkX, closeTo(checkCallButtonX, 0.01));
    expect(
      semantics.properties.label,
      'Recommended CHECK, hand strength 40 percent',
    );

    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      guidanceEquity: 0.40,
      guidanceAction: HeroRecommendedAction.call,
      pot: 900,
      callAmount: 100,
    )));
    await tester.pumpAndSettle();
    final double callX = tester.getCenter(find.byKey(guidanceKey)).dx;
    semantics = tester.widget<Semantics>(find.byKey(guidanceKey));

    expect(callX, closeTo(checkX, 0.01));
    expect(callX, closeTo(checkCallButtonX, 0.01));
    expect(
      semantics.properties.label,
      'Recommended CALL, hand strength 40 percent',
    );
  });

  testWidgets('releasing raise slider waits for explicit CONFIRM',
      (tester) async {
    int sliderTo = 200;
    int commits = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Center(
                child: _bar(
                  winnerOverlayVisible: false,
                  compact: false,
                  canAct: true,
                  minRaiseTo: 200,
                  maxRaiseTo: 1000,
                  sliderTo: sliderTo,
                  onRaiseToChanged: (int value) {
                    setState(() => sliderTo = value);
                  },
                  onBetOrRaise: () => commits++,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(raiseButtonKey));
    await tester.pump();
    expect(find.text('CONFIRM'), findsOneWidget);

    Slider slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!.call(600);
    await tester.pump();
    slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChangeEnd!.call(600);
    await tester.pump();

    expect(sliderTo, 600);
    expect(commits, 0);
    expect(find.text('CONFIRM'), findsOneWidget);

    await tester.tap(find.byKey(raiseButtonKey));
    await tester.pump();
    expect(commits, 1);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('illegal raise cannot open the slider', (tester) async {
    await tester.pumpWidget(_wrap(_bar(
      winnerOverlayVisible: false,
      compact: false,
      canAct: true,
      canRaise: false,
      minRaiseTo: 200,
      maxRaiseTo: 1000,
      sliderTo: 200,
    )));

    await tester.tap(find.byKey(raiseButtonKey));
    await tester.pump();

    expect(find.byType(Slider), findsNothing);
    expect(find.text('CONFIRM'), findsNothing);
  });

  testWidgets('phone-safe transformed controls retain 44px hit targets',
      (tester) async {
    const Size viewport = Size(844, 390);
    const EdgeInsets safeInsets = EdgeInsets.only(left: 44, right: 44);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = viewport;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: viewport,
            viewPadding: safeInsets,
          ),
          child: GameViewport(
            backgroundColor: Colors.black,
            child: Material(
              color: Colors.black,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _bar(
                  winnerOverlayVisible: false,
                  compact: true,
                  canAct: true,
                  minRaiseTo: 200,
                  maxRaiseTo: 1000,
                  sliderTo: 200,
                  onSettings: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    for (final Key key in <Key>[
      allInButtonKey,
      raiseButtonKey,
      callButtonKey,
      yellowButtonKey,
    ]) {
      final Finder hitTarget = find
          .ancestor(
            of: find.byKey(key),
            matching: find.byType(InkWell),
          )
          .first;
      final Rect hitRect = tester.getRect(hitTarget);
      expect(hitRect.width, greaterThanOrEqualTo(44));
      expect(hitRect.height, greaterThanOrEqualTo(43.9));
    }

    for (final Key visualKey in <Key>[
      handExamplesButtonKey,
      scoreboardButtonKey,
      tipsButtonKey,
      settingsButtonKey,
      pauseButtonKey,
    ]) {
      final Finder hitTarget = find
          .ancestor(
            of: find.byKey(visualKey),
            matching: find.byType(InkWell),
          )
          .first;
      final Rect hitRect = tester.getRect(hitTarget);
      expect(hitRect.width, greaterThanOrEqualTo(43.9));
      expect(hitRect.height, greaterThanOrEqualTo(43.9));
    }
  });
}
