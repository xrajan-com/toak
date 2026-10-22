import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/services/game_analytics.dart';

void main() {
  test('analytics stay off in debug builds and tests', () async {
    expect(GameAnalytics.supported, isFalse);
    await GameAnalytics.start();
    expect(GameAnalytics.enabled, isFalse);
    // Logging when off is a silent no-op.
    await GameAnalytics.gameStarted(kind: 'quick');
    await GameAnalytics.gameFinished(kind: 'fort', place: 1, players: 6);
    await GameAnalytics.campaignWon(
      title: false,
      circuit: 'india',
      kingdom: 'Jaipur',
    );
  });

  test('the advertising id is never collected on Android', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      RegExp(
        r'android:name="google_analytics_adid_collection_enabled"\s*'
        r'android:value="false"',
      ).hasMatch(manifest),
      isTrue,
    );
    expect(
      RegExp(
        r'android:name="com.google.android.gms.permission.AD_ID"\s*'
        r'tools:node="remove"',
      ).hasMatch(manifest),
      isTrue,
    );
  });

  test('the privacy policy discloses analytics', () {
    final privacy = File('hosting/privacy.html').readAsStringSync();
    expect(privacy, contains('Google Analytics for Firebase'));
    expect(privacy, contains('advertising ID is not collected'));
  });

  group('new-player funnel', () {
    late List<String> sent;

    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      sent = <String>[];
      GameAnalytics.debugCaptureEvents((name, _) => sent.add(name));
    });

    tearDown(() => GameAnalytics.debugCaptureEvents(null));

    test('opens on the welcome screen and sends each step once', () async {
      await GameAnalytics.onboarding(OnboardingStep.welcomeShown);
      await GameAnalytics.onboarding(OnboardingStep.disclaimerAccepted);
      await GameAnalytics.onboarding(OnboardingStep.disclaimerAccepted);
      await GameAnalytics.onboarding(OnboardingStep.welcomeShown);
      expect(sent, <String>[
        'onboard_welcome_shown',
        'onboard_disclaimer_accepted',
      ]);
    });

    test('players from before this build never enter it', () async {
      await GameAnalytics.onboarding(OnboardingStep.modeShown);
      await GameAnalytics.onboarding(OnboardingStep.firstHandDealt);
      expect(sent, isEmpty);
    });

    test('a step sent in an earlier session is not sent again', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'analytics.onboarding.started_ms': 1,
        'analytics.onboarding.firstHandDealt': true,
      });
      await GameAnalytics.onboarding(OnboardingStep.firstHandDealt);
      await GameAnalytics.onboarding(OnboardingStep.firstHandFinished);
      expect(sent, <String>['onboard_first_hand_finished']);
    });

    test('steps carry their details and the seconds since welcome', () async {
      final params = <Map<String, Object>>[];
      GameAnalytics.debugCaptureEvents((_, p) => params.add(p));
      await GameAnalytics.onboarding(OnboardingStep.welcomeShown);
      await GameAnalytics.onboarding(
        OnboardingStep.modeChosen,
        parameters: <String, Object>{'mode': 'quick'},
      );
      expect(params, hasLength(2));
      expect(params.last['mode'], 'quick');
      expect(params.last['elapsed_s'], isA<int>());
    });

    test('event names fit Analytics rules', () {
      for (final step in OnboardingStep.values) {
        expect(step.eventName.length, lessThanOrEqualTo(40));
        expect(RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(step.eventName), isTrue);
      }
    });
  });
}
