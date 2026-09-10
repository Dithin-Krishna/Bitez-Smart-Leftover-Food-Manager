import 'dart:convert';
import 'package:http/http.dart' as http;
import 'food_recognition_service.dart';

/// Nutrition information extracted from Open Food Facts.
class NutritionInfo {
  final double? calories;
  final double? proteins;
  final double? carbs;
  final double? fat;

  const NutritionInfo({
    this.calories,
    this.proteins,
    this.carbs,
    this.fat,
  });

  factory NutritionInfo.fromJson(Map<String, dynamic> nutriments) {
    double? parseNum(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    return NutritionInfo(
      calories: parseNum(nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal']),
      proteins: parseNum(nutriments['proteins_100g']),
      carbs:    parseNum(nutriments['carbohydrates_100g']),
      fat:      parseNum(nutriments['fat_100g']),
    );
  }
}

/// Result returned from scanning a barcode against Open Food Facts.
class BarcodeProductResult {
  final String barcode;
  final String productName;
  final String? brand;
  final String? imageUrl;
  final RecognizedFoodItem foodItem;
  final NutritionInfo? nutrition;

  const BarcodeProductResult({
    required this.barcode,
    required this.productName,
    this.brand,
    this.imageUrl,
    required this.foodItem,
    this.nutrition,
  });
}

/// Service that queries the public Open Food Facts database for barcode metadata.
class BarcodeService {
  BarcodeService._();
  static final BarcodeService instance = BarcodeService._();

  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v0/product';
  static const String _userAgent = 'Bitez-LeftoverFoodManager/1.0.0 (contact@bitez.app)';

  /// Queries Open Food Facts for the given barcode.
  /// Returns `BarcodeProductResult` if product exists, or `null` if not found.
  Future<BarcodeProductResult?> fetchProductByBarcode(
    String barcode, {
    http.Client? client,
  }) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) return null;

    final httpClient = client ?? http.Client();
    final shouldClose = client == null;

    try {
      final uri = Uri.parse('$_baseUrl/$cleanCode.json');
      final response = await httpClient.get(
        uri,
        headers: {
          'User-Agent': _userAgent,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final status = body['status'];
      if (status != 1 || body['product'] == null) {
        return null;
      }

      final product = body['product'] as Map<String, dynamic>;

      // Extract title / name
      final rawName = product['product_name'] ??
          product['product_name_en'] ??
          product['generic_name'] ??
          product['brands'] ??
          'Packaged Food';
      final brand = product['brands']?.toString();
      final imageUrl = product['image_front_url']?.toString() ?? product['image_url']?.toString();

      final fullLabel = (brand != null && brand.isNotEmpty && !rawName.toString().toLowerCase().contains(brand.toLowerCase()))
          ? '$brand ${rawName.toString()}'
          : rawName.toString();

      // Determine category and section
      final rawCategories = '${product['categories'] ?? ''} ${product['categories_tags'] ?? ''}';
      final section = _inferSection(rawCategories, fullLabel);
      final category = _sectionToCategory(section);
      final emoji = _inferEmoji(section, fullLabel);

      // Parse expiration date or default to shelf life
      final rawExpiry = product['expiration_date']?.toString();
      final expiresAt = _parseOrEstimateExpiry(rawExpiry, section);

      // Extract nutrition
      NutritionInfo? nutrition;
      if (product['nutriments'] is Map<String, dynamic>) {
        nutrition = NutritionInfo.fromJson(product['nutriments'] as Map<String, dynamic>);
      }

      final foodItem = RecognizedFoodItem(
        label: fullLabel,
        category: category,
        section: section,
        emoji: emoji,
        qty: 1,
        isSelected: true,
        isValidated: true,
        expiresAt: expiresAt,
      );

      return BarcodeProductResult(
        barcode: cleanCode,
        productName: fullLabel,
        brand: brand,
        imageUrl: imageUrl,
        foodItem: foodItem,
        nutrition: nutrition,
      );
    } catch (_) {
      return null;
    } finally {
      if (shouldClose) {
        httpClient.close();
      }
    }
  }

  static String _inferSection(String categories, String label) {
    final combined = '${categories.toLowerCase()} ${label.toLowerCase()}';

    if (combined.contains('milk') ||
        combined.contains('cheese') ||
        combined.contains('dairy') ||
        combined.contains('yogurt') ||
        combined.contains('yoghurt') ||
        combined.contains('butter') ||
        combined.contains('egg')) {
      return 'dairy';
    }

    if (combined.contains('vegetable') ||
        combined.contains('veggie') ||
        combined.contains('salad') ||
        combined.contains('carrot') ||
        combined.contains('potato') ||
        combined.contains('tomato') ||
        combined.contains('onion') ||
        combined.contains('spinach')) {
      return 'veggies';
    }

    if (combined.contains('fruit') ||
        combined.contains('apple') ||
        combined.contains('banana') ||
        combined.contains('orange') ||
        combined.contains('berry') ||
        combined.contains('mango') ||
        combined.contains('peach')) {
      return 'fruits';
    }

    if (combined.contains('frozen') ||
        combined.contains('ice cream') ||
        combined.contains('pizza') ||
        combined.contains('dumpling')) {
      return 'frozen';
    }

    if (combined.contains('beverage') ||
        combined.contains('drink') ||
        combined.contains('juice') ||
        combined.contains('soda') ||
        combined.contains('tea') ||
        combined.contains('coffee') ||
        combined.contains('water')) {
      return 'drinks';
    }

    if (combined.contains('sauce') ||
        combined.contains('spread') ||
        combined.contains('jam') ||
        combined.contains('jelly') ||
        combined.contains('nutella') ||
        combined.contains('peanut butter') ||
        combined.contains('ketchup') ||
        combined.contains('mayo') ||
        combined.contains('mustard') ||
        combined.contains('spice') ||
        combined.contains('condiment') ||
        combined.contains('oil') ||
        combined.contains('vinegar')) {
      return 'condiments';
    }

    return 'pantry';
  }

  static String _sectionToCategory(String section) {
    switch (section) {
      case 'dairy':
        return 'Dairy & Eggs';
      case 'veggies':
        return 'Vegetables';
      case 'fruits':
        return 'Fruits';
      case 'frozen':
        return 'Frozen Foods';
      case 'drinks':
        return 'Beverages';
      case 'condiments':
        return 'Condiments & Spices';
      default:
        return 'Pantry';
    }
  }

  static String _inferEmoji(String section, String label) {
    final l = label.toLowerCase();
    if (l.contains('milk')) return '🥛';
    if (l.contains('cheese')) return '🧀';
    if (l.contains('egg')) return '🥚';
    if (l.contains('butter')) return '🧈';
    if (l.contains('yogurt')) return '🍦';
    if (l.contains('bread')) return '🍞';
    if (l.contains('cookie') || l.contains('biscuit')) return '🍪';
    if (l.contains('chocolate')) return '🍫';
    if (l.contains('juice') || l.contains('drink')) return '🧃';
    if (l.contains('coffee') || l.contains('tea')) return '☕';
    if (l.contains('apple')) return '🍎';
    if (l.contains('banana')) return '🍌';
    if (l.contains('tomato')) return '🍅';
    if (l.contains('carrot')) return '🥕';
    if (l.contains('noodle') || l.contains('pasta') || l.contains('ramen')) return '🍜';
    if (l.contains('rice')) return '🍚';
    if (l.contains('sauce') || l.contains('ketchup')) return '🥫';

    switch (section) {
      case 'dairy':
        return '🥛';
      case 'veggies':
        return '🥗';
      case 'fruits':
        return '🍎';
      case 'frozen':
        return '🥟';
      case 'drinks':
        return '🧃';
      case 'condiments':
        return '🧂';
      default:
        return '📦';
    }
  }

  static DateTime _parseOrEstimateExpiry(String? rawExpiry, String section) {
    final now = DateTime.now();

    if (rawExpiry != null && rawExpiry.trim().isNotEmpty) {
      final clean = rawExpiry.trim();

      // Try ISO YYYY-MM-DD
      final parsed = DateTime.tryParse(clean);
      if (parsed != null && parsed.isAfter(now)) {
        return parsed;
      }

      // Try DD/MM/YYYY or DD-MM-YYYY
      final slashParts = clean.split(RegExp(r'[/.-]'));
      if (slashParts.length == 3) {
        final d = int.tryParse(slashParts[0]);
        final m = int.tryParse(slashParts[1]);
        final y = int.tryParse(slashParts[2]);
        if (d != null && m != null && y != null) {
          final year = y < 100 ? 2000 + y : y;
          final custom = DateTime(year, m, d);
          if (custom.isAfter(now)) {
            return custom;
          }
        }
      }
    }

    // Default shelf life days by section
    final days = _defaultShelfLifeDays(section);
    return now.add(Duration(days: days));
  }

  static int _defaultShelfLifeDays(String section) {
    switch (section) {
      case 'dairy':
        return 10;
      case 'veggies':
        return 7;
      case 'fruits':
        return 7;
      case 'drinks':
        return 30;
      case 'frozen':
        return 90;
      case 'condiments':
        return 180;
      default:
        return 30; // pantry
    }
  }
}
