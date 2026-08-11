import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as campaign;
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomCountFor;
import 'package:ten_of_a_kind_poker/config/venues.dart'
    show VenueGroup, kVenueGroups, venuesForGroup;
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/game/models.dart' show PayoutTable;

String _slug(String raw) {
  final lower = raw.trim().toLowerCase();
  final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return replaced.replaceAll(RegExp(r'^_+|_+$'), '');
}

String _fortId(VenueGroup group, String kingdomName, int index) =>
    'sk:${group.name}:${_slug(kingdomName)}:$index';

String _mainId(VenueGroup group, String kingdomName) =>
    'me:${group.name}:${_slug(kingdomName)}';

void main() {
  test('exports the authoritative backend economy catalog', () {
    final configured =
        Platform.environment['ECONOMY_CATALOG_OUTPUT']?.trim() ?? '';
    final payload = _catalogPayload();
    final destination =
        configured.isEmpty ? 'backend/src/economy_catalog.json' : configured;
    _writeCatalog(destination, payload);
    final dartDestination =
        Platform.environment['ECONOMY_CATALOG_DART_OUTPUT']?.trim() ?? '';
    if (dartDestination.isNotEmpty || configured.isEmpty) {
      _writeDartVersion(
        dartDestination.isEmpty
            ? 'lib/config/economy_catalog_version.dart'
            : dartDestination,
        schemaVersion: payload['schemaVersion']! as int,
        eventCount: payload['eventCount']! as int,
        contentHash: payload['contentHash']! as String,
      );
    }
  });
}

Map<String, Object> _catalogPayload() {
  final events = <String, Object>{};
  for (final group in kVenueGroups) {
    for (final venue in venuesForGroup(group)) {
      final canonical = campaign.canonicalKingdomName(
        group: group,
        kingdomName: venue.name,
      );
      final count = subKingdomCountFor(
        group: group,
        kingdomName: canonical,
      );
      final fortIds = <String>[
        for (int index = 1; index <= count; index++)
          _fortId(group, canonical, index),
      ];

      for (int index = 1; index <= count; index++) {
        final id = _fortId(group, canonical, index);
        final eventSpec = campaign.subKingdomEventSpec(
          group: group,
          kingdomName: canonical,
          subKingdomIndex: index,
        );
        final prizePool = aup.aupForSubKingdomEvent(
          group: group,
          kingdomName: canonical,
          subKingdomIndex: index,
        );
        final payoutTable = PayoutTable.fromPercentages(
          prizePool,
          const <double>[0.60, 0.25, 0.15],
        );
        events[id] = <String, Object?>{
          'id': id,
          'group': group.name,
          'kingdom': canonical,
          'kind': 'fort',
          'subKingdomIndex': index,
          'maxPlayers': eventSpec.maxPlayers,
          'entryFee': aup.entryFeeForSubKingdomEvent(
            group: group,
            kingdomName: canonical,
            subKingdomIndex: index,
          ),
          'payouts': payoutTable.byRank,
          // Forts are independent entry choices. AUP affordability is the
          // only fort-level gate; clearing every fort still unlocks the Main
          // Event below.
          'predecessorId': null,
        };
      }

      final mainId = _mainId(group, canonical);
      final mainSpec = campaign.kingdomMainEventSpec(
        group: group,
        kingdomName: canonical,
      );
      final mainPrize = aup.aupForKingdomMainEvent(
        group: group,
        kingdomName: canonical,
      );
      events[mainId] = <String, Object>{
        'id': mainId,
        'group': group.name,
        'kingdom': canonical,
        'kind': 'main',
        'maxPlayers': mainSpec.maxPlayers,
        'entryFee': aup.entryFeeForKingdomMainEvent(
          group: group,
          kingdomName: canonical,
        ),
        'payouts': <int>[mainPrize],
        'requiredFortIds': fortIds,
      };
    }
  }

  final sorted = <String, Object>{
    for (final key in events.keys.toList()..sort()) key: events[key]!,
  };
  final content = <String, Object>{
    'schemaVersion': 1,
    'eventCount': sorted.length,
    'events': sorted,
  };
  final contentHash =
      sha256.convert(utf8.encode(jsonEncode(content))).toString();
  return <String, Object>{
    ...content,
    'contentHash': contentHash,
  };
}

void _writeCatalog(String destination, Map<String, Object> payload) {
  const encoder = JsonEncoder.withIndent('  ');
  File(destination).writeAsStringSync('${encoder.convert(payload)}\n');
  stdout.writeln(
    'Wrote ${payload['eventCount']} economy events to $destination',
  );
}

void _writeDartVersion(
  String destination, {
  required int schemaVersion,
  required int eventCount,
  required String contentHash,
}) {
  File(destination).writeAsStringSync('''
// Generated by tools/export_economy_catalog.dart. Do not edit by hand.
const int economyCatalogSchemaVersion = $schemaVersion;
const int economyCatalogEventCount = $eventCount;
const String economyCatalogContentHash =
    '$contentHash';
const String economyCatalogVersion =
    'v\$economyCatalogSchemaVersion:\$economyCatalogEventCount:\$economyCatalogContentHash';
''');
  stdout.writeln('Wrote economy catalog version to $destination');
}
