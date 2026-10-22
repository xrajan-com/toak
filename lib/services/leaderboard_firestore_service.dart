import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:ten_of_a_kind_poker/core/aup.dart' as aup;
import 'package:ten_of_a_kind_poker/services/api_client.dart';
import 'package:ten_of_a_kind_poker/services/aura_points_service.dart';

@immutable
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final int auraMilli;
  final int totalAup;
  final int activityScore;

  /// Forts cleared out of the 500, on Trailblazers rows. 0 on Aura rows.
  final int fortsCleared;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.auraMilli,
    required this.totalAup,
    required this.activityScore,
    this.fortsCleared = 0,
  });

  int get cappedAuraMilli => auraMilli.clamp(
        0,
        aup.kAupMaxAuraTotal * aup.kAuraMilliPerAura,
      );

  double get aura => cappedAuraMilli / 1000.0;
}

/// Where the signed-in player stands on Trailblazers.
///
/// [rank] is their place among every named player (ties share a place), or
/// null before their first fort. [named] is false for an account that never
/// set a player name: it stays off the board, and [rank] is where it would
/// stand once it has one.
@immutable
class TrailStanding {
  final int fortsCleared;
  final int fortTotal;
  final int? rank;
  final bool named;

  const TrailStanding({
    required this.fortsCleared,
    required this.fortTotal,
    required this.rank,
    required this.named,
  });

  /// In the top ten, so already on the board above.
  bool get onBoard => named && rank != null && rank! <= 10;

  factory TrailStanding.fromJson(Map<String, dynamic> json) {
    int whole(Object? raw) => raw is num && raw.isFinite ? raw.toInt() : 0;
    final forts = whole(json['fortsCleared']);
    final rawRank = whole(json['rank']);
    return TrailStanding(
      fortsCleared: forts < 0 ? 0 : forts,
      fortTotal: whole(json['fortTotal']),
      rank: forts > 0 && rawRank > 0 ? rawRank : null,
      named: json['named'] == true,
    );
  }
}

class LeaderboardLoadException implements Exception {
  final String message;
  final Object? cause;

  const LeaderboardLoadException(this.message, {this.cause});

  @override
  String toString() => 'LeaderboardLoadException: $message';
}

class LeaderboardFirestoreService {
  static const String kCollection = 'leaderboard';

  /// Top ten by forts cleared, kept by the backend on every fort clear.
  static const String kTrailblazersCollection = 'trailblazers';
  static const String _firestoreProjectId = 'ten-of-a-kind-poker';
  static const int _auraMilliMultiplier = 2000000000;
  static const int _activityMultiplier = 100000;
  static const int _efficiencyMultiplier = 45000;
  static const int _finishMultiplier = 50000;

  final ApiClient _apiClient;
  final http.Client _httpClient;

  LeaderboardFirestoreService({
    ApiClient? apiClient,
    http.Client? httpClient,
  })  : _apiClient = apiClient ?? ApiClient(),
        _httpClient = httpClient ?? http.Client();

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

    if (_apiClient.isConfigured) {
      // The authoritative backend updates Aura membership only when Aura
      // changes. Opening a leaderboard is deliberately read-only.
      return;
    }

    await _syncCurrentUserClientSide(user: user, wallet: wallet);
  }

  String _displayNameFor(User user) {
    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName.length <= 40
          ? displayName
          : displayName.substring(0, 40);
    }

    final email = user.email?.trim();
    if (email != null && email.contains('@')) {
      final localPart = email.split('@').first.trim();
      if (localPart.isNotEmpty) {
        return localPart.length <= 40 ? localPart : localPart.substring(0, 40);
      }
    }

    return 'Player';
  }

  int _rankScoreFor(AuraPointsService wallet) {
    final auraMilli = wallet.totalAuraMilli
        .clamp(
          0,
          aup.kAupMaxAuraTotal * aup.kAuraMilliPerAura,
        )
        .toInt();
    final efficiency = wallet.auraMilliPerMatch.clamp(0, 20000).toInt();
    final finishSkill =
        (1000 - wallet.avgFinishPermille).clamp(0, 1000).toInt();
    final lastActiveAt = wallet.lastActiveAtUtc;
    final lastActiveDay = lastActiveAt == null
        ? 0
        : lastActiveAt.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

    return (auraMilli * _auraMilliMultiplier) +
        (efficiency * _efficiencyMultiplier) +
        (finishSkill * _finishMultiplier) +
        (wallet.activityScore * _activityMultiplier) +
        lastActiveDay;
  }

  Future<void> _syncCurrentUserClientSide({
    required User user,
    required AuraPointsService wallet,
  }) async {
    final db = _firestoreOrNull();
    if (db == null) return;

    final ref = db.collection(kCollection).doc(user.uid);
    if (wallet.totalAuraMilli <= 0) {
      await ref.delete();
      return;
    }

    await ref.set(
      <String, Object?>{
        'displayName': _displayNameFor(user),
        'auraMilli': wallet.totalAuraMilli,
        'totalAup': wallet.totalAup,
        'activityScore': wallet.activityScore,
        'matchesPlayed': wallet.matchesPlayed,
        'auraMilliPerMatch': wallet.auraMilliPerMatch,
        'avgFinishPermille': wallet.avgFinishPermille,
        'rankScore': _rankScoreFor(wallet),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<List<LeaderboardEntry>> fetchTop10() async {
    if (kIsWeb) return _fetchTop10FromPublicRest(orderBy: 'rankScore');

    final db = _firestoreOrNull();
    if (db == null) {
      throw const LeaderboardLoadException(
        'Leaderboard service is unavailable.',
      );
    }

    try {
      final snap = await db
          .collection(kCollection)
          .orderBy('rankScore', descending: true)
          .limit(10)
          .get();

      return snap.docs
          .map(_entryFromDoc)
          .where((entry) => entry.auraMilli > 0)
          .toList(growable: false);
    } catch (error) {
      debugPrint('Leaderboard fetch failed: $error');
      throw LeaderboardLoadException(
        'Could not load the leaderboard.',
        cause: error,
      );
    }
  }

  Future<List<LeaderboardEntry>> fetchTop10ByAura() async {
    if (kIsWeb) return _fetchTop10FromPublicRest(orderBy: 'auraMilli');

    final db = _firestoreOrNull();
    if (db == null) {
      throw const LeaderboardLoadException(
        'Leaderboard service is unavailable.',
      );
    }

    try {
      final snap = await db
          .collection(kCollection)
          .orderBy('auraMilli', descending: true)
          .limit(10)
          .get();

      return snap.docs
          .map(_entryFromDoc)
          .where((entry) => entry.auraMilli > 0)
          .toList(growable: false);
    } catch (error) {
      debugPrint('Aura leaderboard fetch failed: $error');
      throw LeaderboardLoadException(
        'Could not load the Aura leaderboard.',
        cause: error,
      );
    }
  }

  /// Trailblazers: the ten players with the most forts cleared, most first
  /// (ties go to more Aura; the backend's trailScore already orders them).
  Future<List<LeaderboardEntry>> fetchTrailblazers() async {
    if (kIsWeb) {
      return _fetchTop10FromPublicRest(
        orderBy: 'trailScore',
        collection: kTrailblazersCollection,
      );
    }

    final db = _firestoreOrNull();
    if (db == null) {
      throw const LeaderboardLoadException(
        'Leaderboard service is unavailable.',
      );
    }

    try {
      final snap = await db
          .collection(kTrailblazersCollection)
          .orderBy('trailScore', descending: true)
          .limit(10)
          .get();

      return snap.docs
          .map(_entryFromDoc)
          .where((entry) => entry.fortsCleared > 0)
          .toList(growable: false);
    } catch (error) {
      debugPrint('Trailblazers fetch failed: $error');
      throw LeaderboardLoadException(
        'Could not load the Trailblazers.',
        cause: error,
      );
    }
  }

  /// The signed-in player's own Trailblazers standing, from the backend.
  /// Null for a guest, without a backend, or when it cannot be reached:
  /// the board still shows, just without the player's own row.
  Future<TrailStanding?> fetchMyTrailStanding() async {
    final user = _authOrNull()?.currentUser;
    if (user == null || user.isAnonymous || !_apiClient.isConfigured) {
      return null;
    }
    try {
      final response = await _apiClient.get('/v1/leaderboard/trailblazers/me');
      if (response is! Map<String, dynamic> || response['ok'] != true) {
        return null;
      }
      return TrailStanding.fromJson(response);
    } catch (error) {
      debugPrint('Trailblazers standing fetch failed: $error');
      return null;
    }
  }

  Future<List<LeaderboardEntry>> _fetchTop10FromPublicRest({
    required String orderBy,
    String collection = kCollection,
  }) async {
    final trailblazers = collection == kTrailblazersCollection;
    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$_firestoreProjectId/databases/(default)/documents/'
          '$collection',
      <String, String>{
        'pageSize': '10',
        'orderBy': '$orderBy desc',
      },
    );

    try {
      final response = await _httpClient.get(uri).timeout(
            const Duration(seconds: 12),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw http.ClientException(
          'Public leaderboard returned ${response.statusCode}.',
          uri,
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid leaderboard response.');
      }
      final documents = decoded['documents'];
      if (documents == null) return const <LeaderboardEntry>[];
      if (documents is! List) {
        throw const FormatException('Invalid leaderboard documents.');
      }

      return documents
          .whereType<Map>()
          .map((document) => _entryFromRestDocument(
                Map<String, dynamic>.from(document),
              ))
          .where((entry) =>
              trailblazers ? entry.fortsCleared > 0 : entry.auraMilli > 0)
          .take(10)
          .toList(growable: false);
    } catch (error) {
      debugPrint('Public leaderboard REST fetch failed: $error');
      throw LeaderboardLoadException(
        trailblazers
            ? 'Could not load the Trailblazers.'
            : 'Could not load the Aura leaderboard.',
        cause: error,
      );
    }
  }

  @visibleForTesting
  Future<List<LeaderboardEntry>> fetchTop10FromPublicRestForTesting({
    String orderBy = 'auraMilli',
    String collection = kCollection,
  }) {
    return _fetchTop10FromPublicRest(orderBy: orderBy, collection: collection);
  }

  LeaderboardEntry _entryFromRestDocument(Map<String, dynamic> document) {
    final name = document['name']?.toString() ?? '';
    final rawFields = document['fields'];
    final fields = rawFields is Map
        ? Map<String, dynamic>.from(rawFields)
        : const <String, dynamic>{};
    final legacyAura = _restInt(fields['aura']);
    final auraMilli = _restInt(
      fields['auraMilli'],
      fallback: legacyAura * 1000,
    );

    return LeaderboardEntry(
      uid: name.split('/').last,
      displayName: _restString(fields['displayName'], fallback: 'Player'),
      auraMilli: auraMilli,
      totalAup: _restInt(fields['totalAup']),
      activityScore: _restInt(fields['activityScore']),
      fortsCleared: _restInt(fields['fortsCleared']),
    );
  }

  static int _restInt(Object? field, {int fallback = 0}) {
    if (field is! Map) return fallback;
    final value = field['integerValue'] ?? field['doubleValue'];
    return switch (value) {
      int number => number,
      num number => number.toInt(),
      String text =>
        int.tryParse(text) ?? double.tryParse(text)?.toInt() ?? fallback,
      _ => fallback,
    };
  }

  static String _restString(Object? field, {required String fallback}) {
    if (field is! Map) return fallback;
    final value = field['stringValue']?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  LeaderboardEntry _entryFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final int legacyAura = _numToInt(data['aura']);
    final int auraMilli =
        _numToInt(data['auraMilli'], fallback: legacyAura * 1000);
    return LeaderboardEntry(
      uid: doc.id,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? (data['displayName'] as String).trim()
          : 'Player',
      auraMilli: auraMilli,
      totalAup: _numToInt(data['totalAup']),
      activityScore: _numToInt(data['activityScore']),
      fortsCleared: _numToInt(data['fortsCleared']),
    );
  }
}

final leaderboardFirestoreService = LeaderboardFirestoreService();
