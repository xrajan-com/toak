import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/venues.dart' show VenueGroup;
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;

/// The entry sheet shows the player what the server will charge and pay.
/// This holds the app to the backend catalog, event by event.
void main() {
  test('every entry fee, payout and table size matches the backend catalog',
      () {
    final Map<String, dynamic> catalog = jsonDecode(
      File('backend/src/economy/catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final Map<String, dynamic> events =
        catalog['events'] as Map<String, dynamic>;
    expect(events, hasLength(catalog['eventCount']));

    for (final MapEntry<String, dynamic> entry in events.entries) {
      final Map<String, dynamic> event = entry.value as Map<String, dynamic>;
      final VenueGroup group = VenueGroup.values.byName(event['group']);
      final String kingdom = event['kingdom'] as String;
      final bool isTitle = event['kind'] == 'main';
      final int? index = event['subKingdomIndex'] as int?;

      final int fee = isTitle
          ? aup.entryFeeForKingdomMainEvent(group: group, kingdomName: kingdom)
          : aup.entryFeeForSubKingdomEvent(
              group: group,
              kingdomName: kingdom,
              subKingdomIndex: index!,
            );
      final List<int> payouts = isTitle
          ? aup.payoutsForKingdomMainEvent(group: group, kingdomName: kingdom)
          : aup.payoutsForSubKingdomEvent(
              group: group,
              kingdomName: kingdom,
              subKingdomIndex: index!,
            );
      final int seats = isTitle
          ? ce.kingdomMainEventSpec(group: group, kingdomName: kingdom)
              .maxPlayers
          : ce
              .subKingdomEventSpec(
                group: group,
                kingdomName: kingdom,
                subKingdomIndex: index!,
              )
              .maxPlayers;

      expect(fee, event['entryFee'], reason: '${entry.key} entry fee');
      expect(payouts, List<int>.from(event['payouts'] as List),
          reason: '${entry.key} payouts');
      expect(seats, event['maxPlayers'], reason: '${entry.key} seats');
    }
  });
}
