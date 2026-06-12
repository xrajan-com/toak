import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/game_mode_screen.dart';

void main() {
  testWidgets('Game mode screen shows both play paths', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameModeScreen(),
      ),
    );

    expect(find.text('Game Mode'), findsOneWidget);
    expect(find.text('Quick Game'), findsOneWidget);
    expect(find.text('Play Career'), findsOneWidget);
    expect(find.text('Enter Quick Game'), findsOneWidget);
    expect(find.text('Begin Career Run'), findsOneWidget);
  });

  testWidgets('unregistered career tap opens login/register screen',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>(
        create: (_) => AuthService(),
        child: const MaterialApp(
          home: GameModeScreen(),
        ),
      ),
    );

    await tester.tap(find.text('Begin Career Run'));
    await tester.pumpAndSettle();

    expect(find.text('Login or Register for Career'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsNothing);
  });
}
