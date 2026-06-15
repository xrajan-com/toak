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
    expect(service.indiaAup, 500);
    expect(service.internationalAup, 2500);
    expect(service.euroAup, 2500);
    expect(service.oceaniaAup, 2500);
  });

  test('anonymous users do not receive starter AUP', () async {
    final service = AuraPointsService();

    service.bindUserId(null);
    await service.init();

    expect(service.totalAup, 0);
  });
}
