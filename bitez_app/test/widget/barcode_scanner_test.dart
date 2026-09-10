import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:bitez_app/models/user_model.dart';
import 'package:bitez_app/providers/auth_provider.dart';
import 'package:bitez_app/screens/barcode_scanner_screen.dart';
import 'package:bitez_app/services/food_recognition_service.dart';
import 'package:bitez_app/widgets/food_confirmation_dialog.dart';

class MockAuthProvider extends ChangeNotifier implements AuthProvider {
  final UserModel _user = const UserModel(id: 'u1', name: 'Tester', email: 'test@bitez.app');
  final String _token = 'jwt_test_token';

  @override
  UserModel? get user => _user;

  @override
  String? get token => _token;

  @override
  bool get isLoggedIn => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget buildTestWidget({required Widget child}) {
  return MaterialApp(
    home: ChangeNotifierProvider<AuthProvider>(
      create: (_) => MockAuthProvider(),
      child: child,
    ),
  );
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('Barcode & Food Confirmation Widget Tests', () {
    testWidgets('FoodConfirmationDialog renders barcode icon badge when imageFile is null', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testItem = RecognizedFoodItem(
        label: 'Ferrero Nutella',
        category: 'Condiments & Spices',
        section: 'condiments',
        emoji: '🍫',
        qty: 2,
        isSelected: true,
        isValidated: true,
        expiresAt: DateTime.now().add(const Duration(days: 90)),
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => FoodConfirmationDialog.show(
                context,
                imageFile: null,
                title: 'Barcode: Ferrero Nutella',
                detectedItems: [testItem],
              ),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify custom barcode title
      expect(find.text('Barcode: Ferrero Nutella'), findsOneWidget);

      // Verify QR / barcode scanner icon rendered instead of file image
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);

      // Verify item label
      expect(find.text('Ferrero Nutella'), findsOneWidget);

      // Verify Feature 3: Expiration Date row with calendar icon
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.textContaining('Expires:'), findsOneWidget);

      // Tap calendar date row to open date picker
      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();

      // Date picker is opened
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Dismiss date picker
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('BarcodeScannerScreen displays scanner controls and manual fallback button', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(child: const BarcodeScannerScreen()),
      );
      await tester.pump();

      // Verify App Bar & controls
      expect(find.text('Scan Barcode'), findsOneWidget);
      expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);
      expect(find.byIcon(Icons.flip_camera_ios_rounded), findsOneWidget);

      // Verify instructions and Manual Fallback entry button
      expect(find.text('Point camera at packaged food barcode'), findsOneWidget);
      expect(find.text('Can\'t scan? Enter item manually'), findsOneWidget);

      // Tap manual fallback button
      await tester.tap(find.text('Can\'t scan? Enter item manually'));
      await tester.pumpAndSettle();

      // Verify manual entry dialog appears with all fields
      expect(find.text('Item Not Found'), findsOneWidget);
      expect(find.text('Food / Product Name'), findsOneWidget);
      expect(find.text('Fridge Shelf'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget);
      expect(find.textContaining('Expires:'), findsOneWidget);
      expect(find.text('Add to Fridge'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
