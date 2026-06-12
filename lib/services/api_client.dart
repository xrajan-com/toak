import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  final Duration _timeout = const Duration(seconds: 15);

  /// Generic GET request
  Future<dynamic> get(String endpoint, {bool authenticated = true}) async {
    final response = await http
        .get(
          _uri(endpoint),
          headers: await _headers(authenticated: authenticated),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// Generic POST request
  Future<dynamic> post(
    String endpoint,
    Map<String, dynamic> data, {
    bool authenticated = true,
  }) async {
    final response = await http
        .post(
          _uri(endpoint),
          headers: await _headers(authenticated: authenticated),
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// Generic PUT request
  Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> data, {
    bool authenticated = true,
  }) async {
    final response = await http
        .put(
          _uri(endpoint),
          headers: await _headers(authenticated: authenticated),
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  /// Generic DELETE request
  Future<dynamic> delete(String endpoint, {bool authenticated = true}) async {
    final response = await http
        .delete(
          _uri(endpoint),
          headers: await _headers(authenticated: authenticated),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  Uri _uri(String endpoint) {
    final base = _baseUrl.trim();
    if (base.isEmpty) {
      throw StateError('API_BASE_URL is not configured');
    }
    final cleanBase =
        base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final cleanEndpoint =
        endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return Uri.parse('$cleanBase/$cleanEndpoint');
  }

  String get _baseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    try {
      return dotenv.env['API_BASE_URL'] ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Common headers
  Future<Map<String, String>> _headers({required bool authenticated}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (!authenticated) return headers;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('API request requires a Firebase Auth user');
    }

    headers['Authorization'] = 'Bearer ${await user.getIdToken()}';
    return headers;
  }

  /// Handle responses
  dynamic _handleResponse(http.Response response) {
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      data = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      final message =
          data is Map<String, dynamic> ? data['error']?.toString() : null;
      throw Exception('API Error: ${message ?? response.body}');
    }
  }
}
