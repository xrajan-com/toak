import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:ten_of_a_kind_poker/config/campaign_events.dart' as ce;
import 'package:ten_of_a_kind_poker/config/sub_kingdoms.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart';

class CampaignProgressService extends ChangeNotifier {
  static const int _schemaVersion = 1;
  final Set<String> _cleared = <String>{};
  final Set<String> _mainEventsCleared = <String>{};
  FirebaseFirestore? _db;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  String? _uid;
  bool _hydrated = false;

  CampaignProgressService({FirebaseFirestore? firestore}) : _db = firestore;

  bool get isHydrated => _hydrated;

  void bindUserId(String? uid) {
    if (_uid == uid) return;
    _uid = uid;
    _cleared.clear();
    _mainEventsCleared.clear();
    _hydrated = false;
    _sub?.cancel();
    _sub = null;
    notifyListeners();

    if (uid == null || uid.trim().isEmpty) return;
    final db = _dbOrNull();
    if (db == null) return;
    final doc = db.collection('campaign_progress').doc(uid);
    _sub = doc.snapshots().listen(
          _applySnapshot,
          onError: (e) => debugPrint('Campaign progress stream error: $e'),
        );
  }

  void _applySnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) {
      _hydrated = true;
      notifyListeners();
      return;
    }

    final cleared = _stringSetFrom(data['cleared']);
    final mainEvents = _stringSetFrom(data['mainEventsCleared']);

    _cleared
      ..clear()
      ..addAll(cleared);
    _mainEventsCleared
      ..clear()
      ..addAll(mainEvents);
    _hydrated = true;
    notifyListeners();
  }

  Set<String> _stringSetFrom(dynamic raw) {
    if (raw is Iterable) {
      return raw.whereType<String>().toSet();
    }
    return <String>{};
  }

  DocumentReference<Map<String, dynamic>>? _docRef() {
    final uid = _uid;
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

  Future<void> _persistCleared(String id) async {
    final doc = _docRef();
    if (doc == null) return;
    try {
      await doc.set(
        {
          'schemaVersion': _schemaVersion,
          'cleared': FieldValue.arrayUnion([id]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Failed to persist cleared sub-kingdom: $e');
    }
  }

  Future<void> _persistMainEvent(String id) async {
    final doc = _docRef();
    if (doc == null) return;
    try {
      await doc.set(
        {
          'schemaVersion': _schemaVersion,
          'mainEventsCleared': FieldValue.arrayUnion([id]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Failed to persist cleared main event: $e');
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

  void markMainEventCleared({
    required VenueGroup group,
    required String kingdomName,
  }) {
    final id = mainEventId(group: group, kingdomName: kingdomName);
    if (_mainEventsCleared.add(id)) {
      notifyListeners();
      unawaited(_persistMainEvent(id));
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
    final i = subKingdomIndex < 1 ? 1 : subKingdomIndex;
    final order = ce.subKingdomIndicesByPrizePool(
      group: group,
      kingdomName: kingdomName,
    );
    final int pos = order.indexOf(i);

    // Free sub-kingdom is the lowest-prize one; keep legacy fallback if we
    // can't resolve an order list.
    if (order.isEmpty) return i == 1;
    if (pos < 0) {
      if (i == 1) return true;
      return isCleared(
        group: group,
        kingdomName: kingdomName,
        subKingdomIndex: i - 1,
      );
    }
    if (pos <= 0) return true;

    final int prev = order[pos - 1];
    return isCleared(
      group: group,
      kingdomName: kingdomName,
      subKingdomIndex: prev,
    );
  }

  void markCleared({
    required VenueGroup group,
    required String kingdomName,
    required int subKingdomIndex,
  }) {
    final id = subKingdomId(
      group: group,
      kingdomName: kingdomName,
      subKingdomIndex: subKingdomIndex,
    );
    if (_cleared.add(id)) {
      notifyListeners();
      unawaited(_persistCleared(id));
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

  static String _slug(String raw) {
    final lower = raw.trim().toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return replaced.replaceAll(RegExp(r'^_+|_+$'), '');
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
