import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

/// Handles registration, login, logout and token persistence.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'bitez_jwt';

  // ── Token persistence ──────────────────────────────────────────────────────
  Future<String?> getSavedToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ── Register ───────────────────────────────────────────────────────────────
  /// Throws [ApiException] on failure.
  Future<({String token, UserModel user})> register({
    required String name,
    required String email,
    required String password,
    int? age,
    String? gender,
    String? phone,
  }) async {
    final json = await ApiService.instance.post('/api/auth/register', {
      'name':     name,
      'email':    email,
      'password': password,
      if (age    != null) 'age':    age,
      if (gender != null) 'gender': gender,
      if (phone  != null) 'phone':  phone,
    });

    final token = json['token'] as String;
    final user  = UserModel.fromJson(json['user'] as Map<String, dynamic>);
    await _saveToken(token);
    return (token: token, user: user);
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  /// Throws [ApiException] on failure.
  Future<({String token, UserModel user})> login({
    required String email,
    required String password,
  }) async {
    final json = await ApiService.instance.post('/api/auth/login', {
      'email':    email,
      'password': password,
    });

    final token = json['token'] as String;
    final user  = UserModel.fromJson(json['user'] as Map<String, dynamic>);
    await _saveToken(token);
    return (token: token, user: user);
  }

  // ── Fetch profile ──────────────────────────────────────────────────────────
  Future<UserModel> getProfile(String token) async {
    final json = await ApiService.instance.get('/api/user/me', token: token);
    return UserModel.fromJson(json['user'] as Map<String, dynamic>);
  }
}
