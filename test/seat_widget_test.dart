import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_screen/players.dart';

void main() {
  testWidgets('seat always exposes name and stack while tap reveals details',
      (tester) async {
    final Seat seat = Seat(
      name: 'Riya Sharma',
      chips: 2400,
      startChips: 2000,
      bet: 0,
      contributedThisHand: 1200,
      avatarKey: 'bot',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          color: Colors.black,
          child: Center(
            child: SizedBox(
              width: 88,
              height: 88,
              child: SeatWidget(
                seat: seat,
                isLeader: false,
                growWhenOthersGone: false,
                isTurn: false,
                isSB: false,
                isBB: false,
                fallbackAvatarAsset: '',
                seatMaxWidth: 156,
                seatHeight: 88,
                showTopBubble: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Riya'), findsOneWidget);
    expect(find.text('2.4K'), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);

    expect(
      find.bySemanticsLabel(RegExp(r'Riya Sharma, 2\.4K chips')),
      findsOneWidget,
    );

    await tester.tap(find.byType(SeatWidget));
    await tester.pump(const Duration(milliseconds: 260));

    expect(find.text('Riya'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('Riya'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Riya'), findsOneWidget);
    expect(find.text('2.4K'), findsOneWidget);
  });
}
