import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomNamesFor;
import 'package:ten_of_a_kind_poker/config/venues.dart'
    show kVenueGroups, venueGroupLabel, venuesForGroup;

void main() {
  test('exports the complete circuit, kingdom, and fort catalog', () {
    final destination =
        Platform.environment['FORT_CATALOG_OUTPUT']?.trim().isNotEmpty == true
            ? Platform.environment['FORT_CATALOG_OUTPUT']!.trim()
            : 'docs/FORT_CATALOG.md';
    final output = File(destination);
    output.parent.createSync(recursive: true);
    output.writeAsStringSync(_buildCatalog());
    stdout.writeln('Wrote complete fort catalog to $destination');
  });
}

String _buildCatalog() {
  final circuitCounts = <int>[];
  var totalKingdoms = 0;
  var totalForts = 0;

  for (final group in kVenueGroups) {
    var circuitForts = 0;
    final venues = venuesForGroup(group);
    totalKingdoms += venues.length;
    for (final venue in venues) {
      circuitForts += subKingdomNamesFor(
        group: group,
        kingdomName: venue.name,
      ).length;
    }
    circuitCounts.add(circuitForts);
    totalForts += circuitForts;
  }

  if (kVenueGroups.length != 5 || totalKingdoms != 50 || totalForts != 500) {
    throw StateError(
      'Unexpected catalog size: ${kVenueGroups.length} circuits, '
      '$totalKingdoms kingdoms, $totalForts forts.',
    );
  }

  final buffer = StringBuffer()
    ..writeln('# Complete Fort Catalog')
    ..writeln()
    ..writeln(
      'Authoritative game catalog: **${kVenueGroups.length} circuits, '
      '$totalKingdoms kingdoms, $totalForts forts**.',
    )
    ..writeln()
    ..writeln(
      '_Generated from `lib/config/venues.dart` and '
      '`lib/config/sub_kingdoms.dart` by '
      '`tools/export_fort_catalog.dart`._',
    )
    ..writeln();

  for (var groupIndex = 0; groupIndex < kVenueGroups.length; groupIndex++) {
    final group = kVenueGroups[groupIndex];
    final venues = venuesForGroup(group);
    buffer
      ..writeln(
        '## ${groupIndex + 1}. ${venueGroupLabel(group)} '
        '(${circuitCounts[groupIndex]} forts)',
      )
      ..writeln();

    for (var venueIndex = 0; venueIndex < venues.length; venueIndex++) {
      final venue = venues[venueIndex];
      final forts = subKingdomNamesFor(
        group: group,
        kingdomName: venue.name,
      );
      buffer
        ..writeln(
          '### ${groupIndex + 1}.${venueIndex + 1} ${venue.name} '
          '(${forts.length} forts)',
        )
        ..writeln();
      for (var fortIndex = 0; fortIndex < forts.length; fortIndex++) {
        buffer.writeln('${fortIndex + 1}. ${forts[fortIndex]}');
      }
      buffer.writeln();
    }
  }

  return buffer.toString();
}
