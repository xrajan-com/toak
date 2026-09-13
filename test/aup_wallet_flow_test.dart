import 'dart:async';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/.env.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/game/models.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';
import 'package:ten_of_a_kind_poker/services/campaign_progress_service.dart';
import 'package:ten_of_a_kind_poker/services/economy_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=');
    SharedPreferences.setMockInitialValues(const <String, Object>{});
  });

  test('production progression and affordability bypasses are disabled', () {
    expect(Env.debugMode, isFalse);
    expect(Env.unlockMainEvents, isFalse);
  });

  test('fort win funds the circuit wallet and a paid fort deducts its fee',
      () async {
    final candidate = _coveringFreeFort();
    final wallet = AuraPointsService();
    final progress = CampaignProgressService();

    final credited = await wallet.awardForCampaignWin(
      group: candidate.group,
      kingdomName: candidate.kingdomName,
      isMainEvent: false,
      subKingdomIndex: candidate.freeIndex,
      rewardAup: candidate.firstPrize,
    );
    progress.markCleared(
      group: candidate.group,
      kingdomName: candidate.kingdomName,
      subKingdomIndex: candidate.freeIndex,
    );

    expect(credited, candidate.firstPrize);
    expect(wallet.aupForGroup(candidate.group), candidate.firstPrize);
    expect(
      progress.isUnlocked(
        group: candidate.group,
        kingdomName: candidate.kingdomName,
        subKingdomIndex: candidate.nextIndex,
      ),
      isTrue,
    );

    final paid = await wallet.payEntryFee(
      group: candidate.group,
      amount: candidate.nextEntryFee,
    );

    expect(paid, isTrue);
    expect(
      wallet.aupForGroup(candidate.group),
      candidate.firstPrize - candidate.nextEntryFee,
    );

    final reloadedWallet = AuraPointsService();
    await reloadedWallet.init();
    expect(
      reloadedWallet.aupForGroup(candidate.group),
      candidate.firstPrize - candidate.nextEntryFee,
    );
  });

  test('an unaffordable paid fort is rejected without changing the wallet',
      () async {
    final wallet = AuraPointsService();
    await wallet.init();
    final entryFee = aup.entryFeeForSubKingdomEvent(
      group: VenueGroup.india,
      kingdomName: 'Baroda',
      subKingdomIndex: 1,
    );
    expect(entryFee, greaterThan(0));

    final paid = await wallet.payEntryFee(
      group: VenueGroup.india,
      amount: entryFee,
    );

    expect(paid, isFalse);
    expect(wallet.indiaAup, 0);
    expect(wallet.totalAup, 0);
  });

  test('rapid duplicate entry requests permit only one reservation', () async {
    final wallet = AuraPointsService();
    final first = wallet.reserveCampaignEntry(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      expectedEntryFee: 0,
    );
    final duplicate = await wallet.reserveCampaignEntry(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      expectedEntryFee: 0,
    );

    expect(duplicate.status, EntryPaymentStatus.walletLoading);
    expect((await first).canEnter, isTrue);
  });

  test('a win cannot pay an entry fee from a different circuit', () async {
    final wallet = AuraPointsService();
    const reward = 12000;
    await wallet.awardForCampaignWin(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      rewardAup: reward,
    );

    final paid = await wallet.payEntryFee(
      group: VenueGroup.india,
      amount: 1000,
    );

    expect(paid, isFalse);
    expect(wallet.euroAup, reward);
    expect(wallet.indiaAup, 0);
  });

  test('an exact circuit balance pays the fee and reaches zero', () async {
    final wallet = AuraPointsService();
    const balance = 12000;
    await wallet.awardForCampaignWin(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      rewardAup: balance,
    );

    expect(
      await wallet.payEntryFee(
        group: VenueGroup.euro,
        amount: balance,
      ),
      isTrue,
    );
    expect(wallet.euroAup, 0);
  });

  test('a registered win waits for wallet hydration before applying', () async {
    final economyApi = _DelayedWalletEconomyApi();
    final wallet = AuraPointsService(economyApi: economyApi);
    wallet.bindUserId('registered-player', registeredUser: true);
    await economyApi.walletRequested.future;

    final creditFuture = () async {
      final reserved = await wallet.reserveCampaignEntry(
        group: VenueGroup.euro,
        kingdomName: 'Central Asia',
        isMainEvent: false,
        subKingdomIndex: 10,
        expectedEntryFee: 0,
      );
      expect(reserved.canEnter, isTrue);
      final committed = await wallet.commitEntry(reserved.reservation!);
      expect(committed.canEnter, isTrue);
      return wallet.awardForCampaignWin(
        group: VenueGroup.euro,
        kingdomName: 'Central Asia',
        isMainEvent: false,
        subKingdomIndex: 10,
        rewardAup: _eurasiaFreeFortFirstPrize(),
      );
    }();
    await Future<void>.delayed(Duration.zero);
    economyApi.completeWalletHydration();

    expect(await creditFuture, _eurasiaFreeFortFirstPrize());
    await Future<void>.delayed(Duration.zero);
    expect(wallet.euroAup, _eurasiaFreeFortFirstPrize());
  });

  test('a timed-out server win reconciles before a paid fort is reserved',
      () async {
    final economyApi = _RecoveringEconomyApi();
    final wallet = AuraPointsService(economyApi: economyApi);
    wallet.bindUserId('registered-player', registeredUser: true);
    await _waitUntil(() => wallet.isReady);

    final freeEntry = await wallet.reserveCampaignEntry(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      expectedEntryFee: 0,
    );
    expect(freeEntry.canEnter, isTrue);
    expect(
      (await wallet.commitEntry(freeEntry.reservation!)).canEnter,
      isTrue,
    );

    economyApi.online = false;
    final credited = await wallet.awardForCampaignWin(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      rewardAup: _eurasiaFreeFortFirstPrize(),
    );

    expect(credited, _eurasiaFreeFortFirstPrize());
    expect(
      wallet.euroAup,
      _RecoveringEconomyApi.initialCircuitAup +
          _eurasiaFreeFortFirstPrize(),
    );
    final offlinePaid = await wallet.reserveCampaignEntry(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 3,
      expectedEntryFee: _eurasiaNextFortEntryFee(),
    );
    expect(offlinePaid.status, EntryPaymentStatus.serviceUnavailable);

    economyApi.online = true;
    final paidEntry = await wallet.reserveCampaignEntry(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 3,
      expectedEntryFee: _eurasiaNextFortEntryFee(),
    );
    expect(paidEntry.status, EntryPaymentStatus.reserved);
    expect(paidEntry.reservation?.amount, _eurasiaNextFortEntryFee());
    final expectedBalance = _RecoveringEconomyApi.initialCircuitAup +
        _eurasiaFreeFortFirstPrize() -
        _eurasiaNextFortEntryFee();
    expect(wallet.euroAup, expectedBalance);
    expect(economyApi.progress.euroAup, expectedBalance);
  });

  test(
      'queued campaign result stays locked until authoritative acknowledgement',
      () async {
    final economyApi = _RecoveringEconomyApi();
    final wallet = AuraPointsService(economyApi: economyApi);
    final progress = CampaignProgressService(economyApi: economyApi);
    wallet.bindUserId('queued-player', registeredUser: true);
    progress.bindUserId('queued-player');
    await _waitUntil(() => wallet.isReady && progress.isHydrated);

    final reservation = await _reserveAndCommitCentralAsiaFreeFort(wallet);
    economyApi.online = false;
    final settlement = await wallet.finalizeCampaignResult(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      entryAttemptId: reservation.attemptId,
      finishRank: 1,
      totalPlayers: 10,
      payoutAup: _eurasiaFreeFortFirstPrize(),
    );

    expect(settlement.status, CampaignSettlementStatus.queued);
    expect(settlement.creditedAup, 0);
    expect(
        wallet.euroAup, _RecoveringEconomyApi.initialCircuitAup);
    expect(
      progress.isCleared(
        group: VenueGroup.euro,
        kingdomName: 'Central Asia',
        subKingdomIndex: 10,
      ),
      isFalse,
    );

    economyApi.online = true;
    expect(await wallet.reconcilePendingEconomy(), isTrue);
    expect(await progress.refreshFromAuthority(), isTrue);
    expect(
      progress.isCleared(
        group: VenueGroup.euro,
        kingdomName: 'Central Asia',
        subKingdomIndex: 10,
      ),
      isTrue,
    );
    expect(
      wallet.euroAup,
      _RecoveringEconomyApi.initialCircuitAup +
          _eurasiaFreeFortFirstPrize(),
    );

    final next = await wallet.reserveCampaignEntry(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 3,
      expectedEntryFee: _eurasiaNextFortEntryFee(),
    );
    expect(next.status, EntryPaymentStatus.reserved);
  });

  test('rejected campaign result never clears or unlocks progression',
      () async {
    final economyApi = _RecoveringEconomyApi();
    final wallet = AuraPointsService(economyApi: economyApi);
    final progress = CampaignProgressService(economyApi: economyApi);
    wallet.bindUserId('rejected-player', registeredUser: true);
    progress.bindUserId('rejected-player');
    await _waitUntil(() => wallet.isReady && progress.isHydrated);

    final reservation = await _reserveAndCommitCentralAsiaFreeFort(wallet);
    economyApi.rejectCampaignResults = true;
    final settlement = await wallet.finalizeCampaignResult(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      entryAttemptId: reservation.attemptId,
      finishRank: 1,
      totalPlayers: 10,
      payoutAup: _eurasiaFreeFortFirstPrize(),
    );

    expect(settlement.status, CampaignSettlementStatus.rejected);
    expect(settlement.clearConfirmed, isFalse);
    expect(
      progress.isCleared(
        group: VenueGroup.euro,
        kingdomName: 'Central Asia',
        subKingdomIndex: 10,
      ),
      isFalse,
    );
  });

  test('accepted result at wallet cap still confirms the campaign clear',
      () async {
    final economyApi = _RecoveringEconomyApi(
      euroAup: aup.kAupPerCircuit,
    );
    final wallet = AuraPointsService(economyApi: economyApi);
    final progress = CampaignProgressService(economyApi: economyApi);
    wallet.bindUserId('capped-player', registeredUser: true);
    progress.bindUserId('capped-player');
    await _waitUntil(() => wallet.isReady && progress.isHydrated);

    final reservation = await _reserveAndCommitCentralAsiaFreeFort(wallet);
    final settlement = await wallet.finalizeCampaignResult(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      isMainEvent: false,
      subKingdomIndex: 10,
      entryAttemptId: reservation.attemptId,
      finishRank: 1,
      totalPlayers: 10,
      payoutAup: _eurasiaFreeFortFirstPrize(),
    );
    expect(settlement.status, CampaignSettlementStatus.accepted);
    expect(settlement.creditedAup, 0);
    expect(settlement.clearConfirmed, isTrue);
    await progress.applyAuthoritativeSnapshot(settlement.progress!);
    expect(
      progress.isCleared(
        group: VenueGroup.euro,
        kingdomName: 'Central Asia',
        subKingdomIndex: 10,
      ),
      isTrue,
    );
  });
}

Future<EntryReservation> _reserveAndCommitCentralAsiaFreeFort(
  AuraPointsService wallet,
) async {
  final reserved = await wallet.reserveCampaignEntry(
    group: VenueGroup.euro,
    kingdomName: 'Central Asia',
    isMainEvent: false,
    subKingdomIndex: 10,
    expectedEntryFee: 0,
  );
  expect(reserved.canEnter, isTrue);
  final committed = await wallet.commitEntry(reserved.reservation!);
  expect(committed.canEnter, isTrue);
  return committed.reservation!;
}

int _eurasiaFreeFortFirstPrize() {
  final pool = aup.aupForSubKingdomEvent(
    group: VenueGroup.euro,
    kingdomName: 'Central Asia',
    subKingdomIndex: 10,
  );
  return PayoutTable.fromPercentages(pool, const <double>[0.60, 0.25, 0.15])
      .pays(1);
}

int _eurasiaNextFortEntryFee() => aup.entryFeeForSubKingdomEvent(
      group: VenueGroup.euro,
      kingdomName: 'Central Asia',
      subKingdomIndex: 3,
    );

Future<void> _waitUntil(bool Function() predicate) async {
  for (int attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  throw StateError('Condition did not become true in time.');
}

({
  VenueGroup group,
  String kingdomName,
  int freeIndex,
  int nextIndex,
  int firstPrize,
  int nextEntryFee,
}) _coveringFreeFort() {
  for (final group in VenueGroup.values) {
    for (final venue in venuesForGroup(group)) {
      final order = ce.subKingdomIndicesByPrizePool(
        group: group,
        kingdomName: venue.name,
      );
      if (order.length < 2) continue;
      final freeIndex = ce.freeSubKingdomIndexFor(
        group: group,
        kingdomName: venue.name,
      );
      final freePosition = order.indexOf(freeIndex);
      if (freePosition < 0 || freePosition + 1 >= order.length) continue;
      final nextIndex = order[freePosition + 1];
      final freePrize = aup.aupForSubKingdomEvent(
        group: group,
        kingdomName: venue.name,
        subKingdomIndex: freeIndex,
      );
      final firstPrize =
          PayoutTable.fromPercentages(freePrize, const [0.60, 0.25, 0.15])
              .pays(1);
      final nextEntryFee = aup.entryFeeForSubKingdomEvent(
        group: group,
        kingdomName: venue.name,
        subKingdomIndex: nextIndex,
      );
      if (firstPrize >= nextEntryFee) {
        return (
          group: group,
          kingdomName: venue.name,
          freeIndex: freeIndex,
          nextIndex: nextIndex,
          firstPrize: firstPrize,
          nextEntryFee: nextEntryFee,
        );
      }
    }
  }
  throw StateError('Expected at least one free fort to fund the next entry.');
}

EconomyProgressSnapshot _copyProgress(
  EconomyProgressSnapshot current, {
  int? indiaAup,
  int? internationalAup,
  int? euroAup,
  int? oceaniaAup,
  int? northAmericaAup,
  List<String>? awardedEventIds,
  List<String>? cleared,
}) {
  return EconomyProgressSnapshot(
    walletVersion: current.walletVersion + 1,
    indiaAup: indiaAup ?? current.indiaAup,
    internationalAup: internationalAup ?? current.internationalAup,
    euroAup: euroAup ?? current.euroAup,
    oceaniaAup: oceaniaAup ?? current.oceaniaAup,
    northAmericaAup: northAmericaAup ?? current.northAmericaAup,
    awardedEventIds: awardedEventIds ?? current.awardedEventIds,
    cleared: cleared ?? current.cleared,
    mainEventsCleared: current.mainEventsCleared,
    lastActiveAtMs: current.lastActiveAtMs,
    prevActiveAtMs: current.prevActiveAtMs,
    lastActiveDayKey: current.lastActiveDayKey,
    activityScore: current.activityScore,
    abandonedGames: current.abandonedGames,
    matchesPlayed: current.matchesPlayed,
    finishPermilleSum: current.finishPermilleSum,
    registeredStarterGranted: current.registeredStarterGranted,
    catalogVersion: current.catalogVersion,
  );
}

class _DelayedWalletEconomyApi extends EconomyApiService {
  final walletRequested = Completer<void>();
  final _walletResponse = Completer<EconomyProgressSnapshot?>();
  final Map<String, EntryReservationSnapshot> _entries =
      <String, EntryReservationSnapshot>{};
  var _progress = const EconomyProgressSnapshot(
    indiaAup: 0,
    internationalAup: 0,
    euroAup: 0,
    oceaniaAup: 0,
    awardedEventIds: <String>[],
    lastActiveAtMs: 0,
    prevActiveAtMs: 0,
    lastActiveDayKey: '',
    activityScore: 0,
    abandonedGames: 0,
    matchesPlayed: 0,
    finishPermilleSum: 0,
    registeredStarterGranted: true,
  );

  @override
  bool get isConfigured => true;

  @override
  Future<EconomyProgressSnapshot?> wallet() {
    if (!walletRequested.isCompleted) walletRequested.complete();
    return _walletResponse.future;
  }

  void completeWalletHydration() {
    if (!_walletResponse.isCompleted) {
      _walletResponse.complete(_progress);
    }
  }

  @override
  Future<EconomyOperationResult> reserveEntry({
    required String campaignId,
    required String attemptId,
  }) async {
    final existing = _entries[attemptId];
    if (existing != null) {
      return EconomyOperationResult(
        status: EconomyOperationStatus.accepted,
        duplicate: true,
        reason: 'accepted',
        progress: _progress,
        reservation: existing,
      );
    }
    final reservation = EntryReservationSnapshot(
      attemptId: attemptId,
      campaignId: campaignId,
      group: VenueGroup.euro,
      amount: campaignId.endsWith(':10') ? 0 : _eurasiaNextFortEntryFee(),
      status: 'reserved',
    );
    _entries[attemptId] = reservation;
    return EconomyOperationResult(
      status: EconomyOperationStatus.accepted,
      reason: reservation.amount == 0 ? 'free_entry_reserved' : 'accepted',
      progress: _progress,
      reservation: reservation,
    );
  }

  @override
  Future<EconomyOperationResult> commitEntry({
    required String attemptId,
  }) async {
    final existing = _entries[attemptId];
    if (existing == null) {
      return const EconomyOperationResult(
        status: EconomyOperationStatus.notFound,
        reason: 'reservation_not_found',
      );
    }
    final committed = EntryReservationSnapshot(
      attemptId: existing.attemptId,
      campaignId: existing.campaignId,
      group: existing.group,
      amount: existing.amount,
      status: 'committed',
    );
    _entries[attemptId] = committed;
    return EconomyOperationResult(
      status: EconomyOperationStatus.accepted,
      reason: 'accepted',
      progress: _progress,
      reservation: committed,
    );
  }

  @override
  Future<EconomyEventResult?> applyEvent({
    required String action,
    required VenueGroup group,
    required String eventId,
    String? campaignId,
    String? entryAttemptId,
    int? placement,
    int? amount,
    bool? heroWon,
    int? finishRank,
    int? totalPlayers,
  }) async {
    final delta = amount ?? 0;
    _progress = _copyProgress(
      _progress,
      indiaAup: group == VenueGroup.india ? _progress.indiaAup + delta : null,
      internationalAup: group == VenueGroup.international
          ? _progress.internationalAup + delta
          : null,
      euroAup: group == VenueGroup.euro ? _progress.euroAup + delta : null,
      oceaniaAup:
          group == VenueGroup.oceania ? _progress.oceaniaAup + delta : null,
      awardedEventIds: <String>[
        ..._progress.awardedEventIds,
        if (campaignId != null) campaignId,
      ],
      cleared: <String>[
        ..._progress.cleared,
        if (campaignId != null && placement == 1) campaignId,
      ],
    );
    return EconomyEventResult(
      accepted: true,
      duplicate: false,
      delta: delta,
      progress: _progress,
    );
  }
}

class _RecoveringEconomyApi extends EconomyApiService {
  static const int initialCircuitAup = 2500;

  bool online = true;
  bool rejectCampaignResults = false;
  final Set<String> _appliedEventIds = <String>{};
  final Map<String, EntryReservationSnapshot> _entries =
      <String, EntryReservationSnapshot>{};
  late EconomyProgressSnapshot progress;

  _RecoveringEconomyApi({
    int euroAup = initialCircuitAup,
  }) {
    progress = EconomyProgressSnapshot(
      indiaAup: 2500,
      internationalAup: 2500,
      euroAup: euroAup,
      oceaniaAup: 2500,
      awardedEventIds: const <String>[],
      lastActiveAtMs: 0,
      prevActiveAtMs: 0,
      lastActiveDayKey: '',
      activityScore: 0,
      abandonedGames: 0,
      matchesPlayed: 0,
      finishPermilleSum: 0,
      registeredStarterGranted: true,
    );
  }

  @override
  bool get isConfigured => true;

  @override
  Future<EconomyProgressSnapshot?> wallet() async {
    if (!online) throw StateError('offline');
    return progress;
  }

  @override
  Future<EconomyOperationResult> reserveEntry({
    required String campaignId,
    required String attemptId,
  }) async {
    if (!online) {
      return const EconomyOperationResult(
        status: EconomyOperationStatus.unavailable,
        reason: 'network',
      );
    }
    final existing = _entries[attemptId];
    if (existing != null) {
      return EconomyOperationResult(
        status: EconomyOperationStatus.accepted,
        duplicate: true,
        reason: 'accepted',
        progress: progress,
        reservation: existing,
      );
    }
    final amount =
        campaignId.endsWith(':10') ? 0 : _eurasiaNextFortEntryFee();
    final balance = progress.euroAup;
    if (balance < amount) {
      return EconomyOperationResult(
        status: EconomyOperationStatus.insufficientFunds,
        reason: 'insufficient_funds',
        progress: progress,
      );
    }
    if (amount > 0) {
      progress = _copyProgress(
        progress,
        euroAup: balance - amount,
      );
    }
    final reservation = EntryReservationSnapshot(
      attemptId: attemptId,
      campaignId: campaignId,
      group: VenueGroup.euro,
      amount: amount,
      status: 'reserved',
    );
    _entries[attemptId] = reservation;
    return EconomyOperationResult(
      status: EconomyOperationStatus.accepted,
      reason: amount == 0 ? 'free_entry_reserved' : 'accepted',
      progress: progress,
      reservation: reservation,
    );
  }

  @override
  Future<EconomyOperationResult> commitEntry({
    required String attemptId,
  }) async {
    if (!online) {
      return const EconomyOperationResult(
        status: EconomyOperationStatus.unavailable,
        reason: 'network',
      );
    }
    final existing = _entries[attemptId];
    if (existing == null) {
      return const EconomyOperationResult(
        status: EconomyOperationStatus.notFound,
        reason: 'reservation_not_found',
      );
    }
    final committed = EntryReservationSnapshot(
      attemptId: existing.attemptId,
      campaignId: existing.campaignId,
      group: existing.group,
      amount: existing.amount,
      status: 'committed',
    );
    _entries[attemptId] = committed;
    return EconomyOperationResult(
      status: EconomyOperationStatus.accepted,
      reason: 'accepted',
      progress: progress,
      reservation: committed,
    );
  }

  @override
  Future<EconomyEventResult?> applyEvent({
    required String action,
    required VenueGroup group,
    required String eventId,
    String? campaignId,
    String? entryAttemptId,
    int? placement,
    int? amount,
    bool? heroWon,
    int? finishRank,
    int? totalPlayers,
  }) async {
    if (!online) return null;
    if (_appliedEventIds.contains(eventId)) {
      return EconomyEventResult(
        accepted: true,
        duplicate: true,
        delta: 0,
        progress: progress,
      );
    }

    final requested = amount ?? 0;
    final before = _balanceFor(group);
    int after = before;
    bool accepted = false;
    if (action == 'campaign_result' && rejectCampaignResults) {
      return EconomyEventResult(
        accepted: false,
        duplicate: false,
        delta: 0,
        reason: 'result_rejected',
        progress: progress,
      );
    }
    if (action == 'campaign_win' || action == 'campaign_result') {
      after = (before + requested).clamp(0, aup.kAupPerCircuit);
      accepted = requested > 0;
      if (action == 'campaign_result') accepted = true;
    }
    if (accepted) {
      _appliedEventIds.add(eventId);
      _setBalance(group, after);
      if (campaignId != null && placement == 1) {
        progress = _copyProgress(
          progress,
          awardedEventIds: <String>[
            ...progress.awardedEventIds,
            campaignId,
          ],
          cleared: <String>[
            ...progress.cleared,
            campaignId,
          ],
        );
      }
    }
    return EconomyEventResult(
      accepted: accepted,
      duplicate: false,
      delta: after - before,
      payoutDelta: after - before,
      clearRecorded:
          action == 'campaign_result' && campaignId != null && placement == 1,
      matchRecorded: action == 'campaign_result',
      reason: accepted ? 'accepted' : 'rejected',
      progress: progress,
    );
  }

  int _balanceFor(VenueGroup group) => switch (group) {
        VenueGroup.india => progress.indiaAup,
        VenueGroup.international => progress.internationalAup,
        VenueGroup.euro => progress.euroAup,
        VenueGroup.oceania => progress.oceaniaAup,
        VenueGroup.northAmerica => progress.northAmericaAup,
      };

  void _setBalance(VenueGroup group, int amount) {
    progress = _copyProgress(
      progress,
      indiaAup: group == VenueGroup.india ? amount : null,
      internationalAup: group == VenueGroup.international ? amount : null,
      euroAup: group == VenueGroup.euro ? amount : null,
      oceaniaAup: group == VenueGroup.oceania ? amount : null,
      northAmericaAup: group == VenueGroup.northAmerica ? amount : null,
    );
  }
}
