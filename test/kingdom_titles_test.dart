import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';

void main() {
  test('venue circuits are ordered by visible label', () {
    expect(kVenueGroups, const <VenueGroup>[
      VenueGroup.euro,
      VenueGroup.northAmerica,
      VenueGroup.oceania,
      VenueGroup.international,
      VenueGroup.india,
    ]);
    expect(
      kVenueGroups.map(venueGroupLabel),
      <String>[
        'Europe',
        'Americas',
        'Asia-Pacific',
        'World Frontiers',
        'Indian Ocean',
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
      'Australia': 'Premier',
      'North Africa': 'Pasha',
      'Sub-Saharan Africa': 'Mansa',
      'Arabia': 'Sheikh',
      'Persia & Mesopotamia': 'Shah',
      'Central Asia': 'Emir',
      'Indian Ocean Isles': 'Admiral',
      'Atlantic Isles': 'Warden',
      'French & Dutch Isles': 'Burgher',
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
      'Pacific': 'Tui',
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

  test('euro, oceania, and US circuit venues use their own flag assets', () {
    const expectedEuroFlags = <String, String>{
      'Britain & Ireland': 'assets/images/flags/euro/britain.png',
      'France': 'assets/images/flags/euro/france.png',
      'Italy': 'assets/images/flags/euro/italy.png',
      'Iberia': 'assets/images/flags/euro/spain.png',
      'Low Countries': 'assets/images/flags/euro/north_sea.png',
      'Scandinavia': 'assets/images/flags/euro/scandinavia.png',
      'Central Europe': 'assets/images/flags/europe.png',
      'Balkans & Mediterranean': 'assets/images/flags/euro/mediterranean.png',
      'Baltic Marches': 'assets/images/flags/euro/baltic_marches.png',
      'Russia & Siberia': 'assets/images/flags/euro/russia_siberia.png',
    };
    const expectedOceaniaFlags = <String, String>{
      'China': 'assets/images/flags/china.png',
      'Japan': 'assets/images/flags/japan.png',
      'Korea': 'assets/images/flags/china.png',
      'Taiwan': 'assets/images/flags/oceania/dragonland.png',
      'Vietnam': 'assets/images/flags/asean.png',
      'Mekong': 'assets/images/flags/asean.png',
      'Philippines': 'assets/images/flags/oceania/american_isles.png',
      'Straits': 'assets/images/flags/oceania/straits.png',
      'Indonesia': 'assets/images/flags/oceania/straits.png',
      'Pacific': 'assets/images/flags/oceania/pacific.png',
    };
    const expectedNorthAmericaFlags = <String, String>{
      'Canada': 'assets/images/flags/us/canada.png',
      'Northeast USA': 'assets/images/flags/us/massachusetts.png',
      'Atlantic USA': 'assets/images/flags/us/new_york.png',
      'Southern USA': 'assets/images/flags/us/florida.png',
      'Western USA': 'assets/images/flags/us/california.png',
      'Mexico & Central America': 'assets/images/flags/us/texas.png',
      'Caribbean': 'assets/images/flags/oceania/caribbean.png',
      'Brazil': 'assets/images/flags/amazon.png',
      'Andes': 'assets/images/flags/us/colorado.png',
      'Southern Cone': 'assets/images/flags/us/virginia.png',
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
