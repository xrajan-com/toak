import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:ten_of_a_kind_poker/config/economy_catalog_version.dart';

enum ApiFailureKind {
  notConfigured,
  unauthenticated,
  timeout,
  network,
  rateLimited,
  conflict,
  rejected,
  server,
  malformedResponse,
}

class ApiException implements Exception {
  final ApiFailureKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final String? requestId;
  final Object? cause;

  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.requestId,
    this.cause,
  });

  bool get isRetryable => switch (kind) {
        ApiFailureKind.timeout ||
        ApiFailureKind.network ||
        ApiFailureKind.rateLimited ||
        ApiFailureKind.server =>
          true,
        _ => false,
      };

  @override
  String toString() {
    final requestSuffix =
        requestId == null || requestId!.isEmpty ? '' : ' [$requestId]';
    return 'ApiException(${kind.name}): $message$requestSuffix';
  }
}

class AccountDeletionResult {
  final bool deleted;
  final String? requestId;

  const AccountDeletionResult({
    required this.deleted,
    this.requestId,
  });
}

class ApiClient {
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String _productionBaseUrl =
      'https://toak-backend-xolu57aqba-el.a.run.app';

  final Duration _timeout;
  final http.Client _httpClient;
  final String? _baseUrlOverride;
  final Future<String?> Function(bool forceRefresh)? _tokenProvider;

  ApiClient({
    http.Client? httpClient,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 15),
    Future<String?> Function(bool forceRefresh)? tokenProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _baseUrlOverride = baseUrl,
        _timeout = timeout,
        _tokenProvider = tokenProvider;

  bool get isConfigured => _baseUrl.trim().isNotEmpty;

  Future<dynamic> get(
    String endpoint, {
    bool authenticated = true,
    bool forceRefreshToken = false,
  }) {
    return _send(
      () async => _httpClient.get(
        _uri(endpoint),
        headers: await _headers(
          authenticated: authenticated,
          forceRefreshToken: forceRefreshToken,
        ),
      ),
    );
  }

  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool authenticated = true,
    bool forceRefreshToken = false,
  }) {
    return _send(
      () async => _httpClient.post(
        _uri(endpoint),
        headers: await _headers(
          authenticated: authenticated,
          forceRefreshToken: forceRefreshToken,
        ),
        body: jsonEncode(data),
      ),
    );
  }

  Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> data, {
    bool authenticated = true,
    bool forceRefreshToken = false,
  }) {
    return _send(
      () async => _httpClient.put(
        _uri(endpoint),
        headers: await _headers(
          authenticated: authenticated,
          forceRefreshToken: forceRefreshToken,
        ),
        body: jsonEncode(data),
      ),
    );
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? data,
    bool authenticated = true,
    bool forceRefreshToken = false,
  }) {
    return _send(
      () async => _httpClient.delete(
        _uri(endpoint),
        headers: await _headers(
          authenticated: authenticated,
          forceRefreshToken: forceRefreshToken,
        ),
        body: data == null ? null : jsonEncode(data),
      ),
    );
  }

  /// Deletes the authenticated user's app data and Firebase Auth account.
  ///
  /// The caller must reauthenticate first. A forced token refresh ensures the
  /// backend sees the new `auth_time`; the backend enforces a five-minute age.
  Future<AccountDeletionResult> deleteCurrentAccount() async {
    final response = await delete(
      '/v1/auth/account',
      data: const <String, dynamic>{'confirmation': 'DELETE'},
      forceRefreshToken: true,
    );
    if (response is! Map<String, dynamic> || response['deleted'] != true) {
      throw const ApiException(
        kind: ApiFailureKind.malformedResponse,
        message: 'The account deletion response was invalid.',
      );
    }
    return AccountDeletionResult(
      deleted: true,
      requestId: response['requestId']?.toString(),
    );
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_timeout);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw ApiException(
        kind: ApiFailureKind.timeout,
        message: 'The service did not respond in time.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        kind: ApiFailureKind.network,
        message: 'The service could not be reached.',
        cause: error,
      );
    } catch (error) {
      throw ApiException(
        kind: ApiFailureKind.network,
        message: 'The service could not be reached.',
        cause: error,
      );
    }
  }

  Uri _uri(String endpoint) {
    final base = _baseUrl.trim();
    if (base.isEmpty) {
      throw const ApiException(
        kind: ApiFailureKind.notConfigured,
        message: 'API_BASE_URL is not configured.',
      );
    }
    final cleanBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanEndpoint =
        endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return Uri.parse('$cleanBase/$cleanEndpoint');
  }

  String get _baseUrl {
    final override = _baseUrlOverride?.trim() ?? '';
    if (override.isNotEmpty) return override;
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    try {
      final environmentUrl = dotenv.env['API_BASE_URL']?.trim() ?? '';
      if (environmentUrl.isNotEmpty) return environmentUrl;
    } catch (_) {
      // A missing optional dotenv asset must not disable the release economy.
    }
    // Direct store builds do not always pass dart-defines. Keep distributable
    // clients connected to the verified authority while preserving the local
    // wallet path used by debug builds and tests.
    return kReleaseMode ? _productionBaseUrl : '';
  }

  Future<Map<String, String>> _headers({
    required bool authenticated,
    required bool forceRefreshToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Economy-Catalog-Version': economyCatalogVersion,
    };
    if (!authenticated) return headers;

    final token = _tokenProvider != null
        ? await _tokenProvider(forceRefreshToken)
        : await FirebaseAuth.instance.currentUser
            ?.getIdToken(forceRefreshToken);
    if (token == null || token.trim().isEmpty) {
      throw const ApiException(
        kind: ApiFailureKind.unauthenticated,
        message: 'This request requires a signed-in user.',
      );
    }
    headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  dynamic _handleResponse(http.Response response) {
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      data = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final body = data is Map<String, dynamic> ? data : null;
    final requestId =
        body?['requestId']?.toString() ?? response.headers['x-request-id'];
    final code = body?['code']?.toString();
    final message =
        body?['error']?.toString() ?? 'The service rejected the request.';
    final kind = switch (response.statusCode) {
      401 || 403 => ApiFailureKind.unauthenticated,
      409 => ApiFailureKind.conflict,
      429 => ApiFailureKind.rateLimited,
      >= 500 => ApiFailureKind.server,
      _ => ApiFailureKind.rejected,
    };
    throw ApiException(
      kind: kind,
      message: message,
      statusCode: response.statusCode,
      code: code,
      requestId: requestId,
    );
  }
}
