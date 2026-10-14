import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase App Check: proves to the backend that a request comes from a real
/// copy of X Poker (Play Integrity on Android, DeviceCheck on iOS), so the API
/// cannot simply be scripted with a player's login.
///
/// Like [CrashReporting], it runs only in release builds on a phone. Debug
/// builds and tests never call the production backend, and the web app has no
/// reCAPTCHA key yet, so neither sends a token. The backend decides what a
/// missing token means (backend/src/security/app_check.js): while older
/// builds are still installed it only logs it.
class AppCheckService {
  AppCheckService._();

  static const String header = 'X-Firebase-AppCheck';

  static bool _active = false;

  /// True once tokens are being issued.
  static bool get active => _active;

  /// Whether this build may use App Check at all.
  static bool get supported =>
      kReleaseMode &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Call once Firebase has initialized. Does nothing if it did not.
  static Future<void> start() async {
    if (!supported || Firebase.apps.isEmpty) return;
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        appleProvider: AppleProvider.deviceCheck,
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      _active = true;
    } catch (_) {
      _active = false;
    }
  }

  /// The current token, or null. Never throws and never holds a request up
  /// for long: a request without a token still goes out.
  static Future<String?> token() async {
    if (!_active) return null;
    try {
      final String? token = await FirebaseAppCheck.instance
          .getToken()
          .timeout(const Duration(seconds: 3));
      return token == null || token.trim().isEmpty ? null : token;
    } catch (_) {
      return null;
    }
  }
}
