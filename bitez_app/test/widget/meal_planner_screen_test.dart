import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bitez_app/models/user_model.dart';
import 'package:bitez_app/providers/auth_provider.dart';
import 'package:bitez_app/screens/meal_planner_screen.dart';

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

  group('MealPlannerScreen Widget Tests', () {
    testWidgets('Renders 7-day calendar selector, Monday menu, and pinned meal card', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/meal-planner' && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'success': true,
              'totalPinned': 2,
              'mealPlan': {
                'monday': [
                  {
                    '_id': 'mp_001',
                    'dayOfWeek': 'monday',
                    'recipeTitle': 'Vegetable Stir Fry',
                    'ingredients': ['Broccoli', 'Carrots', 'Soy sauce', 'Rice'],
                    'cookTime': 20,
                    'mealType': 'dinner',
                    'servings': 2,
                  },
                ],
                'tuesday': [
                  {
                    '_id': 'mp_002',
                    'dayOfWeek': 'tuesday',
                    'recipeTitle': 'Scrambled Eggs on Toast',
                    'ingredients': ['Eggs', 'Butter', 'Bread'],
                    'cookTime': 10,
                    'mealType': 'breakfast',
                    'servings': 1,
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
        const UserModel(id: 'u1', name: 'Meal Planner', email: 'planner@bitez.app'),
        'fake_jwt_token',
      );

      await http.runWithClient(() async {
        await tester.pumpWidget(buildTestWidget(
          child: const MealPlannerScreen(),
          authProvider: auth,
        ));

        // Initial loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();

        // Verify title
        expect(find.text('Weekly Meal Planner'), findsOneWidget);

        // Verify day selector buttons
        expect(find.text('MON'), findsOneWidget);
        expect(find.text('TUE'), findsOneWidget);
        expect(find.text('WED'), findsOneWidget);
        expect(find.text('THU'), findsOneWidget);
        expect(find.text('FRI'), findsOneWidget);
        expect(find.text('SAT'), findsOneWidget);
        expect(find.text('SUN'), findsOneWidget);

        // Verify Monday Menu and Pinned Meal
        expect(find.text('Monday\'s Menu'), findsOneWidget);
        expect(find.text('Vegetable Stir Fry'), findsOneWidget);
        expect(find.text('Dinner'), findsOneWidget);
        expect(find.text('⏱️ 20 min'), findsOneWidget);
        expect(find.text('• 4 items'), findsOneWidget);

        // Verify Consolidated Grocery Banner
        expect(find.text('Weekly Consolidated Grocery'), findsOneWidget);
        expect(find.text('7 ingredients needed this week'), findsOneWidget);
        expect(find.text('Add to List'), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('Switching day tabs displays that day\'s planned menu', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/meal-planner') {
          return http.Response(
            jsonEncode({
              'success': true,
              'totalPinned': 1,
              'mealPlan': {
                'tuesday': [
                  {
                    '_id': 'mp_002',
                    'dayOfWeek': 'tuesday',
                    'recipeTitle': 'Berry Smoothie Bowl',
                    'ingredients': ['Blueberries', 'Banana', 'Greek yogurt'],
                    'cookTime': 5,
                    'mealType': 'breakfast',
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
        const UserModel(id: 'u1', name: 'Meal Planner', email: 'planner@bitez.app'),
        'fake_jwt_token',
      );

      await http.runWithClient(() async {
        await tester.pumpWidget(buildTestWidget(
          child: const MealPlannerScreen(),
          authProvider: auth,
        ));
        await tester.pumpAndSettle();

        // Monday is initially empty
        expect(find.text('No meals planned for Monday'), findsOneWidget);

        // Tap TUE
        await tester.tap(find.text('TUE'));
        await tester.pumpAndSettle();

        // Tuesday displays the Berry Smoothie Bowl
        expect(find.text('Tuesday\'s Menu'), findsOneWidget);
        expect(find.text('Berry Smoothie Bowl'), findsOneWidget);
        expect(find.text('Breakfast'), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('Generates consolidated grocery list on button tap', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/meal-planner') {
          return http.Response(
            jsonEncode({
              'success': true,
              'totalPinned': 1,
              'mealPlan': {
                'monday': [
                  {
                    '_id': 'mp_001',
                    'dayOfWeek': 'monday',
                    'recipeTitle': 'Quick Omelette',
                    'ingredients': ['2 eggs', '1 tbsp butter', 'cheddar cheese'],
                  },
                ],
              },
            }),
            200,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          );
        }

        if (request.url.path == '/api/grocery/bulk' && request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'success': true,
              'count': 3,
              'items': [
                {'_id': 'g1', 'label': 'eggs', 'qty': 1},
                {'_id': 'g2', 'label': 'butter', 'qty': 1},
                {'_id': 'g3', 'label': 'cheddar cheese', 'qty': 1},
              ],
            }),
            201,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          );
        }

        return http.Response('{"success": false}', 404);
      });

      final auth = TestAuthProvider();
      auth.setLoggedInUser(
        const UserModel(id: 'u1', name: 'Planner', email: 'planner@bitez.app'),
        'fake_jwt_token',
      );

      await http.runWithClient(() async {
        await tester.pumpWidget(buildTestWidget(
          child: const MealPlannerScreen(),
          authProvider: auth,
        ));
        await tester.pumpAndSettle();

        // Tap "Add to List" button
        await tester.tap(find.text('Add to List'));
        await tester.pumpAndSettle();

        // Verify confirmation dialog
        expect(find.text('Consolidated Grocery'), findsOneWidget);
        expect(find.textContaining('Added or updated 3 ingredients'), findsOneWidget);
        expect(find.text('View Grocery List'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);

        // Dismiss
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
      }, () => mockClient);
    });
  });
}
