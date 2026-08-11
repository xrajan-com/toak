import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  test(
    'campaign abandon finishes after dispose without leaking its committed entry',
    () async {
      final wallet = AuraPointsService();
      await wallet.init();

      final reserved = await wallet.reserveCampaignEntry(
        group: VenueGroup.international,
        kingdomName: 'Central Asia',
        isMainEvent: false,
        subKingdomIndex: 10,
        expectedEntryFee: 0,
      );
      expect(reserved.canEnter, isTrue);

      final committed = await wallet.commitEntry(reserved.reservation!);
      expect(committed.canEnter, isTrue);
      expect(wallet.activeCommittedEntries, hasLength(1));

      final settlement = wallet.finalizeCampaignAbandon(
        group: VenueGroup.international,
        kingdomName: 'Central Asia',
        isMainEvent: false,
        subKingdomIndex: 10,
        entryAttemptId: committed.reservation!.attemptId,
        totalPlayers: 6,
      );
      wallet.dispose();

      expect((await settlement).accepted, isTrue);

      final restoredWallet = AuraPointsService();
      await restoredWallet.init();
      expect(restoredWallet.activeCommittedEntries, isEmpty);
      restoredWallet.dispose();
    },
  );
}
