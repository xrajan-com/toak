import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';
import 'package:ten_of_a_kind_poker/services/economy_api_service.dart';

class CampaignProgressService extends ChangeNotifier {
  static const int _schemaVersion = 1;
  static const String _pendingOutboxKeyPrefix = 'campaign.pending_outbox_v2';
  static const String _pendingClearedKeyPrefix = 'campaign.pending_cleared_v1';
  static const String _pendingMainEventsKeyPrefix =
      'campaign.pending_main_events_v1';
  static const String _authorityCacheKeyPrefix =
      'campaign.authoritative_cache_v1';

  final Set<String> _cleared = <String>{};
  final Set<String> _mainEventsCleared = <String>{};
  final Set<String> _pendingCleared = <String>{};
  final Set<String> _pendingMainEvents = <String>{};
  FirebaseFirestore? _db;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  bool _hydrated = true;
  bool _authorityUnavailable = false;
  int _bindingGeneration = 0;
  Future<void>? _flushFuture;
  Future<bool>? _authorityRefreshFuture;
  final Set<String> _purgedUserIds = <String>{};
  final Map<String, Future<void>> _pendingStorageTails =
      <String, Future<void>>{};
  final EconomyApiService _economyApi;

  CampaignProgressService({
    FirebaseFirestore? firestore,
    EconomyApiService? economyApi,
  })  : _db = firestore,
        _economyApi = economyApi ?? EconomyApiService();

  bool get isHydrated => _hydrated;
  bool get isAuthorityUnavailable => _authorityUnavailable;

  void bindUserId(String? uid) {
    final normalizedUid = uid?.trim();
    if (_uid == normalizedUid) return;
    final generation = ++_bindingGeneration;
    _uid = normalizedUid;
    _cleared.clear();
    _mainEventsCleared.clear();
    _pendingCleared.clear();
    _pendingMainEvents.clear();
    _hydrated = normalizedUid == null || normalizedUid.isEmpty;
    _authorityUnavailable = false;
    _flushFuture = null;
    _authorityRefreshFuture = null;
    _sub?.cancel();
    _sub = null;
    notifyListeners();

    if (normalizedUid == null || normalizedUid.isEmpty) return;
    unawaited(_bindRemote(normalizedUid, generation));
  }

  Future<void> _bindRemote(String uid, int generation) async {
    if (_economyApi.isConfigured) {
      await _loadAuthorityCache(uid, generation);
      if (!_isCurrentBinding(uid, generation)) return;
      final wallet = await _economyApi.walletResult();
      if (!_isCurrentBinding(uid, generation)) return;
      final server = wallet.progress;
      if (wallet.status == EconomyWalletStatus.loaded && server != null) {
        _authorityUnavailable = false;
        await _applyAuthoritativeProgress(uid, generation, server);
      } else {
        _authorityUnavailable = true;
      }
      if (!_isCurrentBinding(uid, generation)) return;
      _hydrated = true;
      notifyListeners();
      return;
    }

    await _loadPending(uid, generation);
    if (!_isCurrentBinding(uid, generation)) return;

    final db = _dbOrNull();
    if (db == null) {
      _hydrated = true;
      notifyListeners();
      return;
    }
    final doc = db.collection('campaign_progress').doc(uid);
    _sub = doc.snapshots().listen(
      (snap) => _applySnapshot(snap, uid, generation),
      onError: (e) {
        if (!_isCurrentBinding(uid, generation)) return;
        debugPrint('Campaign progress stream error: $e');
        _hydrated = true;
        notifyListeners();
      },
    );
  }

  Future<void> _applyAuthoritativeProgress(
    String uid,
    int generation,
    EconomyProgressSnapshot snapshot,
  ) async {
    final serverCleared = snapshot.cleared.toSet();
    final serverMainEvents = snapshot.mainEventsCleared.toSet();
    if (_economyApi.isConfigured) {
      _cleared
        ..clear()
        ..addAll(serverCleared);
      _mainEventsCleared
        ..clear()
        ..addAll(serverMainEvents);
      _pendingCleared.clear();
      _pendingMainEvents.clear();
      await _writeAuthorityCache(uid, snapshot);
      return;
    }

    _cleared
      ..addAll(serverCleared)
      ..addAll(_pendingCleared);
    _mainEventsCleared
      ..addAll(serverMainEvents)
      ..addAll(_pendingMainEvents);

    final acknowledgedCleared = _pendingCleared.intersection(serverCleared);
    final acknowledgedMainEvents =
        _pendingMainEvents.intersection(serverMainEvents);
    if (acknowledgedCleared.isEmpty && acknowledgedMainEvents.isEmpty) {
      return;
    }
    final remaining = await _mutateStoredPending(
      uid,
      removeCleared: acknowledgedCleared,
      removeMainEvents: acknowledgedMainEvents,
    );
    if (!_isCurrentBinding(uid, generation)) return;
    _pendingCleared
      ..removeAll(acknowledgedCleared)
      ..addAll(remaining.cleared);
    _pendingMainEvents
      ..removeAll(acknowledgedMainEvents)
      ..addAll(remaining.mainEvents);
  }

  bool _isCurrentBinding(String uid, int generation) {
    return _uid == uid && _bindingGeneration == generation;
  }

  void _applySnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
    String uid,
    int generation,
  ) {
    if (!_isCurrentBinding(uid, generation)) return;
    final data = snap.data();
    final cleared = data == null ? <String>{} : _stringSetFrom(data['cleared']);
    final mainEvents =
        data == null ? <String>{} : _stringSetFrom(data['mainEventsCleared']);

    // Campaign completion is monotonic. Unioning prevents an older cached
    // snapshot from rolling back a locally queued or just-acknowledged clear.
    _cleared
      ..addAll(cleared)
      ..addAll(_pendingCleared);
    _mainEventsCleared
      ..addAll(mainEvents)
      ..addAll(_pendingMainEvents);
    _hydrated = true;
    notifyListeners();
    unawaited(_requestPendingFlush(uid, generation));
  }

  Set<String> _stringSetFrom(dynamic raw) {
    if (raw is Iterable) {
      return raw.whereType<String>().toSet();
    }
    return <String>{};
  }

  Future<bool> refreshFromAuthority() {
    if (!_economyApi.isConfigured) return Future<bool>.value(true);
    final existing = _authorityRefreshFuture;
    if (existing != null) return existing;
    late final Future<bool> refresh;
    refresh = _refreshFromAuthority().whenComplete(() {
      if (_authorityRefreshFuture == refresh) {
        _authorityRefreshFuture = null;
      }
    });
    _authorityRefreshFuture = refresh;
    return refresh;
  }

  Future<bool> _refreshFromAuthority() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return false;
    final generation = _bindingGeneration;
    final wallet = await _economyApi.walletResult();
    if (!_isCurrentBinding(uid, generation)) return false;
    final snapshot = wallet.progress;
    if (wallet.status != EconomyWalletStatus.loaded || snapshot == null) {
      _authorityUnavailable = true;
      notifyListeners();
      return false;
    }
    _authorityUnavailable = false;
    await _applyAuthoritativeProgress(uid, generation, snapshot);
    if (!_isCurrentBinding(uid, generation)) return false;
    _hydrated = true;
    notifyListeners();
    return true;
  }

  Future<void> applyAuthoritativeSnapshot(
    EconomyProgressSnapshot snapshot,
  ) async {
    if (!_economyApi.isConfigured) return;
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final generation = _bindingGeneration;
    _authorityUnavailable = false;
    await _applyAuthoritativeProgress(uid, generation, snapshot);
    if (!_isCurrentBinding(uid, generation)) return;
    _hydrated = true;
    notifyListeners();
  }

  DocumentReference<Map<String, dynamic>>? _docRef([String? explicitUid]) {
    final uid = explicitUid ?? _uid;
    if (uid == null || uid.trim().isEmpty) return null;
    final db = _dbOrNull();
    if (db == null) return null;
    return db.collection('campaign_progress').doc(uid);
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

  String _pendingKey(String prefix, String uid) {
    final encoded = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return '$prefix.$encoded';
  }

  Future<void> _loadAuthorityCache(String uid, int generation) async {
    if (_purgedUserIds.contains(uid)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          prefs.getString(_pendingKey(_authorityCacheKeyPrefix, uid));
      if (encoded == null || encoded.isEmpty) return;
      final decoded = jsonDecode(encoded);
      if (decoded is! Map || !_isCurrentBinding(uid, generation)) return;
      _cleared
        ..clear()
        ..addAll(_stringSetFrom(decoded['cleared']));
      _mainEventsCleared
        ..clear()
        ..addAll(_stringSetFrom(decoded['mainEventsCleared']));
    } catch (error) {
      debugPrint('Failed to load authoritative campaign cache: $error');
    }
  }

  Future<void> _writeAuthorityCache(
    String uid,
    EconomyProgressSnapshot snapshot,
  ) async {
    if (_purgedUserIds.contains(uid)) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_purgedUserIds.contains(uid)) return;
      final cleared = snapshot.cleared.toSet().toList()..sort();
      final mainEvents = snapshot.mainEventsCleared.toSet().toList()..sort();
      await prefs.setString(
        _pendingKey(_authorityCacheKeyPrefix, uid),
        jsonEncode(<String, Object>{
          'catalogVersion': snapshot.catalogVersion,
          'cleared': cleared,
          'mainEventsCleared': mainEvents,
        }),
      );
    } catch (error) {
      debugPrint('Failed to persist authoritative campaign cache: $error');
    }
  }

  Future<T> _withPendingStorage<T>(
    String uid,
    Future<T> Function() operation,
  ) {
    final result = Completer<T>();
    final previous = _pendingStorageTails[uid] ?? Future<void>.value();
    late final Future<void> current;
    current = previous.then<void>((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    }).whenComplete(() {
      if (identical(_pendingStorageTails[uid], current)) {
        _pendingStorageTails.remove(uid);
      }
    });
    _pendingStorageTails[uid] = current;
    return result.future;
  }

  _PendingCampaignProgress _readPending(
    SharedPreferences prefs,
    String uid,
  ) {
    final pending = _PendingCampaignProgress();
    final encoded = prefs.getString(_pendingKey(_pendingOutboxKeyPrefix, uid));
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map) {
          pending.cleared.addAll(_stringSetFrom(decoded['cleared']));
          pending.mainEvents.addAll(
            _stringSetFrom(decoded['mainEventsCleared']),
          );
        }
      } catch (e) {
        debugPrint('Failed to decode pending campaign progress: $e');
      }
    }

    // Import the short-lived v1 two-key format. The next successful mutation
    // rewrites it as one record, avoiding partial and stale overwrites.
    pending.cleared.addAll(
      prefs.getStringList(_pendingKey(_pendingClearedKeyPrefix, uid)) ??
          const <String>[],
    );
    pending.mainEvents.addAll(
      prefs.getStringList(_pendingKey(_pendingMainEventsKeyPrefix, uid)) ??
          const <String>[],
    );
    return pending;
  }

  Future<void> _writePending(
    SharedPreferences prefs,
    String uid,
    _PendingCampaignProgress pending,
  ) async {
    if (_purgedUserIds.contains(uid)) return;
    final cleared = pending.cleared.toList()..sort();
    final mainEvents = pending.mainEvents.toList()..sort();
    final saved = await prefs.setString(
      _pendingKey(_pendingOutboxKeyPrefix, uid),
      jsonEncode(<String, Object>{
        'cleared': cleared,
        'mainEventsCleared': mainEvents,
      }),
    );
    if (!saved) {
      throw StateError('SharedPreferences rejected campaign progress write.');
    }

    await prefs.remove(_pendingKey(_pendingClearedKeyPrefix, uid));
    await prefs.remove(_pendingKey(_pendingMainEventsKeyPrefix, uid));
  }

  Future<_PendingCampaignProgress> _mutateStoredPending(
    String uid, {
    Iterable<String> addCleared = const <String>[],
    Iterable<String> addMainEvents = const <String>[],
    Iterable<String> removeCleared = const <String>[],
    Iterable<String> removeMainEvents = const <String>[],
  }) {
    if (_purgedUserIds.contains(uid)) {
      return Future<_PendingCampaignProgress>.value(
        _PendingCampaignProgress(),
      );
    }
    return _withPendingStorage(uid, () async {
      final prefs = await SharedPreferences.getInstance();
      final pending = _readPending(prefs, uid);
      pending.cleared
        ..addAll(addCleared)
        ..removeAll(removeCleared);
      pending.mainEvents
        ..addAll(addMainEvents)
        ..removeAll(removeMainEvents);
      await _writePending(prefs, uid, pending);
      return pending;
    });
  }

  Future<void> _loadPending(String uid, int generation) async {
    if (_purgedUserIds.contains(uid)) return;
    try {
      final pending = await _withPendingStorage(uid, () async {
        final prefs = await SharedPreferences.getInstance();
        return _readPending(prefs, uid);
      });
      if (!_isCurrentBinding(uid, generation)) return;
      _pendingCleared.addAll(pending.cleared);
      _pendingMainEvents.addAll(pending.mainEvents);
      _cleared.addAll(_pendingCleared);
      _mainEventsCleared.addAll(_pendingMainEvents);
    } catch (e) {
      debugPrint('Failed to load pending campaign progress: $e');
    }
  }

  Future<void> _queuePending({
    required String uid,
    String? clearedId,
    String? mainEventId,
  }) async {
    if (clearedId != null) _pendingCleared.add(clearedId);
    if (mainEventId != null) _pendingMainEvents.add(mainEventId);
    await _mutateStoredPending(
      uid,
      addCleared: clearedId == null ? const <String>[] : <String>[clearedId],
      addMainEvents:
          mainEventId == null ? const <String>[] : <String>[mainEventId],
    );
  }

  Future<void> _requestPendingFlush(String uid, int generation) {
    if (_economyApi.isConfigured) return Future<void>.value();
    final existing = _flushFuture;
    if (existing != null) return existing;

    late final Future<void> flush;
    flush = _flushPending(uid, generation).whenComplete(() {
      if (_flushFuture == flush) _flushFuture = null;
    });
    _flushFuture = flush;
    return flush;
  }

  Future<void> _flushPending(String uid, int generation) async {
    if (!_isCurrentBinding(uid, generation)) return;
    final doc = _docRef(uid);
    if (doc == null) return;

    final cleared = Set<String>.from(_pendingCleared);
    final mainEvents = Set<String>.from(_pendingMainEvents);
    if (cleared.isEmpty && mainEvents.isEmpty) return;

    try {
      await doc.set(
        <String, dynamic>{
          'schemaVersion': _schemaVersion,
          if (cleared.isNotEmpty)
            'cleared': FieldValue.arrayUnion(cleared.toList()),
          if (mainEvents.isNotEmpty)
            'mainEventsCleared': FieldValue.arrayUnion(mainEvents.toList()),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      final remaining = await _mutateStoredPending(
        uid,
        removeCleared: cleared,
        removeMainEvents: mainEvents,
      );
      if (!_isCurrentBinding(uid, generation)) return;

      _pendingCleared
        ..removeAll(cleared)
        ..addAll(remaining.cleared);
      _pendingMainEvents
        ..removeAll(mainEvents)
        ..addAll(remaining.mainEvents);
      if (_pendingCleared.isNotEmpty || _pendingMainEvents.isNotEmpty) {
        await _flushPending(uid, generation);
      }
    } catch (e) {
      debugPrint('Failed to flush pending campaign progress: $e');
    }
  }

  String subKingdomId({
    required VenueGroup group,
    required String kingdomName,
    required int subKingdomIndex,
  }) {
    final k = _slug(kingdomName);
    final i = subKingdomIndex < 1 ? 1 : subKingdomIndex;
    return 'sk:${group.name}:$k:$i';
  }

  bool isCleared({
    required VenueGroup group,
    required String kingdomName,
    required int subKingdomIndex,
  }) {
    return _cleared.contains(subKingdomId(
      group: group,
      kingdomName: kingdomName,
      subKingdomIndex: subKingdomIndex,
    ));
  }

  int clearedCount({
    required VenueGroup group,
    required String kingdomName,
  }) {
    final total = subKingdomCountFor(group: group, kingdomName: kingdomName);
    int count = 0;
    for (int i = 1; i <= total; i++) {
      if (isCleared(
          group: group, kingdomName: kingdomName, subKingdomIndex: i)) {
        count++;
      }
    }
    return count;
  }

  bool hasClearedAllSubKingdoms({
    required VenueGroup group,
    required String kingdomName,
  }) {
    final total = subKingdomCountFor(group: group, kingdomName: kingdomName);
    return clearedCount(group: group, kingdomName: kingdomName) >= total;
  }

  String mainEventId({
    required VenueGroup group,
    required String kingdomName,
  }) {
    final k = _slug(kingdomName);
    return 'me:${group.name}:$k';
  }

  bool isMainEventCleared({
    required VenueGroup group,
    required String kingdomName,
  }) {
    return _mainEventsCleared.contains(mainEventId(
      group: group,
      kingdomName: kingdomName,
    ));
  }

  Future<void> markMainEventCleared({
    required VenueGroup group,
    required String kingdomName,
  }) async {
    if (_economyApi.isConfigured) {
      await refreshFromAuthority();
      return;
    }
    final id = mainEventId(group: group, kingdomName: kingdomName);
    if (_mainEventsCleared.add(id)) {
      notifyListeners();
      final uid = _uid;
      if (uid == null || uid.isEmpty) return;
      final generation = _bindingGeneration;
      await _queuePending(uid: uid, mainEventId: id);
      unawaited(_requestPendingFlush(uid, generation));
    }
  }

  bool hasTitle({
    required VenueGroup group,
    required String kingdomName,
  }) {
    return hasClearedAllSubKingdoms(group: group, kingdomName: kingdomName) &&
        isMainEventCleared(group: group, kingdomName: kingdomName);
  }

  bool isUnlocked({
    required VenueGroup group,
    required String kingdomName,
    required int subKingdomIndex,
  }) {
    final int count = subKingdomCountFor(
      group: group,
      kingdomName: kingdomName,
    );
    final int index = subKingdomIndex < 1 ? 1 : subKingdomIndex;
    return index <= count;
  }

  Future<void> markCleared({
    required VenueGroup group,
    required String kingdomName,
    required int subKingdomIndex,
  }) async {
    if (_economyApi.isConfigured) {
      await refreshFromAuthority();
      return;
    }
    final id = subKingdomId(
      group: group,
      kingdomName: kingdomName,
      subKingdomIndex: subKingdomIndex,
    );
    if (_cleared.add(id)) {
      notifyListeners();
      final uid = _uid;
      if (uid == null || uid.isEmpty) return;
      final generation = _bindingGeneration;
      await _queuePending(uid: uid, clearedId: id);
      unawaited(_requestPendingFlush(uid, generation));
    }
  }

  int titlesEarned(VenueGroup group) {
    final venues = venuesForGroup(group);
    int count = 0;
    for (final v in venues) {
      if (hasTitle(group: group, kingdomName: v.name)) count++;
    }
    return count;
  }

  /// Forts cleared across every kingdom of every circuit.
  ///
  /// Backs the home-screen conquest challenge, which measures a player
  /// against the whole map rather than the kingdom they happen to be in.
  int totalClearedCount() {
    int total = 0;
    for (final group in kVenueGroups) {
      for (final v in venuesForGroup(group)) {
        total += clearedCount(group: group, kingdomName: v.name);
      }
    }
    return total;
  }

  /// Titles held across every circuit — one per fully conquered kingdom.
  int totalTitlesEarned() {
    int total = 0;
    for (final group in kVenueGroups) {
      total += titlesEarned(group);
    }
    return total;
  }

  static String _slug(String raw) {
    final lower = raw.trim().toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return replaced.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  @visibleForTesting
  Future<void> acknowledgePendingForTesting({
    required String uid,
    Iterable<String> cleared = const <String>[],
    Iterable<String> mainEvents = const <String>[],
  }) async {
    await _mutateStoredPending(
      uid,
      removeCleared: cleared,
      removeMainEvents: mainEvents,
    );
  }

  /// Removes all device-local career caches and outbox rows for a deleted
  /// account. Existing queued storage work is allowed to drain first and is
  /// prevented from writing once the account is marked purged.
  Future<void> purgeLocalDataForUser(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return;
    _purgedUserIds.add(normalizedUid);
    if (_uid == normalizedUid) bindUserId(null);

    final pendingTail = _pendingStorageTails[normalizedUid];
    if (pendingTail != null) {
      try {
        await pendingTail;
      } catch (_) {
        // Removal below is still required if an older cache write failed.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await Future.wait<bool>(<Future<bool>>[
      prefs.remove(_pendingKey(_pendingOutboxKeyPrefix, normalizedUid)),
      prefs.remove(_pendingKey(_pendingClearedKeyPrefix, normalizedUid)),
      prefs.remove(_pendingKey(_pendingMainEventsKeyPrefix, normalizedUid)),
      prefs.remove(_pendingKey(_authorityCacheKeyPrefix, normalizedUid)),
    ]);
  }

  @override
  void dispose() {
    _bindingGeneration++;
    _uid = null;
    _flushFuture = null;
    _authorityRefreshFuture = null;
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }
}

class _PendingCampaignProgress {
  final Set<String> cleared = <String>{};
  final Set<String> mainEvents = <String>{};
}
