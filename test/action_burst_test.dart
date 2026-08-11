import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/action_burst.dart';

void main() {
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

    const origins = <Offset>[
      Offset(180, 520),
      Offset(400, 520),
      Offset(620, 520),
    ];
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
}
