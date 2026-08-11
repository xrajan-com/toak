import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CI compiles release code without requiring private signing files', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(workflow,
        contains('Compile unsigned backend-authoritative public AAB'));
    expect(workflow, contains('flutter build appbundle'));
    expect(
        workflow, isNot(contains('run: bash tools/build_public_release.sh')));
    expect(gradle, contains('hasReleaseSigning'));
    expect(
      gradle,
      isNot(contains('keystoreProperties["keyAlias"] as String')),
    );
  });

  test('distributable Android scripts require validated signing', () {
    for (final path in <String>[
      'tools/build_public_release.sh',
      'tools/build_closed_testing.sh',
    ]) {
      final script = File(path).readAsStringSync();
      expect(script, contains('verify_android_signing.sh'), reason: path);
      expect(script, contains('ALLOW_LOCAL_ECONOMY_DEV=false'), reason: path);
    }
    final verifier = File('tools/verify_android_signing.sh').readAsStringSync();
    expect(verifier, contains('android/key.properties is required'));
    expect(verifier, contains('keytool -list'));
  });

  test('release builds retain the production economy endpoint', () {
    final apiClient = File('lib/services/api_client.dart').readAsStringSync();

    expect(apiClient, contains('kReleaseMode ? _productionBaseUrl'));
    expect(
      apiClient,
      contains('https://toak-backend-xolu57aqba-el.a.run.app'),
    );
  });

  test('phones are landscape-only from native launch through Flutter routes',
      () {
    final systemUi = File('lib/app/system_ui.dart').readAsStringSync();
    final bootstrap = File('lib/app/bootstrap.dart').readAsStringSync();
    final android = File(
      'android/app/src/main/kotlin/com/tenofakind/poker/MainActivity.kt',
    ).readAsStringSync();
    final ios = File('ios/Runner/Info.plist').readAsStringSync();
    final iphoneOrientations = ios.substring(
      ios.indexOf('<key>UISupportedInterfaceOrientations</key>'),
      ios.indexOf('<key>UISupportedInterfaceOrientations~ipad</key>'),
    );

    expect(bootstrap, contains('await applyAppSystemUi();'));
    expect(systemUi, contains('logicalSize.shortestSide < 600'));
    expect(android, contains('smallestScreenWidthDp < 600'));
    expect(android, contains('SCREEN_ORIENTATION_SENSOR_LANDSCAPE'));
    expect(
        iphoneOrientations, isNot(contains('UIInterfaceOrientationPortrait')));
    expect(iphoneOrientations, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(
        iphoneOrientations, contains('UIInterfaceOrientationLandscapeRight'));
  });

  test('anonymous author copy does not publish a personal phone number', () {
    final overlay =
        File('lib/ui/widgets/author_flash_overlay.dart').readAsStringSync();

    expect(overlay, isNot(contains('+91')));
    expect(overlay, isNot(matches(RegExp(r'\b\d{10}\b'))));
  });

  test('backend deploy validates Cloud Run before locking Firestore writes',
      () {
    final deploy = File('tools/deploy_backend.sh').readAsStringSync();
    final cloudRun = deploy.indexOf('gcloud run deploy');
    final firstMutatingSmoke = deploy.indexOf('ALLOW_MUTATING_SMOKE=1');
    final rules = deploy.indexOf('--only firestore:rules');
    final secondMutatingSmoke = deploy.indexOf(
      'ALLOW_MUTATING_SMOKE=1',
      firstMutatingSmoke + 1,
    );

    expect(cloudRun, greaterThanOrEqualTo(0));
    expect(firstMutatingSmoke, greaterThan(cloudRun));
    expect(rules, greaterThan(firstMutatingSmoke));
    expect(secondMutatingSmoke, greaterThan(rules));
  });
}
