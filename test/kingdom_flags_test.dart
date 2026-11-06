import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';

void main() {
  final List<VenueTheme> kingdoms = <VenueTheme>[
    for (final VenueGroup group in kVenueGroups) ...venuesForGroup(group),
  ];

  test('every kingdom has a flag file', () {
    for (final VenueTheme k in kingdoms) {
      expect(File(k.flagAsset).existsSync(), isTrue,
          reason: '${k.name}: ${k.flagAsset} is missing');
    }
  });

  test('no two kingdoms fly the same flag', () {
    final Map<String, String> seen = <String, String>{};
    for (final VenueTheme k in kingdoms) {
      final String? other = seen[k.flagAsset];
      expect(other, isNull,
          reason: '${k.name} and $other both use ${k.flagAsset}');
      seen[k.flagAsset] = k.name;
    }
  });

  test('country kingdoms fly their modern national flag', () {
    const Map<String, String> expected = <String, String>{
      'Japan': 'jp',
      'Korea': 'kr',
      'Taiwan': 'tw',
      'Vietnam': 'vn',
      'Indonesia': 'id',
      'Philippines': 'ph',
      'China': 'cn',
      'Brazil': 'br',
      'Canada': 'ca',
      'France': 'fr',
      'Italy': 'it',
      'Australia': 'au',
      'Russia & Siberia': 'ru',
    };
    expected.forEach((String name, String code) {
      expect(kingdomFlagAsset(name), 'assets/images/flags/world/$code.png');
    });
  });

  test('a kingdom flag is found by name in any case', () {
    expect(kingdomFlagAsset('japan'), kingdomFlagAsset('Japan'));
    expect(kingdomFlagAsset('Atlantis'), isNull);
    expect(kingdomFlagAsset(''), isNull);
  });
}
