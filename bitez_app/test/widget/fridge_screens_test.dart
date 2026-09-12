import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bitez_app/models/recipe_model.dart';
import 'package:bitez_app/models/user_model.dart';
import 'package:bitez_app/providers/auth_provider.dart';
import 'package:bitez_app/providers/expiry_provider.dart';
import 'package:bitez_app/providers/user_prefs_provider.dart';
import 'package:bitez_app/providers/saved_recipes_provider.dart';
import 'package:bitez_app/screens/expiry_tracker_screen.dart';
import 'package:bitez_app/screens/fridge_screen.dart';
import 'package:bitez_app/screens/recipe_detail_screen.dart';
import 'package:bitez_app/services/api_service.dart';
import 'package:bitez_app/services/food_recognition_service.dart';
import 'package:bitez_app/widgets/food_confirmation_dialog.dart';

class FakeFridgeAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserModel _mockUser = const UserModel(
    id: 'usr_1',
    name: 'Chef Tester',
    email: 'chef@bitez.app',
  );
  final String _mockToken = 'valid_test_token_123';

  @override
  UserModel? get user => _mockUser;

  @override
  String? get token => _mockToken;

  @override
  bool get isLoggedIn => true;

  @override
  Future<void> tryAutoLogin() async {}

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    int? age,
    String? gender,
    String? phone,
  }) async {}

  @override
  Future<void> updateProfile({
    String? name,
    int? age,
    String? gender,
    String? phone,
    String? avatarUrl,
  }) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.connectionStatus.value = ServerConnectionStatus.connected;
    ApiService.customBaseUrl = 'http://localhost:3000';
  });

  tearDown(() {
    ApiService.customBaseUrl = null;
  });

  Widget buildTestableWidget({
    required Widget child,
    AuthProvider? authProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider ?? FakeFridgeAuthProvider(),
        ),
        ChangeNotifierProvider<UserPrefsProvider>(
          create: (_) => UserPrefsProvider(),
        ),
        ChangeNotifierProvider<SavedRecipesProvider>(
          create: (_) => SavedRecipesProvider(),
        ),
        ChangeNotifierProvider<ExpiryProvider>(
          create: (_) => ExpiryProvider(),
        ),
  });
}
