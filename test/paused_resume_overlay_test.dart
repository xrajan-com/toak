import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/ui.dart';

void main() {
  testWidgets('every point on the paused game surface resumes play',
      (tester) async {
    int resumeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PausedResumeOverlay(
            onPressed: () => resumeCount++,
          ),
        ),
      ),
    );

    expect(find.text('TAP ANYWHERE TO RESUME'), findsOneWidget);

    await tester.tapAt(const Offset(12, 12));
    await tester.pump();
    expect(resumeCount, 1);

    final Size screen = tester.getSize(find.byType(Scaffold));
    await tester.tapAt(Offset(screen.width - 12, screen.height - 12));
    await tester.pump();
    expect(resumeCount, 2);

    await tester.tapAt(tester.getCenter(find.byType(PausedResumeOverlay)));
    await tester.pump();
    expect(resumeCount, 3);
  });
}
