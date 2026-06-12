import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/venues.dart' show VenueGroup;
import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/services/economy_api_service.dart';

class AuraPointsService extends ChangeNotifier {
  static const int _schemaVersion = 1;
  static const String _kIndiaKey = 'aup.india';
  static const String _kIntlKey = 'aup.international';
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

  // Aura is *only* gained by winning; it can decay based on behavior.
  // These values are intentionally not shown in the UI copy.
  static const int _kQuitPenaltyPermille = 3; // 0.3%
  static const int _kLossPenaltyPermille = 1; // 0.1%
  static const int _kLowFrequencyPenaltyPermille =
      2; // 0.2% per week (<2 games/7d)

  bool _loaded = false;
  bool get isLoaded => _loaded;

  int _indiaAup = 0;
  int _internationalAup = 0;
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

  FirebaseFirestore? _db;
  final EconomyApiService _economyApi;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _syncTimer;
  String? _uid;
  bool _hydratingRemote = false;
  bool _usingServerAuthority = false;
  bool _registeredUser = false;

  AuraPointsService({
    FirebaseFirestore? firestore,
    EconomyApiService? economyApi,
  })  : _db = firestore,
        _economyApi = economyApi ?? EconomyApiService();

  int get indiaAup => _indiaAup;
  int get internationalAup => _internationalAup;
  int get totalAup => _indiaAup + _internationalAup;

  int get indiaAuraMilli => aup
      .auraMilliFromAup(_indiaAup)
      .clamp(0, aup.kAupMaxAuraPerCircuit * aup.kAuraMilliPerAura);
  int get internationalAuraMilli => aup
      .auraMilliFromAup(_internationalAup)
      .clamp(0, aup.kAupMaxAuraPerCircuit * aup.kAuraMilliPerAura);
  int get totalAuraMilli => aup
      .auraMilliFromAup(totalAup)
      .clamp(0, aup.kAupMaxAuraTotal * aup.kAuraMilliPerAura);

  double get indiaAura => indiaAuraMilli / aup.kAuraMilliPerAura;
  double get internationalAura =>
      internationalAuraMilli / aup.kAuraMilliPerAura;
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
    _uid = normalizedUid;
    _registeredUser = nextRegisteredUser;
    _sub?.cancel();
    _sub = null;

    if (!hasUid) {
      _usingServerAuthority = false;
      _resetState();
      unawaited(_persist(syncRemote: false));
      notifyListeners();
      return;
    }

    _resetState();
    _usingServerAuthority = false;
    unawaited(_hydrateFromRemote(normalizedUid));
  }

  Future<void> _hydrateFromRemote(String uid) async {
    await init();
    final serverSnapshot = await _economyApi.wallet();
    if (serverSnapshot != null) {
      _usingServerAuthority = true;
      _applyAuthoritativeSnapshot(serverSnapshot);
      await _persist(syncRemote: false);
    }

    final doc = _docRef(uid);
    if (doc == null) {
      await _ensureRegisteredStarterAup();
      return;
    }

    try {
      final snap = await doc.get();
      final data = snap.data();
      if (serverSnapshot != null) {
        // Server-owned progress is authoritative for AUP/leaderboards. Keep the
        // legacy progress document around only for campaign-cleared fields.
      } else if (data != null && _hasRemoteAuraData(data)) {
        _applyRemote(data);
        await _persist(syncRemote: false);
      } else if (await _hydrateFromLegacyAuraWallet(uid)) {
        // Legacy wallet data was copied into the combined progress document.
        await _syncToFirestore();
      } else if (!snap.exists) {
        // No remote doc yet; push local state so progress is preserved.
        await _syncToFirestore();
      }
      await _ensureRegisteredStarterAup();
    } catch (e) {
      debugPrint('Aura remote hydrate failed: $e');
      await _ensureRegisteredStarterAup();
    }

    _sub = doc.snapshots().listen(
      (snap) {
        if (_usingServerAuthority) return;
        final data = snap.data();
        if (data == null) return;
        _applyRemote(data);
        unawaited(_persist(syncRemote: false));
      },
      onError: (e) => debugPrint('Aura remote stream error: $e'),
    );
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
      return false;
    }
  }

  bool _hasRemoteAuraData(Map<String, dynamic> data) {
    return data.containsKey('indiaAup') ||
        data.containsKey('internationalAup') ||
        data.containsKey('awardedEventIds') ||
        data.containsKey('matchesPlayed') ||
        data.containsKey('finishPermilleSum') ||
        data.containsKey('registeredStarterGranted');
  }

  void _applyRemote(Map<String, dynamic> data) {
    _hydratingRemote = true;
    if (data.containsKey('indiaAup')) {
      _indiaAup = _numInt(data['indiaAup'], fallback: _indiaAup);
    }
    if (data.containsKey('internationalAup')) {
      _internationalAup =
          _numInt(data['internationalAup'], fallback: _internationalAup);
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
    _indiaAup = snapshot.indiaAup;
    _internationalAup = snapshot.internationalAup;
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

  Future<EconomyEventResult?> _applyServerEvent({
    required String action,
    required VenueGroup group,
    required String eventId,
    int? amount,
    bool? heroWon,
    int? finishRank,
    int? totalPlayers,
  }) async {
    final uid = _uid;
    if (uid == null || uid.trim().isEmpty) return null;
    final result = await _economyApi.applyEvent(
      action: action,
      group: group,
      eventId: eventId,
      amount: amount,
      heroWon: heroWon,
      finishRank: finishRank,
      totalPlayers: totalPlayers,
    );
    if (result == null) return null;
    _usingServerAuthority = true;
    _applyAuthoritativeSnapshot(result.progress);
    await _persist(syncRemote: false);
    notifyListeners();
    return result;
  }

  void _resetState() {
    _indiaAup = 0;
    _internationalAup = 0;
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
    return db.collection('campaign_progress').doc(uid);
  }

  DocumentReference<Map<String, dynamic>>? _legacyDocRef(String uid) {
    final db = _dbOrNull();
    if (db == null) return null;
    return db.collection('aura_wallets').doc(uid);
  }

  Map<String, dynamic> _toFirestoreMap() {
    final List<String> awarded = _awardedEventIds.toList()
      ..sort((a, b) => a.compareTo(b));
    return <String, dynamic>{
      'schemaVersion': _schemaVersion,
      'indiaAup': _indiaAup,
      'internationalAup': _internationalAup,
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
      await doc.set(_toFirestoreMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Aura sync failed: $e');
    }
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
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _indiaAup = prefs.getInt(_kIndiaKey) ?? 0;
      _internationalAup = prefs.getInt(_kIntlKey) ?? 0;
      final list = prefs.getStringList(_kAwardedKey) ?? const <String>[];
      _awardedEventIds = list.toSet();
      _lastActiveAtMs = prefs.getInt(_kLastActiveAtKey) ?? 0;
      _prevActiveAtMs = prefs.getInt(_kPrevActiveAtKey) ?? 0;
      _lastActiveDayKey = prefs.getString(_kLastActiveDayKey) ?? '';
      _activityScore = prefs.getInt(_kActivityScoreKey) ?? 0;
      _lastLowFreqDecayAtMs = prefs.getInt(_kLastLowFreqDecayAtKey) ?? 0;
      _abandonedGames = prefs.getInt(_kAbandonedGamesKey) ?? 0;
      _matchesPlayed = prefs.getInt(_kMatchesPlayedKey) ?? 0;
      _finishPermilleSum = prefs.getInt(_kFinishPermilleSumKey) ?? 0;
      _registeredStarterGranted =
          prefs.getBool(_kRegisteredStarterGrantedKey) ?? false;
    } catch (_) {
      // Keep defaults; don't crash the app if prefs aren't available.
      _indiaAup = 0;
      _internationalAup = 0;
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
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> _ensureRegisteredStarterAup() async {
    if (!_registeredUser || _registeredStarterGranted) return;
    if (!_loaded) await init();

    if (totalAup <= 0) {
      final int indiaGrant = aup.kRegisteredStarterAup ~/ 2;
      final int internationalGrant = aup.kRegisteredStarterAup - indiaGrant;
      _indiaAup = (_indiaAup + indiaGrant).clamp(0, aup.kAupPerCircuit);
      _internationalAup =
          (_internationalAup + internationalGrant).clamp(0, aup.kAupPerCircuit);
    }
    _registeredStarterGranted = true;
    await _persist();
    notifyListeners();
  }

  bool hasAwardedEventId(String id) => _awardedEventIds.contains(id);

  /// Deducts an entry fee from the circuit wallet. Returns false if insufficient.
  Future<bool> payEntryFee({
    required VenueGroup group,
    required int amount,
  }) async {
    if (amount <= 0) return true;
    if (!_loaded) await init();
    await _ensureRegisteredStarterAup();

    final server = await _applyServerEvent(
      action: 'entry_fee',
      group: group,
      eventId: _newEventId('fee:${group.name}:$amount'),
      amount: amount,
    );
    if (server != null) return server.accepted;

    if (group == VenueGroup.india) {
      if (_indiaAup < amount) return false;
      _indiaAup = (_indiaAup - amount).clamp(0, aup.kAupPerCircuit);
    } else {
      if (_internationalAup < amount) return false;
      _internationalAup =
          (_internationalAup - amount).clamp(0, aup.kAupPerCircuit);
    }

    await _persist();
    notifyListeners();
    return true;
  }

  Future<int> awardForCampaignWin({
    required VenueGroup group,
    required String kingdomName,
    required bool isMainEvent,
    int? subKingdomIndex,
  }) async {
    if (!_loaded) await init();
    final canonical =
        ce.canonicalKingdomName(group: group, kingdomName: kingdomName);
    final String eventId = isMainEvent
        ? _mainEventId(group: group, kingdomName: canonical)
        : _subKingdomId(
            group: group,
            kingdomName: canonical,
            subKingdomIndex: subKingdomIndex,
          );
    if (hasAwardedEventId(eventId)) return 0;

    final int delta = isMainEvent
        ? aup.aupForKingdomMainEvent(group: group, kingdomName: canonical)
        : aup.aupForSubKingdomEvent(
            group: group,
            kingdomName: canonical,
            subKingdomIndex: subKingdomIndex ?? 1,
          );

    if (delta <= 0) return 0;

    final server = await _applyServerEvent(
      action: 'campaign_win',
      group: group,
      eventId: eventId,
      amount: delta,
    );
    if (server != null) {
      return server.accepted ? server.delta.clamp(0, delta) : 0;
    }

    final int before =
        group == VenueGroup.india ? _indiaAup : _internationalAup;
    if (group == VenueGroup.india) {
      _indiaAup = (_indiaAup + delta).clamp(0, aup.kAupPerCircuit);
    } else {
      _internationalAup =
          (_internationalAup + delta).clamp(0, aup.kAupPerCircuit);
    }

    final int after = group == VenueGroup.india ? _indiaAup : _internationalAup;
    final int credited = (after - before).clamp(0, delta);
    _awardedEventIds.add(eventId); // still tracked for milestones/analytics
    await _persist();
    notifyListeners();
    return credited;
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

    final int before =
        group == VenueGroup.india ? _indiaAup : _internationalAup;
    if (group == VenueGroup.india) {
      _indiaAup = (_indiaAup + amount).clamp(0, aup.kAupPerCircuit);
    } else {
      _internationalAup =
          (_internationalAup + amount).clamp(0, aup.kAupPerCircuit);
    }

    final int after = group == VenueGroup.india ? _indiaAup : _internationalAup;
    final int credited = (after - before).clamp(0, amount);
    await _persist();
    notifyListeners();
    return credited;
  }

  Future<void> _persist({bool syncRemote = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kIndiaKey, _indiaAup);
      await prefs.setInt(_kIntlKey, _internationalAup);
      await prefs.setStringList(
          _kAwardedKey, _awardedEventIds.toList()..sort());
      await prefs.setInt(_kLastActiveAtKey, _lastActiveAtMs);
      await prefs.setInt(_kPrevActiveAtKey, _prevActiveAtMs);
      await prefs.setString(_kLastActiveDayKey, _lastActiveDayKey);
      await prefs.setInt(_kActivityScoreKey, _activityScore);
      await prefs.setInt(_kLastLowFreqDecayAtKey, _lastLowFreqDecayAtMs);
      await prefs.setInt(_kAbandonedGamesKey, _abandonedGames);
      await prefs.setInt(_kMatchesPlayedKey, _matchesPlayed);
      await prefs.setInt(_kFinishPermilleSumKey, _finishPermilleSum);
      await prefs.setBool(
        _kRegisteredStarterGrantedKey,
        _registeredStarterGranted,
      );
    } catch (_) {
      // ignore persistence failures
    }
    if (syncRemote) _scheduleSync();
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

    void takeFromIntlFirst() {
      final int takeIntl = _internationalAup.clamp(0, remaining);
      _internationalAup -= takeIntl;
      remaining -= takeIntl;
      if (remaining <= 0) return;
      final int takeIndia = _indiaAup.clamp(0, remaining);
      _indiaAup -= takeIndia;
      remaining -= takeIndia;
    }

    void takeFromIndiaFirst() {
      final int takeIndia = _indiaAup.clamp(0, remaining);
      _indiaAup -= takeIndia;
      remaining -= takeIndia;
      if (remaining <= 0) return;
      final int takeIntl = _internationalAup.clamp(0, remaining);
      _internationalAup -= takeIntl;
      remaining -= takeIntl;
    }

    if (_internationalAup >= _indiaAup) {
      takeFromIntlFirst();
    } else {
      takeFromIndiaFirst();
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
  }) async {
    if (!_loaded) await init();
    final server = await _applyServerEvent(
      action: 'match_completed',
      group: VenueGroup.india,
      eventId: _newEventId('match:$finishRank:$totalPlayers'),
      heroWon: heroWon,
      finishRank: finishRank,
      totalPlayers: totalPlayers,
    );
    if (server != null) return server.delta < 0 ? -server.delta : 0;

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
    await _persist();
    notifyListeners();
    return deducted;
  }

  Future<int> recordGameAbandoned({required int totalPlayers}) async {
    if (!_loaded) await init();
    final server = await _applyServerEvent(
      action: 'game_abandoned',
      group: VenueGroup.india,
      eventId: _newEventId('abandoned:$totalPlayers'),
      totalPlayers: totalPlayers,
    );
    if (server != null) return server.delta < 0 ? -server.delta : 0;

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
    _sub?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }
}
