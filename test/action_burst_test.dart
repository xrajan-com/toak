import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/core/sound_fx.dart' show FireworkSound;
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/action_burst.dart';

void main() {
  const origins = <Offset>[
    Offset(180, 520),
    Offset(400, 520),
    Offset(620, 520),
  ];

  test('final-three hands use exactly double celebration particles', () {
    expect(winnerBurstIntensityForRemainingPlayers(4), 1.0);
    expect(winnerBurstIntensityForRemainingPlayers(3), 2.0);
    expect(winnerBurstIntensityForRemainingPlayers(2), 2.0);
    expect(winnerBurstIntensityForRemainingPlayers(1), 2.0);
  });

  testWidgets('winner burst animates smoothly through staged fireworks',
      (tester) async {
    final burstKey = GlobalKey<ActionBurstOverlayState>();
    final burstPaint = find.descendant(
      of: find.byType(ActionBurstOverlay),
      matching: find.byType(CustomPaint),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionBurstOverlay(key: burstKey),
        ),
      ),
    );

    expect(burstPaint, findsNothing);

    burstKey.currentState!.burstAtMany(origins);
    final standardParticleCount = burstKey.currentState!.debugParticleCount;
    burstKey.currentState!.burstAtMany(origins, intensity: 2.0);
    final finalThreeParticleCount = burstKey.currentState!.debugParticleCount;
    expect(finalThreeParticleCount, standardParticleCount * 2);
    await tester.pump();

    expect(burstPaint, findsOneWidget);
    final customPaint = tester.widget<CustomPaint>(burstPaint);
    expect(customPaint.isComplex, isTrue);
    expect(customPaint.willChange, isTrue);

    // Exercise successive display-refresh frames and the delayed starbursts.
    for (int i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 650));
    expect(burstPaint, findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 2));
    expect(burstPaint, findsNothing);
  });

  testWidgets(
      'every show doubles exactly for the final three, within budget and '
      'under three seconds', (tester) async {
    final burstKey = GlobalKey<ActionBurstOverlayState>();
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ActionBurstOverlay(key: burstKey))),
    );
    final ActionBurstOverlayState burst = burstKey.currentState!;

    for (final FireworkShow show in FireworkShow.values) {
      burst.burstAtMany(origins, show: show);
      final int single = burst.debugParticleCount;
      burst.burstAtMany(origins, show: show, intensity: 2.0);
      final int doubled = burst.debugParticleCount;

      expect(single, greaterThan(0), reason: show.name);
      expect(doubled, single * 2, reason: show.name);
      // About what the classic show costs at double intensity (360).
      expect(doubled, lessThanOrEqualTo(420), reason: show.name);
      // Over before the winners overlay is.
      expect(
        burst.debugDuration,
        lessThanOrEqualTo(const Duration(milliseconds: 2900)),
        reason: show.name,
      );
    }
  });

  testWidgets('every show paints through to its end', (tester) async {
    final burstKey = GlobalKey<ActionBurstOverlayState>();
    final burstPaint = find.descendant(
      of: find.byType(ActionBurstOverlay),
      matching: find.byType(CustomPaint),
    );
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ActionBurstOverlay(key: burstKey))),
    );

    for (final FireworkShow show in FireworkShow.values) {
      burstKey.currentState!.burstAtMany(origins, show: show, intensity: 2.0);
      await tester.pump();
      expect(burstPaint, findsOneWidget, reason: show.name);
      for (int i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(burstPaint, findsNothing, reason: show.name);
      expect(tester.takeException(), isNull, reason: show.name);
    }
  });

  test('every show plays before any repeats, and never twice in a row', () {
    final FireworkShowPicker picker = FireworkShowPicker(math.Random(7));
    final Set<FireworkShow> firstRound = <FireworkShow>{
      for (int i = 0; i < FireworkShow.values.length; i++) picker.next(),
    };
    expect(firstRound.length, FireworkShow.values.length);

    FireworkShow? previous = picker.last;
    for (int i = 0; i < 500; i++) {
      final FireworkShow show = picker.next();
      expect(show, isNot(previous));
      previous = show;
    }
  });

  test('a finale gets different shows, none of them the one just played', () {
    final FireworkShowPicker picker = FireworkShowPicker(math.Random(3));
    for (int i = 0; i < 200; i++) {
      final FireworkShow handWin = picker.next();
      final List<FireworkShow> finale =
          picker.nextDistinct(kFireworkFinaleShowCount);
      expect(finale.toSet().length, kFireworkFinaleShowCount);
      expect(finale, isNot(contains(handWin)));
    }
  });

  testWidgets(
      'a show with sound plays a few sounds, in step with the sparks',
      (tester) async {
    final burstKey = GlobalKey<ActionBurstOverlayState>();
    final List<FireworkSound> heard = <FireworkSound>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionBurstOverlay(key: burstKey, onSound: heard.add),
        ),
      ),
    );

    for (final FireworkShow show in FireworkShow.values) {
      for (final double intensity in <double>[1.0, 2.0]) {
        heard.clear();
        burstKey.currentState!.burstAtMany(origins,
            show: show, intensity: intensity, sound: true);
        final List<(double, FireworkSound)> cues =
            burstKey.currentState!.debugSoundCues;
        final double length =
            burstKey.currentState!.debugDuration.inMilliseconds / 1000;

        expect(cues, isNotEmpty, reason: show.name);
        expect(cues.length, lessThanOrEqualTo(kFireworkMaxSoundsPerShow),
            reason: show.name);
        expect(
            cues.where((c) => c.$2 == FireworkSound.launch).length,
            lessThanOrEqualTo(1),
            reason: show.name);
        for (int i = 0; i < cues.length; i++) {
          expect(cues[i].$1, inInclusiveRange(0.0, length), reason: show.name);
          if (i > 0) {
            expect(cues[i].$1, greaterThanOrEqualTo(cues[i - 1].$1),
                reason: show.name);
          }
        }

        for (int i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(heard, <FireworkSound>[for (final c in cues) c.$2],
            reason: show.name);
      }
    }
  });

  testWidgets('a bot win, or an overlay with no player, is silent',
      (tester) async {
    final burstKey = GlobalKey<ActionBurstOverlayState>();
    final quietKey = GlobalKey<ActionBurstOverlayState>();
    final List<FireworkSound> heard = <FireworkSound>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Expanded(
                child: ActionBurstOverlay(key: burstKey, onSound: heard.add),
              ),
              Expanded(child: ActionBurstOverlay(key: quietKey)),
            ],
          ),
        ),
      ),
    );

    burstKey.currentState!.burstAtMany(origins, show: FireworkShow.kamuro);
    quietKey.currentState!
        .burstAtMany(origins, show: FireworkShow.kamuro, sound: true);
    expect(burstKey.currentState!.debugSoundCues, isEmpty);
    expect(quietKey.currentState!.debugSoundCues, isEmpty);
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(heard, isEmpty);
  });

  testWidgets('the game-win finale plays out and reports when it is done',
      (tester) async {
    int done = 0;
    final List<FireworkSound> heard = <FireworkSound>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FireworkFinale(onDone: () => done++, onSound: heard.add),
        ),
      ),
    );
    await tester.pump();

    final ActionBurstOverlayState burst =
        tester.state<ActionBurstOverlayState>(find.byType(ActionBurstOverlay));
    expect(burst.debugParticleCount, greaterThan(0));
    // Three shows overlapping, finished before the match-end ad at 5 s.
    expect(
      burst.debugDuration,
      lessThanOrEqualTo(const Duration(milliseconds: 4600)),
    );

    for (int i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(done, 1);
    expect(heard, isNotEmpty);
    expect(heard.length,
        lessThanOrEqualTo(kFireworkFinaleShowCount * kFireworkMaxSoundsPerShow));
    expect(tester.takeException(), isNull);
  });
}
