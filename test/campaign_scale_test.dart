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

  test('the campaign is five circuits of ten kingdoms', () {
    expect(kVenueGroups.length, 5);
    expect(totalKingdomCount(), 50);
    for (final group in kVenueGroups) {
      expect(
        venuesForGroup(group).length,
        10,
        reason: 'every circuit should carry ten kingdoms ($group)',
      );
    }
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
