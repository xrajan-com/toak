import 'package:flutter/foundation.dart';
import 'package:ten_of_a_kind_poker/config/economy_catalog_version.dart';
import 'package:ten_of_a_kind_poker/config/venues.dart' show VenueGroup;
import 'package:ten_of_a_kind_poker/services/api_client.dart';

class EconomyProgressSnapshot {
  final int walletVersion;
  final int indiaAup;
  final int internationalAup;
  final int euroAup;
  final int oceaniaAup;
  final int northAmericaAup;
  final List<String> awardedEventIds;
  final List<String> cleared;
  final List<String> mainEventsCleared;
  final int lastActiveAtMs;
  final int prevActiveAtMs;
  final String lastActiveDayKey;
  final int activityScore;
  final int abandonedGames;
  final int matchesPlayed;
  final int finishPermilleSum;
  final bool registeredStarterGranted;
  final int legacyMigrationVersion;
  final String catalogVersion;

  const EconomyProgressSnapshot({
    this.walletVersion = 0,
    required this.indiaAup,
    required this.internationalAup,
    this.euroAup = 0,
    this.oceaniaAup = 0,
    this.northAmericaAup = 0,
    required this.awardedEventIds,
    this.cleared = const <String>[],
    this.mainEventsCleared = const <String>[],
    required this.lastActiveAtMs,
    required this.prevActiveAtMs,
    required this.lastActiveDayKey,
    required this.activityScore,
    required this.abandonedGames,
    required this.matchesPlayed,
    required this.finishPermilleSum,
    required this.registeredStarterGranted,
    this.legacyMigrationVersion = 0,
    this.catalogVersion = '',
  });

  factory EconomyProgressSnapshot.fromJson(Map<String, dynamic> json) {
    return EconomyProgressSnapshot(
      walletVersion: _int(json['walletVersion']),
      indiaAup: _int(json['indiaAup']),
      internationalAup: _int(json['internationalAup']),
      euroAup: _int(json['euroAup']),
      oceaniaAup: _int(json['oceaniaAup']),
      northAmericaAup: _int(json['northAmericaAup']),
      awardedEventIds: _strings(json['awardedEventIds']),
      cleared: _strings(json['cleared']),
      mainEventsCleared: _strings(json['mainEventsCleared']),
      lastActiveAtMs: _int(json['lastActiveAtMs']),
      prevActiveAtMs: _int(json['prevActiveAtMs']),
      lastActiveDayKey: (json['lastActiveDayKey'] as String?) ?? '',
      activityScore: _int(json['activityScore']),
      abandonedGames: _int(json['abandonedGames']),
      matchesPlayed: _int(json['matchesPlayed']),
      finishPermilleSum: _int(json['finishPermilleSum']),
      registeredStarterGranted: json['registeredStarterGranted'] == true,
      legacyMigrationVersion: _int(json['legacyMigrationVersion']),
      catalogVersion: (json['catalogVersion'] as String?) ?? '',
    );
  }

  static int _int(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return 0;
  }

  static List<String> _strings(Object? raw) {
    return (raw as Iterable?)?.whereType<String>().toList(growable: false) ??
        const <String>[];
  }
}

enum EconomyWalletStatus {
  loaded,
  notFound,
  unavailable,
  unauthenticated,
  malformed,
  incompatibleCatalog,
  migrationPending,
}

class EconomyWalletResult {
  final EconomyWalletStatus status;
  final EconomyProgressSnapshot? progress;
  final ApiException? error;

  const EconomyWalletResult({
    required this.status,
    this.progress,
    this.error,
  });

  bool get isConclusive =>
      status == EconomyWalletStatus.loaded ||
      status == EconomyWalletStatus.notFound;
}

enum EconomyOperationStatus {
  accepted,
  insufficientFunds,
  unavailable,
  unauthenticated,
  invalidCatalog,
  migrationPending,
  campaignLocked,
  notFound,
  conflict,
  rejected,
}

class EntryReservationSnapshot {
  final String attemptId;
  final String campaignId;
  final VenueGroup group;
  final int amount;
  final String status;

  const EntryReservationSnapshot({
    required this.attemptId,
    required this.campaignId,
    required this.group,
    required this.amount,
    required this.status,
  });

  factory EntryReservationSnapshot.fromJson(Map<String, dynamic> json) {
    final groupName = json['group']?.toString() ?? '';
    final group = VenueGroup.values.firstWhere(
      (candidate) => candidate.name == groupName,
      orElse: () => VenueGroup.india,
    );
    return EntryReservationSnapshot(
      attemptId: json['attemptId']?.toString() ?? '',
      campaignId: json['campaignId']?.toString() ?? '',
      group: group,
      amount: EconomyProgressSnapshot._int(json['amount']),
      status: json['status']?.toString() ?? '',
    );
  }
}

class EconomyEventResult {
  final bool accepted;
  final bool duplicate;
  final int delta;
  final int payoutDelta;
  final int penaltyDelta;
  final bool clearRecorded;
  final bool matchRecorded;
  final String reason;
  final EconomyProgressSnapshot progress;
  final EntryReservationSnapshot? reservation;

  const EconomyEventResult({
    required this.accepted,
    required this.duplicate,
    required this.delta,
    this.payoutDelta = 0,
    this.penaltyDelta = 0,
    this.clearRecorded = false,
    this.matchRecorded = false,
    this.reason = '',
    required this.progress,
    this.reservation,
  });
}

class EconomyOperationResult {
  final EconomyOperationStatus status;
  final bool duplicate;
  final int delta;
  final int payoutDelta;
  final int penaltyDelta;
  final bool clearRecorded;
  final bool matchRecorded;
  final String reason;
  final EconomyProgressSnapshot? progress;
  final EntryReservationSnapshot? reservation;
  final ApiException? error;

  const EconomyOperationResult({
    required this.status,
    this.duplicate = false,
    this.delta = 0,
    this.payoutDelta = 0,
    this.penaltyDelta = 0,
    this.clearRecorded = false,
    this.matchRecorded = false,
    this.reason = '',
    this.progress,
    this.reservation,
    this.error,
  });

  bool get accepted => status == EconomyOperationStatus.accepted;
}

class EconomyApiService {
  static const bool _allowLocalEconomyInRelease =
      bool.fromEnvironment('ALLOW_LOCAL_ECONOMY_DEV');

  final ApiClient _apiClient;

  EconomyApiService({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  bool get isConfigured => _apiClient.isConfigured;

  /// Local wallets are a debug/test facility. A release build without a
  /// backend is fail-closed unless an engineer deliberately opts into the
  /// non-production development mode at compile time.
  bool get allowsLocalEconomyFallback =>
      !kReleaseMode || _allowLocalEconomyInRelease;

  /// Compatibility surface for tests and older callers.
  Future<EconomyProgressSnapshot?> wallet() async {
    final response = await _apiClient.get('/v1/economy/wallet');
    if (response is Map<String, dynamic> && response['exists'] != true) {
      return null;
    }
    final progress = _progressMap(response);
    if (progress == null) {
      throw const ApiException(
        kind: ApiFailureKind.malformedResponse,
        message: 'The wallet response was invalid.',
      );
    }
    return EconomyProgressSnapshot.fromJson(progress);
  }

  Future<EconomyWalletResult> walletResult() async {
    try {
      final progress = await wallet();
      if (progress != null && !_isCatalogCompatible(progress)) {
        return const EconomyWalletResult(
          status: EconomyWalletStatus.incompatibleCatalog,
          error: ApiException(
            kind: ApiFailureKind.malformedResponse,
            message: 'The app economy catalog does not match the server.',
            code: 'catalog_version_mismatch',
          ),
        );
      }
      if (progress != null && !_isMigrationComplete(progress)) {
        return const EconomyWalletResult(
          status: EconomyWalletStatus.migrationPending,
          error: ApiException(
            kind: ApiFailureKind.server,
            message: 'The account economy migration is not complete.',
            code: 'economy_migration_pending',
          ),
        );
      }
      return EconomyWalletResult(
        status: progress == null
            ? EconomyWalletStatus.notFound
            : EconomyWalletStatus.loaded,
        progress: progress,
      );
    } on ApiException catch (error) {
      debugPrint('Economy wallet fetch unavailable: ${error.kind.name}');
      return EconomyWalletResult(
        status: error.kind == ApiFailureKind.unauthenticated
            ? EconomyWalletStatus.unauthenticated
            : error.kind == ApiFailureKind.malformedResponse
                ? EconomyWalletStatus.malformed
                : EconomyWalletStatus.unavailable,
        error: error,
      );
    } catch (error) {
      debugPrint('Economy wallet fetch unavailable: $error');
      return const EconomyWalletResult(
        status: EconomyWalletStatus.unavailable,
      );
    }
  }

  /// Compatibility surface for existing test doubles.
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
    final body = <String, dynamic>{
      'action': action,
      'group': group.name,
      if (eventId.trim().isNotEmpty) 'eventId': eventId.trim(),
      if (campaignId != null && campaignId.trim().isNotEmpty)
        'campaignId': campaignId.trim(),
      if (entryAttemptId != null && entryAttemptId.trim().isNotEmpty)
        'entryAttemptId': entryAttemptId.trim(),
      if (placement != null) 'placement': placement,
      if (amount != null) 'amount': amount,
      if (heroWon != null) 'heroWon': heroWon,
      if (finishRank != null) 'finishRank': finishRank,
      if (totalPlayers != null) 'totalPlayers': totalPlayers,
    };
    final response = await _apiClient.post('/v1/economy/events', body);
    return _eventResult(response);
  }

  Future<EconomyOperationResult> applyEventOutcome({
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
    try {
      final result = await applyEvent(
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
      if (result == null) {
        return const EconomyOperationResult(
          status: EconomyOperationStatus.unavailable,
          reason: 'empty_response',
        );
      }
      return _operationFromEvent(result);
    } on ApiException catch (error) {
      return _operationFromError(error);
    } catch (error) {
      debugPrint('Economy event "$action" unavailable: $error');
      return const EconomyOperationResult(
        status: EconomyOperationStatus.unavailable,
      );
    }
  }

  Future<EconomyOperationResult> reserveEntry({
    required String campaignId,
    required String attemptId,
  }) {
    return _entryOperation(
      '/v1/economy/entries/reserve',
      <String, dynamic>{
        'campaignId': campaignId,
        'attemptId': attemptId,
      },
    );
  }

  Future<EconomyOperationResult> commitEntry({
    required String attemptId,
  }) {
    return _entryOperation(
      '/v1/economy/entries/commit',
      <String, dynamic>{'attemptId': attemptId},
    );
  }

  Future<EconomyOperationResult> refundEntry({
    required String attemptId,
  }) {
    return _entryOperation(
      '/v1/economy/entries/refund',
      <String, dynamic>{'attemptId': attemptId},
    );
  }

  Future<EconomyOperationResult> recoverCommittedEntry({
    required String attemptId,
  }) {
    return _entryOperation(
      '/v1/economy/entries/recover',
      <String, dynamic>{'attemptId': attemptId},
    );
  }

  Future<EconomyOperationResult> entryStatus({
    required String attemptId,
  }) async {
    try {
      final encoded = Uri.encodeComponent(attemptId);
      final response = await _apiClient.get('/v1/economy/entries/$encoded');
      return _operationFromResponse(response);
    } on ApiException catch (error) {
      return _operationFromError(error);
    } catch (error) {
      debugPrint('Entry status unavailable: $error');
      return const EconomyOperationResult(
        status: EconomyOperationStatus.unavailable,
      );
    }
  }

  Future<EconomyOperationResult> _entryOperation(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _apiClient.post(endpoint, body);
      return _operationFromResponse(response);
    } on ApiException catch (error) {
      return _operationFromError(error);
    } catch (error) {
      debugPrint('Entry operation unavailable: $error');
      return const EconomyOperationResult(
        status: EconomyOperationStatus.unavailable,
      );
    }
  }

  static EconomyEventResult? _eventResult(Object? response) {
    final progress = _progressMap(response);
    if (response is! Map<String, dynamic> || progress == null) return null;
    final reservation = response['reservation'];
    return EconomyEventResult(
      accepted: response['accepted'] == true,
      duplicate: response['duplicate'] == true,
      delta: EconomyProgressSnapshot._int(response['delta']),
      payoutDelta: EconomyProgressSnapshot._int(response['payoutDelta']),
      penaltyDelta: EconomyProgressSnapshot._int(response['penaltyDelta']),
      clearRecorded: response['clearRecorded'] == true,
      matchRecorded: response['matchRecorded'] == true,
      reason: response['reason']?.toString() ?? '',
      progress: EconomyProgressSnapshot.fromJson(progress),
      reservation: reservation is Map<String, dynamic>
          ? EntryReservationSnapshot.fromJson(reservation)
          : null,
    );
  }

  static EconomyOperationResult _operationFromResponse(Object? response) {
    final event = _eventResult(response);
    if (event == null) {
      return const EconomyOperationResult(
        status: EconomyOperationStatus.rejected,
        reason: 'malformed_response',
      );
    }
    return _operationFromEvent(event);
  }

  static EconomyOperationResult _operationFromEvent(
    EconomyEventResult event,
  ) {
    if (!_isCatalogCompatible(event.progress)) {
      return const EconomyOperationResult(
        status: EconomyOperationStatus.invalidCatalog,
        reason: 'catalog_version_mismatch',
      );
    }
    if (!_isMigrationComplete(event.progress)) {
      return const EconomyOperationResult(
        status: EconomyOperationStatus.migrationPending,
        reason: 'economy_migration_pending',
      );
    }
    return EconomyOperationResult(
      status: event.accepted
          ? EconomyOperationStatus.accepted
          : _statusForReason(event.reason),
      duplicate: event.duplicate,
      delta: event.delta,
      payoutDelta: event.payoutDelta,
      penaltyDelta: event.penaltyDelta,
      clearRecorded: event.clearRecorded,
      matchRecorded: event.matchRecorded,
      reason: event.reason,
      progress: event.progress,
      reservation: event.reservation,
    );
  }

  static EconomyOperationResult _operationFromError(ApiException error) {
    return EconomyOperationResult(
      status: switch (error.kind) {
        ApiFailureKind.unauthenticated =>
          EconomyOperationStatus.unauthenticated,
        ApiFailureKind.conflict => EconomyOperationStatus.conflict,
        ApiFailureKind.timeout ||
        ApiFailureKind.network ||
        ApiFailureKind.rateLimited ||
        ApiFailureKind.server =>
          EconomyOperationStatus.unavailable,
        _ => EconomyOperationStatus.rejected,
      },
      reason: error.code ?? error.kind.name,
      error: error,
    );
  }

  static EconomyOperationStatus _statusForReason(String reason) {
    return switch (reason) {
      'insufficient_funds' => EconomyOperationStatus.insufficientFunds,
      'invalid_campaign_event' => EconomyOperationStatus.invalidCatalog,
      'campaign_locked' => EconomyOperationStatus.campaignLocked,
      'reservation_not_found' => EconomyOperationStatus.notFound,
      'attempt_id_conflict' ||
      'active_entry_conflict' =>
        EconomyOperationStatus.conflict,
      _ => EconomyOperationStatus.rejected,
    };
  }

  static Map<String, dynamic>? _progressMap(Object? response) {
    if (response is! Map<String, dynamic>) return null;
    final progress = response['progress'];
    return progress is Map<String, dynamic> ? progress : null;
  }

  static bool _isCatalogCompatible(EconomyProgressSnapshot progress) {
    if (progress.catalogVersion == economyCatalogVersion) return true;
    // Test doubles and local debug backends created before catalog versioning
    // may omit it. Production release responses are always strict.
    return !kReleaseMode && progress.catalogVersion.isEmpty;
  }

  static bool _isMigrationComplete(EconomyProgressSnapshot progress) {
    if (progress.legacyMigrationVersion >= 1) return true;
    // Old test doubles may omit the marker, but production must never consume
    // an account until the field-level legacy merge has completed.
    return !kReleaseMode;
  }
}
