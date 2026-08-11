import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('account deletion purges every per-user device cache', () async {
    const uid = 'deleted-user-123';
    final encodedUid = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    final encodedGuest =
        base64Url.encode(utf8.encode('guest')).replaceAll('=', '');
    final deletedKeys = <String>[
      'profile.avatar.$uid',
      'profile.name.$uid',
      'profile.email.$uid',
      'profile.about.$uid',
      'profile.kingdom.$uid',
      'profile.complete.$uid',
      'aup.wallet_v3.$encodedUid',
      'campaign.pending_outbox_v2.$encodedUid',
      'campaign.pending_cleared_v1.$encodedUid',
      'campaign.pending_main_events_v1.$encodedUid',
      'campaign.authoritative_cache_v1.$encodedUid',
      'aup.legacy_wallet_owner_v3',
      'aup.india',
      'aup.international',
      'aup.awarded_events',
      'aup.pending_campaign_wins_v1',
    ];
    final initialValues = <String, Object>{
      for (final key in deletedKeys) key: '',
    }..addAll(<String, Object>{
        'profile.complete.$uid': true,
        'aup.legacy_wallet_owner_v3': uid,
        'aup.india': 1234,
        'aup.international': 5678,
        'aup.awarded_events': <String>['win:1'],
        'aup.pending_campaign_wins_v1': '[]',
        'settings.sound': true,
        'aup.wallet_v3.$encodedGuest': '{"indiaAup":99}',
      });
    SharedPreferences.setMockInitialValues(initialValues);

    final profile = ProfileService();
    final wallet = AuraPointsService();
    final campaign = CampaignProgressService();
    await Future.wait<void>(<Future<void>>[
      profile.purgeLocalDataForUser(uid),
      wallet.purgeLocalDataForUser(uid),
      campaign.purgeLocalDataForUser(uid),
    ]);

    final prefs = await SharedPreferences.getInstance();
    for (final key in deletedKeys) {
      expect(prefs.containsKey(key), isFalse, reason: key);
    }
    expect(prefs.getBool('settings.sound'), isTrue);
    expect(prefs.getString('aup.wallet_v3.$encodedGuest'), '{"indiaAup":99}');

    await profile.setLocalAvatarBytes(
      Uint8List.fromList(<int>[1, 2, 3]),
      uidOverride: uid,
    );
    expect(prefs.containsKey('profile.avatar.$uid'), isFalse);

    profile.dispose();
    wallet.dispose();
    campaign.dispose();
  });

  test('anonymous account deletion resets but does not disable guest storage',
      () async {
    final encodedGuest =
        base64Url.encode(utf8.encode('guest')).replaceAll('=', '');
    final guestKey = 'aup.wallet_v3.$encodedGuest';
    SharedPreferences.setMockInitialValues(<String, Object>{
      guestKey: jsonEncode(<String, Object>{
        'walletStorageVersion': 3,
        'indiaAup': 99,
      }),
    });

    final wallet = AuraPointsService();
    await wallet.init();
    expect(wallet.indiaAup, 99);

    await wallet.purgeLocalDataForUser(
      'anonymous-firebase-uid',
      includeGuestWallet: true,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(wallet.totalAup, 0);
    expect(prefs.containsKey(guestKey), isFalse);

    expect(
      await wallet.awardRewardedAdBonus(
        group: VenueGroup.india,
        amount: 1,
      ),
      1,
    );
    expect(prefs.containsKey(guestKey), isTrue);
    wallet.dispose();
  });
}
