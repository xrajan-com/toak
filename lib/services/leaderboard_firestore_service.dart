import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:ten_of_a_kind_poker/services/api_client.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';

@immutable
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int auraMilli;
  final int totalAup;
  final int activityScore;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.auraMilli,
    required this.totalAup,
    required this.activityScore,
  });

  double get aura => auraMilli / 1000.0;
}

class LeaderboardFirestoreService {
  static const String kCollection = 'leaderboard';

  final ApiClient _apiClient;

  LeaderboardFirestoreService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  FirebaseAuth? _authOrNull() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? _firestoreOrNull() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static int _numToInt(Object? v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return fallback;
  }

  Future<void> syncCurrentUserIfTop10({
    required AuraPointsService wallet,
  }) async {
    if (!wallet.isLoaded) return;

    final auth = _authOrNull();
    if (auth == null) return;

    final user = auth.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      await _apiClient.post('/v1/leaderboard/sync', const <String, dynamic>{});
    } catch (e) {
      debugPrint('Leaderboard sync failed: $e');
    }
  }

  Future<List<LeaderboardEntry>> fetchTop10() async {
    final db = _firestoreOrNull();
    if (db == null) return const <LeaderboardEntry>[];

    try {
      final snap = await db
          .collection(kCollection)
          .orderBy('rankScore', descending: true)
          .limit(10)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        final int legacyAura = _numToInt(data['aura']);
        final int auraMilli =
            _numToInt(data['auraMilli'], fallback: legacyAura * 1000);
        return LeaderboardEntry(
          uid: doc.id,
          displayName:
              (data['displayName'] as String?)?.trim().isNotEmpty == true
                  ? (data['displayName'] as String).trim()
                  : 'Player',
          auraMilli: auraMilli,
          totalAup: _numToInt(data['totalAup']),
          activityScore: _numToInt(data['activityScore']),
        );
      }).toList(growable: false);
    } catch (e) {
      debugPrint('Leaderboard fetch failed: $e');
      return const <LeaderboardEntry>[];
    }
  }
}

final leaderboardFirestoreService = LeaderboardFirestoreService();
