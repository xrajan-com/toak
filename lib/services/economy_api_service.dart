import 'package:flutter/foundation.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart' show VenueGroup;
import 'package:ten_of_a_kind_poker/services/api_client.dart';

class EconomyProgressSnapshot {
  final int indiaAup;
  final int internationalAup;
  final List<String> awardedEventIds;
  final int lastActiveAtMs;
  final int prevActiveAtMs;
  final String lastActiveDayKey;
  final int activityScore;
  final int abandonedGames;
  final int matchesPlayed;
  final int finishPermilleSum;
  final bool registeredStarterGranted;

  const EconomyProgressSnapshot({
    required this.indiaAup,
    required this.internationalAup,
    required this.awardedEventIds,
    required this.lastActiveAtMs,
    required this.prevActiveAtMs,
    required this.lastActiveDayKey,
    required this.activityScore,
    required this.abandonedGames,
    required this.matchesPlayed,
    required this.finishPermilleSum,
    required this.registeredStarterGranted,
  });

  factory EconomyProgressSnapshot.fromJson(Map<String, dynamic> json) {
    return EconomyProgressSnapshot(
      indiaAup: _int(json['indiaAup']),
      internationalAup: _int(json['internationalAup']),
      awardedEventIds: (json['awardedEventIds'] as Iterable?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
      lastActiveAtMs: _int(json['lastActiveAtMs']),
      prevActiveAtMs: _int(json['prevActiveAtMs']),
      lastActiveDayKey: (json['lastActiveDayKey'] as String?) ?? '',
      activityScore: _int(json['activityScore']),
      abandonedGames: _int(json['abandonedGames']),
      matchesPlayed: _int(json['matchesPlayed']),
      finishPermilleSum: _int(json['finishPermilleSum']),
      registeredStarterGranted: json['registeredStarterGranted'] == true,
    );
  }

  static int _int(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }
}

class EconomyEventResult {
  final bool accepted;
  final bool duplicate;
  final int delta;
  final EconomyProgressSnapshot progress;

  const EconomyEventResult({
    required this.accepted,
    required this.duplicate,
    required this.delta,
    required this.progress,
  });
}

class EconomyApiService {
  final ApiClient _apiClient;

  EconomyApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<EconomyProgressSnapshot?> wallet() async {
    try {
      final response = await _apiClient.get('/v1/economy/wallet');
      if (response is Map<String, dynamic> && response['exists'] != true) {
        return null;
      }
      final progress = _progressMap(response);
      return progress == null
          ? null
          : EconomyProgressSnapshot.fromJson(progress);
    } catch (e) {
      debugPrint('Economy wallet fetch skipped: $e');
      return null;
    }
  }

  Future<EconomyEventResult?> applyEvent({
    required String action,
    required VenueGroup group,
    required String eventId,
    int? amount,
    bool? heroWon,
    int? finishRank,
    int? totalPlayers,
  }) async {
    try {
      final body = <String, dynamic>{
        'action': action,
        'group': group.name,
        if (eventId.trim().isNotEmpty) 'eventId': eventId.trim(),
        if (amount != null) 'amount': amount,
        if (heroWon != null) 'heroWon': heroWon,
        if (finishRank != null) 'finishRank': finishRank,
        if (totalPlayers != null) 'totalPlayers': totalPlayers,
      };
      final response = await _apiClient.post('/v1/economy/events', body);
      final progress = _progressMap(response);
      if (response is! Map<String, dynamic> || progress == null) return null;
      return EconomyEventResult(
        accepted: response['accepted'] == true,
        duplicate: response['duplicate'] == true,
        delta: EconomyProgressSnapshot._int(response['delta']),
        progress: EconomyProgressSnapshot.fromJson(progress),
      );
    } catch (e) {
      debugPrint('Economy event "$action" fell back to local state: $e');
      return null;
    }
  }

  static Map<String, dynamic>? _progressMap(Object? response) {
    if (response is! Map<String, dynamic>) return null;
    final progress = response['progress'];
    return progress is Map<String, dynamic> ? progress : null;
  }
}
