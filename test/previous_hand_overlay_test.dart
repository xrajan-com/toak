import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/overlays.dart' as go;

void main() {
  testWidgets('Previous hand overlay renders table', (tester) async {
    go.LastHandStore.set(
      winners: [
        go.WinnerLine(
          playerName: 'Alice',
          amount: 120,
          delta: 60,
          bet: 60,
          handName: 'One Pair',
          bestFive: const [
            go.UiCard('A', '♠'),
            go.UiCard('A', '♥'),
            go.UiCard('K', '♦'),
            go.UiCard('Q', '♣'),
            go.UiCard('9', '♠'),
          ],
          holeCards: const [go.UiCard('A', '♠'), go.UiCard('K', '♦')],
        ),
      ],
      totalPot: 240,
      hero: go.WinnerLine(
        playerName: 'Hero',
        amount: 0,
        delta: -40,
        bet: 40,
        handName: 'High Card',
        bestFive: const [],
        holeCards: const [],
      ),
      board: const [
        go.UiCard('A', '♥'),
        go.UiCard('K', '♦'),
        go.UiCard('Q', '♣'),
        go.UiCard('9', '♠'),
        go.UiCard('2', '♣'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => go.showPreviousHandOverlay(context),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Previous Hand'), findsOneWidget);
    expect(find.text('Bet'), findsOneWidget);
    expect(find.text('Win/Lose'), findsOneWidget);
  });
}
