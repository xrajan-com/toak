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
const _blue = Color(0xFF20D9FF);

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
      name: 'Australia',
      background: _bg,
      felt: kFeltNavyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/australia.png',
      timeZoneId: 'Australia/Sydney'),
  VenueTheme(
      name: 'North Africa',
      background: _bg,
      felt: kFeltSkyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/africa.png',
      timeZoneId: 'Africa/Cairo'),
  VenueTheme(
      name: 'Sub-Saharan Africa',
      background: _bg,
      felt: kFeltOliveGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/africa.png',
      timeZoneId: 'Africa/Nairobi'),
  VenueTheme(
      name: 'Arabia',
      background: _bg,
      felt: kFeltRed,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/arabia.png',
      timeZoneId: 'Asia/Dubai'),
  VenueTheme(
      name: 'Persia & Mesopotamia',
      background: _bg,
      felt: kFeltDeepPurple,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/arabia.png',
      timeZoneId: 'Asia/Tehran'),
  VenueTheme(
      name: 'Central Asia',
      background: _bg,
      felt: kFeltDarkGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/russia.png',
      timeZoneId: 'Asia/Tashkent'),
  VenueTheme(
      name: 'Indian Ocean Isles',
      background: _bg,
      felt: kFeltTurmeric,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/indian_ocean.png',
      timeZoneId: 'Indian/Mauritius'),
  VenueTheme(
      name: 'Atlantic Isles',
      background: _bg,
      felt: kFeltMagenta,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/british_isles.png',
      timeZoneId: 'Atlantic/Bermuda'),
  VenueTheme(
      name: 'French & Dutch Isles',
      background: _bg,
      felt: kFeltOrange,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/french_isles.png',
      timeZoneId: 'America/Guadeloupe'),
  VenueTheme(
      name: 'Arctic',
      background: _bg,
      felt: kFeltDarkBrown,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/alaska.png',
      timeZoneId: 'America/Anchorage'),
];

const List<VenueTheme> euroVenues = [
  VenueTheme(
      name: 'Britain & Ireland',
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
      name: 'Iberia',
      background: _bg,
      felt: kFeltRed,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/spain.png',
      timeZoneId: 'Europe/Madrid'),
  VenueTheme(
      name: 'Low Countries',
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
      name: 'Central Europe',
      background: _bg,
      felt: kFeltTurmeric,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/europe.png',
      timeZoneId: 'Europe/Vienna'),
  VenueTheme(
      name: 'Balkans & Mediterranean',
      background: _bg,
      felt: kFeltMagenta,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/mediterranean.png',
      timeZoneId: 'Europe/Athens'),
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
      felt: kFeltDarkBrown,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/euro/russia_siberia.png',
      timeZoneId: 'Europe/Moscow'),
];

const List<VenueTheme> oceaniaVenues = [
  VenueTheme(
      name: 'China',
      background: _bg,
      felt: kFeltNavyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/china.png',
      timeZoneId: 'Asia/Shanghai'),
  VenueTheme(
      name: 'Japan',
      background: _bg,
      felt: kFeltSkyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/japan.png',
      timeZoneId: 'Asia/Tokyo'),
  VenueTheme(
      name: 'Korea',
      background: _bg,
      felt: kFeltOliveGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/china.png',
      timeZoneId: 'Asia/Seoul'),
  VenueTheme(
      name: 'Taiwan',
      background: _bg,
      felt: kFeltRed,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/dragonland.png',
      timeZoneId: 'Asia/Taipei'),
  VenueTheme(
      name: 'Vietnam',
      background: _bg,
      felt: kFeltDeepPurple,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/asean.png',
      timeZoneId: 'Asia/Ho_Chi_Minh'),
  VenueTheme(
      name: 'Mekong',
      background: _bg,
      felt: kFeltDarkGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/asean.png',
      timeZoneId: 'Asia/Bangkok'),
  VenueTheme(
      name: 'Philippines',
      background: _bg,
      felt: kFeltTurmeric,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/american_isles.png',
      timeZoneId: 'Asia/Manila'),
  VenueTheme(
      name: 'Straits',
      background: _bg,
      felt: kFeltMagenta,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/straits.png',
      timeZoneId: 'Asia/Singapore'),
  VenueTheme(
      name: 'Indonesia',
      background: _bg,
      felt: kFeltOrange,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/straits.png',
      timeZoneId: 'Asia/Jakarta'),
  VenueTheme(
      name: 'Pacific',
      background: _bg,
      felt: kFeltDarkBrown,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/pacific.png',
      timeZoneId: 'Pacific/Auckland'),
];

const List<VenueTheme> northAmericanVenues = [
  VenueTheme(
      name: 'Canada',
      background: _bg,
      felt: kFeltNavyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/canada.png',
      timeZoneId: 'America/Toronto'),
  VenueTheme(
      name: 'Northeast USA',
      background: _bg,
      felt: kFeltSkyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/massachusetts.png',
      timeZoneId: 'America/New_York'),
  VenueTheme(
      name: 'Atlantic USA',
      background: _bg,
      felt: kFeltOliveGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/new_york.png',
      timeZoneId: 'America/New_York'),
  VenueTheme(
      name: 'Southern USA',
      background: _bg,
      felt: kFeltRed,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/florida.png',
      timeZoneId: 'America/Chicago'),
  VenueTheme(
      name: 'Western USA',
      background: _bg,
      felt: kFeltDeepPurple,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/california.png',
      timeZoneId: 'America/Los_Angeles'),
  VenueTheme(
      name: 'Mexico & Central America',
      background: _bg,
      felt: kFeltDarkGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/texas.png',
      timeZoneId: 'America/Mexico_City'),
  VenueTheme(
      name: 'Caribbean',
      background: _bg,
      felt: kFeltTurmeric,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/oceania/caribbean.png',
      timeZoneId: 'America/Puerto_Rico'),
  VenueTheme(
      name: 'Brazil',
      background: _bg,
      felt: kFeltMagenta,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/amazon.png',
      timeZoneId: 'America/Sao_Paulo'),
  VenueTheme(
      name: 'Andes',
      background: _bg,
      felt: kFeltOrange,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/colorado.png',
      timeZoneId: 'America/Lima'),
  VenueTheme(
      name: 'Southern Cone',
      background: _bg,
      felt: kFeltDarkBrown,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/us/virginia.png',
      timeZoneId: 'America/Argentina/Buenos_Aires'),
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
  VenueGroup.northAmerica,
  VenueGroup.oceania,
  VenueGroup.international,
  VenueGroup.india,
];

String venueGroupLabel(VenueGroup group) => switch (group) {
      VenueGroup.international => 'World Frontiers',
      VenueGroup.india => 'Indian Ocean',
      VenueGroup.euro => 'Europe',
      VenueGroup.oceania => 'Asia-Pacific',
      VenueGroup.northAmerica => 'Americas',
    };
