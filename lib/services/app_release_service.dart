import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ten_of_a_kind_poker/services/api_client.dart';

/// What the server knows about the newest shipped client.
@immutable
class AppRelease {
  const AppRelease({this.latestBuild, this.message, this.storeUrl});

  final int? latestBuild;
  final String? message;
  final String? storeUrl;

  static int? _build(Object? value) {
    final int? parsed = switch (value) {
      final int v => v,
      final num v => v.toInt(),
      final String v => int.tryParse(v.trim()),
      _ => null,
    };
    // The server already bounds this; re-check rather than trust the wire.
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  static String? _text(Object? value) {
    if (value is! String) return null;
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static AppRelease fromJson(Object? raw) {
    if (raw is! Map) return const AppRelease();
    return AppRelease(
      latestBuild: _build(raw['latestBuild']),
      message: _text(raw['message']),
      storeUrl: _text(raw['storeUrl']),
    );
  }
}

/// Asks the backend whether a newer client exists, and remembers when a player
/// has waved the notice away.
///
/// Every failure path returns "nothing to show". An update notice is the least
/// important thing on screen: it must never delay launch, never surface an
/// error, and never appear because a request failed.
class AppReleaseService {
  AppReleaseService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// The running build, baked in at compile time from pubspec.yaml by the
  /// scripts in tools/. Zero means the define was not passed — a bare
  /// `flutter run`, or a test — and a client that cannot identify itself
  /// never claims to be out of date.
  static const int currentBuild = int.fromEnvironment('APP_BUILD');

  static const String _dismissKeyPrefix = 'update.dismissed.build.';
  static const String _endpoint = '/v1/app-release';

  bool isNewerThanRunning(AppRelease release) {
    final int? latest = release.latestBuild;
    return currentBuild > 0 && latest != null && latest > currentBuild;
  }

  Future<bool> isDismissed(int build) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_dismissKeyPrefix$build') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Dismissal is remembered per build, not forever. The "x" settles this
  /// release; the next one earns a fresh notice.
  Future<void> dismiss(int build) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_dismissKeyPrefix$build', true);
    } catch (_) {
      // A prefs failure costs the player one repeated notice, nothing more.
    }
  }

  Future<AppRelease?> fetch() async {
    if (!_apiClient.isConfigured) return null;
    try {
      return AppRelease.fromJson(
        await _apiClient.get(_endpoint, authenticated: false),
      );
    } catch (_) {
      return null;
    }
  }

  /// The release to tell the player about, or null when there is nothing to
  /// say — which is the overwhelmingly common case.
  Future<AppRelease?> pendingUpdate() async {
    if (currentBuild <= 0) return null;
    final AppRelease? release = await fetch();
    if (release == null || !isNewerThanRunning(release)) return null;
    if (await isDismissed(release.latestBuild!)) return null;
    return release;
  }
}
