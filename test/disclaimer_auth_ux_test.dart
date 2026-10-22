import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/app/startup/disclaimer_splash.dart';
import 'package:ten_of_a_kind_poker/app/startup/auth_gate.dart';
import 'package:ten_of_a_kind_poker/services/auth_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/auth_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/profile_setup_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  testWidgets('welcome waits for an explicit PLAY tap',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DisclaimerSplash()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('welcome_play')), findsOneWidget);
    expect(find.textContaining("you confirm you're 18"), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));

    expect(find.byKey(const ValueKey('welcome_play')), findsOneWidget);
  });

  testWidgets('Details shows the full notice', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DisclaimerSplash()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome_details')));
    await tester.pumpAndSettle();

    expect(find.text('Before you play'), findsOneWidget);
    expect(
      find.textContaining('You must be at least 18'),
      findsOneWidget,
    );
  });

  testWidgets('PLAY starts guest play and deals the first table',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>(
        create: (_) => AuthService(),
        child: MaterialApp(
          home: DisclaimerSplash(
            home: const Text('game menu'),
            firstTableBuilder: (_) => const Text('first table'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome_play')));
    await tester.pumpAndSettle();

    // Straight to a table: no sign-in, no menus.
    expect(find.text('first table'), findsOneWidget);
    final BuildContext context = tester.element(find.text('first table'));
    expect(context.read<AuthService>().isLocalGuest, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(DisclaimerSplash.acceptanceKey), isTrue);
    expect(prefs.getBool(AuthService.guestPlayKey), isTrue);

    // When the first table closes, the game menu is waiting.
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(find.text('game menu'), findsOneWidget);
  });

  testWidgets('a returning player skips the welcome screen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      DisclaimerSplash.acceptanceKey: true,
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: DisclaimerSplash(home: Text('game menu')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('welcome_play')), findsNothing);
    expect(find.text('game menu'), findsOneWidget);
  });

  testWidgets('an offline guest is not asked to sign in again',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      AuthService.guestPlayKey: true,
    });
    final auth = AuthService();
    await tester.pumpAndSettle();
    expect(auth.isLocalGuest, isTrue);

    await auth.logout();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AuthService.guestPlayKey), isNull);
    auth.dispose();
  });

  testWidgets('auth exposes reset and explicit guest choices',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AuthScreen()),
    );

    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Continue as Guest'), findsOneWidget);

    await tester.tap(find.text('Create new account'));
    await tester.pump();

    expect(find.text('Forgot password?'), findsNothing);
    expect(find.text('Register'), findsOneWidget);
  });

  testWidgets('registered-only auth does not offer guest entry',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(requireRegisteredUser: true),
      ),
    );

    expect(find.text('Continue as Guest'), findsNothing);
  });

  testWidgets('guest entry works when Firebase Auth is unavailable',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
          ChangeNotifierProvider(create: (_) => ProfileService()),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue as Guest'));
    await tester.pumpAndSettle();

    expect(find.text('Game Mode'), findsOneWidget);
    expect(find.text('Guest sign-in is unavailable right now.'), findsNothing);
  });

  testWidgets('configured iOS Google sign-in is enabled',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      final Finder label = find.text('Sign in with Google');
      expect(label, findsOneWidget);
      final Finder button = find.ancestor(
        of: label,
        matching: find.byType(InkWell),
      );
      expect(button, findsOneWidget);
      expect(tester.widget<InkWell>(button).onTap, isNotNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('auth and profile setup remain usable on a compact screen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
    expect(find.byKey(const ValueKey('auth_email')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileService>(
        create: (_) => ProfileService(),
        child: const MaterialApp(home: ProfileSetupScreen()),
      ),
    );
    await tester.pump();
    expect(find.text('Player Details'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('auth errors are friendly and do not expose provider text', () {
    final message = friendlyAuthErrorMessage(
      FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Internal provider diagnostic',
      ),
    );

    expect(message, 'The email or password is incorrect.');
    expect(message, isNot(contains('diagnostic')));
  });
}
