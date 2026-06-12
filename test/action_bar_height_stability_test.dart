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

  ActionBar _bar({
    required bool winnerOverlayVisible,
    required bool compact,
  }) {
    return ActionBar(
      pot: 0,
      callAmount: 0,
      minRaiseTo: 0,
      maxRaiseTo: 0,
      sliderTo: 0,
      canAct: false, // avoid sound + raise-strip changes in tests
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
      compact: compact,
      winnerOverlayVisible: winnerOverlayVisible,
      winnerName: 'Rani',
      winnerAbout:
          'A long winner about line that should not change the bar height when toggled.',
      winnerIsHero: false,
      winnerGlow: const AlwaysStoppedAnimation<double>(0.0),
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
}
