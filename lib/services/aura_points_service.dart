import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/venues.dart' show VenueGroup;
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/game/models.dart' show PayoutTable;
import 'package:ten_of_a_kind_poker/services/economy_api_service.dart';

enum EntryPaymentStatus {
  reserved,
  free,
  insufficientFunds,
  walletLoading,
  serviceUnavailable,
  updateRequired,
  pending,
  campaignLocked,
  conflict,
  recovered,
  rejected,
}

enum CampaignSettlementStatus {
  accepted,
  queued,
  rejected,
}

class CampaignSettlementResult {
  final CampaignSettlementStatus status;
  final int creditedAup;
  final String reason;
  final bool clearConfirmed;
  final EconomyProgressSnapshot? progress;

  const CampaignSettlementResult({
    required this.status,
    this.creditedAup = 0,
    this.reason = '',
    this.clearConfirmed = false,
    this.progress,
  });

  bool get accepted => status == CampaignSettlementStatus.accepted;
  bool get queued => status == CampaignSettlementStatus.queued;
}

class EntryReservation {
  final String attemptId;
  final String campaignId;
  final VenueGroup group;
  final int amount;
  final String state;

  const EntryReservation({
    required this.attemptId,
    required this.campaignId,
    required this.group,
    required this.amount,
    required this.state,
  });

  EntryReservation copyWith({String? state}) => EntryReservation(
        attemptId: attemptId,
        campaignId: campaignId,
        group: group,
        amount: amount,
        state: state ?? this.state,
      );

  Map<String, Object> toJson() => <String, Object>{
        'attemptId': attemptId,
        'campaignId': campaignId,
        'group': group.name,
        'amount': amount,
        'state': state,
      };

  static EntryReservation? fromJson(Map<String, Object?> json) {
    final attemptId = json['attemptId'] as String?;
    final campaignId = json['campaignId'] as String?;
    final groupName = json['group'] as String?;
    final amount = json['amount'];
    final state = json['state'] as String?;
    VenueGroup? group;
    for (final candidate in VenueGroup.values) {
      if (candidate.name == groupName) {
        group = candidate;
        break;
      }
    }
    if (attemptId == null ||
        attemptId.isEmpty ||
        campaignId == null ||
        campaignId.isEmpty ||
        group == null ||
        amount is! num ||
        state == null ||
        state.isEmpty) {
      return null;
    }
    return EntryReservation(
      attemptId: attemptId,
      campaignId: campaignId,
      group: group,
      amount: amount.toInt(),
      state: state,
    );
  }
}

class EntryPaymentResult {
  final EntryPaymentStatus status;
  final EntryReservation? reservation;
  final String reason;

  const EntryPaymentResult({
    required this.status,
    this.reservation,
    this.reason = '',
  });

  bool get canEnter =>
      status == EntryPaymentStatus.reserved ||
      status == EntryPaymentStatus.free;
}

class _PendingCampaignWin {
  final String uid;
  final String action;
  final String eventId;
  final String campaignId;
  final VenueGroup group;
  final int amount;
  final int placement;
  final int totalPlayers;
  final String entryAttemptId;

  const _PendingCampaignWin({
    required this.uid,
    this.action = 'campaign_win',
    required this.eventId,
    required this.campaignId,
    required this.group,
    required this.amount,
    required this.placement,
    this.totalPlayers = 10,
    required this.entryAttemptId,
  });

  Map<String, Object> toJson() => <String, Object>{
        'uid': uid,
        'action': action,
        'eventId': eventId,
        'campaignId': campaignId,
        'group': group.name,
        'amount': amount,
        'placement': placement,
        'totalPlayers': totalPlayers,
        'entryAttemptId': entryAttemptId,
      };

  static _PendingCampaignWin? fromJson(Map<String, Object?> json) {
    final uid = json['uid'] as String?;
    final action = json['action'] as String? ?? 'campaign_win';
    final eventId = json['eventId'] as String?;
    final campaignId = json['campaignId'] as String?;
    final groupName = json['group'] as String?;
    final amount = json['amount'];
    final placement = json['placement'];
    final totalPlayers = json['totalPlayers'];
    final entryAttemptId = json['entryAttemptId'] as String?;
    if (uid == null ||
        uid.trim().isEmpty ||
        eventId == null ||
        eventId.trim().isEmpty ||
        campaignId == null ||
        campaignId.trim().isEmpty ||
        groupName == null ||
        amount is! num ||
        amount < 0 ||
        placement is! num ||
        placement <= 0 ||
        (action != 'campaign_win' &&
            action != 'campaign_result' &&
            action != 'campaign_abandoned') ||
        entryAttemptId == null ||
        entryAttemptId.trim().isEmpty) {
      return null;
    }
    VenueGroup? group;
    for (final candidate in VenueGroup.values) {
      if (candidate.name == groupName) {
        group = candidate;
        break;
      }
    }
    if (group == null) return null;
    return _PendingCampaignWin(
      uid: uid,
      action: action,
      eventId: eventId,
      campaignId: campaignId,
      group: group,
      amount: amount.toInt(),
      placement: placement.toInt(),
      totalPlayers:
          totalPlayers is num ? totalPlayers.toInt().clamp(1, 10) : 10,
      entryAttemptId: entryAttemptId,
    );
  }
}

class AuraPointsService extends ChangeNotifier {
  static const int _schemaVersion = 1;
  static const int _walletStorageVersion = 4;
  static const String _kWalletKeyPrefix = 'aup.wallet_v3';
  static const String _kLegacyWalletOwnerKey = 'aup.legacy_wallet_owner_v3';
  static const String _kIndiaKey = 'aup.india';
  static const String _kIntlKey = 'aup.international';
  static const String _kEuroKey = 'aup.euro';
  static const String _kOceaniaKey = 'aup.oceania';
  static const String _kNorthAmericaKey = 'aup.north_america';
  static const String _kAwardedKey = 'aup.awarded_events';
  static const String _kLastActiveAtKey = 'aup.last_active_at_ms';
  static const String _kPrevActiveAtKey = 'aup.prev_active_at_ms';
  static const String _kLastActiveDayKey = 'aup.last_active_day';
  static const String _kActivityScoreKey = 'aup.activity_score';
  static const String _kLastLowFreqDecayAtKey = 'aup.last_low_freq_decay_at_ms';
  static const String _kAbandonedGamesKey = 'aup.abandoned_games';
  static const String _kMatchesPlayedKey = 'aup.matches_played';
  static const String _kFinishPermilleSumKey = 'aup.finish_permille_sum';
  static const String _kRegisteredStarterGrantedKey =
      'aup.registered_starter_granted';
  static const String _kPendingCampaignWinsKey = 'aup.pending_campaign_wins_v1';

  // Aura is *only* gained by winning; it can decay based on behavior.
  // These values are intentionally not shown in the UI copy.
  static const int _kQuitPenaltyPermille = 3; // 0.3%
  static const int _kLossPenaltyPermille = 1; // 0.1%
  static const int _kLowFrequencyPenaltyPermille =
      2; // 0.2% per week (<2 games/7d)

  bool _loaded = false;
  bool _isDisposed = false;
  bool get isLoaded => _loaded;

  @override
  void notifyListeners() {
    // Settlement and persistence work can legitimately outlive the widget
    // tree that owned this service (for example, while a game route is being
    // disposed). Let that work finish without notifying a disposed notifier.
    if (_isDisposed) return;
    super.notifyListeners();
  }

  int _indiaAup = 0;
  int _internationalAup = 0;
  int _euroAup = 0;
  int _oceaniaAup = 0;
  int _northAmericaAup = 0;
  Set<String> _awardedEventIds = <String>{};

  int _lastActiveAtMs = 0;
  int _prevActiveAtMs = 0;
  String _lastActiveDayKey = '';
  int _activityScore = 0;
  int _lastLowFreqDecayAtMs = 0;
  int _abandonedGames = 0;
  int _matchesPlayed = 0;
  int _finishPermilleSum = 0;
  bool _registeredStarterGranted = false;
  final Set<String> _purgedStorageOwners = <String>{};
  List<_PendingCampaignWin> _pendingCampaignWins = <_PendingCampaignWin>[];
  List<EntryReservation> _entryReservations = <EntryReservation>[];
  int _walletRevision = 0;
  int _remoteRevision = 0;
  bool _syncConflict = false;
  bool _authorityUnavailable = false;
  bool _catalogUpdateRequired = false;

  FirebaseFirestore? _db;
  final EconomyApiService _economyApi;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _syncTimer;
  Timer? _entryRecoveryTimer;
  String? _uid;
  bool _hydratingRemote = false;
  bool _usingServerAuthority = false;
  bool _registeredUser = false;
  bool _remoteHydrating = false;
  Future<void>? _remoteHydration;
  int _bindingGeneration = 0;
  bool _entryFeePaymentInProgress = false;
  bool _entryReservationInProgress = false;
  String? _loadedOwner;
  String? _entryRecoveryNotice;

  AuraPointsService({
    FirebaseFirestore? firestore,
    EconomyApiService? economyApi,
  })  : _db = firestore,
        _economyApi = economyApi ?? EconomyApiService();

  int get indiaAup => _indiaAup;
  int get internationalAup => _internationalAup;
  int get euroAup => _euroAup;
  int get oceaniaAup => _oceaniaAup;
  int get northAmericaAup => _northAmericaAup;
  int get totalAup =>
      _indiaAup + _internationalAup + _euroAup + _oceaniaAup + _northAmericaAup;
  bool get isReady => _loaded && !_remoteHydrating;
  bool get isSyncConflict => _syncConflict;
  bool get isAuthorityUnavailable => _authorityUnavailable;
  bool get isCatalogUpdateRequired => _catalogUpdateRequired;
  bool get usesServerAuthority => _usingServerAuthority;
  bool get hasPendingCampaignSettlements => _pendingCampaignWins.any(
        (event) =>
            event.action == 'campaign_result' ||
            event.action == 'campaign_abandoned',
      );
  String? takeEntryRecoveryNotice() {
    final notice = _entryRecoveryNotice;
    _entryRecoveryNotice = null;
    return notice;
  }

  int aupForGroup(VenueGroup group) => switch (group) {
        VenueGroup.india => _indiaAup,
        VenueGroup.international => _internationalAup,
        VenueGroup.euro => _euroAup,
        VenueGroup.oceania => _oceaniaAup,
        VenueGroup.northAmerica => _northAmericaAup,
      };

  void _setAupForGroup(VenueGroup group, int value) {
    final clamped = value.clamp(0, aup.kAupPerCircuit);
    switch (group) {
      case VenueGroup.india:
        _indiaAup = clamped;
        break;
      case VenueGroup.international:
        _internationalAup = clamped;
        break;
      case VenueGroup.euro:
        _euroAup = clamped;
        break;
      case VenueGroup.oceania:
        _oceaniaAup = clamped;
        break;
      case VenueGroup.northAmerica:
        _northAmericaAup = clamped;
        break;
    }
  }

  void _applyNormalizedCircuitAup({
    required int indiaAup,
    required int internationalAup,
    required int euroAup,
    required int oceaniaAup,
    required int northAmericaAup,
  }) {
    final legacyCap = aup.kAupPerAura * 25;
    final currentCap = aup.kAupPerCircuit;
    var overflow = 0;

    int normalizeLegacy(int value) {
      final legacyValue = value.clamp(0, legacyCap);
      overflow += math.max(legacyValue - currentCap, 0);
      return math.min(legacyValue, currentCap);
    }

    _indiaAup = normalizeLegacy(indiaAup);
    _internationalAup = normalizeLegacy(internationalAup);
    _euroAup = normalizeLegacy(euroAup);
    _oceaniaAup = normalizeLegacy(oceaniaAup);
    _northAmericaAup =
        (northAmericaAup.clamp(0, currentCap) + overflow).clamp(0, currentCap);
  }

  int get indiaAuraMilli => aup
      .auraMilliFromAup(_indiaAup)
      .clamp(0, aup.kAupMaxAuraPerCircuit * aup.kAuraMilliPerAura);
  int get internationalAuraMilli => aup
      .auraMilliFromAup(_internationalAup)
      .clamp(0, aup.kAupMaxAuraPerCircuit * aup.kAuraMilliPerAura);
  int get euroAuraMilli => aup
      .auraMilliFromAup(_euroAup)
      .clamp(0, aup.kAupMaxAuraPerCircuit * aup.kAuraMilliPerAura);
  int get oceaniaAuraMilli => aup
      .auraMilliFromAup(_oceaniaAup)
      .clamp(0, aup.kAupMaxAuraPerCircuit * aup.kAuraMilliPerAura);
  int get northAmericaAuraMilli => aup
      .auraMilliFromAup(_northAmericaAup)
      .clamp(0, aup.kAupMaxAuraPerCircuit * aup.kAuraMilliPerAura);
  int get totalAuraMilli => aup
      .auraMilliFromAup(totalAup)
      .clamp(0, aup.kAupMaxAuraTotal * aup.kAuraMilliPerAura);

  double get indiaAura => indiaAuraMilli / aup.kAuraMilliPerAura;
  double get internationalAura =>
      internationalAuraMilli / aup.kAuraMilliPerAura;
  double get euroAura => euroAuraMilli / aup.kAuraMilliPerAura;
  double get oceaniaAura => oceaniaAuraMilli / aup.kAuraMilliPerAura;
  double get northAmericaAura => northAmericaAuraMilli / aup.kAuraMilliPerAura;
  double get totalAura => totalAuraMilli / aup.kAuraMilliPerAura;

  int get activityScore => _activityScore.clamp(0, 10000);
  int get abandonedGames => _abandonedGames.clamp(0, 1 << 30);
  int get matchesPlayed => _matchesPlayed.clamp(0, 1 << 30);
  int get avgFinishPermille => matchesPlayed <= 0
      ? 0
      : (_finishPermilleSum ~/ matchesPlayed).clamp(0, 1000);
  int get auraMilliPerMatch => matchesPlayed <= 0
      ? 0
      : (totalAuraMilli ~/ matchesPlayed).clamp(0, 100000);

  DateTime? get lastActiveAtUtc => _lastActiveAtMs <= 0
      ? null
      : DateTime.fromMillisecondsSinceEpoch(_lastActiveAtMs, isUtc: true);

  void bindUserId(String? uid, {bool registeredUser = false}) {
    final normalizedUid = uid?.trim();
    final bool hasUid = normalizedUid != null && normalizedUid.isNotEmpty;
    final bool nextRegisteredUser = hasUid && registeredUser;
    if (_uid == normalizedUid && _registeredUser == nextRegisteredUser) return;
    final int generation = ++_bindingGeneration;
    _uid = normalizedUid;
    _registeredUser = nextRegisteredUser;
    _syncTimer?.cancel();
    _syncTimer = null;
    _entryRecoveryTimer?.cancel();
    _entryRecoveryTimer = null;
    _sub?.cancel();
    _sub = null;
    _resetState();
    _loaded = false;
    _usingServerAuthority = false;
    _authorityUnavailable = false;
    _catalogUpdateRequired = false;
    _syncConflict = false;
    _remoteHydrating = true;
    notifyListeners();
    final hydration = hasUid
        ? _hydrateFromRemote(normalizedUid, generation)
        : _hydrateLocalGuest(generation);
    _remoteHydration = hydration;
    unawaited(hydration);
  }

  Future<void> _hydrateLocalGuest(int generation) async {
    try {
      await init();
    } finally {
      if (_uid == null && _bindingGeneration == generation) {
        _remoteHydrating = false;
        notifyListeners();
      }
    }
  }

  Future<void> _hydrateFromRemote(String uid, int generation) async {
    try {
      await init();
      if (!_isCurrentBinding(uid, generation)) return;

      if (_economyApi.isConfigured) {
        final walletResult = await _economyApi.walletResult();
        if (!_isCurrentBinding(uid, generation)) return;
        final serverSnapshot = walletResult.progress;
        if (walletResult.status != EconomyWalletStatus.loaded ||
            serverSnapshot == null) {
          // An unavailable or inconclusive authority read must never grant a
          // starter wallet or upload the local fallback over remote state.
          _authorityUnavailable = true;
          _catalogUpdateRequired =
              walletResult.status == EconomyWalletStatus.incompatibleCatalog;
          return;
        }
        _usingServerAuthority = true;
        _authorityUnavailable = false;
        _catalogUpdateRequired = false;
        _applyAuthoritativeSnapshot(serverSnapshot);
        await _persist(syncRemote: false);
        await _flushPendingCampaignWins();
        await _reconcileEntryReservationsAfterStartup();
        return;
      }

      await _reconcileLocalEntryReservationsAfterStartup();
      final doc = _docRef(uid);
      if (doc == null) {
        await _ensureRegisteredStarterAup(authorityConfirmed: true);
        return;
      }

      final snap = await doc.get().timeout(const Duration(seconds: 12));
      if (!_isCurrentBinding(uid, generation)) return;
      final data = snap.data();
      final bool hasDedicatedWallet = (data?['walletStorageVersion'] == 2 ||
              data?['walletStorageVersion'] == 3 ||
              data?['walletStorageVersion'] == 4) &&
          _hasRemoteAuraData(data!);
      if (hasDedicatedWallet) {
        final remoteRevision = _numInt(data['walletRevision']);
        _remoteRevision = remoteRevision;
        if (remoteRevision >= _walletRevision) {
          _applyRemote(data);
          await _persist(syncRemote: false);
        } else {
          _scheduleSync();
        }
      } else if (await _hydrateFromLegacyAuraWallet(uid)) {
        if (!_isCurrentBinding(uid, generation)) return;
        // Legacy wallet data was copied into the dedicated wallet document.
        await _syncToFirestore();
      } else if (data != null && _hasRemoteAuraData(data)) {
        // Very old aura_wallets documents predate the storage marker. Preserve
        // them when no newer combined campaign document exists.
        _applyRemote(data);
        await _persist(syncRemote: false);
        await _syncToFirestore();
      } else if (!snap.exists) {
        await _ensureRegisteredStarterAup(authorityConfirmed: true);
        await _syncToFirestore();
      }
      if (!_isCurrentBinding(uid, generation)) return;
      await _ensureRegisteredStarterAup(authorityConfirmed: true);

      if (!_isCurrentBinding(uid, generation)) return;
      _sub = doc.snapshots().listen(
        (snap) {
          if (!_isCurrentBinding(uid, generation)) return;
          if (_usingServerAuthority) return;
          final data = snap.data();
          if (data == null) return;
          final remoteRevision = _numInt(data['walletRevision']);
          if (remoteRevision < _walletRevision) return;
          _remoteRevision = remoteRevision;
          _applyRemote(data);
          unawaited(_persist(syncRemote: false));
        },
        onError: (e) => debugPrint('Aura remote stream error: $e'),
      );
    } catch (e) {
      debugPrint('Aura remote hydrate failed: $e');
      if (_isCurrentBinding(uid, generation)) {
        _authorityUnavailable = true;
      }
    } finally {
      if (_isCurrentBinding(uid, generation)) {
        _remoteHydrating = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentBinding(String uid, int generation) {
    return _uid == uid && _bindingGeneration == generation;
  }

  Future<bool> _prepareForWalletMutation() async {
    if (!_loaded) await init();
    final hydration = _remoteHydration;
    if (hydration != null) {
      try {
        await hydration.timeout(const Duration(seconds: 18));
      } on TimeoutException {
        _authorityUnavailable = true;
        return false;
      }
    }
    if (!_economyApi.isConfigured) {
      final localAllowed = _economyApi.allowsLocalEconomyFallback;
      _authorityUnavailable = !localAllowed;
      _catalogUpdateRequired = false;
      return localAllowed;
    }
    if (!_authorityUnavailable) return true;

    // A prior timeout is not a permanent lockout. Re-read the authoritative
    // wallet before retrying any mutation; only a conclusive snapshot may
    // clear the outage state.
    final walletResult = await _economyApi.walletResult();
    final snapshot = walletResult.progress;
    if (walletResult.status != EconomyWalletStatus.loaded || snapshot == null) {
      _authorityUnavailable = true;
      _catalogUpdateRequired =
          walletResult.status == EconomyWalletStatus.incompatibleCatalog;
      return false;
    }
    _usingServerAuthority = true;
    _authorityUnavailable = false;
    _catalogUpdateRequired = false;
    _applyAuthoritativeSnapshot(snapshot);
    await _persist(syncRemote: false);
    notifyListeners();
    return true;
  }

  Future<bool> _hydrateFromLegacyAuraWallet(String uid) async {
    final legacyDoc = _legacyDocRef(uid);
    if (legacyDoc == null) return false;
    try {
      final snap = await legacyDoc.get();
      final data = snap.data();
      if (data == null || !_hasRemoteAuraData(data)) return false;
      _applyRemote(data);
      await _persist(syncRemote: false);
      return true;
    } catch (e) {
      debugPrint('Legacy aura hydrate failed: $e');
      rethrow;
    }
  }

  bool _hasRemoteAuraData(Map<String, dynamic> data) {
    return data.containsKey('indiaAup') ||
        data.containsKey('internationalAup') ||
        data.containsKey('euroAup') ||
        data.containsKey('oceaniaAup') ||
        data.containsKey('northAmericaAup') ||
        data.containsKey('awardedEventIds') ||
        data.containsKey('matchesPlayed') ||
        data.containsKey('finishPermilleSum') ||
        data.containsKey('registeredStarterGranted');
  }

  void _applyRemote(Map<String, dynamic> data) {
    _hydratingRemote = true;
    if (data.containsKey('walletRevision')) {
      _walletRevision =
          _numInt(data['walletRevision'], fallback: _walletRevision);
    }
    if (data.containsKey('indiaAup') ||
        data.containsKey('internationalAup') ||
        data.containsKey('euroAup') ||
        data.containsKey('oceaniaAup') ||
        data.containsKey('northAmericaAup')) {
      _applyNormalizedCircuitAup(
        indiaAup: _numInt(data['indiaAup'], fallback: _indiaAup),
        internationalAup: _numInt(
          data['internationalAup'],
          fallback: _internationalAup,
        ),
        euroAup: _numInt(data['euroAup'], fallback: _euroAup),
        oceaniaAup: _numInt(data['oceaniaAup'], fallback: _oceaniaAup),
        northAmericaAup: _numInt(
          data['northAmericaAup'],
          fallback: _northAmericaAup,
        ),
      );
    }
    if (data.containsKey('awardedEventIds')) {
      _awardedEventIds = _stringSetFrom(data['awardedEventIds']);
    }
    if (data.containsKey('lastActiveAtMs')) {
      _lastActiveAtMs =
          _numInt(data['lastActiveAtMs'], fallback: _lastActiveAtMs);
    }
    if (data.containsKey('prevActiveAtMs')) {
      _prevActiveAtMs =
          _numInt(data['prevActiveAtMs'], fallback: _prevActiveAtMs);
    }
    if (data.containsKey('lastActiveDayKey')) {
      _lastActiveDayKey =
          (data['lastActiveDayKey'] as String?) ?? _lastActiveDayKey;
    }
    if (data.containsKey('activityScore')) {
      _activityScore = _numInt(data['activityScore'], fallback: _activityScore);
    }
    if (data.containsKey('lastLowFreqDecayAtMs')) {
      _lastLowFreqDecayAtMs = _numInt(
        data['lastLowFreqDecayAtMs'],
        fallback: _lastLowFreqDecayAtMs,
      );
    }
    if (data.containsKey('abandonedGames')) {
      _abandonedGames =
          _numInt(data['abandonedGames'], fallback: _abandonedGames);
    }
    if (data.containsKey('matchesPlayed')) {
      _matchesPlayed = _numInt(data['matchesPlayed'], fallback: _matchesPlayed);
    }
    if (data.containsKey('finishPermilleSum')) {
      _finishPermilleSum =
          _numInt(data['finishPermilleSum'], fallback: _finishPermilleSum);
    }
    if (data.containsKey('registeredStarterGranted')) {
      _registeredStarterGranted = data['registeredStarterGranted'] == true;
    }
    _hydratingRemote = false;
    notifyListeners();
  }

  void _applyAuthoritativeSnapshot(EconomyProgressSnapshot snapshot) {
    _hydratingRemote = true;
    _walletRevision = snapshot.walletVersion;
    _remoteRevision = snapshot.walletVersion;
    _applyNormalizedCircuitAup(
      indiaAup: snapshot.indiaAup,
      internationalAup: snapshot.internationalAup,
      euroAup: snapshot.euroAup,
      oceaniaAup: snapshot.oceaniaAup,
      northAmericaAup: snapshot.northAmericaAup,
    );
    _awardedEventIds = snapshot.awardedEventIds.toSet();
    _lastActiveAtMs = snapshot.lastActiveAtMs;
    _prevActiveAtMs = snapshot.prevActiveAtMs;
    _lastActiveDayKey = snapshot.lastActiveDayKey;
    _activityScore = snapshot.activityScore;
    _abandonedGames = snapshot.abandonedGames;
    _matchesPlayed = snapshot.matchesPlayed;
    _finishPermilleSum = snapshot.finishPermilleSum;
    _registeredStarterGranted = snapshot.registeredStarterGranted;
    _hydratingRemote = false;
  }

  Future<EconomyOperationResult?> _applyServerEvent({
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
    final uid = _uid;
    if (uid == null || uid.trim().isEmpty) return null;
    if (!_economyApi.isConfigured) return null;
    final result = await _economyApi.applyEventOutcome(
      action: action,
      group: group,
      eventId: eventId,
      campaignId: campaignId,
      entryAttemptId: entryAttemptId,
      placement: placement,
      amount: amount,
      heroWon: heroWon,
      finishRank: finishRank,
      totalPlayers: totalPlayers,
    );
    final progress = result.progress;
    if (progress != null) {
      _usingServerAuthority = true;
      _authorityUnavailable = false;
      _applyAuthoritativeSnapshot(progress);
      await _persist(syncRemote: false);
      notifyListeners();
    } else if (result.status == EconomyOperationStatus.unavailable) {
      _authorityUnavailable = true;
    }
    return result;
  }

  Future<bool> _flushPendingCampaignWins() async {
    final uid = _uid;
    if (uid == null || uid.trim().isEmpty) return true;
    if (!_economyApi.isConfigured) return true;

    final pending = _pendingCampaignWins
        .where((event) => event.uid == uid)
        .toList(growable: false);
    for (final event in pending) {
      final result = await _economyApi.applyEventOutcome(
        action: event.action,
        group: event.group,
        eventId: event.eventId,
        campaignId: event.campaignId,
        entryAttemptId: event.entryAttemptId,
        placement: event.placement,
        amount: event.amount,
        totalPlayers: event.totalPlayers,
      );
      if (!result.accepted) {
        if (result.status == EconomyOperationStatus.unavailable) return false;
        debugPrint(
          'Pending campaign settlement rejected: ${result.reason}',
        );
        _pendingCampaignWins.removeWhere(
          (candidate) =>
              candidate.uid == event.uid && candidate.eventId == event.eventId,
        );
        await _persist(syncRemote: false);
        continue;
      }
      if (_uid != uid) return false;

      _usingServerAuthority = true;
      if (result.progress != null) {
        _applyAuthoritativeSnapshot(result.progress!);
      }
      if (event.action == 'campaign_result' ||
          event.action == 'campaign_abandoned') {
        _removeEntryReservation(event.entryAttemptId);
      } else {
        _replaceEntryReservationState(event.entryAttemptId, 'settled');
      }
      _pendingCampaignWins.removeWhere(
        (candidate) =>
            candidate.uid == event.uid && candidate.eventId == event.eventId,
      );
      await _persist(syncRemote: false);
      notifyListeners();
    }
    return !_pendingCampaignWins.any((event) => event.uid == uid);
  }

  Future<bool> reconcilePendingEconomy() async {
    if (!_economyApi.isConfigured) return true;
    if (!await _prepareForWalletMutation()) return false;
    return _flushPendingCampaignWins();
  }

  void _queuePendingCampaignWin(_PendingCampaignWin event) {
    final exists = _pendingCampaignWins.any(
      (candidate) =>
          candidate.uid == event.uid && candidate.eventId == event.eventId,
    );
    if (!exists) _pendingCampaignWins.add(event);
  }

  void _resetState() {
    _indiaAup = 0;
    _internationalAup = 0;
    _euroAup = 0;
    _oceaniaAup = 0;
    _northAmericaAup = 0;
    _awardedEventIds = <String>{};
    _lastActiveAtMs = 0;
    _prevActiveAtMs = 0;
    _lastActiveDayKey = '';
    _activityScore = 0;
    _lastLowFreqDecayAtMs = 0;
    _abandonedGames = 0;
    _matchesPlayed = 0;
    _finishPermilleSum = 0;
    _registeredStarterGranted = false;
    _pendingCampaignWins = <_PendingCampaignWin>[];
    _entryReservations = <EntryReservation>[];
    _walletRevision = 0;
    _remoteRevision = 0;
    _catalogUpdateRequired = false;
    _entryRecoveryNotice = null;
  }

  FirebaseFirestore? _dbOrNull() {
    if (_db != null) return _db;
    try {
      _db = FirebaseFirestore.instance;
      return _db;
    } catch (e) {
      debugPrint('Firestore unavailable: $e');
      return null;
    }
  }

  DocumentReference<Map<String, dynamic>>? _docRef(String uid) {
    final db = _dbOrNull();
    if (db == null) return null;
    return db.collection('aura_wallets').doc(uid);
  }

  DocumentReference<Map<String, dynamic>>? _legacyDocRef(String uid) {
    final db = _dbOrNull();
    if (db == null) return null;
    return db.collection('campaign_progress').doc(uid);
  }

  Map<String, dynamic> _toFirestoreMap() {
    final List<String> awarded = _awardedEventIds.toList()
      ..sort((a, b) => a.compareTo(b));
    return <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'walletStorageVersion': _walletStorageVersion,
      'walletRevision': _walletRevision,
      'indiaAup': _indiaAup,
      'internationalAup': _internationalAup,
      'euroAup': _euroAup,
      'oceaniaAup': _oceaniaAup,
      'northAmericaAup': _northAmericaAup,
      'awardedEventIds': awarded,
      'lastActiveAtMs': _lastActiveAtMs,
      'prevActiveAtMs': _prevActiveAtMs,
      'lastActiveDayKey': _lastActiveDayKey,
      'activityScore': _activityScore,
      'lastLowFreqDecayAtMs': _lastLowFreqDecayAtMs,
      'abandonedGames': _abandonedGames,
      'matchesPlayed': _matchesPlayed,
      'finishPermilleSum': _finishPermilleSum,
      'registeredStarterGranted': _registeredStarterGranted,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  void _scheduleSync() {
    if (_hydratingRemote) return;
    if (_usingServerAuthority) return;
    if (_uid == null || _uid!.trim().isEmpty) return;
    _syncTimer ??= Timer(const Duration(seconds: 2), () {
      _syncTimer = null;
      unawaited(_syncToFirestore());
    });
  }

  Future<void> syncRemoteNow() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    await _syncToFirestore();
  }

  Future<void> _syncToFirestore() async {
    if (_hydratingRemote) return;
    if (_usingServerAuthority) return;
    final uid = _uid;
    if (uid == null || uid.trim().isEmpty) return;
    final doc = _docRef(uid);
    if (doc == null) return;
    try {
      final db = _dbOrNull();
      if (db == null) return;
      final conflict =
          await db.runTransaction<Map<String, dynamic>?>((transaction) async {
        final snapshot = await transaction.get(doc);
        final remote = snapshot.data();
        final remoteRevision = _numInt(remote?['walletRevision']);
        if (snapshot.exists && remoteRevision != _remoteRevision) {
          return remote;
        }
        transaction.set(
          doc,
          _toFirestoreMap(),
          SetOptions(merge: true),
        );
        return null;
      }).timeout(const Duration(seconds: 12));
      if (conflict != null) {
        _syncConflict = true;
        debugPrint(
          'Aura sync paused because a newer remote wallet version exists.',
        );
        notifyListeners();
        return;
      }
      _remoteRevision = _walletRevision;
      _syncConflict = false;
    } catch (e) {
      debugPrint('Aura sync failed: $e');
    }
  }

  void _markLocalMutation() {
    _walletRevision = (_walletRevision + 1).clamp(0, 1 << 52);
  }

  Set<String> _stringSetFrom(dynamic raw) {
    if (raw is Iterable) {
      return raw.whereType<String>().toSet();
    }
    return <String>{};
  }

  int _numInt(Object? v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  Future<void> init() async {
    final owner = _storageOwner;
    if (_loaded && _loadedOwner == owner) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, Object?>? wallet;
      final encoded = prefs.getString(_walletStorageKey(owner))?.trim() ?? '';
      if (encoded.isNotEmpty) {
        final decoded = jsonDecode(encoded);
        if (decoded is Map) {
          wallet = Map<String, Object?>.from(decoded);
        }
      } else {
        wallet = await _legacyWalletForOwner(prefs, owner);
      }
      if (_storageOwner != owner) return;
      _resetState();
      if (wallet != null) _applyLocalWalletJson(wallet);
      _loadedOwner = owner;
    } catch (error) {
      debugPrint('Aura local wallet load failed: $error');
      if (_storageOwner != owner) return;
      // Keep defaults; don't crash the app if prefs aren't available.
      _resetState();
      _loadedOwner = owner;
    } finally {
      if (_storageOwner == owner) {
        _loaded = true;
        notifyListeners();
      }
    }
  }

  String get _storageOwner {
    final uid = _uid?.trim() ?? '';
    return uid.isEmpty ? 'guest' : uid;
  }

  String _walletStorageKey(String owner) {
    final encoded = base64Url.encode(utf8.encode(owner)).replaceAll('=', '');
    return '$_kWalletKeyPrefix.$encoded';
  }

  Future<Map<String, Object?>?> _legacyWalletForOwner(
    SharedPreferences prefs,
    String owner,
  ) async {
    final existingOwner = prefs.getString(_kLegacyWalletOwnerKey);
    if (existingOwner != null && existingOwner != owner) return null;
    final hasLegacy = <bool>[
      prefs.containsKey(_kIndiaKey),
      prefs.containsKey(_kIntlKey),
      prefs.containsKey(_kEuroKey),
      prefs.containsKey(_kOceaniaKey),
      prefs.containsKey(_kNorthAmericaKey),
      prefs.containsKey(_kAwardedKey),
    ].any((value) => value);
    if (!hasLegacy) return null;
    if (existingOwner == null) {
      await prefs.setString(_kLegacyWalletOwnerKey, owner);
    }
    return <String, Object?>{
      'walletStorageVersion': 2,
      'walletRevision': 0,
      'indiaAup': prefs.getInt(_kIndiaKey) ?? 0,
      'internationalAup': prefs.getInt(_kIntlKey) ?? 0,
      'euroAup': prefs.getInt(_kEuroKey) ?? 0,
      'oceaniaAup': prefs.getInt(_kOceaniaKey) ?? 0,
      'northAmericaAup': prefs.getInt(_kNorthAmericaKey) ?? 0,
      'awardedEventIds': prefs.getStringList(_kAwardedKey) ?? const <String>[],
      'lastActiveAtMs': prefs.getInt(_kLastActiveAtKey) ?? 0,
      'prevActiveAtMs': prefs.getInt(_kPrevActiveAtKey) ?? 0,
      'lastActiveDayKey': prefs.getString(_kLastActiveDayKey) ?? '',
      'activityScore': prefs.getInt(_kActivityScoreKey) ?? 0,
      'lastLowFreqDecayAtMs': prefs.getInt(_kLastLowFreqDecayAtKey) ?? 0,
      'abandonedGames': prefs.getInt(_kAbandonedGamesKey) ?? 0,
      'matchesPlayed': prefs.getInt(_kMatchesPlayedKey) ?? 0,
      'finishPermilleSum': prefs.getInt(_kFinishPermilleSumKey) ?? 0,
      'registeredStarterGranted':
          prefs.getBool(_kRegisteredStarterGrantedKey) ?? false,
      'pendingCampaignWins': _decodeLegacyPendingWins(
        prefs.getString(_kPendingCampaignWinsKey),
      ),
    };
  }

  List<Object?> _decodeLegacyPendingWins(String? encoded) {
    if (encoded == null || encoded.trim().isEmpty) return const <Object?>[];
    try {
      final decoded = jsonDecode(encoded);
      return decoded is List ? decoded : const <Object?>[];
    } catch (_) {
      return const <Object?>[];
    }
  }

  void _applyLocalWalletJson(Map<String, Object?> data) {
    _walletRevision = _numInt(data['walletRevision']);
    _remoteRevision = _numInt(data['remoteRevision']);
    _applyNormalizedCircuitAup(
      indiaAup: _numInt(data['indiaAup']),
      internationalAup: _numInt(data['internationalAup']),
      euroAup: _numInt(data['euroAup']),
      oceaniaAup: _numInt(data['oceaniaAup']),
      northAmericaAup: _numInt(data['northAmericaAup']),
    );
    _awardedEventIds = _stringSetFrom(data['awardedEventIds']);
    _lastActiveAtMs = _numInt(data['lastActiveAtMs']);
    _prevActiveAtMs = _numInt(data['prevActiveAtMs']);
    _lastActiveDayKey = data['lastActiveDayKey'] as String? ?? '';
    _activityScore = _numInt(data['activityScore']);
    _lastLowFreqDecayAtMs = _numInt(data['lastLowFreqDecayAtMs']);
    _abandonedGames = _numInt(data['abandonedGames']);
    _matchesPlayed = _numInt(data['matchesPlayed']);
    _finishPermilleSum = _numInt(data['finishPermilleSum']);
    _registeredStarterGranted = data['registeredStarterGranted'] == true;
    final pending = data['pendingCampaignWins'];
    if (pending is List) {
      _pendingCampaignWins = pending
          .whereType<Map>()
          .map(
            (item) => _PendingCampaignWin.fromJson(
              Map<String, Object?>.from(item),
            ),
          )
          .whereType<_PendingCampaignWin>()
          .toList();
    }
    final reservations = data['entryReservations'];
    if (reservations is List) {
      _entryReservations = reservations
          .whereType<Map>()
          .map(
            (item) => EntryReservation.fromJson(
              Map<String, Object?>.from(item),
            ),
          )
          .whereType<EntryReservation>()
          .toList();
    }
  }

  Future<void> _ensureRegisteredStarterAup({
    required bool authorityConfirmed,
  }) async {
    if (!authorityConfirmed) return;
    if (!_registeredUser || _registeredStarterGranted) return;
    if (!_loaded) await init();

    if (totalAup <= 0) {
      final groups = VenueGroup.values;
      final int baseGrant = aup.kRegisteredStarterAup ~/ groups.length;
      int remainder = aup.kRegisteredStarterAup - (baseGrant * groups.length);
      for (final group in groups) {
        final extra = remainder > 0 ? 1 : 0;
        if (remainder > 0) remainder--;
        _setAupForGroup(group, aupForGroup(group) + baseGrant + extra);
      }
    }
    _registeredStarterGranted = true;
    _markLocalMutation();
    await _persist();
    notifyListeners();
  }

  bool hasAwardedEventId(String id) => _awardedEventIds.contains(id);

  String campaignEventId({
    required VenueGroup group,
    required String kingdomName,
    required bool isMainEvent,
    int? subKingdomIndex,
  }) {
    final canonical =
        ce.canonicalKingdomName(group: group, kingdomName: kingdomName);
    return isMainEvent
        ? _mainEventId(group: group, kingdomName: canonical)
        : _subKingdomId(
            group: group,
            kingdomName: canonical,
            subKingdomIndex: subKingdomIndex,
          );
  }

  Future<EntryPaymentResult> reserveCampaignEntry({
    required VenueGroup group,
    required String kingdomName,
    required bool isMainEvent,
    int? subKingdomIndex,
    required int expectedEntryFee,
  }) async {
    if (_entryReservationInProgress) {
      return const EntryPaymentResult(
        status: EntryPaymentStatus.walletLoading,
        reason: 'entry_operation_in_progress',
      );
    }
    _entryReservationInProgress = true;
    try {
      return await _reserveCampaignEntryUnlocked(
        group: group,
        kingdomName: kingdomName,
        isMainEvent: isMainEvent,
        subKingdomIndex: subKingdomIndex,
        expectedEntryFee: expectedEntryFee,
      );
    } finally {
      _entryReservationInProgress = false;
    }
  }

  Future<EntryPaymentResult> _reserveCampaignEntryUnlocked({
    required VenueGroup group,
    required String kingdomName,
    required bool isMainEvent,
    int? subKingdomIndex,
    required int expectedEntryFee,
  }) async {
    if (!await _prepareForWalletMutation()) {
      return EntryPaymentResult(
        status: _catalogUpdateRequired
            ? EntryPaymentStatus.updateRequired
            : EntryPaymentStatus.serviceUnavailable,
        reason: _catalogUpdateRequired
            ? 'catalog_version_mismatch'
            : 'wallet_authority_unavailable',
      );
    }
    final campaignId = campaignEventId(
      group: group,
      kingdomName: kingdomName,
      isMainEvent: isMainEvent,
      subKingdomIndex: subKingdomIndex,
    );
    var reservation = _latestEntryReservation(
      campaignId,
      const <String>{'intent', 'reserved'},
    );
    reservation ??= EntryReservation(
      attemptId: _newEventId('entry:$campaignId'),
      campaignId: campaignId,
      group: group,
      amount: expectedEntryFee.clamp(0, 1 << 30),
      state: 'intent',
    );
    _putLocalEntryReservation(reservation);
    await _persist(syncRemote: false);

    if (_uid != null && _economyApi.isConfigured) {
      if (!await _flushPendingCampaignWins()) {
        return EntryPaymentResult(
          status: EntryPaymentStatus.serviceUnavailable,
          reservation: reservation,
          reason: 'pending_rewards_not_synced',
        );
      }
      final result = await _economyApi.reserveEntry(
        campaignId: campaignId,
        attemptId: reservation.attemptId,
      );
      if (result.progress != null) {
        _usingServerAuthority = true;
        _authorityUnavailable = false;
        _applyAuthoritativeSnapshot(result.progress!);
      }
      if (result.accepted) {
        final remote = result.reservation;
        reservation = EntryReservation(
          attemptId: reservation.attemptId,
          campaignId: campaignId,
          group: remote?.group ?? group,
          amount: remote?.amount ?? expectedEntryFee,
          state: remote?.status ?? 'reserved',
        );
        _putLocalEntryReservation(reservation);
        await _persist(syncRemote: false);
        notifyListeners();
        return EntryPaymentResult(
          status: reservation.amount <= 0
              ? EntryPaymentStatus.free
              : EntryPaymentStatus.reserved,
          reservation: reservation,
          reason: result.reason,
        );
      }

      if (result.status == EconomyOperationStatus.unavailable) {
        _authorityUnavailable = true;
        await _persist(syncRemote: false);
        notifyListeners();
        return EntryPaymentResult(
          status: EntryPaymentStatus.pending,
          reservation: reservation,
          reason: result.reason,
        );
      }
      _removeEntryReservation(reservation.attemptId);
      await _persist(syncRemote: false);
      notifyListeners();
      return EntryPaymentResult(
        status: switch (result.status) {
          EconomyOperationStatus.insufficientFunds =>
            EntryPaymentStatus.insufficientFunds,
          EconomyOperationStatus.campaignLocked =>
            EntryPaymentStatus.campaignLocked,
          EconomyOperationStatus.invalidCatalog =>
            EntryPaymentStatus.updateRequired,
          EconomyOperationStatus.conflict => EntryPaymentStatus.conflict,
          _ => EntryPaymentStatus.rejected,
        },
        reason: result.reason,
      );
    }

    final amount = reservation.amount;
    final before = aupForGroup(group);
    if (amount > 0 && before < amount) {
      _removeEntryReservation(reservation.attemptId);
      await _persist(syncRemote: false);
      return const EntryPaymentResult(
        status: EntryPaymentStatus.insufficientFunds,
        reason: 'insufficient_funds',
      );
    }
    if (amount > 0) _setAupForGroup(group, before - amount);
    reservation = reservation.copyWith(state: 'reserved');
    _putLocalEntryReservation(reservation);
    _markLocalMutation();
    await _persist();
    notifyListeners();
    return EntryPaymentResult(
      status:
          amount <= 0 ? EntryPaymentStatus.free : EntryPaymentStatus.reserved,
      reservation: reservation,
    );
  }

  Future<EntryPaymentResult> commitEntry(EntryReservation reservation) async {
    final current = _findLocalEntryReservation(reservation.attemptId);
    if (current == null) {
      return const EntryPaymentResult(
        status: EntryPaymentStatus.rejected,
        reason: 'reservation_not_found',
      );
    }
    if (_uid != null && _economyApi.isConfigured) {
      final committing = current.copyWith(state: 'committing');
      _putLocalEntryReservation(committing);
      await _persist(syncRemote: false);
      final result = await _economyApi.commitEntry(
        attemptId: current.attemptId,
      );
      if (result.progress != null) {
        _applyAuthoritativeSnapshot(result.progress!);
      }
      if (result.accepted) {
        final committed = current.copyWith(
          state: result.reservation?.status ?? 'committed',
        );
        _putLocalEntryReservation(committed);
        await _persist(syncRemote: false);
        notifyListeners();
        return EntryPaymentResult(
          status: committed.amount <= 0
              ? EntryPaymentStatus.free
              : EntryPaymentStatus.reserved,
          reservation: committed,
          reason: result.reason,
        );
      }
      if (result.status == EconomyOperationStatus.unavailable) {
        return EntryPaymentResult(
          status: EntryPaymentStatus.pending,
          reservation: committing,
          reason: result.reason,
        );
      }
      return EntryPaymentResult(
        status: EntryPaymentStatus.rejected,
        reservation: current,
        reason: result.reason,
      );
    }

    final committed = current.copyWith(state: 'committed');
    _putLocalEntryReservation(committed);
    await _persist(syncRemote: false);
    return EntryPaymentResult(
      status: committed.amount <= 0
          ? EntryPaymentStatus.free
          : EntryPaymentStatus.reserved,
      reservation: committed,
    );
  }

  Future<EntryPaymentResult> refundEntry(EntryReservation reservation) async {
    final current = _findLocalEntryReservation(reservation.attemptId);
    if (current == null) {
      return const EntryPaymentResult(
        status: EntryPaymentStatus.rejected,
        reason: 'reservation_not_found',
      );
    }
    if (_uid != null && _economyApi.isConfigured) {
      final result = await _economyApi.refundEntry(
        attemptId: current.attemptId,
      );
      if (result.progress != null) {
        _applyAuthoritativeSnapshot(result.progress!);
      }
      if (result.accepted) {
        _removeEntryReservation(current.attemptId);
        await _persist(syncRemote: false);
        notifyListeners();
        return EntryPaymentResult(
          status: EntryPaymentStatus.rejected,
          reason: 'refunded',
        );
      }
      return EntryPaymentResult(
        status: result.status == EconomyOperationStatus.unavailable
            ? EntryPaymentStatus.pending
            : EntryPaymentStatus.rejected,
        reservation: current,
        reason: result.reason,
      );
    }

    if (current.state == 'reserved') {
      _setAupForGroup(
        current.group,
        aupForGroup(current.group) + current.amount,
      );
      _markLocalMutation();
    }
    _removeEntryReservation(current.attemptId);
    await _persist();
    notifyListeners();
    return const EntryPaymentResult(
      status: EntryPaymentStatus.rejected,
      reason: 'refunded',
    );
  }

  EntryReservation? _findLocalEntryReservation(String attemptId) {
    for (final reservation in _entryReservations.reversed) {
      if (reservation.attemptId == attemptId) return reservation;
    }
    return null;
  }

  EntryReservation? _latestEntryReservation(
    String campaignId,
    Set<String> states,
  ) {
    for (final reservation in _entryReservations.reversed) {
      if (reservation.campaignId == campaignId &&
          states.contains(reservation.state)) {
        return reservation;
      }
    }
    return null;
  }

  EntryReservation? _activeEntryForCampaign(String campaignId) {
    for (final reservation in _entryReservations.reversed) {
      if (reservation.campaignId == campaignId &&
          (reservation.state == 'committed' ||
              reservation.state == 'committing')) {
        return reservation;
      }
    }
    return null;
  }

  List<EntryReservation> get activeCommittedEntries =>
      List<EntryReservation>.unmodifiable(
        _entryReservations.where(
          (entry) => entry.state == 'committed' || entry.state == 'committing',
        ),
      );

  EntryReservation? activeCommittedEntry({String? campaignId}) {
    if (campaignId != null && campaignId.trim().isNotEmpty) {
      return _activeEntryForCampaign(campaignId.trim());
    }
    for (final reservation in _entryReservations.reversed) {
      if (reservation.state == 'committed' ||
          reservation.state == 'committing') {
        return reservation;
      }
    }
    return null;
  }

  Future<EntryPaymentResult> recoverOrphanedEntry({
    required String attemptId,
  }) async {
    final terminalPending = _pendingCampaignWins.any(
      (event) =>
          event.entryAttemptId == attemptId &&
          (event.action == 'campaign_result' ||
              event.action == 'campaign_abandoned'),
    );
    if (terminalPending) {
      return const EntryPaymentResult(
        status: EntryPaymentStatus.pending,
        reason: 'terminal_settlement_pending',
      );
    }
    final reservation = _findLocalEntryReservation(attemptId);
    if (reservation == null) {
      return const EntryPaymentResult(
        status: EntryPaymentStatus.rejected,
        reason: 'reservation_not_found',
      );
    }
    if (_uid != null && _economyApi.isConfigured) {
      final result = await _economyApi.recoverCommittedEntry(
        attemptId: attemptId,
      );
      if (result.progress != null) {
        _applyAuthoritativeSnapshot(result.progress!);
      }
      if (result.accepted) {
        _removeEntryReservation(attemptId);
        _entryRecoveryNotice =
            'An interrupted entry was recovered. Its entry fee was returned '
            'and the standard abandonment adjustment was applied.';
        await _persist(syncRemote: false);
        notifyListeners();
        return const EntryPaymentResult(
          status: EntryPaymentStatus.recovered,
          reason: 'abandoned_entry_recovered',
        );
      }
      if (result.reason == 'entry_already_settled' ||
          result.reason == 'reservation_not_found') {
        _removeEntryReservation(attemptId);
        await _persist(syncRemote: false);
        return EntryPaymentResult(
          status: EntryPaymentStatus.rejected,
          reason: result.reason,
        );
      }
      return EntryPaymentResult(
        status: result.status == EconomyOperationStatus.unavailable
            ? EntryPaymentStatus.serviceUnavailable
            : EntryPaymentStatus.pending,
        reservation: reservation,
        reason: result.reason,
      );
    }

    _setAupForGroup(
      reservation.group,
      aupForGroup(reservation.group) + reservation.amount,
    );
    _deductPermilleOfTotalAup(_kQuitPenaltyPermille);
    _abandonedGames = (_abandonedGames + 1).clamp(0, 1 << 30);
    _matchesPlayed = (_matchesPlayed + 1).clamp(0, 1 << 30);
    _removeEntryReservation(attemptId);
    _entryRecoveryNotice =
        'An interrupted entry was recovered. Its entry fee was returned '
        'and the standard abandonment adjustment was applied.';
    _markLocalMutation();
    await _persist();
    notifyListeners();
    return const EntryPaymentResult(
      status: EntryPaymentStatus.recovered,
      reason: 'abandoned_entry_recovered',
    );
  }

  Future<void> clearActiveEntry(String attemptId) async {
    _removeEntryReservation(attemptId);
    await _persist(syncRemote: false);
  }

  void _putLocalEntryReservation(EntryReservation reservation) {
    _entryReservations.removeWhere(
      (candidate) => candidate.attemptId == reservation.attemptId,
    );
    _entryReservations.add(reservation);
    if (_entryReservations.length > 40) {
      _entryReservations =
          _entryReservations.sublist(_entryReservations.length - 40);
    }
  }

  void _replaceEntryReservationState(String attemptId, String state) {
    final reservation = _findLocalEntryReservation(attemptId);
    if (reservation == null) return;
    _putLocalEntryReservation(reservation.copyWith(state: state));
  }

  void _removeEntryReservation(String attemptId) {
    _entryReservations.removeWhere(
      (candidate) => candidate.attemptId == attemptId,
    );
  }

  Future<void> _reconcileEntryReservationsAfterStartup() async {
    final pending = _entryReservations
        .where(
          (entry) => entry.state == 'intent' || entry.state == 'reserved',
        )
        .toList(growable: false);
    for (final reservation in pending) {
      final result = await _economyApi.refundEntry(
        attemptId: reservation.attemptId,
      );
      if (result.status == EconomyOperationStatus.unavailable) return;
      if (result.progress != null) {
        _applyAuthoritativeSnapshot(result.progress!);
      }
      if (result.accepted || result.status == EconomyOperationStatus.notFound) {
        _removeEntryReservation(reservation.attemptId);
      }
    }
    final committed = activeCommittedEntries.toList(growable: false);
    var recoveryPending = false;
    for (final reservation in committed) {
      final recovery = await recoverOrphanedEntry(
        attemptId: reservation.attemptId,
      );
      if (recovery.status == EntryPaymentStatus.serviceUnavailable ||
          recovery.status == EntryPaymentStatus.pending) {
        recoveryPending = true;
      }
    }
    await _persist(syncRemote: false);
    if (recoveryPending && _uid != null) {
      final uid = _uid;
      final generation = _bindingGeneration;
      _entryRecoveryTimer?.cancel();
      _entryRecoveryTimer = Timer(const Duration(minutes: 10), () {
        if (uid == null || !_isCurrentBinding(uid, generation)) return;
        unawaited(_reconcileEntryReservationsAfterStartup());
      });
    }
  }

  Future<void> _reconcileLocalEntryReservationsAfterStartup() async {
    var changed = false;
    final orphaned = _entryReservations
        .where(
          (entry) => entry.state == 'intent' || entry.state == 'reserved',
        )
        .toList(growable: false);
    for (final reservation in orphaned) {
      if (reservation.state == 'reserved' && reservation.amount > 0) {
        _setAupForGroup(
          reservation.group,
          aupForGroup(reservation.group) + reservation.amount,
        );
      }
      _removeEntryReservation(reservation.attemptId);
      changed = true;
    }
    if (!changed) return;
    _markLocalMutation();
    await _persist();
    notifyListeners();
  }

  /// Deducts an entry fee from the circuit wallet. Returns false if insufficient.
  Future<bool> payEntryFee({
    required VenueGroup group,
    required int amount,
  }) async {
    if (amount <= 0) return true;
    if (_entryFeePaymentInProgress) return false;
    _entryFeePaymentInProgress = true;
    try {
      if (!await _prepareForWalletMutation()) return false;
      await _ensureRegisteredStarterAup(
        authorityConfirmed: !_economyApi.isConfigured || !_authorityUnavailable,
      );

      if (_uid != null &&
          _economyApi.isConfigured &&
          !await _flushPendingCampaignWins()) {
        return false;
      }

      if (_uid != null && _economyApi.isConfigured) {
        final campaignId = 'legacy_fee:${group.name}:$amount';
        var attempt = _latestEntryReservation(
          campaignId,
          const <String>{'intent'},
        );
        attempt ??= EntryReservation(
          attemptId: _newEventId(campaignId),
          campaignId: campaignId,
          group: group,
          amount: amount,
          state: 'intent',
        );
        _putLocalEntryReservation(attempt);
        await _persist(syncRemote: false);
        final server = await _applyServerEvent(
          action: 'entry_fee',
          group: group,
          eventId: attempt.attemptId,
          amount: amount,
        );
        if (server?.accepted == true) {
          _removeEntryReservation(attempt.attemptId);
          await _persist(syncRemote: false);
          return true;
        }
        return false;
      }

      final before = aupForGroup(group);
      if (before < amount) return false;
      _setAupForGroup(group, before - amount);
      _markLocalMutation();
      await _persist();
      notifyListeners();
      return true;
    } finally {
      _entryFeePaymentInProgress = false;
    }
  }

  Future<CampaignSettlementResult> finalizeCampaignResult({
    required VenueGroup group,
    required String kingdomName,
    required bool isMainEvent,
    int? subKingdomIndex,
    required String entryAttemptId,
    required int finishRank,
    required int totalPlayers,
    int? payoutAup,
  }) async {
    if (!_loaded) await init();
    final canonical =
        ce.canonicalKingdomName(group: group, kingdomName: kingdomName);
    final campaignId = campaignEventId(
      group: group,
      kingdomName: canonical,
      isMainEvent: isMainEvent,
      subKingdomIndex: subKingdomIndex,
    );
    final players = totalPlayers.clamp(1, 10);
    final rank = finishRank.clamp(1, players);
    final prizePool = isMainEvent
        ? aup.aupForKingdomMainEvent(
            group: group,
            kingdomName: canonical,
          )
        : aup.aupForSubKingdomEvent(
            group: group,
            kingdomName: canonical,
            subKingdomIndex: subKingdomIndex ?? 1,
          );
    final payoutTable = isMainEvent
        ? PayoutTable.fixed(<int>[prizePool])
        : PayoutTable.fromPercentages(
            prizePool,
            const <double>[0.60, 0.25, 0.15],
          );
    final expectedPayout = payoutTable.pays(rank).clamp(0, prizePool);
    if (payoutAup != null && payoutAup != expectedPayout) {
      debugPrint(
        'Ignoring campaign payout skew; authoritative catalog payout is used.',
      );
    }

    final entry = _findLocalEntryReservation(entryAttemptId);
    if (entry == null ||
        entry.campaignId != campaignId ||
        entry.group != group ||
        (entry.state != 'committed' && entry.state != 'committing')) {
      return const CampaignSettlementResult(
        status: CampaignSettlementStatus.rejected,
        reason: 'committed_entry_required',
      );
    }

    final uid = _uid;
    if (uid != null && _economyApi.isConfigured) {
      final authorityReady = await _prepareForWalletMutation();
      var pending = _pendingWinForEntry(uid, entryAttemptId);
      pending ??= _PendingCampaignWin(
        uid: uid,
        action: 'campaign_result',
        eventId: _newEventId('campaign_result:$campaignId'),
        campaignId: campaignId,
        group: group,
        amount: expectedPayout,
        placement: rank,
        totalPlayers: players,
        entryAttemptId: entryAttemptId,
      );
      _queuePendingCampaignWin(pending);
      await _persist(syncRemote: false);

      EconomyOperationResult? server;
      if (authorityReady) {
        server = await _applyServerEvent(
          action: 'campaign_result',
          group: group,
          eventId: pending.eventId,
          campaignId: campaignId,
          entryAttemptId: entryAttemptId,
          placement: rank,
          amount: expectedPayout,
          finishRank: rank,
          totalPlayers: players,
        );
      }
      if (server?.accepted == true) {
        _pendingCampaignWins.removeWhere(
          (candidate) =>
              candidate.uid == uid && candidate.eventId == pending!.eventId,
        );
        _removeEntryReservation(entryAttemptId);
        await _persist(syncRemote: false);
        notifyListeners();
        final snapshot = server!.progress;
        final clearConfirmed = server.clearRecorded ||
            (rank == 1 &&
                (isMainEvent
                    ? snapshot?.mainEventsCleared.contains(campaignId) == true
                    : snapshot?.cleared.contains(campaignId) == true));
        return CampaignSettlementResult(
          status: CampaignSettlementStatus.accepted,
          creditedAup: server.payoutDelta.clamp(0, expectedPayout),
          reason: server.reason,
          clearConfirmed: clearConfirmed,
          progress: snapshot,
        );
      }
      if (server == null ||
          server.status == EconomyOperationStatus.unavailable) {
        return CampaignSettlementResult(
          status: CampaignSettlementStatus.queued,
          creditedAup: 0,
          reason: server?.reason ?? 'wallet_authority_unavailable',
        );
      }

      _pendingCampaignWins.removeWhere(
        (candidate) =>
            candidate.uid == uid && candidate.eventId == pending!.eventId,
      );
      await _persist(syncRemote: false);
      return CampaignSettlementResult(
        status: CampaignSettlementStatus.rejected,
        reason: server.reason,
        progress: server.progress,
      );
    }

    if (!await _prepareForWalletMutation()) {
      return CampaignSettlementResult(
        status: CampaignSettlementStatus.rejected,
        reason: _catalogUpdateRequired
            ? 'catalog_version_mismatch'
            : 'wallet_authority_unavailable',
      );
    }
    final before = aupForGroup(group);
    _setAupForGroup(group, before + expectedPayout);
    final credited = (aupForGroup(group) - before).clamp(0, expectedPayout);
    _matchesPlayed = (_matchesPlayed + 1).clamp(0, 1 << 30);
    _finishPermilleSum = (_finishPermilleSum +
            _finishPermille(finishRank: rank, totalPlayers: players))
        .clamp(0, 1 << 30);
    if (rank != 1) _deductPermilleOfTotalAup(_kLossPenaltyPermille);
    _awardedEventIds.add(campaignId);
    _removeEntryReservation(entryAttemptId);
    _markLocalMutation();
    await _persist();
    notifyListeners();
    return CampaignSettlementResult(
      status: CampaignSettlementStatus.accepted,
      creditedAup: credited,
      reason: credited == 0 && expectedPayout > 0
          ? 'wallet_cap_reached'
          : 'accepted',
      clearConfirmed: rank == 1,
    );
  }

  Future<CampaignSettlementResult> finalizeCampaignAbandon({
    required VenueGroup group,
    required String kingdomName,
    required bool isMainEvent,
    int? subKingdomIndex,
    required String entryAttemptId,
    required int totalPlayers,
  }) async {
    if (!_loaded) await init();
    final campaignId = campaignEventId(
      group: group,
      kingdomName: kingdomName,
      isMainEvent: isMainEvent,
      subKingdomIndex: subKingdomIndex,
    );
    final entry = _findLocalEntryReservation(entryAttemptId);
    if (entry == null ||
        entry.campaignId != campaignId ||
        entry.group != group ||
        (entry.state != 'committed' && entry.state != 'committing')) {
      return const CampaignSettlementResult(
        status: CampaignSettlementStatus.rejected,
        reason: 'committed_entry_required',
      );
    }
    final players = totalPlayers.clamp(1, 10);
    final uid = _uid;
    if (uid != null && _economyApi.isConfigured) {
      final authorityReady = await _prepareForWalletMutation();
      var pending = _pendingWinForEntry(uid, entryAttemptId);
      pending ??= _PendingCampaignWin(
        uid: uid,
        action: 'campaign_abandoned',
        eventId: _newEventId('campaign_abandoned:$campaignId'),
        campaignId: campaignId,
        group: group,
        amount: 0,
        placement: players,
        totalPlayers: players,
        entryAttemptId: entryAttemptId,
      );
      _queuePendingCampaignWin(pending);
      await _persist(syncRemote: false);

      EconomyOperationResult? server;
      if (authorityReady) {
        server = await _applyServerEvent(
          action: 'campaign_abandoned',
          group: group,
          eventId: pending.eventId,
          campaignId: campaignId,
          entryAttemptId: entryAttemptId,
          placement: players,
          totalPlayers: players,
        );
      }
      if (server?.accepted == true) {
        _pendingCampaignWins.removeWhere(
          (candidate) =>
              candidate.uid == uid && candidate.eventId == pending!.eventId,
        );
        _removeEntryReservation(entryAttemptId);
        await _persist(syncRemote: false);
        notifyListeners();
        return CampaignSettlementResult(
          status: CampaignSettlementStatus.accepted,
          reason: server!.reason,
          progress: server.progress,
        );
      }
      if (server == null ||
          server.status == EconomyOperationStatus.unavailable) {
        return CampaignSettlementResult(
          status: CampaignSettlementStatus.queued,
          reason: server?.reason ?? 'wallet_authority_unavailable',
        );
      }
      _pendingCampaignWins.removeWhere(
        (candidate) =>
            candidate.uid == uid && candidate.eventId == pending!.eventId,
      );
      await _persist(syncRemote: false);
      return CampaignSettlementResult(
        status: CampaignSettlementStatus.rejected,
        reason: server.reason,
        progress: server.progress,
      );
    }

    final deducted = await recordGameAbandoned(
      totalPlayers: players,
      entryAttemptId: entryAttemptId,
    );
    return CampaignSettlementResult(
      status: CampaignSettlementStatus.accepted,
      reason: 'accepted',
      creditedAup: -deducted,
    );
  }

  Future<int> awardForCampaignWin({
    required VenueGroup group,
    required String kingdomName,
    required bool isMainEvent,
    int? subKingdomIndex,
    int? rewardAup,
  }) async {
    if (!await _prepareForWalletMutation()) return 0;
    final canonical =
        ce.canonicalKingdomName(group: group, kingdomName: kingdomName);
    final String eventId = isMainEvent
        ? _mainEventId(group: group, kingdomName: canonical)
        : _subKingdomId(
            group: group,
            kingdomName: canonical,
            subKingdomIndex: subKingdomIndex,
          );

    final int configuredReward = isMainEvent
        ? aup.aupForKingdomMainEvent(group: group, kingdomName: canonical)
        : aup.aupForSubKingdomEvent(
            group: group,
            kingdomName: canonical,
            subKingdomIndex: subKingdomIndex ?? 1,
          );
    final int delta =
        (rewardAup ?? configuredReward).clamp(0, configuredReward);

    if (delta <= 0) return 0;

    final uid = _uid;
    if (uid != null && _economyApi.isConfigured) {
      final placement = _campaignPlacement(
        isMainEvent: isMainEvent,
        prizePool: configuredReward,
        payout: delta,
      );
      if (placement == null) return 0;
      var entry = _activeEntryForCampaign(eventId);
      if (entry == null) {
        debugPrint('Campaign settlement rejected: no committed entry.');
        return 0;
      }
      if (entry.state == 'committing') {
        final committed = await commitEntry(entry);
        entry = committed.reservation ?? entry;
      }

      var pending = _pendingWinForEntry(uid, entry.attemptId);
      final alreadyQueued = pending != null;
      pending ??= _PendingCampaignWin(
        uid: uid,
        eventId: _newEventId('campaign_win:$eventId'),
        campaignId: eventId,
        group: group,
        amount: delta,
        placement: placement,
        entryAttemptId: entry.attemptId,
      );
      _queuePendingCampaignWin(pending);
      await _persist(syncRemote: false);

      final before = aupForGroup(group);
      final server = await _applyServerEvent(
        action: 'campaign_win',
        group: group,
        eventId: pending.eventId,
        campaignId: eventId,
        entryAttemptId: pending.entryAttemptId,
        placement: pending.placement,
        amount: delta,
      );
      if (server?.accepted == true) {
        _pendingCampaignWins.removeWhere(
          (candidate) =>
              candidate.uid == pending!.uid &&
              candidate.eventId == pending.eventId,
        );
        _removeEntryReservation(entry.attemptId);
        await _persist(syncRemote: false);
        notifyListeners();
        final reflected = (aupForGroup(group) - before).clamp(0, delta);
        return server!.delta.clamp(0, delta) > 0
            ? server.delta.clamp(0, delta)
            : reflected;
      }
      if (server?.status == EconomyOperationStatus.unavailable) {
        if (!alreadyQueued) {
          final optimisticBefore = aupForGroup(group);
          _setAupForGroup(group, optimisticBefore + delta);
          _awardedEventIds.add(eventId);
          await _persist(syncRemote: false);
          notifyListeners();
          return (aupForGroup(group) - optimisticBefore).clamp(0, delta);
        }
        return 0;
      }

      _pendingCampaignWins.removeWhere(
        (candidate) =>
            candidate.uid == pending!.uid &&
            candidate.eventId == pending.eventId,
      );
      await _persist(syncRemote: false);
      return 0;
    }

    final int before = aupForGroup(group);
    _setAupForGroup(group, before + delta);

    final int after = aupForGroup(group);
    final int credited = (after - before).clamp(0, delta);
    _awardedEventIds.add(eventId); // still tracked for milestones/analytics
    _markLocalMutation();
    await _persist();
    notifyListeners();
    return credited;
  }

  int? _campaignPlacement({
    required bool isMainEvent,
    required int prizePool,
    required int payout,
  }) {
    final payouts = isMainEvent
        ? PayoutTable.fixed(<int>[prizePool])
        : PayoutTable.fromPercentages(
            prizePool,
            const <double>[0.60, 0.25, 0.15],
          );
    for (int rank = 1; rank <= payouts.byRank.length; rank++) {
      if (payouts.pays(rank) == payout) return rank;
    }
    return null;
  }

  _PendingCampaignWin? _pendingWinForEntry(
    String uid,
    String entryAttemptId,
  ) {
    for (final pending in _pendingCampaignWins.reversed) {
      if (pending.uid == uid && pending.entryAttemptId == entryAttemptId) {
        return pending;
      }
    }
    return null;
  }

  Future<int> awardRewardedAdBonus({
    required VenueGroup group,
    required int amount,
  }) async {
    if (amount <= 0) return 0;
    if (!_loaded) await init();

    final server = await _applyServerEvent(
      action: 'rewarded_ad',
      group: group,
      eventId: _newEventId('rewarded_ad:${group.name}'),
      amount: amount,
    );
    if (server != null)
      return server.accepted ? server.delta.clamp(0, amount) : 0;

    final int before = aupForGroup(group);
    _setAupForGroup(group, before + amount);

    final int after = aupForGroup(group);
    final int credited = (after - before).clamp(0, amount);
    _markLocalMutation();
    await _persist();
    notifyListeners();
    return credited;
  }

  Future<void> _persist({bool syncRemote = true}) async {
    final owner = _storageOwner;
    if (_purgedStorageOwners.contains(owner)) return;
    final payload = <String, Object?>{
      'schemaVersion': _schemaVersion,
      'walletStorageVersion': _walletStorageVersion,
      'walletRevision': _walletRevision,
      'remoteRevision': _remoteRevision,
      'indiaAup': _indiaAup,
      'internationalAup': _internationalAup,
      'euroAup': _euroAup,
      'oceaniaAup': _oceaniaAup,
      'northAmericaAup': _northAmericaAup,
      'awardedEventIds': _awardedEventIds.toList()..sort(),
      'lastActiveAtMs': _lastActiveAtMs,
      'prevActiveAtMs': _prevActiveAtMs,
      'lastActiveDayKey': _lastActiveDayKey,
      'activityScore': _activityScore,
      'lastLowFreqDecayAtMs': _lastLowFreqDecayAtMs,
      'abandonedGames': _abandonedGames,
      'matchesPlayed': _matchesPlayed,
      'finishPermilleSum': _finishPermilleSum,
      'registeredStarterGranted': _registeredStarterGranted,
      'pendingCampaignWins':
          _pendingCampaignWins.map((event) => event.toJson()).toList(),
      'entryReservations':
          _entryReservations.map((entry) => entry.toJson()).toList(),
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_purgedStorageOwners.contains(owner)) return;
      final saved = await prefs.setString(
        _walletStorageKey(owner),
        jsonEncode(payload),
      );
      if (!saved) {
        throw StateError('SharedPreferences rejected the AUP wallet write.');
      }
    } catch (error) {
      debugPrint('Aura local persistence failed: $error');
    }
    if (syncRemote && _storageOwner == owner) _scheduleSync();
  }

  /// Erases the deleted account's complete local wallet, pending settlements,
  /// and entry reservations without touching a guest or another account.
  Future<void> purgeLocalDataForUser(
    String uid, {
    bool includeGuestWallet = false,
  }) async {
    final owner = uid.trim();
    if (owner.isEmpty) return;
    _purgedStorageOwners.add(owner);
    if (_uid == owner) bindUserId(null);

    final ownersToRemove = <String>{owner};
    if (includeGuestWallet) {
      ownersToRemove.add('guest');
      _purgedStorageOwners.add('guest');
      _syncTimer?.cancel();
      _syncTimer = null;
      _resetState();
      _loaded = true;
      _loadedOwner = 'guest';
      notifyListeners();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      for (final storageOwner in ownersToRemove) {
        await prefs.remove(_walletStorageKey(storageOwner));
      }

      if (ownersToRemove.contains(prefs.getString(_kLegacyWalletOwnerKey))) {
        await Future.wait<bool>(<Future<bool>>[
          prefs.remove(_kLegacyWalletOwnerKey),
          prefs.remove(_kIndiaKey),
          prefs.remove(_kIntlKey),
          prefs.remove(_kEuroKey),
          prefs.remove(_kOceaniaKey),
          prefs.remove(_kNorthAmericaKey),
          prefs.remove(_kAwardedKey),
          prefs.remove(_kLastActiveAtKey),
          prefs.remove(_kPrevActiveAtKey),
          prefs.remove(_kLastActiveDayKey),
          prefs.remove(_kActivityScoreKey),
          prefs.remove(_kLastLowFreqDecayAtKey),
          prefs.remove(_kAbandonedGamesKey),
          prefs.remove(_kMatchesPlayedKey),
          prefs.remove(_kFinishPermilleSumKey),
          prefs.remove(_kRegisteredStarterGrantedKey),
          prefs.remove(_kPendingCampaignWinsKey),
        ]);
      }
    } finally {
      if (includeGuestWallet) _purgedStorageOwners.remove('guest');
    }
  }

  static String _dayKeyUtc(DateTime utc) {
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _newEventId(String prefix) {
    final clean = prefix
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9:_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final micros = DateTime.now().toUtc().microsecondsSinceEpoch;
    return '$clean:$micros';
  }

  static DateTime? _parseDayKeyUtc(String raw) {
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime.utc(y, m, d);
  }

  void _touchDailyActivity(DateTime now) {
    final String today = _dayKeyUtc(now);
    if (today == _lastActiveDayKey) return;

    final prev = _parseDayKeyUtc(_lastActiveDayKey);
    final int gapDays =
        prev == null ? 1 : now.difference(prev).inDays.clamp(1, 3650);
    final int decay = (gapDays - 1).clamp(0, 3650);
    _activityScore = (_activityScore - decay).clamp(0, 10000);
    _activityScore = (_activityScore + 1).clamp(0, 10000);
    _lastActiveDayKey = today;
  }

  int _finishPermille({
    required int finishRank,
    required int totalPlayers,
  }) {
    if (totalPlayers <= 1) return 0;
    final int r = finishRank.clamp(1, totalPlayers);
    final int denom = (totalPlayers - 1).clamp(1, 1000 * 1000 * 1000);
    return ((r - 1) * 1000 ~/ denom).clamp(0, 1000);
  }

  int _deductAupTotal(int amount) {
    if (amount <= 0) return 0;

    final int before = totalAup;
    int remaining = amount;

    while (remaining > 0) {
      final groups = VenueGroup.values.toList()
        ..sort((a, b) => aupForGroup(b).compareTo(aupForGroup(a)));
      final group = groups.first;
      final balance = aupForGroup(group);
      if (balance <= 0) break;
      final take = balance.clamp(0, remaining);
      _setAupForGroup(group, balance - take);
      remaining -= take;
    }

    return (before - totalAup).clamp(0, before);
  }

  int _deductPermilleOfTotalAup(int permille) {
    if (permille <= 0) return 0;
    final int total = totalAup;
    if (total <= 0) return 0;
    final int amount = (total * permille) ~/ 1000;
    if (amount <= 0) return 0;
    return _deductAupTotal(amount);
  }

  Future<int> recordMatchCompleted({
    required bool heroWon,
    required int finishRank,
    required int totalPlayers,
    String? entryAttemptId,
  }) async {
    if (!_loaded) await init();
    final settledAttemptId =
        entryAttemptId ?? activeCommittedEntry()?.attemptId;
    final server = await _applyServerEvent(
      action: 'match_completed',
      group: VenueGroup.india,
      eventId: _newEventId('match:$finishRank:$totalPlayers'),
      entryAttemptId: settledAttemptId,
      heroWon: heroWon,
      finishRank: finishRank,
      totalPlayers: totalPlayers,
    );
    if (server != null) {
      if (server.accepted && settledAttemptId != null) {
        _removeEntryReservation(settledAttemptId);
        await _persist(syncRemote: false);
      }
      return server.delta < 0 ? -server.delta : 0;
    }

    final now = DateTime.now().toUtc();
    final int nowMs = now.millisecondsSinceEpoch;
    if (_lastActiveAtMs > 0 && nowMs > _lastActiveAtMs) {
      _prevActiveAtMs = _lastActiveAtMs;
    }
    _lastActiveAtMs = nowMs;

    _touchDailyActivity(now);

    _matchesPlayed = (_matchesPlayed + 1).clamp(0, 1 << 30);
    _finishPermilleSum = (_finishPermilleSum +
            _finishPermille(finishRank: finishRank, totalPlayers: totalPlayers))
        .clamp(0, 1 << 30);

    final int deducted =
        heroWon ? 0 : _deductPermilleOfTotalAup(_kLossPenaltyPermille);
    if (settledAttemptId != null) {
      _removeEntryReservation(settledAttemptId);
    }
    _markLocalMutation();
    await _persist();
    notifyListeners();
    return deducted;
  }

  Future<int> recordGameAbandoned({
    required int totalPlayers,
    String? entryAttemptId,
  }) async {
    if (!_loaded) await init();
    final settledAttemptId =
        entryAttemptId ?? activeCommittedEntry()?.attemptId;
    final server = await _applyServerEvent(
      action: 'game_abandoned',
      group: VenueGroup.india,
      eventId: _newEventId('abandoned:$totalPlayers'),
      entryAttemptId: settledAttemptId,
      totalPlayers: totalPlayers,
    );
    if (server != null) {
      if (server.accepted && settledAttemptId != null) {
        _removeEntryReservation(settledAttemptId);
        await _persist(syncRemote: false);
      }
      return server.delta < 0 ? -server.delta : 0;
    }

    final now = DateTime.now().toUtc();
    final int nowMs = now.millisecondsSinceEpoch;
    if (_lastActiveAtMs > 0 && nowMs > _lastActiveAtMs) {
      _prevActiveAtMs = _lastActiveAtMs;
    }
    _lastActiveAtMs = nowMs;
    _abandonedGames = (_abandonedGames + 1).clamp(0, 1 << 30);
    _touchDailyActivity(now);

    _matchesPlayed = (_matchesPlayed + 1).clamp(0, 1 << 30);
    _finishPermilleSum = (_finishPermilleSum +
            _finishPermille(
                finishRank: totalPlayers, totalPlayers: totalPlayers))
        .clamp(0, 1 << 30);

    final int deducted = _deductPermilleOfTotalAup(_kQuitPenaltyPermille);
    if (settledAttemptId != null) {
      _removeEntryReservation(settledAttemptId);
    }
    _markLocalMutation();
    await _persist();
    notifyListeners();
    return deducted;
  }

  Future<int> applyInactivityDecayIfNeeded() async {
    if (!_loaded) await init();
    if (_lastActiveAtMs <= 0) return 0;
    if (totalAup <= 0) return 0;

    final int nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final int secondLatestMs =
        _prevActiveAtMs > 0 ? _prevActiveAtMs : _lastActiveAtMs;

    final int daysSinceSecondLatest =
        ((nowMs - secondLatestMs) ~/ Duration.millisecondsPerDay)
            .clamp(0, 99999);
    final int weeksNow = daysSinceSecondLatest ~/ 7;
    if (weeksNow <= 0) return 0;

    final int penalizedDays = _lastLowFreqDecayAtMs <= secondLatestMs
        ? 0
        : ((_lastLowFreqDecayAtMs - secondLatestMs) ~/
                Duration.millisecondsPerDay)
            .clamp(0, 99999);
    final int weeksPenalized = penalizedDays ~/ 7;

    final int newWeeks = (weeksNow - weeksPenalized).clamp(0, 99999);
    if (newWeeks <= 0) return 0;

    int deductedTotal = 0;
    for (int i = 0; i < newWeeks; i++) {
      final int deducted =
          _deductPermilleOfTotalAup(_kLowFrequencyPenaltyPermille);
      if (deducted <= 0) break;
      deductedTotal += deducted;
    }
    if (deductedTotal <= 0) return 0;

    _lastLowFreqDecayAtMs = nowMs;
    _markLocalMutation();
    await _persist();
    notifyListeners();
    return deductedTotal;
  }

  static String _mainEventId({
    required VenueGroup group,
    required String kingdomName,
  }) {
    final k = _slug(kingdomName);
    return 'me:${group.name}:$k';
  }

  static String _subKingdomId({
    required VenueGroup group,
    required String kingdomName,
    required int? subKingdomIndex,
  }) {
    final k = _slug(kingdomName);
    final i = (subKingdomIndex ?? 1) < 1 ? 1 : subKingdomIndex!;
    return 'sk:${group.name}:$k:$i';
  }

  static String _slug(String raw) {
    final lower = raw.trim().toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return replaced.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  @override
  void dispose() {
    _isDisposed = true;
    _sub?.cancel();
    _syncTimer?.cancel();
    _entryRecoveryTimer?.cancel();
    super.dispose();
  }
}
