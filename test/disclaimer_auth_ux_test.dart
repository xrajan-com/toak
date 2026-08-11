import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/app/startup/disclaimer_splash.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';
import 'package:ten_of_a_kind_poker/ui/screens/auth_screen.dart';
import 'package:ten_of_a_kind_poker/ui/screens/profile_setup_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  testWidgets('disclaimer waits for explicit Continue',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DisclaimerSplash()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Before You Play'), findsOneWidget);
    expect(find.byKey(const ValueKey('disclaimer_continue')), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));

    expect(find.text('Before You Play'), findsOneWidget);
    expect(find.byKey(const ValueKey('disclaimer_continue')), findsOneWidget);
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

  testWidgets('misconfigured iOS Google sign-in is clearly disabled',
      (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(const MaterialApp(home: AuthScreen()));
      expect(find.text('Google sign-in unavailable on iOS'), findsOneWidget);
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
