import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
