import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/economy_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  test('pending fort clears and a title survive service restart', () async {
    const group = VenueGroup.india;
    const kingdom = 'Hyderabad';
    const uid = 'campaign-restart-user';
    final fortCount = subKingdomCountFor(group: group, kingdomName: kingdom);

    final first = CampaignProgressService();
    first.bindUserId(uid);
    await _waitUntil(() => first.isHydrated);

    for (int index = 1; index <= fortCount; index++) {
      await first.markCleared(
        group: group,
        kingdomName: kingdom,
        subKingdomIndex: index,
      );
    }
    await first.markMainEventCleared(
      group: group,
      kingdomName: kingdom,
    );
    expect(first.hasTitle(group: group, kingdomName: kingdom), isTrue);

    final reloaded = CampaignProgressService();
    reloaded.bindUserId(uid);
    await _waitUntil(() => reloaded.isHydrated);

    expect(
      reloaded.clearedCount(group: group, kingdomName: kingdom),
      fortCount,
    );
    expect(reloaded.hasTitle(group: group, kingdomName: kingdom), isTrue);
  });

  test('pending campaign progress remains isolated by user id', () async {
    const group = VenueGroup.india;
    const kingdom = 'Hyderabad';
    final first = CampaignProgressService();
    first.bindUserId('campaign-user-a');
    await _waitUntil(() => first.isHydrated);
    await first.markCleared(
      group: group,
      kingdomName: kingdom,
      subKingdomIndex: 1,
    );

    final switched = CampaignProgressService();
    switched.bindUserId('campaign-user-a');
    switched.bindUserId('campaign-user-b');
    await _waitUntil(() => switched.isHydrated);

    expect(
      switched.isCleared(
        group: group,
        kingdomName: kingdom,
        subKingdomIndex: 1,
      ),
      isFalse,
    );
  });

  test('a stale upload acknowledgement preserves newer pending clears',
      () async {
    const group = VenueGroup.india;
    const kingdom = 'Hyderabad';
    const uid = 'campaign-switch-race-user';
    final service = CampaignProgressService();
    service.bindUserId(uid);
    await _waitUntil(() => service.isHydrated);

    await service.markCleared(
      group: group,
      kingdomName: kingdom,
      subKingdomIndex: 1,
    );
    final firstId = service.subKingdomId(
      group: group,
      kingdomName: kingdom,
      subKingdomIndex: 1,
    );
    await service.markCleared(
      group: group,
      kingdomName: kingdom,
      subKingdomIndex: 2,
    );

    service.bindUserId('campaign-switch-race-user-b');
    await service.acknowledgePendingForTesting(
      uid: uid,
      cleared: <String>[firstId],
    );

    final reloaded = CampaignProgressService();
    reloaded.bindUserId(uid);
    await _waitUntil(() => reloaded.isHydrated);

    expect(
      reloaded.isCleared(
        group: group,
        kingdomName: kingdom,
        subKingdomIndex: 2,
      ),
      isTrue,
      reason: 'Acknowledging fort 1 must not erase the newer fort 2 outbox row',
    );
  });

  test('authoritative settlement snapshot does not enqueue a second clear',
      () async {
    const String uid = 'authoritative-settlement-user';
    const EconomyProgressSnapshot settlementSnapshot = EconomyProgressSnapshot(
      indiaAup: 2500,
      internationalAup: 0,
      awardedEventIds: <String>[],
      cleared: <String>['sk:india:hyderabad:1'],
      lastActiveAtMs: 0,
      prevActiveAtMs: 0,
      lastActiveDayKey: '',
      activityScore: 0,
      abandonedGames: 0,
      matchesPlayed: 1,
      finishPermilleSum: 1000,
      registeredStarterGranted: true,
    );
    final api = _AuthoritativeEconomyApi(settlementSnapshot);
    final service = CampaignProgressService(economyApi: api);
    service.bindUserId(uid);
    await _waitUntil(() => service.isHydrated);

    await service.applyAuthoritativeSnapshot(settlementSnapshot);

    expect(
      service.isCleared(
        group: VenueGroup.india,
        kingdomName: 'Hyderabad',
        subKingdomIndex: 1,
      ),
      isTrue,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((key) => key.startsWith('campaign.pending_')),
      isEmpty,
      reason:
          'an accepted authoritative result must not create a redundant clear outbox row',
    );
  });

  test('offline authoritative cache survives restart and stays user-isolated',
      () async {
    const snapshot = EconomyProgressSnapshot(
      indiaAup: 2500,
      internationalAup: 2500,
      awardedEventIds: <String>[],
      cleared: <String>['sk:india:hyderabad:1'],
      mainEventsCleared: <String>['me:india:hyderabad'],
      lastActiveAtMs: 0,
      prevActiveAtMs: 0,
      lastActiveDayKey: '',
      activityScore: 0,
      abandonedGames: 0,
      matchesPlayed: 1,
      finishPermilleSum: 0,
      registeredStarterGranted: true,
    );
    final api = _OfflineCapableEconomyApi(snapshot);
    final online = CampaignProgressService(economyApi: api);
    online.bindUserId('authority-cache-user-a');
    await _waitUntil(() => online.isHydrated);

    api.online = false;
    final restarted = CampaignProgressService(economyApi: api);
    restarted.bindUserId('authority-cache-user-a');
    await _waitUntil(() => restarted.isHydrated);
    expect(restarted.isAuthorityUnavailable, isTrue);
    expect(
      restarted.isCleared(
        group: VenueGroup.india,
        kingdomName: 'Hyderabad',
        subKingdomIndex: 1,
      ),
      isTrue,
    );
    expect(
      restarted.isMainEventCleared(
        group: VenueGroup.india,
        kingdomName: 'Hyderabad',
      ),
      isTrue,
    );

    final otherUser = CampaignProgressService(economyApi: api);
    otherUser.bindUserId('authority-cache-user-b');
    await _waitUntil(() => otherUser.isHydrated);
    expect(otherUser.isAuthorityUnavailable, isTrue);
    expect(
      otherUser.isCleared(
        group: VenueGroup.india,
        kingdomName: 'Hyderabad',
        subKingdomIndex: 1,
      ),
      isFalse,
    );
  });
}

class _AuthoritativeEconomyApi extends EconomyApiService {
  _AuthoritativeEconomyApi(this.snapshot);

  final EconomyProgressSnapshot snapshot;

  @override
  bool get isConfigured => true;

  @override
  Future<EconomyProgressSnapshot?> wallet() async => snapshot;
}

class _OfflineCapableEconomyApi extends EconomyApiService {
  _OfflineCapableEconomyApi(this.snapshot);

  final EconomyProgressSnapshot snapshot;
  bool online = true;

  @override
  bool get isConfigured => true;

  @override
  Future<EconomyProgressSnapshot?> wallet() async {
    if (!online) throw StateError('offline');
    return snapshot;
  }
}

Future<void> _waitUntil(bool Function() predicate) async {
  for (int attempt = 0; attempt < 200; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  throw StateError('Condition did not become true in time.');
}
