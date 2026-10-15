import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/first_game_tips.dart';

void main() {
  test('tips run in the first game only', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final tips = FirstGameTips();
    expect(tips.pending, isFalse, reason: 'quiet until loaded');
    await tips.load();
    expect(tips.pending, isTrue);
    await tips.markDone();
    expect(tips.pending, isFalse);

    final later = FirstGameTips();
    await later.load();
    expect(later.pending, isFalse);
  });

  test('every tip says something short and useful', () {
    for (final tip in CoachTip.values) {
      expect(tip.text.length, inInclusiveRange(40, 180));
    }
  });

  testWidgets('the banner shows the tip and can be dismissed', (tester) async {
    var dismissed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CoachTipBanner(
          text: CoachTip.yourTurn.text,
          onDismiss: () => dismissed = true,
        ),
      ),
    ));
    expect(find.text(CoachTip.yourTurn.text), findsOneWidget);
    await tester.tap(find.text('Got it'));
    expect(dismissed, isTrue);
  });
}
