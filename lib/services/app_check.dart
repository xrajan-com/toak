import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:ten_of_a_kind_poker/config/app_check_config.dart';
import 'package:ten_of_a_kind_poker/services/firebase_ready.dart';

/// Firebase App Check: proves to the backend that a request comes from a real
/// copy of X Poker (Play Integrity on Android, reCAPTCHA Enterprise on the
/// web), so the API cannot simply be scripted with a player's login.
///
/// It runs only in release builds. Debug builds and tests never call the
/// production backend, so they send no token. The web app needs
/// [recaptchaEnterpriseSiteKey] set; until then it sends none. The backend
/// decides what a missing token means (backend/src/security/app_check.js):
/// while older builds are still installed it only logs it.
class AppCheckService {
  AppCheckService._();

  static const String header = 'X-Firebase-AppCheck';

  static bool _active = false;

  /// True once tokens are being issued.
  static bool get active => _active;

  /// Whether this build may use App Check at all. X Poker ships on Android
  /// and the web; other platforms send no token.
  static bool get supported {
    if (!kReleaseMode) return false;
    if (kIsWeb) return recaptchaEnterpriseSiteKey.isNotEmpty;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Call once Firebase has initialized. Does nothing if it did not.
  static Future<void> start() async {
    if (!supported || !firebaseReady()) return;
    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider: AndroidProvider.playIntegrity,
        webProvider: kIsWeb
            ? ReCaptchaEnterpriseProvider(recaptchaEnterpriseSiteKey)
            : null,
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
