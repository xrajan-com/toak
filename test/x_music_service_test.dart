import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/services/x_music_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('XMusicService lounge discovery', () {
    test('includes future audio and reserves the four event tracks', () {
      final String loungePrefix =
          <String>['assets', 'sounds', 'x lounge'].join('/');
      final String soundsPrefix = <String>['assets', 'sounds'].join('/');
      final List<String> discovered =
          XMusicService.loungeAssetsFromManifest(<String>[
        'assets/sounds/x lounge/Velvet_Tide.mp3',
        'assets/sounds/x lounge/future additions/new track.OGG',
        '$loungePrefix/cover.png',
        'assets/sounds/x lounge/game over with no prize.mp3',
        'assets/sounds/x lounge/game over with prize.mp3',
        'assets/sounds/x lounge/user is in bottom half of chips.mp3',
        'assets/sounds/x lounge/user secures prize.mp3',
        '$soundsPrefix/not_in_the_lounge.mp3',
      ]);

      expect(
        discovered,
        <String>[
          'assets/sounds/x lounge/Velvet_Tide.mp3',
          'assets/sounds/x lounge/future additions/new track.OGG',
        ],
      );
    });

    testWidgets('finds all eight current interchangeable lounge tracks',
        (WidgetTester tester) async {
      final AssetManifest manifest =
          await AssetManifest.loadFromAssetBundle(rootBundle);
      final List<String> discovered =
          XMusicService.loungeAssetsFromManifest(manifest.listAssets());

      expect(discovered, hasLength(8));
      expect(
        discovered,
        contains('assets/sounds/x lounge/Midnight_on_the_Loch.mp3'),
      );
      expect(
        discovered,
        contains('assets/sounds/x lounge/Velvet_and_Thistle.mp3'),
      );
    });
  });

  test('maps each Career circuit to the supplied theme', () {
    expect(
      XMusicService.circuitAssetFor(VenueGroup.euro),
      'assets/sounds/x_music/euro_circuit.mp3',
    );
    expect(
      XMusicService.circuitAssetFor(VenueGroup.india),
      'assets/sounds/x_music/india_circuit.mp3',
    );
    expect(
      XMusicService.circuitAssetFor(VenueGroup.international),
      'assets/sounds/x_music/international_circuit.mp3',
    );
    expect(
      XMusicService.circuitAssetFor(VenueGroup.oceania),
      'assets/sounds/x_music/asia_circuit.mp3',
    );
    expect(
      XMusicService.circuitAssetFor(VenueGroup.northAmerica),
      'assets/sounds/x_music/us_circuit.mp3',
    );
  });
}
