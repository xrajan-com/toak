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
  TrailblazersViewer? viewer,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showTrailblazers(context, load: load, viewer: viewer),
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

  test('rows: players without a name of their own stay off the board', () {
    final rows = trailblazerRows([
      _entry('Player', 17),
      _entry('Peter Power', 17),
      _entry('  ', 9),
      _entry('PLAYER', 4),
      _entry('Long Xiao', 3),
    ]);
    expect(
      rows.map((row) => row.displayName),
      ['Peter Power', 'Long Xiao'],
    );
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

  Future<List<LeaderboardEntry>> board() async =>
      [_entry('Peter Power', 17), _entry('Long Xiao', 3)];

  testWidgets('a guest is asked to log in, and the button does it',
      (tester) async {
    var signIns = 0;
    await _open(
      tester,
      board,
      viewer: TrailblazersViewer(
        registered: false,
        onSignIn: () => signIns += 1,
      ),
    );
    expect(
      find.text('Log in to save your forts and join the Trailblazers.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(signIns, 1);
    // The panel closed first.
    expect(find.text('TRAILBLAZERS'), findsNothing);
  });

  testWidgets('a named player sees their own place under the top ten',
      (tester) async {
    await _open(
      tester,
      board,
      viewer: TrailblazersViewer(
        registered: true,
        name: 'Shawn',
        loadStanding: () async => const TrailStanding(
          fortsCleared: 2,
          fortTotal: 500,
          rank: 23,
          named: true,
        ),
      ),
    );
    final own = find.byKey(const ValueKey<String>('trailblazers-own-row'));
    expect(own, findsOneWidget);
    expect(
      find.descendant(of: own, matching: find.text('#23')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: own, matching: find.text('YOU · SHAWN')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: own, matching: find.text('2 / 500')),
      findsOneWidget,
    );
    expect(find.text('Set name'), findsNothing);
  });

  testWidgets('a player without a name is asked to set one, with the place '
      'it would take', (tester) async {
    var setNames = 0;
    await _open(
      tester,
      board,
      viewer: TrailblazersViewer(
        registered: true,
        loadStanding: () async => const TrailStanding(
          fortsCleared: 17,
          fortTotal: 500,
          rank: 1,
          named: false,
        ),
        onSetName: () => setNames += 1,
      ),
    );
    expect(
      find.text("You'd be #1 on the board. Set your player name to take "
          'your place.'),
      findsOneWidget,
    );
    expect(find.text('YOU'), findsOneWidget);
    await tester.tap(find.text('Set name'));
    await tester.pumpAndSettle();
    expect(setNames, 1);
    expect(find.text('TRAILBLAZERS'), findsNothing);
  });

  testWidgets('a failed standing load leaves just the board', (tester) async {
    await _open(
      tester,
      board,
      viewer: TrailblazersViewer(
        registered: true,
        loadStanding: () async => throw StateError('offline'),
      ),
    );
    expect(find.text('PETER POWER'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('trailblazers-own-row')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  test('standing JSON: no forts means no place', () {
    final none = TrailStanding.fromJson(<String, dynamic>{
      'ok': true,
      'fortsCleared': 0,
      'fortTotal': 500,
      'rank': null,
      'named': true,
    });
    expect(none.rank, isNull);
    expect(none.onBoard, isFalse);
    final top = TrailStanding.fromJson(<String, dynamic>{
      'fortsCleared': 9,
      'fortTotal': 500,
      'rank': 4,
      'named': true,
    });
    expect(top.rank, 4);
    expect(top.onBoard, isTrue);
    final unnamed = TrailStanding.fromJson(<String, dynamic>{
      'fortsCleared': 9,
      'fortTotal': 500,
      'rank': 4,
      'named': false,
    });
    expect(unnamed.onBoard, isFalse);
  });
}
