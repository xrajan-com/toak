import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomCountFor;
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/venues.dart'
    show VenueGroup, VenueTheme, kVenueGroups, venuesForGroup;
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;

void main() {
  test('AUP economy tops out at 100 Aura across four circuits', () {
    expect(aup.kAupPerAura, 10000000);
    expect(aup.kAupPerCircuit, 250000000);
    expect(aup.kAupMaxTotal, 1000000000);
    expect(aup.kAupMaxAuraPerCircuit, 25);
    expect(aup.kAupMaxAuraTotal, 100);
    expect(aup.auraValueFromAup(aup.kAupMaxTotal), 100);
    expect(aup.auraValueFromAup(aup.kAupPerCircuit), 25);
  });

  test('Circuit kingdom totals sum to 250,000,000 AUP', () {
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
