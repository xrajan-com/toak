import 'package:flutter_test/flutter_test.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart'
    show subKingdomCountFor;
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/venues.dart'
    show VenueGroup, VenueTheme, indianVenues, internationalVenues;
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;

void main() {
  test('Sikh Empire and N. America are fixed at 10,000,000 AUP', () {
    expect(
      aup.aupForKingdomTotal(
          group: VenueGroup.india, kingdomName: 'Sikh Empire'),
      10000000,
    );
    expect(
      aup.aupForKingdomTotal(
        group: VenueGroup.international,
        kingdomName: 'N. America',
      ),
      10000000,
    );
    expect(
      aup.aupForKingdomTotal(
        group: VenueGroup.international,
        kingdomName: 'USA',
      ),
      10000000,
    );
  });

  test('Circuit kingdom totals sum to 50,000,000 AUP', () {
    final indiaSum = indianVenues.fold<int>(
      0,
      (sum, v) =>
          sum +
          aup.aupForKingdomTotal(group: VenueGroup.india, kingdomName: v.name),
    );
    expect(indiaSum, aup.kAupPerCircuit);

    final intlSum = internationalVenues.fold<int>(
      0,
      (sum, v) =>
          sum +
          aup.aupForKingdomTotal(
            group: VenueGroup.international,
            kingdomName: v.name,
          ),
    );
    expect(intlSum, aup.kAupPerCircuit);
  });

  test('Kingdom totals are unique within each circuit', () {
    final indiaTotals = <int>[
      for (final v in indianVenues)
        aup.aupForKingdomTotal(group: VenueGroup.india, kingdomName: v.name),
    ];
    expect(indiaTotals.toSet().length, indiaTotals.length);

    final intlTotals = <int>[
      for (final v in internationalVenues)
        aup.aupForKingdomTotal(
          group: VenueGroup.international,
          kingdomName: v.name,
        ),
    ];
    expect(intlTotals.toSet().length, intlTotals.length);
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

    checkGroup(VenueGroup.india, indianVenues);
    checkGroup(VenueGroup.international, internationalVenues);
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

    checkGroup(VenueGroup.india, indianVenues);
    checkGroup(VenueGroup.international, internationalVenues);
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

    checkGroup(VenueGroup.india, indianVenues);
    checkGroup(VenueGroup.international, internationalVenues);
  });

  test('Quick Game venue fees are varied and two ads can cover each entry', () {
    final fees = <int>[
      for (final v in indianVenues)
        aup.entryFeeForQuickGameVenue(
          group: VenueGroup.india,
          venueName: v.name,
        ),
      for (final v in internationalVenues)
        aup.entryFeeForQuickGameVenue(
          group: VenueGroup.international,
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
