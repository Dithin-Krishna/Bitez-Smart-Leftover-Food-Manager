import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Custom exception carrying a user-readable message and HTTP status code.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Central HTTP client for the Bitez backend.
///
/// Usage:
///   final api = ApiService.instance;
///   final json = await api.get('/api/fridge', token: myToken);
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ── Base URL ──────────────────────────────────────────────────────────────
  // Android emulator → 10.0.2.2 maps to localhost on the host machine.
  // iOS simulator   → 127.0.0.1 works directly.
  // Physical device → replace with your LAN IP (e.g. 192.168.x.x).
  static const String baseUrl = 'http://10.0.2.2:3000';

  // ── Helpers ───────────────────────────────────────────────────────────────
  Map<String, String> _headers({String? token}) => {
        HttpHeaders.contentTypeHeader: 'application/json',
        if (token != null) HttpHeaders.authorizationHeader: 'Bearer $token',
      };

  Map<String, dynamic> _parse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final msg = body['message']?.toString() ?? 'Request failed';
    throw ApiException(msg, statusCode: response.statusCode);
  }

  // ── HTTP verbs ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.get(uri, headers: _headers(token: token));
    return _parse(res);
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(
      uri,
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.put(
      uri,
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.patch(
      uri,
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> delete(String path, {String? token}) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.delete(uri, headers: _headers(token: token));
    return _parse(res);
  }
}
