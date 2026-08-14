import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('account deletion page never reads PII from URL parameters', () {
    final html = File('hosting/delete-account.html').readAsStringSync();

    expect(html, isNot(contains('URLSearchParams')));
    expect(html, isNot(contains("params.get('email')")));
    expect(html, isNot(contains("params.get('uid')")));
    expect(html, isNot(contains("params.get('name')")));
    expect(html, contains('does not place your email, account ID'));
  });

  test('guest privacy copy matches anonymous Firebase sign-in', () {
    final privacy = File('hosting/privacy.html').readAsStringSync();
    final deletion = File('hosting/delete-account.html').readAsStringSync();

    expect(privacy, contains('anonymous Firebase account identifier'));
    expect(deletion, contains('anonymous Firebase account identifier'));
    expect(privacy, isNot(contains('account data is not created')));
  });

  test('web viewport keeps browser zoom available', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, isNot(contains('user-scalable=no')));
    expect(html, isNot(contains('maximum-scale=1.0')));
    expect(html, contains('free recreational poker simulation'));
  });

  test('public metadata identifies X Poker with tenofakind.com', () {
    final landingPage = File('hosting/index.html').readAsStringSync();
    final privacy = File('hosting/privacy.html').readAsStringSync();
    final deletion = File('hosting/delete-account.html').readAsStringSync();
    final webApp = File('web/index.html').readAsStringSync();

    for (final page in <String>[landingPage, privacy, deletion, webApp]) {
      expect(page, contains('X Poker'));
      expect(page, isNot(contains('xrajan.com')));
    }

    expect(
      landingPage,
      contains('<link rel="canonical" href="https://tenofakind.com/">'),
    );
    expect(landingPage, contains('"@type": "SoftwareApplication"'));
    expect(
      privacy,
      contains('href="https://tenofakind.com/privacy.html"'),
    );
    expect(
      deletion,
      contains('href="https://tenofakind.com/delete-account.html"'),
    );
    expect(
      webApp,
      contains('href="https://tenofakind.com/web/"'),
    );
  });

  test('web startup treats Firebase modules as optional', () {
    final bootstrap = File('lib/app/bootstrap.dart').readAsStringSync();
    final systemUi = File('lib/app/system_ui.dart').readAsStringSync();

    expect(bootstrap, contains('await _initializeOptionalFirebase();'));
    expect(
      bootstrap,
      contains("category: 'firebase'"),
    );
    expect(
      bootstrap,
      contains('severity: AppErrorSeverity.warning'),
    );
    expect(systemUi, contains('if (kIsWeb) return;'));
  });

  test('installed web app leaves non-game screens orientation adaptive', () {
    final sourceManifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    expect(sourceManifest['orientation'], 'any');

    final generatedManifest = File('hosting/web/manifest.json');
    if (generatedManifest.existsSync()) {
      final generated = jsonDecode(
        generatedManifest.readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(generated['orientation'], 'any');
    }
  });

  test('hosting protects legal and app pages with conservative headers', () {
    final firebase = jsonDecode(
      File('firebase.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final hosting = firebase['hosting'] as Map<String, dynamic>;
    final rules =
        (hosting['headers'] as List<dynamic>).cast<Map<String, dynamic>>();
    final globalRule = rules.singleWhere(
      (rule) => rule['source'] == '**',
    );
    final headers = <String, String>{
      for (final header in (globalRule['headers'] as List<dynamic>)
          .cast<Map<String, dynamic>>())
        header['key'] as String: header['value'] as String,
    };

    expect(headers['X-Content-Type-Options'], 'nosniff');
    expect(headers['Referrer-Policy'], 'strict-origin-when-cross-origin');
    expect(headers['X-Frame-Options'], 'DENY');
    expect(
      headers['Permissions-Policy'],
      'camera=(), microphone=(), geolocation=(), payment=(), usb=()',
    );
  });

  test('public website shows only verified leaderboard data', () {
    final html = File('hosting/index.html').readAsStringSync();
    final script = File('hosting/scripts.js').readAsStringSync();

    expect(html, contains('Live Overall Leaderboard'));
    expect(html, contains('Loading live rankings'));
    expect(html, isNot(contains('YOUR_SITE_KEY_HERE')));
    expect(html, isNot(contains('guest@example.com')));
    expect(html, isNot(contains('id="userPhoto"')));
    expect(script, contains('renderLiveLeaderboards'));
    expect(script, contains('No published rankings yet.'));
    expect(script, isNot(contains('leaderboardFallbacks')));
    expect(script, isNot(contains('source: "fallback"')));
    expect(script, contains('collection("server_progress")'));
    expect(script, contains('collection("users")'));
    expect(script, isNot(contains('extra.progress')));
    expect(html, contains('<strong>AUP Balance</strong>'));
  });

  test('Android backup cannot restore deleted local account caches', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
  });
}
