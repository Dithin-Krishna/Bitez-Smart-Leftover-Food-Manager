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
import 'package:bitez_app/providers/user_prefs_provider.dart';
import 'package:bitez_app/providers/saved_recipes_provider.dart';
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
      ],
      child: MaterialApp(
        home: Scaffold(body: child),
      ),
    );
  }

  final fridgeMockClient = MockClient((request) async {
    final uri = request.url.path;

    if (uri == '/api/fridge' && request.method == 'GET') {
      return http.Response(
        jsonEncode({
          'success': true,
          'grouped': {
            'frozen': [
              {'_id': 'fz_1', 'emoji': '*', 'label': 'Dumplings', 'qty': 4, 'color': 1989524, 'section': 'frozen'}
            ],
            'dairy': [
              {'_id': 'dy_1', 'emoji': '*', 'label': 'Fresh Milk', 'qty': 2, 'color': 2775956, 'section': 'dairy'},
              {'_id': 'dy_2', 'emoji': '*', 'label': 'Eggs', 'qty': 6, 'color': 2775956, 'section': 'dairy'}
            ],
            'veggies': [
              {'_id': 'vg_1', 'emoji': '*', 'label': 'Carrots', 'qty': 3, 'color': 2656093, 'section': 'veggies'}
            ],
            'fruits': [
              {'_id': 'fr_1', 'emoji': '*', 'label': 'Red Apples', 'qty': 5, 'color': 9059114, 'section': 'fruits'}
            ],
          },
          'items': [
            {'_id': 'fz_1', 'emoji': '*', 'label': 'Dumplings', 'qty': 4, 'color': 1989524, 'section': 'frozen'},
            {'_id': 'dy_1', 'emoji': '*', 'label': 'Fresh Milk', 'qty': 2, 'color': 2775956, 'section': 'dairy'},
            {'_id': 'dy_2', 'emoji': '*', 'label': 'Eggs', 'qty': 6, 'color': 2775956, 'section': 'dairy'},
            {'_id': 'vg_1', 'emoji': '*', 'label': 'Carrots', 'qty': 3, 'color': 2656093, 'section': 'veggies'},
            {'_id': 'fr_1', 'emoji': '*', 'label': 'Red Apples', 'qty': 5, 'color': 9059114, 'section': 'fruits'},
          ],
        }),
        200,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      );
    }

    if (uri.contains('/api/fridge/') && uri.endsWith('/qty')) {
      return http.Response(
        jsonEncode({'success': true, 'item': {'qty': 7}}),
        200,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      );
    }

    if (uri == '/api/fridge/deduct' && request.method == 'PATCH') {
      return http.Response(
        jsonEncode({
          'success': true,
          'deducted': [
            {'itemId': 'dy_2', 'label': 'Eggs', 'previousQty': 6, 'newQty': 5, 'removed': false}
          ]
        }),
        200,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      );
    }

    if (uri.startsWith('/api/fridge/') && request.method == 'DELETE') {
      return http.Response(
        jsonEncode({'success': true}),
        200,
        headers: {HttpHeaders.contentTypeHeader: 'application/json'},
      );
    }

    return http.Response(
      jsonEncode({'success': true}),
      200,
      headers: {HttpHeaders.contentTypeHeader: 'application/json'},
    );
  });

  group('Fridge Screen Widget Tests', () {
    testWidgets('Renders fridge screen and opens freezer and fridge doors', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await http.runWithClient(() async {
        await tester.pumpWidget(buildTestableWidget(child: const FridgeScreen()));
        // Flush async fridge fetch
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 200));

        // Verify fridge screen structure is rendered
        expect(find.byType(FridgeScreen), findsOneWidget);

        // Find tap to open prompt on doors
        final tapToOpenPrompts = find.text('– tap to open –');
        expect(tapToOpenPrompts, findsNWidgets(2));

        // Tap top door (Freezer) to open
        await tester.tap(tapToOpenPrompts.first);
        await tester.pump(); // starts animation controller
        await tester.pump(const Duration(milliseconds: 1000)); // advances to completion
        await tester.pump(); // fires status listener setState

        // Verify freezer items are rendered
        expect(find.text('Dumplings'), findsOneWidget);

        // Tap bottom door (Fridge) to open
        await tester.tap(tapToOpenPrompts.last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pump();

        // Verify shelves rendered inside fridge interior
        expect(find.text('Dairy & Eggs'), findsOneWidget);
        expect(find.text('Vegetables'), findsOneWidget);
        expect(find.text('Fruits'), findsNWidgets(2)); // shelf title and bottom bar chip

        // Verify individual food items are rendered
        expect(find.text('Fresh Milk'), findsOneWidget);
        expect(find.text('Eggs'), findsOneWidget);
        expect(find.text('Carrots'), findsOneWidget);
        expect(find.text('Red Apples'), findsOneWidget);
      }, () => fridgeMockClient);
    });

    testWidgets('Quantity step controls: tapping + increments quantity', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await http.runWithClient(() async {
        await tester.pumpWidget(buildTestableWidget(child: const FridgeScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 200));

        // Open freezer door
        await tester.tap(find.text('– tap to open –').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Dumplings has initial qty 4
        expect(find.byKey(const ValueKey(4)), findsOneWidget);

        // Find add icon in the item card
        final addIcons = find.byIcon(Icons.add);
        expect(addIcons, findsWidgets);

        // Tap add button on Dumplings
        await tester.tap(addIcons.first);
        await tester.pump(); // trigger setState
        await tester.pump(const Duration(milliseconds: 200));

        // Verify updated count 5 is displayed for the item
        expect(find.byKey(const ValueKey(5)), findsOneWidget);
      }, () => fridgeMockClient);
    });

    testWidgets('Item deletion flow: qty to 0 shows delete icon and confirmation dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await http.runWithClient(() async {
        await tester.pumpWidget(buildTestableWidget(child: const FridgeScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 200));

        // Open freezer door
        await tester.tap(find.text('– tap to open –').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Dumplings starts at qty 4
        // Decrement 4 times: 4 -> 3 -> 2 -> 1 -> 0
        for (int i = 0; i < 4; i++) {
          final minus = find.byIcon(Icons.remove).first;
          await tester.tap(minus);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 200)); // AnimatedSwitcher duration is 180ms
        }

        // When qty == 0, the delete icon appears instead of minus
        final deleteIcon = find.byIcon(Icons.delete_outline_rounded);
        expect(deleteIcon, findsOneWidget);

        // Tap delete icon to trigger confirmation dialog
        await tester.tap(deleteIcon, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify confirmation dialog
        expect(find.text('Remove Dumplings?'), findsOneWidget);
        expect(find.text('Out of stock. Remove from shelf?'), findsOneWidget);
        expect(find.text('Keep'), findsOneWidget);
        expect(find.text('Remove'), findsOneWidget);

        // Tap Remove to confirm deletion
        await tester.tap(find.text('Remove'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify item is removed from shelf
        expect(find.text('Dumplings'), findsNothing);
      }, () => fridgeMockClient);
    });
  });

  group('Feature 1 & Feature 3 Integration Widget Tests', () {
    testWidgets('Feature 1: "I Cooked This!" fridge auto-deduction flow in RecipeDetailScreen', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await http.runWithClient(() async {
        const testRecipe = RecipeModel(
          id: 7001,
          title: 'Scrambled Eggs on Toast',
          image: 'https://example.com/scrambled.jpg',
          usedIngredientCount: 1,
          missedIngredientCount: 0,
          usedIngredients: ['Eggs'],
          missedIngredients: [],
          readyInMinutes: 8,
          servings: 1,
          instructions: ['Beat eggs and cook on low heat.'],
        );

        await tester.pumpWidget(
          buildTestableWidget(
            child: const RecipeDetailScreen(recipe: testRecipe),
          ),
        );
        // Flush async getAllItems load
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 200));

        // "I Cooked This!" button must appear because fridge inventory contains 'Eggs'
        final cookedBtn = find.text('I Cooked This!');
        expect(cookedBtn, findsOneWidget);

        // Tap the button to open the fridge auto-deduction dialog
        await tester.tap(cookedBtn);
        await tester.pump();

        // Verify the deduction dialog header and items
        expect(find.text('Deduct used ingredients from your fridge'), findsOneWidget);
        expect(find.text('Deduct 1 Ingredient'), findsOneWidget);

        // Confirm deduction
        await tester.tap(find.text('Deduct 1 Ingredient'));
        await tester.pump(); // async deductItems
        await tester.pump(const Duration(milliseconds: 50)); // async _loadFridgeItems
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(); // show SnackBar

        // Verify success snackbar
        expect(find.text('✅ Deducted 1 ingredient from your fridge!'), findsOneWidget);
      }, () => fridgeMockClient);
    });

    testWidgets('Feature 3: Custom Expiration Date Setter in FoodConfirmationDialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final detectedItems = [
        RecognizedFoodItem(
          label: 'Fresh Broccoli',
          category: 'Vegetables',
          section: 'veggies',
          emoji: '🥦',
          qty: 2,
          isSelected: true,
          isValidated: true,
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodConfirmationDialog(
              imageFile: File('mock_image.jpg'),
              detectedItems: detectedItems,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify dialog header and item row
      expect(find.text('AI Food Recognition'), findsOneWidget);
      expect(find.text('Fresh Broccoli'), findsOneWidget);

      // Verify expiration date row with calendar icon is present
      final calendarIcon = find.byIcon(Icons.calendar_today);
      expect(calendarIcon, findsOneWidget);
      expect(find.textContaining('Expires:'), findsOneWidget);

      // Tap calendar icon to trigger date picker
      await tester.tap(calendarIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // DatePicker should now be open
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}
