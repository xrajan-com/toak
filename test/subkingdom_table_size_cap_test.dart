import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomCountFor;
import 'package:ten_of_a_kind_poker/config/venues.dart'
    show VenueGroup, venuesForGroup;

void main() {
  test('Sub-kingdom table sizes stay onboarding-friendly', () {
    for (final group in VenueGroup.values) {
      final venues = venuesForGroup(group);
      for (final v in venues) {
        final rawName = v.name.trim();
        if (rawName.isEmpty) continue;
        final canonical = ce.canonicalKingdomName(
          group: group,
          kingdomName: rawName,
        );
        final int count =
            subKingdomCountFor(group: group, kingdomName: canonical);
        if (count <= 0) continue;

        int sixPlayerEvents = 0;
        int eightPlayerEvents = 0;
        for (int i = 1; i <= count; i++) {
          final spec = ce.subKingdomEventSpec(
            group: group,
            kingdomName: canonical,
            subKingdomIndex: i,
          );
          switch (spec.maxPlayers) {
            case 8:
              eightPlayerEvents += 1;
              break;
            case 6:
              sixPlayerEvents += 1;
              break;
            default:
              fail(
                'Unexpected maxPlayers=${spec.maxPlayers} for ${group.name}/$canonical sub=$i',
              );
          }
        }

        final freeIndex = ce.freeSubKingdomIndexFor(
          group: group,
          kingdomName: canonical,
        );
        final freeSpec = ce.subKingdomEventSpec(
          group: group,
          kingdomName: canonical,
          subKingdomIndex: freeIndex,
        );
        expect(
          freeSpec.maxPlayers,
          6,
          reason:
              'Expected the free sub-kingdom to stay 6-player for ${group.name}/$canonical.',
        );

        if (count > 0) {
          expect(
            sixPlayerEvents,
            greaterThan(eightPlayerEvents),
            reason:
                'Expected 6-player tables to outnumber 8-player tables for ${group.name}/$canonical. Got 6p=$sixPlayerEvents 8p=$eightPlayerEvents.',
          );
        }
      }
    }
  });
}
