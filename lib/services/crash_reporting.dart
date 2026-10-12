import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Crash reports from players' phones, through Firebase Crashlytics.
///
/// Collection is off in the Android manifest and the iOS Info.plist, and
/// [start] turns it on only in release builds on a phone. Debug builds,
/// tests and the web app never send anything. A report holds the error, its
/// stack trace, the app version and the device model and OS; the app never
/// attaches the player's account, name or email.
class CrashReporting {
  CrashReporting._();

  static bool _enabled = false;

  /// True once reports are being sent.
  static bool get enabled => _enabled;

  /// Whether this build may report at all.
  static bool get supported =>
      kReleaseMode &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Call once Firebase has initialized. Does nothing if it did not.
  static Future<void> start() async {
    if (kIsWeb || Firebase.apps.isEmpty) return;
    try {
      // Written on every launch, so a debug build installed over a release
      // one stops reporting too.
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(supported);
      _enabled = supported;
    } catch (_) {
      _enabled = false;
    }
  }

  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    required String reason,
    bool fatal = false,
  }) async {
    if (!_enabled) return;
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (_) {
      // Reporting must never become a second failure.
    }
  }

  static Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (!_enabled) return;
    try {
      await FirebaseCrashlytics.instance.recordFlutterError(details);
    } catch (_) {
      // Reporting must never become a second failure.
    }
  }
}
