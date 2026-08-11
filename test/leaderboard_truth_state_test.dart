import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ten_of_a_kind_poker/services/leaderboard_firestore_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/leaderboard_screen.dart';

void main() {
  testWidgets('leaderboard distinguishes load failure from empty data',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          entriesLoader: () => Future<List<LeaderboardEntry>>.error(
            const LeaderboardLoadException('offline'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load the leaderboard.'), findsOneWidget);
    expect(find.text('No ranked players yet.'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a successful empty leaderboard has an honest empty state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LeaderboardScreen(
          entriesLoader: () async => const <LeaderboardEntry>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No ranked players yet.'), findsOneWidget);
    expect(find.text('Could not load the leaderboard.'), findsNothing);
  });
}
