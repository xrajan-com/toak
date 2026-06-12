import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/overlays.dart' as go;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/players.dart';

void main() {
  testWidgets('Hero finish overlay centers podium header copy', (tester) async {
    final heroSeat = Seat(
      name: 'Hero',
      chips: 0,
      startChips: 10000,
      bet: 0,
      isHero: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => go.showHeroFinishOverlay(
                    context,
                    heroSeat: heroSeat,
                    rank: 2,
                    totalPlayers: 10,
                    handsPlayed: 6,
                    finalChips: 0,
                    winnings: 0,
                    venueName: 'Indore',
                  ),
                  child: const Text('Open finish overlay'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open finish overlay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final go.GoldenText title = tester.widget(
      find.byWidgetPredicate(
        (widget) => widget is go.GoldenText && widget.text == 'CONGRATULATIONS',
      ),
    );
    final Text subtitle = tester.widget(find.text('YOU FINISHED 2ND OF 10.'));
    final Text summary = tester.widget(
      find.text('PODIUM FINISH. STRONG RUN TO THE END.'),
    );
    final Text heroName = tester.widget(find.text('Hero'));

    expect(title.textAlign, TextAlign.center);
    expect(subtitle.textAlign, TextAlign.center);
    expect(summary.textAlign, TextAlign.center);
    expect(heroName.textAlign, TextAlign.center);
  });

  testWidgets('Game over overlay can award rewarded AUP in place', (
    tester,
  ) async {
    final heroSeat = Seat(
      name: 'Hero',
      chips: 0,
      startChips: 10000,
      bet: 0,
      isHero: true,
    );
    int rewardCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => go.showHeroFinishOverlay(
                    context,
                    heroSeat: heroSeat,
                    rank: 6,
                    totalPlayers: 10,
                    handsPlayed: 8,
                    finalChips: 0,
                    winnings: 0,
                    rewardedAdLabel: 'WATCH AD FOR +2,000 AUP',
                    onWatchRewardedAd: () async {
                      rewardCalls += 1;
                      return 2000;
                    },
                  ),
                  child: const Text('Open game over overlay'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open game over overlay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('WATCH AD FOR +2,000 AUP'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(rewardCalls, 1);
    expect(find.text('AUP +2,000 added.'), findsOneWidget);
  });

  testWidgets('Hero finish overlay runs match-end hook after five seconds', (
    tester,
  ) async {
    final heroSeat = Seat(
      name: 'Hero',
      chips: 0,
      startChips: 10000,
      bet: 0,
      isHero: true,
    );
    final List<String> events = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => go.showHeroFinishOverlay(
                    context,
                    heroSeat: heroSeat,
                    rank: 5,
                    totalPlayers: 10,
                    handsPlayed: 7,
                    finalChips: 0,
                    winnings: 0,
                    onBeforeExit: () async {
                      events.add('before-exit');
                    },
                    onExitToVenue: () {
                      events.add('after-dialog');
                    },
                  ),
                  child: const Text('Open exit overlay'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open exit overlay'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pump(const Duration(milliseconds: 4600));
    expect(events, isEmpty);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(events, <String>['before-exit']);

    await tester.tap(find.text('EXIT TO VENUE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(events, <String>['before-exit', 'after-dialog']);
    expect(find.text('GAME OVER'), findsNothing);
  });
}
