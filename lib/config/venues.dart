import 'package:flutter/material.dart';

enum VenueGroup { international, india, euro, oceania, northAmerica }

class VenueTheme {
  final String name;
  final Color background; // page bg
  final Color felt; // tile border color / table felt
  final Color accent; // brand red
  final Color accentAlt; // brand blue
  final String flagAsset; // small flag image (left of name)

  /// Geographic coverage represented by this venue/kingdom.
  final List<String> territories;

  /// IANA time-zone identifier for the venue's representative local clock.
  final String timeZoneId;

  const VenueTheme({
    required this.name,
    required this.background,
    required this.felt,
    required this.accent,
    required this.accentAlt,
    required this.flagAsset,
    this.territories = const <String>[],
    required this.timeZoneId,
  });

  String get coverageLabel => territories.join(', ');
}

/* ---------- BRAND ---------- */

const _bg = Color(0xFF000000);
const _red = Color(0xFFFF2800);
const _blue = Color(0xFF24B6FF);

/* ---------- FELT COLORS ---------- */

const kFeltRed = Color(0xFF8B0000);
const kFeltOrange = Color.fromARGB(212, 255, 107, 1);
const kFeltMagenta = Color.fromARGB(204, 220, 83, 220);
const kFeltTurmeric = Color.fromARGB(218, 203, 160, 20);
const kFeltNavyBlue = Color.fromARGB(255, 36, 36, 122);
const kFeltSkyBlue = Color.fromARGB(208, 0, 166, 232);
const kFeltDeepPurple = Color.fromARGB(173, 118, 30, 180);
const kFeltDarkGreen = Color(0xFF013220);
const kFeltOliveGreen = Color(0xFF556B2F);
const kFeltDarkBrown = Color.fromARGB(227, 95, 65, 58);

/* ---------- VENUE DATA ---------- */

const List<VenueTheme> indianVenues = [
  VenueTheme(
      name: 'Baroda',
      background: _bg,
      felt: kFeltTurmeric,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/baroda.png',
      timeZoneId: 'Asia/Kolkata'),
  VenueTheme(
      name: 'Hyderabad',
      background: _bg,
      felt: kFeltDeepPurple,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/hyderabad.png',
      timeZoneId: 'Asia/Kolkata'),
  VenueTheme(
      name: 'Indore',
      background: _bg,
      felt: kFeltRed,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/indore.png',
      timeZoneId: 'Asia/Kolkata'),
  VenueTheme(
      name: 'Jaipur',
      background: _bg,
      felt: kFeltMagenta,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/jaipur.png',
      timeZoneId: 'Asia/Kolkata'),
  VenueTheme(
      name: 'Maratha Empire',
      background: _bg,
      felt: kFeltOrange,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/maratha_empire.png',
      timeZoneId: 'Asia/Kolkata'),
  VenueTheme(
      name: 'Mysore',
      background: _bg,
      felt: kFeltDarkBrown,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/mysore.png',
      timeZoneId: 'Asia/Kolkata'),
  VenueTheme(
      name: 'New Delhi',
      background: _bg,
      felt: kFeltSkyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/new_delhi.png',
      timeZoneId: 'Asia/Kolkata'),
  VenueTheme(
      name: 'Sikh Empire',
      background: _bg,
      felt: kFeltNavyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/sikh_empire.png',
      timeZoneId: 'Asia/Kolkata'),
  VenueTheme(
      name: 'Sikkim',
      background: _bg,
      felt: kFeltDarkGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/sikkim.png',
      timeZoneId: 'Asia/Kolkata'),
  VenueTheme(
      name: 'Travancore',
      background: _bg,
      felt: kFeltOliveGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/travancore.png',
      timeZoneId: 'Asia/Kolkata'),
];

const List<VenueTheme> internationalVenues = [
  VenueTheme(
      name: 'Africa',
      background: _bg,
      felt: kFeltOliveGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/africa.png',
      timeZoneId: 'Africa/Cairo'),
  VenueTheme(
      name: 'S. America',
      background: _bg,
      felt: kFeltDarkGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/amazon.png',
      timeZoneId: 'America/Sao_Paulo'),
  VenueTheme(
      name: 'N. America',
      background: _bg,
      felt: kFeltNavyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/america.png',
      timeZoneId: 'America/New_York'),
  VenueTheme(
      name: 'Arabia',
      background: _bg,
      felt: kFeltDarkBrown,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/arabia.png',
      timeZoneId: 'Asia/Dubai'),
  VenueTheme(
      name: 'China',
      background: _bg,
      felt: kFeltRed,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/china.png',
      timeZoneId: 'Asia/Shanghai'),
  VenueTheme(
      name: 'Far East',
      background: _bg,
      felt: kFeltMagenta,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/china.png',
      timeZoneId: 'Asia/Tokyo'),
  VenueTheme(
      name: 'Asia Rest',
      background: _bg,
      felt: kFeltSkyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/asean.png',
      timeZoneId: 'Asia/Bangkok'),
  VenueTheme(
      name: 'Central Asia',
      background: _bg,
      felt: kFeltDeepPurple,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/russia.png',
      timeZoneId: 'Asia/Tashkent'),
  VenueTheme(
      name: 'Persia',
      background: _bg,
      felt: kFeltOrange,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/arabia.png',
      timeZoneId: 'Asia/Tehran'),
  VenueTheme(
      name: 'Europe',
      background: _bg,
      felt: kFeltTurmeric,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/europe.png',
      timeZoneId: 'Europe/Paris'),
];

const List<VenueTheme> euroVenues = [
  VenueTheme(
      name: 'Britain',
      background: _bg,
      felt: kFeltNavyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/britain.png',
      timeZoneId: 'Europe/London'),
  VenueTheme(
      name: 'France',
      background: _bg,
      felt: kFeltSkyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/france.png',
      timeZoneId: 'Europe/Paris'),
  VenueTheme(
      name: 'Italy',
      background: _bg,
      felt: kFeltOliveGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/italy.png',
      timeZoneId: 'Europe/Rome'),
  VenueTheme(
      name: 'Spain',
      background: _bg,
      felt: kFeltRed,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/spain.png',
      timeZoneId: 'Europe/Madrid'),
  VenueTheme(
      name: 'Portugal',
      background: _bg,
      felt: kFeltTurmeric,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/portugal.png',
      timeZoneId: 'Europe/Lisbon'),
  VenueTheme(
      name: 'North Sea',
      background: _bg,
      felt: kFeltDeepPurple,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/north_sea.png',
      timeZoneId: 'Europe/Amsterdam'),
  VenueTheme(
      name: 'Scandinavia',
      background: _bg,
      felt: kFeltDarkGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/scandinavia.png',
      timeZoneId: 'Europe/Stockholm'),
  VenueTheme(
      name: 'Baltic Marches',
      background: _bg,
      felt: kFeltOrange,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/baltic_marches.png',
      timeZoneId: 'Europe/Riga'),
  VenueTheme(
      name: 'Russia & Siberia',
      background: _bg,
      felt: kFeltMagenta,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/russia_siberia.png',
      timeZoneId: 'Europe/Moscow'),
  VenueTheme(
      name: 'Mediterranean',
      background: _bg,
      felt: kFeltDarkBrown,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/mediterranean.png',
      timeZoneId: 'Europe/Athens'),
];

const List<VenueTheme> oceaniaVenues = [
  VenueTheme(
      name: 'Alaska',
      background: _bg,
      felt: kFeltNavyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/alaska.png',
      timeZoneId: 'America/Anchorage'),
  VenueTheme(
      name: 'Caribbean',
      background: _bg,
      felt: kFeltTurmeric,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/caribbean.png',
      timeZoneId: 'America/Puerto_Rico'),
  VenueTheme(
      name: 'Dragonland',
      background: _bg,
      felt: kFeltRed,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/dragonland.png',
      timeZoneId: 'Asia/Shanghai'),
  VenueTheme(
      name: 'Straits',
      background: _bg,
      felt: kFeltSkyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/straits.png',
      timeZoneId: 'Asia/Singapore'),
  VenueTheme(
      name: 'Indian Ocean',
      background: _bg,
      felt: kFeltDarkGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/indian_ocean.png',
      timeZoneId: 'Asia/Colombo'),
  VenueTheme(
      name: 'Pacific',
      background: _bg,
      felt: kFeltOliveGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/pacific.png',
      timeZoneId: 'Pacific/Auckland'),
  VenueTheme(
      name: 'British Isles',
      background: _bg,
      felt: kFeltDeepPurple,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/british_isles.png',
      timeZoneId: 'Atlantic/Bermuda'),
  VenueTheme(
      name: 'French Isles',
      background: _bg,
      felt: kFeltMagenta,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/french_isles.png',
      timeZoneId: 'America/Guadeloupe'),
  VenueTheme(
      name: 'Dutch Isles',
      background: _bg,
      felt: kFeltOrange,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/dutch_isles.png',
      timeZoneId: 'America/Curacao'),
  VenueTheme(
      name: 'American Isles',
      background: _bg,
      felt: kFeltDarkBrown,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/american_isles.png',
      timeZoneId: 'Pacific/Honolulu'),
];

const List<VenueTheme> northAmericanVenues = [
  VenueTheme(
      name: 'Dominion of Canada',
      background: _bg,
      felt: kFeltRed,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/canada.png',
      territories: <String>['Canada'],
      timeZoneId: 'America/Toronto'),
  VenueTheme(
      name: 'Massachusetts',
      background: _bg,
      felt: kFeltNavyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/massachusetts.png',
      territories: <String>[
        'Massachusetts',
        'Maine',
        'Vermont',
        'New Hampshire',
        'Rhode Island',
        'Connecticut',
      ],
      timeZoneId: 'America/New_York'),
  VenueTheme(
      name: 'New York',
      background: _bg,
      felt: kFeltSkyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/new_york.png',
      territories: <String>[
        'New York',
        'New Jersey',
        'Pennsylvania',
        'Delaware',
        'Maryland',
        'District of Columbia',
      ],
      timeZoneId: 'America/New_York'),
  VenueTheme(
      name: 'Virginia',
      background: _bg,
      felt: kFeltDeepPurple,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/virginia.png',
      territories: <String>[
        'Virginia',
        'West Virginia',
        'Kentucky',
        'Tennessee',
      ],
      timeZoneId: 'America/New_York'),
  VenueTheme(
      name: 'Illinois',
      background: _bg,
      felt: kFeltDarkGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/illinois.png',
      territories: <String>[
        'Illinois',
        'Indiana',
        'Michigan',
        'Ohio',
        'Wisconsin',
        'Iowa',
        'Minnesota',
      ],
      timeZoneId: 'America/Chicago'),
  VenueTheme(
      name: 'Florida',
      background: _bg,
      felt: kFeltTurmeric,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/florida.png',
      territories: <String>[
        'Florida',
        'Georgia',
        'Alabama',
        'Mississippi',
        'South Carolina',
        'North Carolina',
      ],
      timeZoneId: 'America/New_York'),
  VenueTheme(
      name: 'Texas',
      background: _bg,
      felt: kFeltDarkBrown,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/texas.png',
      territories: <String>['Texas', 'Louisiana', 'Arkansas'],
      timeZoneId: 'America/Chicago'),
  VenueTheme(
      name: 'Kansas',
      background: _bg,
      felt: kFeltOliveGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/kansas.png',
      territories: <String>[
        'Kansas',
        'Nebraska',
        'Oklahoma',
        'North Dakota',
        'South Dakota',
        'Missouri',
      ],
      timeZoneId: 'America/Chicago'),
  VenueTheme(
      name: 'Colorado',
      background: _bg,
      felt: kFeltOrange,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/colorado.png',
      territories: <String>[
        'Colorado',
        'Wyoming',
        'Montana',
        'Idaho',
        'Utah',
      ],
      timeZoneId: 'America/Denver'),
  VenueTheme(
      name: 'California',
      background: _bg,
      felt: kFeltMagenta,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/california.png',
      territories: <String>[
        'California',
        'Oregon',
        'Washington',
        'Alaska',
        'Hawaii',
        'Nevada',
        'Arizona',
        'New Mexico',
      ],
      timeZoneId: 'America/Los_Angeles'),
];

List<VenueTheme> venuesForGroup(VenueGroup group) => switch (group) {
      VenueGroup.international => internationalVenues,
      VenueGroup.india => indianVenues,
      VenueGroup.euro => euroVenues,
      VenueGroup.oceania => oceaniaVenues,
      VenueGroup.northAmerica => northAmericanVenues,
    };

const List<VenueGroup> kVenueGroups = <VenueGroup>[
  VenueGroup.euro,
  VenueGroup.india,
  VenueGroup.international,
  VenueGroup.oceania,
  VenueGroup.northAmerica,
];

String venueGroupLabel(VenueGroup group) => switch (group) {
      VenueGroup.international => 'International Circuit',
      VenueGroup.india => 'Indian Circuit',
      VenueGroup.euro => 'Euro Circuit',
      VenueGroup.oceania => 'Micro Circuit',
      VenueGroup.northAmerica => 'US Circuit',
    };
