import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  /// Allow setting a custom base URL dynamically.
  static String? customBaseUrl;

  /// Host IP on local Wi-Fi for physical devices
  static const String _hostWifiIp = '192.168.0.160';

  static String get baseUrl => customBaseUrl ?? _defaultCandidates().first;

  static List<String> _defaultCandidates() {
    if (kIsWeb) return ['http://localhost:3000', 'http://127.0.0.1:3000'];
    try {
      if (Platform.isAndroid) {
        return [
          'http://127.0.0.1:3000',      // Works via ADB reverse over USB (Instant)
          'http://localhost:3000',      // Works via ADB reverse
          'http://192.168.0.160:3000',  // Host Wi-Fi IP
          'http://10.0.2.2:3000',       // Android Emulator standard loopback
        ];
      }
    } catch (_) {}
    return ['http://127.0.0.1:3000', 'http://localhost:3000', 'http://192.168.0.160:3000'];
  }

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
  Future<Map<String, dynamic>> _send(Future<http.Response> Function(String base) req) async {
    final defaults = _defaultCandidates();
    final candidates = customBaseUrl != null
        ? [customBaseUrl!, ...defaults.where((d) => d != customBaseUrl)]
        : defaults;
    
    Object? lastError;
    for (final base in candidates) {
      try {
        final res = await req(base).timeout(const Duration(seconds: 4));
        customBaseUrl = base; // Cache successful connection URL
        return _parse(res);
      } on ApiException {
        customBaseUrl = base; // Server answered (even with error code), connection succeeded
        rethrow;
      } catch (e) {
        lastError = e;
        if (customBaseUrl == base) {
          customBaseUrl = null; // Invalidate bad cached URL
        }
      }
    }
    throw ApiException('Could not connect to server (${candidates.join(", ")}). Details: ${lastError ?? "Check connection and server status."}');
  }

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    return _send((base) => http.get(Uri.parse('$base$path'), headers: _headers(token: token)));
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    return _send((base) => http.post(
          Uri.parse('$base$path'),
          headers: _headers(token: token),
          body: jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    return _send((base) => http.put(
          Uri.parse('$base$path'),
          headers: _headers(token: token),
          body: jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    return _send((base) => http.patch(
          Uri.parse('$base$path'),
          headers: _headers(token: token),
          body: jsonEncode(body),
        ));
  }

  Future<Map<String, dynamic>> delete(String path, {String? token}) async {
    return _send((base) => http.delete(Uri.parse('$base$path'), headers: _headers(token: token)));
  }
}
