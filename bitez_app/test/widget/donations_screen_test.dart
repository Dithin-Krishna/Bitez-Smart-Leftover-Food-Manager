import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bitez_app/models/user_model.dart';
import 'package:bitez_app/providers/auth_provider.dart';
import 'package:bitez_app/screens/donations_screen.dart';

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

  group('DonationsScreen Widget Tests', () {
    testWidgets('Renders empty state when no items are pledged', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/fridge/donations')) {
          return http.Response(
            jsonEncode({'items': []}),
            200,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final authProvider = TestAuthProvider();
      authProvider.setLoggedInUser(
        const UserModel(id: 'u1', name: 'Test User', email: 'test@example.com'),
        'fake-jwt-token',
      );

      await http.runWithClient(() async {
        await tester.pumpWidget(buildTestWidget(
          child: const DonationsScreen(),
          authProvider: authProvider,
        ));

        await tester.pumpAndSettle();

        expect(find.text('Food Bank Donations'), findsOneWidget);
        expect(find.text('Community Food Sharing'), findsOneWidget);
        expect(find.text('No Items Pledged for Donation Yet'), findsOneWidget);
        expect(find.text('Food Bank Donation Guidelines'), findsOneWidget);
      }, () => mockClient);
    });

    testWidgets('Renders pledged donation cards with actions', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('/api/fridge/donations')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  '_id': 'don_1',
                  'label': 'Organic Carrots',
                  'emoji': '🥕',
                  'qty': 4,
                  'section': 'veggies',
                  'isDonation': true,
                  'donationStatus': 'pledged',
                  'donationNotes': 'Fresh bundle',
                  'expiresAt': DateTime.now().add(const Duration(days: 4)).toIso8601String(),
                }
              ]
            }),
            200,
            headers: {HttpHeaders.contentTypeHeader: 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final authProvider = TestAuthProvider();
      authProvider.setLoggedInUser(
        const UserModel(id: 'u1', name: 'Test User', email: 'test@example.com'),
        'fake-jwt-token',
      );

      await http.runWithClient(() async {
        await tester.pumpWidget(buildTestWidget(
          child: const DonationsScreen(),
          authProvider: authProvider,
        ));

        await tester.pumpAndSettle();

        expect(find.text('Organic Carrots'), findsOneWidget);
        expect(find.text('Qty: 4'), findsOneWidget);
        expect(find.text('Mark Donated'), findsOneWidget);
        expect(find.text('Cancel Pledge'), findsOneWidget);
        expect(find.textContaining('Fresh bundle'), findsOneWidget);
      }, () => mockClient);
    });
  });
}
