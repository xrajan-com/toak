import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/chip_stack.dart';
import 'package:ten_of_a_kind_poker/ui/widgets/player_avatar.dart';

void main() {
  testWidgets('play-chip widgets never present chips as real-world currency',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PlayerAvatar(username: 'Player', chips: 1500),
              ChipStack(chipAmount: 1200),
            ],
          ),
        ),
      ),
    );

    expect(find.text('1500 chips'), findsOneWidget);
    expect(find.text('1200 chips'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
  });
}
