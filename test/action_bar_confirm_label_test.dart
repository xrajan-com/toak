import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/action_bar.dart';

void main() {
  Widget _wrap(ActionBar bar) {
    return MaterialApp(
      home: Scaffold(
        body: Center(child: bar),
      ),
    );
  }

  testWidgets(
      'raise button changes to confirm and shows a raise amount pill',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        ActionBar(
          pot: 1200,
          callAmount: 200,
          minRaiseTo: 400,
          maxRaiseTo: 1200,
          sliderTo: 400,
          canAct: true,
          onHandExamples: () {},
          onBotLearning: () {},
          showBotLearning: false,
          onScoreboard: () {},
          onCall: () {},
          onFold: () {},
          onAllIn: () {},
          onRaiseToChanged: (_) {},
          onBetOrRaise: () {},
          onTips: () {},
          onTogglePause: () {},
          paused: false,
          canSkipToWinner: false,
          canSkipNow: false,
          canShowdown: false,
          everyoneElseFolded: false,
          onSkipToWinner: () {},
          onShowdown: () {},
        ),
      ),
    );

    expect(find.textContaining('RAISE'), findsOneWidget);
    expect(find.text('RAISE TO 400'), findsNothing);
    expect(find.text('CONFIRM'), findsNothing);

    await tester.tap(find.textContaining('RAISE'));
    await tester.pump();

    expect(find.text('CONFIRM'), findsOneWidget);
    expect(find.text('RAISE TO 400'), findsOneWidget);
    expect(find.text('CONFIRM-400'), findsNothing);
  });
}
