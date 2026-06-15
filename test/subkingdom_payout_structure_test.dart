import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomCountFor;
import 'package:ten_of_a_kind_poker/config/venues.dart'
    show VenueGroup, VenueTheme, kVenueGroups, venuesForGroup;
import 'package:ten_of_a_kind_poker/game/models.dart' show PayoutTable;

void main() {
  test('Sub-kingdom events always pay top 3 on a 60/25/15 split', () {
    void checkGroup(VenueGroup group, List<VenueTheme> venues) {
      for (final venue in venues) {
        final int count =
            subKingdomCountFor(group: group, kingdomName: venue.name);
        for (int i = 1; i <= count; i++) {
          final spec = ce.subKingdomEventSpec(
            group: group,
            kingdomName: venue.name,
            subKingdomIndex: i,
          );
          final expected = PayoutTable.fromPercentages(
            spec.prizePool,
            const <double>[0.60, 0.25, 0.15],
          );
          expect(spec.placesPaid, 3,
              reason: 'Unexpected paid places for $group:${venue.name}:$i');
          expect(spec.payoutTable.byRank, expected.byRank,
              reason: 'Unexpected payout split for $group:${venue.name}:$i');
        }
      }
    }

    for (final group in kVenueGroups) {
      checkGroup(group, venuesForGroup(group));
    }
  });

  test('Main events remain winner-take-all', () {
    void checkGroup(VenueGroup group, List<VenueTheme> venues) {
      for (final venue in venues) {
        final spec = ce.kingdomMainEventSpec(
          group: group,
          kingdomName: venue.name,
        );
        expect(spec.placesPaid, 1,
            reason:
                'Main event should pay only first for $group:${venue.name}');
        expect(spec.payoutTable.byRank, <int>[spec.prizePool],
            reason:
                'Main event payout table should stay winner-take-all for $group:${venue.name}');
      }
    }

    for (final group in kVenueGroups) {
      checkGroup(group, venuesForGroup(group));
    }
  });
}
