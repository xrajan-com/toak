import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show totalKingdomCount, totalSubKingdomCount;
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
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

  testWidgets('Career with no account and no connection explains why',
      (tester) async {
    // Firebase is unavailable in tests: no guest account can be made, the
    // same as a first launch with no connection.
    SharedPreferences.setMockInitialValues(const <String, Object>{});
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

    // No sign-in wall any more: guests play Career.
    expect(find.text('Login or Register for Career'), findsNothing);
    expect(find.textContaining('Connect to the internet'), findsOneWidget);
    expect(find.text('Game Mode'), findsOneWidget);
  });

  testWidgets('home screen invites players onto the whole-map run',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameModeScreen(),
      ),
    );

    // Rendered with no providers at all: the challenge still has to show,
    // it just loses the progress read-out.
    expect(
      find.text('THE ROAD TO ALL ${totalSubKingdomCount()} FORTS'),
      findsOneWidget,
    );
    expect(find.textContaining('Forts '), findsNothing);
  });

  testWidgets('the run reports progress when campaign progress is available',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<CampaignProgressService>(
        create: (_) => CampaignProgressService(),
        child: const MaterialApp(
          home: GameModeScreen(),
        ),
      ),
    );

    expect(
      find.textContaining('Forts 0 / ${totalSubKingdomCount()}'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Titles 0 / ${totalKingdomCount()}'),
      findsOneWidget,
    );
  });
}
