import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ten_of_a_kind_poker/services/leaderboard_firestore_service.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/trailblazers_panel.dart';

LeaderboardEntry _entry(String name, int forts, {int auraMilli = 0}) =>
    LeaderboardEntry(
      uid: name,
      displayName: name,
      auraMilli: auraMilli,
      totalAup: 0,
      activityScore: 0,
      fortsCleared: forts,
    );

Future<void> _open(
  WidgetTester tester,
  Future<List<LeaderboardEntry>> Function() load, {
  Size size = const Size(1200, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showTrailblazers(context, load: load),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  test('rows: forts first, Aura breaks ties, no zero-fort players, ten max', () {
    final rows = trailblazerRows([
      _entry('Low', 3),
      _entry('None', 0, auraMilli: 99000),
      _entry('TieLowAura', 40, auraMilli: 1000),
      _entry('TieHighAura', 40, auraMilli: 5000),
      for (var i = 0; i < 12; i++) _entry('Filler $i', 10),
    ]);
    expect(rows.length, 10);
    expect(rows[0].displayName, 'TieHighAura');
    expect(rows[1].displayName, 'TieLowAura');
    expect(rows.any((row) => row.displayName == 'None'), isFalse);
    expect(rows.any((row) => row.displayName == 'Low'), isFalse);
  });

  testWidgets('shows the top players as forts out of the total, in white',
      (tester) async {
    await _open(tester, () async => [_entry('Dũng Lê', 128), _entry('Shawn', 7)]);

    expect(find.text('TRAILBLAZERS'), findsOneWidget);
    expect(find.text('DŨNG LÊ'), findsOneWidget);
    expect(find.textContaining('128 / '), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    final title = tester.widget<Text>(find.text('TRAILBLAZERS'));
    expect(title.style?.color, Colors.white);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says so when nobody has cleared a fort yet', (tester) async {
    await _open(tester, () async => const <LeaderboardEntry>[]);
    expect(find.text('No forts cleared yet. Be the first.'), findsOneWidget);
  });

  testWidgets('a failed load offers Retry', (tester) async {
    var calls = 0;
    await _open(tester, () async {
      calls += 1;
      throw const LeaderboardLoadException('Could not load the Trailblazers.');
    });
    expect(find.text('Could not load the Trailblazers.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('fits a landscape phone', (tester) async {
    await _open(
      tester,
      () async => [for (var i = 0; i < 10; i++) _entry('Player $i', 100 - i)],
      size: const Size(800, 360),
    );
    final box = find.byKey(const ValueKey<String>('trailblazers-fitted-box'));
    expect(tester.getTopLeft(box).dy, greaterThanOrEqualTo(0));
    expect(tester.getBottomRight(box).dy, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
  });
}
