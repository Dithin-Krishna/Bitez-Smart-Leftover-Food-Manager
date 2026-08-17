import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Global auth state shared across the widget tree via [Provider].
///
/// Screens listen to [user] and [token] to determine whether the user is
/// logged in and to attach the JWT to API calls.
class AuthProvider extends ChangeNotifier {
  UserModel? _user;
  String?    _token;

  UserModel? get user  => _user;
  String?    get token => _token;
  bool get isLoggedIn  => _token != null && _user != null;

  // ── Initialise from persisted token on app start ───────────────────────────
  Future<void> tryAutoLogin() async {
    final saved = await AuthService.instance.getSavedToken();
    if (saved == null) return;

    try {
      final profile = await AuthService.instance.getProfile(saved);
      _token = saved;
      _user  = profile;
      notifyListeners();
    } catch (_) {
      // Token expired or invalid — discard it silently.
      await AuthService.instance.clearToken();
    }
  }

  // ── Login / Register ───────────────────────────────────────────────────────
  Future<void> login(String email, String password) async {
    final result = await AuthService.instance.login(
      email:    email,
      password: password,
    );
    _token = result.token;
    _user  = result.user;
    notifyListeners();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    int?    age,
    String? gender,
    String? phone,
  }) async {
    final result = await AuthService.instance.register(
      name:     name,
      email:    email,
      password: password,
      age:      age,
      gender:   gender,
      phone:    phone,
    );
    _token = result.token;
    _user  = result.user;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    int? age,
    String? gender,
    String? phone,
    String? avatarUrl,
  }) async {
    if (_token == null) return;
    
    final updatedUser = await AuthService.instance.updateProfile(
      _token!,
      name: name,
      age: age,
      gender: gender,
      phone: phone,
      avatarUrl: avatarUrl,
    );
    
    _user = updatedUser;
    notifyListeners();
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await AuthService.instance.clearToken();
    _token = null;
    _user  = null;
    notifyListeners();
  }
  // ── Forgot Password ────────────────────────────────────────────────────────
  Future<void> forgotPassword(String email) async {
    await AuthService.instance.forgotPassword(email);
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await AuthService.instance.resetPassword(
      email: email,
      otp: otp,
      newPassword: newPassword,
    );
  }
}
