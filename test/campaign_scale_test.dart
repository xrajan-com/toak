import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  test('the campaign is five circuits of fifty kingdoms', () {
    expect(kVenueGroups.length, 5);
    expect(totalKingdomCount(), 50);

    // The circuits are drawn by geography, not by a fixed quota, so the
    // counts differ. They are pinned here because each circuit pays the
    // same 20 Aura: a circuit that quietly gains or loses kingdoms changes
    // what every fort in it is worth.
    const expected = <VenueGroup, int>{
      VenueGroup.india: 10,
      VenueGroup.euro: 11,
      VenueGroup.oceania: 10,
      VenueGroup.northAmerica: 10,
      VenueGroup.international: 9,
    };
    for (final group in kVenueGroups) {
      expect(
        venuesForGroup(group).length,
        expected[group],
        reason: 'kingdom count changed for $group',
      );
    }
  });

  test('circuits are ordered and named as the world map reads', () {
    expect(kVenueGroups, const <VenueGroup>[
      VenueGroup.india,
      VenueGroup.euro,
      VenueGroup.oceania,
      VenueGroup.northAmerica,
      VenueGroup.international,
    ]);
    expect(kVenueGroups.map(venueGroupLabel), <String>[
      'Indian Ocean',
      'Eurasia',
      'Australasia',
      'Americas',
      'Rest of the World',
    ]);
  });

  test('every kingdom sits in exactly one circuit', () {
    final seen = <String, VenueGroup>{};
    for (final group in kVenueGroups) {
      for (final venue in venuesForGroup(group)) {
        expect(
          seen.containsKey(venue.name),
          isFalse,
          reason: '${venue.name} is in both ${seen[venue.name]} and $group',
        );
        seen[venue.name] = group;
      }
    }
    expect(seen.length, 50);
  });

  test('the campaign holds 500 forts', () {
    expect(
      totalSubKingdomCount(),
      500,
      reason: 'The home screen challenges players to clear every fort and '
          'the store copy quotes this number. If forts were deliberately '
          'added or removed, update this expectation and the marketing copy '
          'together.',
    );
  });

  test('circuit fort counts sum to the global total', () {
    final int sum = kVenueGroups.fold<int>(
      0,
      (total, group) => total + subKingdomCountForGroup(group),
    );
    expect(sum, totalSubKingdomCount());
  });

  test('every kingdom has at least one fort to clear', () {
    for (final group in kVenueGroups) {
      for (final venue in venuesForGroup(group)) {
        expect(
          subKingdomCountFor(group: group, kingdomName: venue.name),
          greaterThan(0),
          reason: '${venue.name} ($group) has no forts',
        );
      }
    }
  });

  test('conquest totals aggregate across every circuit', () async {
    const group = VenueGroup.india;
    const kingdom = 'Hyderabad';
    final int forts = subKingdomCountFor(group: group, kingdomName: kingdom);

    final progress = CampaignProgressService();
    expect(progress.totalClearedCount(), 0);
    expect(progress.totalTitlesEarned(), 0);

    for (int index = 1; index <= forts; index++) {
      await progress.markCleared(
        group: group,
        kingdomName: kingdom,
        subKingdomIndex: index,
      );
    }

    expect(progress.totalClearedCount(), forts);
    expect(
      progress.totalTitlesEarned(),
      0,
      reason: 'a title also needs the kingdom main event',
    );

    await progress.markMainEventCleared(group: group, kingdomName: kingdom);
    expect(progress.totalTitlesEarned(), 1);

    progress.dispose();
  });
}
