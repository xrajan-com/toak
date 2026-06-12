import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart' as pc;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/cards.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/hand_examples.dart';

void main() {
  testWidgets('HandExamples renders sample cards while table cards are hidden',
      (tester) async {
    final bool wasEnabled = CardVisibilityGate.enabled.value;
    addTearDown(() => CardVisibilityGate.enabled.value = wasEnabled);
    CardVisibilityGate.hide();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF141414),
          body: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: HandExamples(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Royal / Straight Flush'), findsOneWidget);
    expect(find.text('High Card'), findsOneWidget);
    expect(find.byType(pc.PlayingCardView), findsWidgets);
  });

  testWidgets('HandExamplesSheet defaults to hands and switches to tips',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF141414),
          body: SizedBox(
            width: 420,
            height: 960,
            child: HandExamplesSheet(),
          ),
        ),
      ),
    );

    expect(find.text('Royal / Straight Flush'), findsOneWidget);
    expect(find.text('TIPS'), findsOneWidget);
    expect(find.text('Action Bar'), findsNothing);

    await tester.tap(find.text('TIPS'));
    await tester.pumpAndSettle();

    expect(find.text('Action Bar'), findsOneWidget);
    expect(find.textContaining('Check / Call:'), findsOneWidget);
    expect(find.textContaining('Fold / Skip:'), findsOneWidget);
    expect(find.text('Basic Rules'), findsOneWidget);
  });
}
