import 'package:flutter/material.dart';

enum VenueGroup { india, international }

class VenueTheme {
  final String name;
  final Color background; // page bg
  final Color felt; // tile border color / table felt
  final Color accent; // brand red
  final Color accentAlt; // brand blue
  final String flagAsset; // small flag image (left of name)
  final int? timezoneOffsetMinutes;

  const VenueTheme({
    required this.name,
    required this.background,
    required this.felt,
    required this.accent,
    required this.accentAlt,
    required this.flagAsset,
    this.timezoneOffsetMinutes,
  });
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
      timezoneOffsetMinutes: 330),
  VenueTheme(
      name: 'Hyderabad',
      background: _bg,
      felt: kFeltDeepPurple,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/hyderabad.png',
      timezoneOffsetMinutes: 330),
  VenueTheme(
      name: 'Indore',
      background: _bg,
      felt: kFeltRed,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/indore.png',
      timezoneOffsetMinutes: 330),
  VenueTheme(
      name: 'Jaipur',
      background: _bg,
      felt: kFeltMagenta,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/jaipur.png',
      timezoneOffsetMinutes: 330),
  VenueTheme(
      name: 'Maratha Empire',
      background: _bg,
      felt: kFeltOrange,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/maratha_empire.png',
      timezoneOffsetMinutes: 330),
  VenueTheme(
      name: 'Mysore',
      background: _bg,
      felt: kFeltDarkBrown,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/mysore.png',
      timezoneOffsetMinutes: 330),
  VenueTheme(
      name: 'New Delhi',
      background: _bg,
      felt: kFeltSkyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/new_delhi.png',
      timezoneOffsetMinutes: 330),
  VenueTheme(
      name: 'Sikh Empire',
      background: _bg,
      felt: kFeltNavyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/sikh_empire.png',
      timezoneOffsetMinutes: 330),
  VenueTheme(
      name: 'Sikkim',
      background: _bg,
      felt: kFeltDarkGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/sikkim.png',
      timezoneOffsetMinutes: 330),
  VenueTheme(
      name: 'Travancore',
      background: _bg,
      felt: kFeltOliveGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/travancore.png',
      timezoneOffsetMinutes: 330),
];

const List<VenueTheme> internationalVenues = [
  VenueTheme(
      name: 'Africa',
      background: _bg,
      felt: kFeltOliveGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/africa.png',
      timezoneOffsetMinutes: 120),
  VenueTheme(
      name: 'S. America',
      background: _bg,
      felt: kFeltDarkGreen,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/amazon.png',
      timezoneOffsetMinutes: -240),
  VenueTheme(
      name: 'N. America',
      background: _bg,
      felt: kFeltNavyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/america.png',
      timezoneOffsetMinutes: -300),
  VenueTheme(
      name: 'Arabia',
      background: _bg,
      felt: kFeltDarkBrown,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/arabia.png',
      timezoneOffsetMinutes: 180),
  VenueTheme(
      name: 'Australia',
      background: _bg,
      felt: kFeltTurmeric,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/australia.png',
      timezoneOffsetMinutes: 600),
  VenueTheme(
      name: 'China',
      background: _bg,
      felt: kFeltRed,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/china.png',
      timezoneOffsetMinutes: 480),
  VenueTheme(
      name: 'Europe',
      background: _bg,
      felt: kFeltMagenta,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/europe.png',
      timezoneOffsetMinutes: 120),
  VenueTheme(
      name: 'India',
      background: _bg,
      felt: kFeltSkyBlue,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/india.png',
      timezoneOffsetMinutes: 330),
  VenueTheme(
      name: 'Russia',
      background: _bg,
      felt: kFeltDeepPurple,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/russia.png',
      timezoneOffsetMinutes: 180),
  VenueTheme(
      name: 'Asia',
      background: _bg,
      felt: kFeltOrange,
      accent: _red,
      accentAlt: _blue,
      flagAsset: 'assets/images/flags/asean.png',
      timezoneOffsetMinutes: 420),
];
