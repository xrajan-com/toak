import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/services/app_release_service.dart';

void main() {
  group('AppRelease.fromJson', () {
    test('reads a well-formed payload', () {
      final AppRelease release = AppRelease.fromJson(<String, Object?>{
        'latestBuild': 84,
        'message': 'A new version is available.',
        'storeUrl': 'https://play.google.com/store/apps/details?id=com.toak',
      });
      expect(release.latestBuild, 84);
      expect(release.message, 'A new version is available.');
      expect(
        release.storeUrl,
        'https://play.google.com/store/apps/details?id=com.toak',
      );
    });

    test('a build number sent as a string still parses', () {
      expect(
        AppRelease.fromJson(<String, Object?>{'latestBuild': '84'}).latestBuild,
        84,
      );
    });

    test('malformed payloads degrade to nulls rather than throwing', () {
      for (final Object? raw in <Object?>[null, 'nonsense', 7, <int>[1, 2]]) {
        final AppRelease release = AppRelease.fromJson(raw);
        expect(release.latestBuild, isNull);
        expect(release.message, isNull);
        expect(release.storeUrl, isNull);
      }
    });

    test('non-positive and unparseable build numbers are discarded', () {
      for (final Object? bad in <Object?>[0, -1, 'v84', '', null]) {
        final AppRelease release =
            AppRelease.fromJson(<String, Object?>{'latestBuild': bad});
        expect(release.latestBuild, isNull, reason: 'expected $bad rejected');
      }
    });

    test('blank text reads as absent so the client falls back to its own copy',
        () {
      final AppRelease release = AppRelease.fromJson(<String, Object?>{
        'message': '   ',
        'storeUrl': '',
      });
      expect(release.message, isNull);
      expect(release.storeUrl, isNull);
    });
  });

  group('AppReleaseService', () {
    test('a build that cannot identify itself never reports out of date', () {
      // Tests run without --dart-define=APP_BUILD, which is exactly the state
      // of a bare `flutter run`. Such a client must stay quiet rather than
      // tell every developer they are on an old version.
      expect(AppReleaseService.currentBuild, 0);
      expect(
        AppReleaseService()
            .isNewerThanRunning(const AppRelease(latestBuild: 9999)),
        isFalse,
      );
    });

    test('a release at or below the running build is not an update', () {
      final AppReleaseService service = AppReleaseService();
      expect(service.isNewerThanRunning(const AppRelease()), isFalse);
      expect(
        service.isNewerThanRunning(const AppRelease(latestBuild: 1)),
        isFalse,
      );
    });
  });
}
