import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=');
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  test('registered users receive one 10,000 AUP starter wallet', () async {
    final service = AuraPointsService();

    service.bindUserId('registered-user', registeredUser: true);
    final paid = await service.payEntryFee(
      group: VenueGroup.india,
      amount: 2000,
    );

    expect(paid, isTrue);
    expect(service.totalAup, aup.kRegisteredStarterAup - 2000);
    expect(service.indiaAup, 0);
    expect(service.internationalAup, 2000);
    expect(service.euroAup, 2000);
    expect(service.oceaniaAup, 2000);
    expect(service.northAmericaAup, 2000);
  });

  test('anonymous users do not receive starter AUP', () async {
    final service = AuraPointsService();

    service.bindUserId(null);
    await service.init();

    expect(service.totalAup, 0);
  });

  test('legacy 25-Aura circuit overflow migrates into the US Circuit',
      () async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'aup.india': 250000000,
      'aup.international': 250000000,
      'aup.euro': 250000000,
      'aup.oceania': 250000000,
      'aup.registered_starter_granted': true,
    });
    final service = AuraPointsService();

    service.bindUserId(null);
    await service.init();

    expect(service.indiaAup, 200000000);
    expect(service.internationalAup, 200000000);
    expect(service.euroAup, 200000000);
    expect(service.oceaniaAup, 200000000);
    expect(service.northAmericaAup, 200000000);
    expect(service.totalAup, 1000000000);
  });

  test('campaign wins credit the actual fort payout', () async {
    final service = AuraPointsService();

    service.bindUserId(null);
    final credited = await service.awardForCampaignWin(
      group: VenueGroup.international,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      rewardAup: 12000,
    );

    expect(credited, 12000);
    expect(service.internationalAup, 12000);
    expect(service.totalAup, 12000);
  });

  test('replaying a grindable fort credits each tournament win', () async {
    final service = AuraPointsService();

    service.bindUserId(null);
    final firstCredit = await service.awardForCampaignWin(
      group: VenueGroup.international,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      rewardAup: 12000,
    );
    final replayCredit = await service.awardForCampaignWin(
      group: VenueGroup.international,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      rewardAup: 12000,
    );

    expect(firstCredit, 12000);
    expect(replayCredit, 12000);
    expect(service.internationalAup, 24000);
  });

  test('fort replay rewards have no play-count limit', () async {
    final service = AuraPointsService();

    service.bindUserId(null);
    for (int replay = 0; replay < 550; replay++) {
      expect(
        await service.awardForCampaignWin(
          group: VenueGroup.international,
          kingdomName: 'Central Asia',
          isMainEvent: false,
          subKingdomIndex: 10,
          rewardAup: 1,
        ),
        1,
        reason: 'Replay ${replay + 1} should still earn AUP',
      );
    }

    expect(service.internationalAup, 550);
  });
}
