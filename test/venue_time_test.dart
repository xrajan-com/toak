import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/core/venue_time.dart';

void main() {
  final venues = <VenueTheme>[
    for (final group in VenueGroup.values) ...venuesForGroup(group),
  ];

  test('every game venue has a valid IANA time zone', () {
    final instant = DateTime.utc(2026, 7, 18, 12);

    expect(venues, hasLength(50));
    for (final venue in venues) {
      final local = VenueTime.at(instant, timeZoneId: venue.timeZoneId);
      expect(local.toUtc(), instant, reason: venue.name);
    }
  });

  test('venue conversion depends on the instant, not the device zone', () {
    final utc = DateTime.utc(2026, 7, 18, 12);
    final sameInstantFromIndia = DateTime.parse('2026-07-18T17:30:00+05:30');

    final fromUtc = VenueTime.at(utc, timeZoneId: 'America/New_York');
    final fromIndia =
        VenueTime.at(sameInstantFromIndia, timeZoneId: 'America/New_York');

    expect(fromIndia, fromUtc);
    expect(fromUtc.hour, 8);
  });

  test('IANA rules apply daylight saving for venue clocks', () {
    final londonWinter = VenueTime.at(
      DateTime.utc(2026, 1, 15, 12),
      timeZoneId: 'Europe/London',
    );
    final londonSummer = VenueTime.at(
      DateTime.utc(2026, 7, 15, 12),
      timeZoneId: 'Europe/London',
    );
    final newYorkWinter = VenueTime.at(
      DateTime.utc(2026, 1, 15, 12),
      timeZoneId: 'America/New_York',
    );
    final newYorkSummer = VenueTime.at(
      DateTime.utc(2026, 7, 15, 12),
      timeZoneId: 'America/New_York',
    );

    expect(londonWinter.timeZoneOffset, Duration.zero);
    expect(londonSummer.timeZoneOffset, const Duration(hours: 1));
    expect(newYorkWinter.timeZoneOffset, const Duration(hours: -5));
    expect(newYorkSummer.timeZoneOffset, const Duration(hours: -4));
  });

  test('regional venues use their intended representative city', () {
    final byName = <String, VenueTheme>{for (final v in venues) v.name: v};

    expect(byName['S. America']!.timeZoneId, 'America/Sao_Paulo');
    expect(byName['N. America']!.timeZoneId, 'America/New_York');
    expect(byName['Arabia']!.timeZoneId, 'Asia/Dubai');
    expect(byName['Britain']!.timeZoneId, 'Europe/London');
    expect(byName['Alaska']!.timeZoneId, 'America/Anchorage');
    expect(byName['Pacific']!.timeZoneId, 'Pacific/Auckland');
  });
}
