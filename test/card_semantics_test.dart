import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/cards.dart';

void main() {
  setUp(CardVisibilityGate.show);
  tearDown(CardVisibilityGate.hide);

  testWidgets('face-up cards expose rank and suit to assistive technology',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: FaceCard(
              const CardSpec('A', 'H'),
              w: 60,
              h: 84,
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Ace of hearts'), findsOneWidget);
  });

  testWidgets('card backs identify themselves without revealing a card',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Center(
            child: CardBack(w: 60, h: 84),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Face-down playing card'), findsOneWidget);
  });
}
