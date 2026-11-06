import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';

void main() {
  test('venue circuits are ordered by visible label', () {
    expect(kVenueGroups, const <VenueGroup>[
      VenueGroup.india,
      VenueGroup.euro,
      VenueGroup.oceania,
      VenueGroup.northAmerica,
      VenueGroup.international,
    ]);
    expect(
      kVenueGroups.map(venueGroupLabel),
      <String>[
        'Indian Ocean',
        'Eurasia',
        'Australasia',
        'Americas',
        'Rest of the World',
      ],
    );
  });

  test('kingdom titles match the circuit title list', () {
    const expectedIndianTitles = <String, String>{
      'Baroda': 'Patel',
      'Hyderabad': 'Nizam',
      'Indore': 'Subedar',
      'Jaipur': 'Rawal',
      'Maratha Empire': 'Peshwa',
      'Mysore': 'Sultan',
      'New Delhi': 'Raja',
      'Sikh Empire': 'Zaildar',
      'Sikkim': 'Sherpa',
      'Travancore': 'Thala',
    };
    const expectedInternationalTitles = <String, String>{
      'North Africa': 'Pasha',
      'Sub-Saharan Africa': 'Mansa',
      'Arabia': 'Sheikh',
      'Persia & Mesopotamia': 'Shah',
      'Central Asia': 'Emir',
      'Indian Ocean Isles': 'Admiral',
      'Atlantic Isles': 'Warden',
      'French & Dutch Isles': 'Burgher',
      'Pacific': 'Tui',
      'Arctic': 'Chieftain',
    };
    const expectedEuroTitles = <String, String>{
      'Britain & Ireland': 'Baron',
      'France': 'Marquis',
      'Italy': 'Conte',
      'Iberia': 'Hidalgo',
      'Low Countries': 'Stadtholder',
      'Scandinavia': 'Jarl',
      'Central Europe': 'Margrave',
      'Balkans & Mediterranean': 'Strategos',
      'Baltic Marches': 'Hetman',
      'Russia & Siberia': 'Ataman',
    };
    const expectedOceaniaTitles = <String, String>{
      'China': 'Jiangjun',
      'Japan': 'Shogun',
      'Korea': 'Daegam',
      'Taiwan': 'Taipan',
      'Vietnam': 'Vương',
      'Mekong': 'Mandala',
      'Philippines': 'Datu',
      'Straits': 'Laksamana',
      'Indonesia': 'Sultan',
      'Australia': 'Premier',
    };
    const expectedNorthAmericaTitles = <String, String>{
      'Canada': 'Mountie',
      'Northeast USA': 'Patriot',
      'Atlantic USA': 'Commodore',
      'Southern USA': 'Colonel',
      'Western USA': 'Prospector',
      'Mexico & Central America': 'Caudillo',
      'Caribbean': 'Governor',
      'Brazil': 'Bandeirante',
      'Andes': 'Inca',
      'Southern Cone': 'Gaucho',
    };

    expect(kKingdomTitles[VenueGroup.india], expectedIndianTitles);
    expect(
        kKingdomTitles[VenueGroup.international], expectedInternationalTitles);
    expect(kKingdomTitles[VenueGroup.euro], expectedEuroTitles);
    expect(kKingdomTitles[VenueGroup.oceania], expectedOceaniaTitles);
    expect(
      kKingdomTitles[VenueGroup.northAmerica],
      expectedNorthAmericaTitles,
    );
  });

  // Country kingdoms fly their modern flag; a kingdom spanning countries
  // flies the flag of the country with most of its forts
  // (docs/ART_DIRECTION.md, "Kingdom flags").
  test('Eurasia, Australasia and US circuit venues keep their own flags', () {
    const w = 'assets/images/flags/world';
    const expectedEuroFlags = <String, String>{
      'Britain & Ireland': '$w/gb_eng.png',
      'France': '$w/fr.png',
      'Italy': '$w/it.png',
      'Iberia': '$w/es.png',
      'Low Countries': '$w/nl.png',
      'Scandinavia': 'assets/images/flags/euro/scandinavia.png',
      'Central Europe': '$w/eu.png',
      'Balkans & Mediterranean': '$w/hr.png',
      'Baltic Marches': '$w/ua.png',
      'Russia & Siberia': '$w/ru.png',
    };
    const expectedOceaniaFlags = <String, String>{
      'China': '$w/cn.png',
      'Japan': '$w/jp.png',
      'Korea': '$w/kr.png',
      'Taiwan': '$w/tw.png',
      'Vietnam': '$w/vn.png',
      'Mekong': '$w/th.png',
      'Philippines': '$w/ph.png',
      'Straits': '$w/my.png',
      'Indonesia': '$w/id.png',
      'Australia': '$w/au.png',
    };
    const expectedNorthAmericaFlags = <String, String>{
      'Canada': '$w/ca.png',
      'Northeast USA': 'assets/images/flags/us/massachusetts.png',
      'Atlantic USA': 'assets/images/flags/us/new_york.png',
      'Southern USA': 'assets/images/flags/us/florida.png',
      'Western USA': 'assets/images/flags/us/california.png',
      'Mexico & Central America': '$w/mx.png',
      'Caribbean': '$w/pr.png',
      'Brazil': '$w/br.png',
      'Andes': '$w/ve.png',
      'Southern Cone': '$w/cl.png',
    };

    expect(
      {for (final venue in euroVenues) venue.name: venue.flagAsset},
      expectedEuroFlags,
    );
    expect(
      {for (final venue in oceaniaVenues) venue.name: venue.flagAsset},
      expectedOceaniaFlags,
    );
    expect(
      {for (final venue in northAmericanVenues) venue.name: venue.flagAsset},
      expectedNorthAmericaFlags,
    );
  });
}
