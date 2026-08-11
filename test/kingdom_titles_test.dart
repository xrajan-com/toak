import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/kingdom_titles.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';

void main() {
  test('venue circuits are ordered by visible label', () {
    expect(kVenueGroups, const <VenueGroup>[
      VenueGroup.euro,
      VenueGroup.india,
      VenueGroup.international,
      VenueGroup.oceania,
      VenueGroup.northAmerica,
    ]);
    expect(venueGroupLabel(VenueGroup.oceania), 'Micro Circuit');
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
      'Africa': 'Mansa',
      'S. America': 'Caudillo',
      'N. America': 'Chief',
      'Arabia': 'Sheikh',
      'China': 'Jiangjun',
      'Far East': 'Shogun',
      'Asia Rest': 'Mandala',
      'Central Asia': 'Emir',
      'Persia': 'Shah',
      'Europe': 'Duke',
    };
    const expectedEuroTitles = <String, String>{
      'Britain': 'Baron',
      'France': 'Marquis',
      'Italy': 'Conte',
      'Spain': 'Hidalgo',
      'Portugal': 'Infante',
      'North Sea': 'Stadtholder',
      'Scandinavia': 'Jarl',
      'Baltic Marches': 'Hetman',
      'Russia & Siberia': 'Ataman',
      'Mediterranean': 'Strategos',
    };
    const expectedOceaniaTitles = <String, String>{
      'Alaska': 'Chieftain',
      'Caribbean': 'Governor',
      'Dragonland': 'Taipan',
      'Straits': 'Laksamana',
      'Indian Ocean': 'Admiral',
      'Pacific': 'Tui',
      'British Isles': 'Warden',
      'French Isles': 'Seigneur',
      'Dutch Isles': 'Burgher',
      'American Isles': 'Marshal',
    };
    const expectedNorthAmericaTitles = <String, String>{
      'Dominion of Canada': 'Mountie',
      'Massachusetts': 'Patriot',
      'New York': 'Maccabee',
      'Virginia': 'Cavalier',
      'Illinois': 'Loopmaster',
      'Florida': 'Buccaneer',
      'Texas': 'Longhorn',
      'Kansas': 'Marshal',
      'Colorado': 'Prospector',
      'California': 'Rainmaker',
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
      'Britain': 'assets/images/flags/euro/britain.png',
      'France': 'assets/images/flags/euro/france.png',
      'Italy': 'assets/images/flags/euro/italy.png',
      'Spain': 'assets/images/flags/euro/spain.png',
      'Portugal': 'assets/images/flags/euro/portugal.png',
      'North Sea': 'assets/images/flags/euro/north_sea.png',
      'Scandinavia': 'assets/images/flags/euro/scandinavia.png',
      'Baltic Marches': 'assets/images/flags/euro/baltic_marches.png',
      'Russia & Siberia': 'assets/images/flags/euro/russia_siberia.png',
      'Mediterranean': 'assets/images/flags/euro/mediterranean.png',
    };
    const expectedOceaniaFlags = <String, String>{
      'Alaska': 'assets/images/flags/oceania/alaska.png',
      'Caribbean': 'assets/images/flags/oceania/caribbean.png',
      'Dragonland': 'assets/images/flags/oceania/dragonland.png',
      'Straits': 'assets/images/flags/oceania/straits.png',
      'Indian Ocean': 'assets/images/flags/oceania/indian_ocean.png',
      'Pacific': 'assets/images/flags/oceania/pacific.png',
      'British Isles': 'assets/images/flags/oceania/british_isles.png',
      'French Isles': 'assets/images/flags/oceania/french_isles.png',
      'Dutch Isles': 'assets/images/flags/oceania/dutch_isles.png',
      'American Isles': 'assets/images/flags/oceania/american_isles.png',
    };
    const expectedNorthAmericaFlags = <String, String>{
      'Dominion of Canada': 'assets/images/flags/us/canada.png',
      'Massachusetts': 'assets/images/flags/us/massachusetts.png',
      'New York': 'assets/images/flags/us/new_york.png',
      'Virginia': 'assets/images/flags/us/virginia.png',
      'Illinois': 'assets/images/flags/us/illinois.png',
      'Florida': 'assets/images/flags/us/florida.png',
      'Texas': 'assets/images/flags/us/texas.png',
      'Kansas': 'assets/images/flags/us/kansas.png',
      'Colorado': 'assets/images/flags/us/colorado.png',
      'California': 'assets/images/flags/us/california.png',
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
