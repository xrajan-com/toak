import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomCountFor;
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/venues.dart'
    show VenueGroup, VenueTheme, kVenueGroups, venuesForGroup;
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/game/models.dart' show PayoutTable;

void main() {
  test('AUP economy tops out at 100 Aura across five circuits', () {
    expect(aup.kAupPerAura, 10000000);
    expect(aup.kAupPerCircuit, 200000000);
    expect(aup.kAupMaxTotal, 1000000000);
    expect(aup.kAupMaxAuraPerCircuit, 20);
    expect(aup.kAupMaxAuraTotal, 100);
    expect(aup.auraValueFromAup(aup.kAupMaxTotal), 100);
    expect(aup.auraValueFromAup(aup.kAupPerCircuit), 20);
  });

  test('Circuit kingdom totals sum to 200,000,000 AUP', () {
    for (final group in kVenueGroups) {
      final sum = venuesForGroup(group).fold<int>(
        0,
        (sum, v) =>
            sum + aup.aupForKingdomTotal(group: group, kingdomName: v.name),
      );
      expect(sum, aup.kAupPerCircuit, reason: 'Mismatch for $group');
    }
  });

  test('All circuit kingdom totals sum to 1,000,000,000 AUP', () {
    final total = kVenueGroups.fold<int>(
      0,
      (sum, group) =>
          sum +
          venuesForGroup(group).fold<int>(
            0,
            (groupSum, v) =>
                groupSum +
                aup.aupForKingdomTotal(group: group, kingdomName: v.name),
          ),
    );
    expect(total, aup.kAupMaxTotal);
  });

  test('Kingdom totals are unique within each circuit', () {
    for (final group in kVenueGroups) {
      final totals = <int>[
        for (final v in venuesForGroup(group))
          aup.aupForKingdomTotal(group: group, kingdomName: v.name),
      ];
      expect(totals.toSet().length, totals.length, reason: '$group');
    }
  });

  test('Main + sub-kingdom event rewards equal kingdom total', () {
    void checkGroup(VenueGroup group, List<VenueTheme> venues) {
      for (final v in venues) {
        final name = v.name;
        final total = aup.aupForKingdomTotal(group: group, kingdomName: name);
        final main =
            aup.aupForKingdomMainEvent(group: group, kingdomName: name);
        final count = subKingdomCountFor(group: group, kingdomName: name);
        int subSum = 0;
        for (int i = 1; i <= count; i++) {
          subSum += aup.aupForSubKingdomEvent(
            group: group,
            kingdomName: name,
            subKingdomIndex: i,
          );
        }
        expect(main + subSum, total, reason: 'Mismatch for $group:$name');
      }
    }

    for (final group in kVenueGroups) {
      checkGroup(group, venuesForGroup(group));
    }
  });

  test('Kingdom rewards are rounded to thousands', () {
    void checkGroup(VenueGroup group, List<VenueTheme> venues) {
      for (final v in venues) {
        final name = v.name;
        final total = aup.aupForKingdomTotal(group: group, kingdomName: name);
        final main =
            aup.aupForKingdomMainEvent(group: group, kingdomName: name);
        expect(total % aup.kAupRewardUnit, 0,
            reason: 'Total not rounded for $group:$name');
        expect(main % aup.kAupRewardUnit, 0,
            reason: 'Main not rounded for $group:$name');

        final count = subKingdomCountFor(group: group, kingdomName: name);
        for (int i = 1; i <= count; i++) {
          final sub = aup.aupForSubKingdomEvent(
            group: group,
            kingdomName: name,
            subKingdomIndex: i,
          );
          expect(
            sub % aup.kAupRewardUnit,
            0,
            reason: 'Sub reward not rounded for $group:$name:$i',
          );
        }
      }
    }

    for (final group in kVenueGroups) {
      checkGroup(group, venuesForGroup(group));
    }
  });

  test('Entry fees are <= prizes and rounded to thousands', () {
    void checkGroup(VenueGroup group, List<VenueTheme> venues) {
      for (final v in venues) {
        final name = v.name;

        final mainPrize =
            aup.aupForKingdomMainEvent(group: group, kingdomName: name);
        final mainFee =
            aup.entryFeeForKingdomMainEvent(group: group, kingdomName: name);
        expect(mainFee >= 0, true);
        expect(mainFee <= mainPrize, true,
            reason: 'Main fee > prize for $group:$name');
        expect(mainFee % aup.kAupEntryFeeUnit, 0,
            reason: 'Main fee not rounded for $group:$name');

        final count = subKingdomCountFor(group: group, kingdomName: name);
        for (int i = 1; i <= count; i++) {
          final subPrize = aup.aupForSubKingdomEvent(
            group: group,
            kingdomName: name,
            subKingdomIndex: i,
          );
          final subFee = aup.entryFeeForSubKingdomEvent(
            group: group,
            kingdomName: name,
            subKingdomIndex: i,
          );
          expect(subFee >= 0, true);
          expect(
            subFee <= subPrize,
            true,
            reason: 'Sub fee > prize for $group:$name:$i',
          );
          expect(
            subFee % aup.kAupEntryFeeUnit,
            0,
            reason: 'Sub fee not rounded for $group:$name:$i',
          );
        }

        final freeIndex =
            ce.freeSubKingdomIndexFor(group: group, kingdomName: name);
        expect(
          aup.entryFeeForSubKingdomEvent(
            group: group,
            kingdomName: name,
            subKingdomIndex: freeIndex,
          ),
          0,
          reason:
              'Free sub-kingdom should be free for $group:$name (freeIndex=$freeIndex).',
        );
      }
    }

    for (final group in kVenueGroups) {
      checkGroup(group, venuesForGroup(group));
    }
  });

  test('Every legitimate single campaign reward fits the backend event limit',
      () {
    const backendCampaignWinLimit = 25000000;
    for (final group in kVenueGroups) {
      for (final venue in venuesForGroup(group)) {
        expect(
          aup.aupForKingdomMainEvent(
            group: group,
            kingdomName: venue.name,
          ),
          lessThanOrEqualTo(backendCampaignWinLimit),
          reason: 'Main-event reward exceeds backend limit: '
              '${group.name}:${venue.name}',
        );

        final count = subKingdomCountFor(
          group: group,
          kingdomName: venue.name,
        );
        for (int i = 1; i <= count; i++) {
          expect(
            aup.aupForSubKingdomEvent(
              group: group,
              kingdomName: venue.name,
              subKingdomIndex: i,
            ),
            lessThanOrEqualTo(backendCampaignWinLimit),
            reason: 'Fort reward exceeds backend limit: '
                '${group.name}:${venue.name}:$i',
          );
        }
      }
    }
  });

  test('Every free fort prize is below 200% of its kingdom average entry fee',
      () {
    const expectedRebalancedFreePrizes = <String, int>{
      'india:Hyderabad': 369000,
      'india:Jaipur': 247000,
    };
    for (final group in kVenueGroups) {
      for (final venue in venuesForGroup(group)) {
        final freeIndex = ce.freeSubKingdomIndexFor(
          group: group,
          kingdomName: venue.name,
        );
        final freePool = aup.aupForSubKingdomEvent(
          group: group,
          kingdomName: venue.name,
          subKingdomIndex: freeIndex,
        );
        final fortCount = subKingdomCountFor(
          group: group,
          kingdomName: venue.name,
        );
        final totalEntryFees = <int>[
          for (int index = 1; index <= fortCount; index++)
            aup.entryFeeForSubKingdomEvent(
              group: group,
              kingdomName: venue.name,
              subKingdomIndex: index,
            ),
        ].fold<int>(0, (sum, fee) => sum + fee);

        expect(
          freePool * fortCount,
          lessThan(2 * totalEntryFees),
          reason: '${group.name}:${venue.name}',
        );
        final expected =
            expectedRebalancedFreePrizes['${group.name}:${venue.name}'];
        if (expected != null) {
          expect(freePool, expected, reason: '${group.name}:${venue.name}');
        }
      }
    }
  });

  test('Quick Game venue fees are varied and two ads can cover each entry', () {
    final fees = <int>[
      for (final group in kVenueGroups)
        for (final v in venuesForGroup(group))
          aup.entryFeeForQuickGameVenue(
            group: group,
            venueName: v.name,
          ),
    ];

    expect(fees.toSet().length, greaterThan(1));
    for (final fee in fees) {
      expect(fee, greaterThan(0));
      expect(fee % aup.kAupEntryFeeUnit, 0);
      expect(fee, lessThanOrEqualTo(aup.kRewardedAdAupBonus * 2));
    }
  });
}
