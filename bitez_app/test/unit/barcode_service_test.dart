import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bitez_app/services/barcode_service.dart';

void main() {
  group('BarcodeService Open Food Facts Unit Tests', () {
    test('Correctly parses product with nutrition and valid expiration date', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v0/product/3017620422003.json');
        return http.Response(
          jsonEncode({
            'status': 1,
            'status_verbose': 'product found',
            'product': {
              'product_name': 'Nutella',
              'brands': 'Ferrero',
              'categories': 'Spreads, Breakfasts, Cocoa and hazelnuts spreads',
              'categories_tags': ['en:spreads', 'en:sweet-spreads'],
              'expiration_date': '2027-12-31',
              'image_front_url': 'https://images.openfoodfacts.org/images/products/301/762/042/2003/front_en.jpg',
              'nutriments': {
                'energy-kcal_100g': 539.0,
                'proteins_100g': 6.3,
                'carbohydrates_100g': 57.5,
                'fat_100g': 30.9,
              },
            },
          }),
          200,
        );
      });

      final result = await BarcodeService.instance.fetchProductByBarcode(
        '3017620422003',
        client: mockClient,
      );

      expect(result, isNotNull);
      expect(result!.barcode, '3017620422003');
      expect(result.productName, contains('Nutella'));
      expect(result.brand, 'Ferrero');
      expect(result.foodItem.section, 'condiments');
      expect(result.foodItem.category, 'Condiments & Spices');
      expect(result.nutrition, isNotNull);
      expect(result.nutrition!.calories, 539.0);
      expect(result.nutrition!.proteins, 6.3);
      expect(result.nutrition!.carbs, 57.5);
      expect(result.nutrition!.fat, 30.9);
      expect(result.foodItem.expiresAt, isNotNull);
      expect(result.foodItem.expiresAt!.year, 2027);
    });

    test('Maps dairy keywords to dairy section and 🥛 emoji with default shelf life', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 1,
            'product': {
              'product_name': 'Organic Whole Milk',
              'brands': 'Horizon',
              'categories': 'Dairies, Milks, Fresh Milk',
            },
          }),
          200,
        );
      });

      final result = await BarcodeService.instance.fetchProductByBarcode(
        '0742365264448',
        client: mockClient,
      );

      expect(result, isNotNull);
      expect(result!.foodItem.label, contains('Organic Whole Milk'));
      expect(result.foodItem.section, 'dairy');
      expect(result.foodItem.category, 'Dairy & Eggs');
      expect(result.foodItem.emoji, '🥛');
      // Default shelf life for dairy is 10 days
      final diffDays = result.foodItem.expiresAt!.difference(DateTime.now()).inDays;
      expect(diffDays, inInclusiveRange(9, 11));
    });

    test('Returns null when product status is 0 (not found)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 0,
            'status_verbose': 'product not found',
          }),
          200,
        );
      });

      final result = await BarcodeService.instance.fetchProductByBarcode(
        '9999999999999',
        client: mockClient,
      );

      expect(result, isNull);
    });

    test('Returns null gracefully on HTTP 404 or network error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final result = await BarcodeService.instance.fetchProductByBarcode(
        '123456789',
        client: mockClient,
      );

      expect(result, isNull);
    });

    test('Returns null immediately on empty or whitespace barcode', () async {
      final result = await BarcodeService.instance.fetchProductByBarcode('   ');
      expect(result, isNull);
    });
  });
}
