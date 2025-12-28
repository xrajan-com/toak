import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  final String _baseUrl = dotenv.env['API_BASE_URL'] ?? '';
  final String _authSecret = dotenv.env['AUTH_SECRET'] ?? '';

  /// Generic GET request
  Future<dynamic> get(String endpoint) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/$endpoint'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Generic POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/$endpoint'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  /// Generic PUT request
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/$endpoint'),
      headers: _headers(),
      body: jsonEncode(data),
    );
    return _handleResponse(response);
  }

  /// Generic DELETE request
  Future<dynamic> delete(String endpoint) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/$endpoint'),
      headers: _headers(),
    );
    return _handleResponse(response);
  }

  /// Common headers
  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_authSecret',
      };

  /// Handle responses
  dynamic _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception('API Error: ${data['error'] ?? response.body}');
    }
  }
}