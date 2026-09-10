import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bitez_app/models/user_model.dart';
import 'package:bitez_app/providers/auth_provider.dart';
import 'package:bitez_app/providers/user_prefs_provider.dart';
import 'package:bitez_app/providers/saved_recipes_provider.dart';
import 'package:bitez_app/providers/chat_provider.dart';
import 'package:bitez_app/providers/expiry_provider.dart';
import 'package:bitez_app/screens/login_intro_screen.dart';
import 'package:bitez_app/screens/forgot_password_screen.dart';
import 'package:bitez_app/services/api_service.dart';

/// Test implementation of AuthProvider to simulate exact auth responses
class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  UserModel? _user;
  String? _token;
  bool shouldFailLogin = false;
  bool shouldFailReset = false;
  String failureMessage = 'Invalid email or password';
  bool loginCalled = false;
  bool forgotPasswordCalled = false;
  bool resetPasswordCalled = false;
  String? lastLoginEmail;
  String? lastLoginPassword;
  String? lastForgotEmail;

  @override
  UserModel? get user => _user;

  @override
  String? get token => _token;

  @override
  bool get isLoggedIn => _token != null && _user != null;

  void setLoggedInUser(UserModel user, String token) {
    _user = user;
    _token = token;
    notifyListeners();
  }

  @override
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('bitez_jwt');
    if (savedToken != null && !shouldFailLogin) {
      _token = savedToken;
      _user = UserModel(
        id: 'test_user_id',
        name: 'Test User',
        email: 'test@example.com',
      );
      notifyListeners();
    }
  }

  @override
  Future<void> login(String email, String password) async {
    loginCalled = true;
    lastLoginEmail = email;
    lastLoginPassword = password;

    if (shouldFailLogin) {
      throw ApiException(failureMessage);
    }

    _token = 'fake_jwt_token_12345';
    _user = UserModel(
      id: 'user_1',
      name: 'Logged User',
      email: email,
    );
    notifyListeners();
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    int? age,
    String? gender,
    String? phone,
  }) async {
    _token = 'fake_jwt_token_12345';
    _user = UserModel(id: 'user_1', name: name, email: email);
    notifyListeners();
  }

  @override
  Future<void> updateProfile({
    String? name,
    int? age,
    String? gender,
    String? phone,
    String? avatarUrl,
  }) async {}

  @override
  Future<void> logout() async {
    _token = null;
    _user = null;
    notifyListeners();
  }

  @override
  Future<void> forgotPassword(String email) async {
    forgotPasswordCalled = true;
    lastForgotEmail = email;
    if (shouldFailReset) {
      throw ApiException('User with this email not found');
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    resetPasswordCalled = true;
    if (shouldFailReset) {
      throw ApiException('Invalid or expired OTP');
    }
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiService.connectionStatus.value = ServerConnectionStatus.connected;
  });

  Widget buildTestableWidget({
    required Widget child,
    FakeAuthProvider? authProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(
          value: authProvider ?? FakeAuthProvider(),
        ),
        ChangeNotifierProvider<UserPrefsProvider>(
          create: (_) => UserPrefsProvider(),
        ),
        ChangeNotifierProvider<SavedRecipesProvider>(
          create: (_) => SavedRecipesProvider(),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(),
        ),
        ChangeNotifierProvider<ExpiryProvider>(
          create: (_) => ExpiryProvider(),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  final mockClient = MockClient((request) async {
    if (request.url.path == '/' || request.url.path.isEmpty) {
      return http.Response(jsonEncode({'status': 'OK', 'message': 'Bitez API healthy'}), 200);
    }
    return http.Response(jsonEncode({'success': true}), 200);
  });

  Future<void> pumpPastLoginIntro(WidgetTester tester) async {
    // 1. Initial pump
    await tester.pump();
    // 2. PostFrameCallback fires _main.forward()
    await tester.pump();
    // 3. Advance past the 7100ms sequence
    await tester.pump(const Duration(milliseconds: 7200));
    await tester.pump(const Duration(milliseconds: 300));
    // 4. Ensure connection status is connected
    ApiService.connectionStatus.value = ServerConnectionStatus.connected;
    await tester.pump();
  }

  group('Auth Screen Widget Tests', () {
    testWidgets('Login screen validates empty fields and shows SnackBar', (WidgetTester tester) async {
      await http.runWithClient(() async {
        final fakeAuth = FakeAuthProvider();

        await tester.pumpWidget(
          buildTestableWidget(
            child: const LoginIntroScreen(),
            authProvider: fakeAuth,
          ),
        );

        await pumpPastLoginIntro(tester);

        final loginBtn = find.widgetWithText(ElevatedButton, 'Log in');
        expect(loginBtn, findsOneWidget);

        await tester.tap(loginBtn, warnIfMissed: false);
        await tester.pump(); // trigger validation
        await tester.pump(); // display SnackBar

        expect(find.text('Please enter your email and password.'), findsOneWidget);
        expect(fakeAuth.loginCalled, isFalse);
      }, () => mockClient);
    });

    testWidgets('Login screen executes login with entered credentials', (WidgetTester tester) async {
      await http.runWithClient(() async {
        final fakeAuth = FakeAuthProvider();

        await tester.pumpWidget(
          buildTestableWidget(
            child: const LoginIntroScreen(),
            authProvider: fakeAuth,
          ),
        );

        await pumpPastLoginIntro(tester);

        final emailField = find.widgetWithText(TextField, 'name@email.com');
        final passField = find.widgetWithText(TextField, 'Password');

        expect(emailField, findsOneWidget);
        expect(passField, findsOneWidget);

        await tester.enterText(emailField, 'chef@bitez.app');
        await tester.enterText(passField, 'Secret123!');

        final loginBtn = find.widgetWithText(ElevatedButton, 'Log in');
        await tester.tap(loginBtn, warnIfMissed: false);
        await tester.pump();
        await tester.pump();

        expect(fakeAuth.loginCalled, isTrue);
        expect(fakeAuth.lastLoginEmail, equals('chef@bitez.app'));
        expect(fakeAuth.lastLoginPassword, equals('Secret123!'));
      }, () => mockClient);
    });

    testWidgets('Login failure displays error message from ApiException', (WidgetTester tester) async {
      await http.runWithClient(() async {
        final fakeAuth = FakeAuthProvider()
          ..shouldFailLogin = true
          ..failureMessage = 'Invalid credentials provided';

        await tester.pumpWidget(
          buildTestableWidget(
            child: const LoginIntroScreen(),
            authProvider: fakeAuth,
          ),
        );

        await pumpPastLoginIntro(tester);

        final emailField = find.widgetWithText(TextField, 'name@email.com');
        final passField = find.widgetWithText(TextField, 'Password');

        await tester.enterText(emailField, 'wrong@bitez.app');
        await tester.enterText(passField, 'WrongPass');

        final loginBtn = find.widgetWithText(ElevatedButton, 'Log in');
        await tester.tap(loginBtn, warnIfMissed: false);
        await tester.pump();
        await tester.pump();

        expect(find.text('Invalid credentials provided'), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('Forgot Password screen validates empty email', (WidgetTester tester) async {
      final fakeAuth = FakeAuthProvider();

      await tester.pumpWidget(
        buildTestableWidget(
          child: const ForgotPasswordScreen(),
          authProvider: fakeAuth,
        ),
      );
      await tester.pump();

      final sendOtpBtn = find.text('Send OTP');
      expect(sendOtpBtn, findsOneWidget);

      await tester.tap(sendOtpBtn);
      await tester.pump();
      await tester.pump();

      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(fakeAuth.forgotPasswordCalled, isFalse);
    });

    testWidgets('Forgot Password sends OTP and completes password reset flow', (WidgetTester tester) async {
      final fakeAuth = FakeAuthProvider();

      await tester.pumpWidget(
        buildTestableWidget(
          child: const ForgotPasswordScreen(),
          authProvider: fakeAuth,
        ),
      );
      await tester.pump();

      final sendOtpBtn = find.text('Send OTP');
      final emailInput = find.byType(TextField).first;

      await tester.enterText(emailInput, 'user@bitez.app');
      await tester.tap(sendOtpBtn);
      await tester.pump(); // async call
      await tester.pump(); // setState
      await tester.pump(); // SnackBar

      expect(fakeAuth.forgotPasswordCalled, isTrue);
      expect(fakeAuth.lastForgotEmail, equals('user@bitez.app'));
      expect(find.text('OTP sent to your email!'), findsOneWidget);

      // Verify OTP step appears
      expect(find.text('Reset Password'), findsOneWidget);

      // Enter OTP and new password
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(3)); // email (disabled), otp, newPassword

      await tester.enterText(textFields.at(1), '654321');
      await tester.enterText(textFields.at(2), 'NewPassword123!');

      final resetBtn = find.text('Reset Password');
      await tester.tap(resetBtn);
      await tester.pump(); // async call
      await tester.pump(); // finish

      expect(fakeAuth.resetPasswordCalled, isTrue);
    });

    testWidgets('Forgot Password trigger is visible on Login screen', (WidgetTester tester) async {
      await http.runWithClient(() async {
        final fakeAuth = FakeAuthProvider();

        await tester.pumpWidget(
          buildTestableWidget(
            child: const LoginIntroScreen(),
            authProvider: fakeAuth,
          ),
        );

        await pumpPastLoginIntro(tester);

        final forgotBtn = find.text('Forgot Password?');
        expect(forgotBtn, findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('Auto-login: JWT persistence restores user session', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'bitez_jwt': 'persisted_jwt_token_xyz',
      });

      final authProvider = FakeAuthProvider();
      expect(authProvider.isLoggedIn, isFalse);

      await authProvider.tryAutoLogin();

      expect(authProvider.isLoggedIn, isTrue);
      expect(authProvider.token, equals('persisted_jwt_token_xyz'));
      expect(authProvider.user?.email, equals('test@example.com'));
    });

    testWidgets('Auto-login: missing JWT keeps user unauthenticated', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      final authProvider = FakeAuthProvider();
      await authProvider.tryAutoLogin();

      expect(authProvider.isLoggedIn, isFalse);
      expect(authProvider.token, isNull);
    });
  });
}
