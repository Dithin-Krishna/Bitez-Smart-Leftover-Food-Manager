import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bitez_app/models/user_model.dart';
import 'package:bitez_app/providers/auth_provider.dart';
import 'package:bitez_app/screens/analytics_dashboard_screen.dart';

class TestAuthProvider extends ChangeNotifier implements AuthProvider {
  UserModel? _user;
  String? _token;

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget buildTestWidget({
  required Widget child,
  required TestAuthProvider authProvider,
}) {
  return MaterialApp(
    home: ChangeNotifierProvider<AuthProvider>.value(
      value: authProvider,
      child: child,
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AnalyticsDashboardScreen Widget Tests', () {
    testWidgets('Renders money saved hero card, streak badge, and progress bar', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/analytics/waste-savings') {
          return http.Response(
            jsonEncode({
              'success': true,
              'analytics': {
                'totalRecipesPrepared': 8,
                'totalLeftoversSaved': 24,
                'totalMoneySaved': 36.00,
                'monthlyStreakDays': 6,
                'currentMonthSaved': 16,
                'currentMonthMoney': 24.00,
                'monthlyGoal': 20,
                'monthlyGoalProgress': 0.80,
                'streakBadge': 'Eco Chef 🔥',
                'categoryCounts': {
                  'veggies': 10,
                  'dairy': 6,
                  'fruits': 5,
                },
                'recentEvents': [
                  {
                    'id': 'log_01',
                    'recipeTitle': 'Cheesy Broccoli Pasta',
                    'totalItemsSaved': 3,
                    'estimatedMoneySaved': 4.50,
                    'cookedAt': '2026-09-09T14:30:00.000Z',
                    'deductions': [
                      {'label': 'Cheddar', 'quantityUsed': 1, 'section': 'dairy'},
                      {'label': 'Broccoli', 'quantityUsed': 2, 'section': 'veggies'},
                    ],
                  },
                ],
              },
            }),
            200,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          );
        }
        return http.Response('{"success": false}', 404);
      });

      final auth = TestAuthProvider();
      auth.setLoggedInUser(
        const UserModel(id: 'u1', name: 'Chef Test', email: 'test@bitez.app'),
        'fake_jwt_token',
      );

      await http.runWithClient(() async {
        await tester.pumpWidget(buildTestWidget(
          child: const AnalyticsDashboardScreen(),
          authProvider: auth,
        ));

        // Initial loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Advance past network call
        await tester.pumpAndSettle();

        // Verify Hero Savings Card
        expect(find.text('\$36.00'), findsOneWidget);
        expect(find.text('ESTIMATED SAVINGS'), findsOneWidget);
        expect(find.text('8'), findsOneWidget); // 8 recipes cooked
        expect(find.text('24'), findsOneWidget); // 24 leftovers saved

        // Verify Streak and Milestone Badge
        expect(find.text('6 Days Cooked'), findsOneWidget);
        expect(find.text('Eco Chef 🔥'), findsOneWidget);
        expect(find.text('16 / 20 items (80%)'), findsOneWidget);

        // Verify Category Breakdown
        expect(find.text('Veggies'), findsOneWidget);
        expect(find.text('10 saved'), findsOneWidget);
        expect(find.text('Dairy'), findsOneWidget);
        expect(find.text('6 saved'), findsOneWidget);

        // Verify Recent Cook History
        expect(find.text('Cheesy Broccoli Pasta'), findsOneWidget);
        expect(find.text('+\$4.50'), findsOneWidget);
        expect(find.text('3 items saved'), findsOneWidget);
        expect(find.text('Cheddar ×1'), findsOneWidget);
        expect(find.text('Broccoli ×2'), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('Renders empty history state when no cook events recorded yet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'analytics': {
              'totalRecipesPrepared': 0,
              'totalLeftoversSaved': 0,
              'totalMoneySaved': 0.0,
              'monthlyStreakDays': 0,
              'currentMonthSaved': 0,
              'currentMonthMoney': 0.0,
              'monthlyGoal': 20,
              'monthlyGoalProgress': 0.0,
              'streakBadge': 'Leftover Starter ⭐',
              'categoryCounts': {},
              'recentEvents': [],
            },
          }),
          200,
          headers: {HttpHeaders.contentTypeHeader: 'application/json'},
        );
      });

      final auth = TestAuthProvider();
      auth.setLoggedInUser(
        const UserModel(id: 'u1', name: 'New Cook', email: 'new@bitez.app'),
        'fake_jwt_token',
      );

      await http.runWithClient(() async {
        await tester.pumpWidget(buildTestWidget(
          child: const AnalyticsDashboardScreen(),
          authProvider: auth,
        ));
        await tester.pumpAndSettle();

        expect(find.text('\$0.00'), findsOneWidget);
        expect(find.text('No cooked meals recorded yet'), findsOneWidget);
        expect(find.text('Leftover Starter ⭐'), findsOneWidget);
      }, () => mockClient);
    });
  });
}
