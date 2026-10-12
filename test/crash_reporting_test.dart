import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/services/crash_reporting.dart';

void main() {
  test('crash reports stay off outside release phone builds', () async {
    expect(CrashReporting.supported, isFalse);
    expect(CrashReporting.enabled, isFalse);
    // Recording before start, or when off, is a silent no-op.
    await CrashReporting.recordError(
      StateError('test'),
      StackTrace.current,
      reason: 'test: nothing is sent',
    );
  });

  test('native collection is off until the app turns it on', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(
      RegExp(
        r'android:name="firebase_crashlytics_collection_enabled"\s*'
        r'android:value="false"',
      ).hasMatch(manifest),
      isTrue,
    );

    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(
      RegExp(r'<key>FirebaseCrashlyticsCollectionEnabled</key>\s*<false/>')
          .hasMatch(plist),
      isTrue,
    );
  });

  test('the privacy policy discloses crash reporting', () {
    final privacy = File('hosting/privacy.html').readAsStringSync();
    expect(privacy, contains('Firebase Crashlytics'));
    expect(privacy, contains('does not contain your name, email address'));
  });
}
