import '../models/meal_plan_model.dart';
import 'api_service.dart';
import 'grocery_service.dart';

/// Service responsible for managing weekly meal plans and generating consolidated grocery lists.
class MealPlannerService {
  MealPlannerService._();
  static final MealPlannerService instance = MealPlannerService._();

  /// GET /api/meal-planner
  Future<WeeklyMealPlan> getWeeklyMealPlan(String token) async {
    final json = await ApiService.instance.get(
      '/api/meal-planner',
      token: token,
    );
    return WeeklyMealPlan.fromJson(json);
  }

  /// POST /api/meal-planner/pin
  Future<MealPlanItem> pinRecipe({
    required String token,
    required String dayOfWeek,
    required String recipeTitle,
    String? recipeId,
    String? imageUrl,
    List<String> ingredients = const [],
    int cookTime = 20,
    String mealType = 'dinner',
    int servings = 2,
  }) async {
    final json = await ApiService.instance.post(
      '/api/meal-planner/pin',
      {
        'dayOfWeek': dayOfWeek.toLowerCase(),
        'recipeTitle': recipeTitle,
        if (recipeId != null) 'recipeId': recipeId,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'ingredients': ingredients,
        'cookTime': cookTime,
        'mealType': mealType,
        'servings': servings,
      },
      token: token,
    );

    return MealPlanItem.fromJson(Map<String, dynamic>.from(json['item'] as Map));
  }

  /// DELETE /api/meal-planner/:id
  Future<void> unpinRecipe({
    required String token,
    required String id,
  }) async {
    await ApiService.instance.delete(
      '/api/meal-planner/$id',
      token: token,
    );
  }

  /// Extracts clean ingredient name from raw recipe strings (e.g. "2 large eggs" -> "eggs").
  static String extractCleanIngredientName(String raw) {
    String clean = raw.trim();
    // Remove parenthetical details e.g. "(diced)"
    clean = clean.replaceAll(RegExp(r'\([^)]*\)'), '').trim();

    // Strip leading quantities and measurement units
    clean = clean.replaceFirst(
      RegExp(
        r'^[\d\s\/\.\,\-¼½¾⅓⅔⅛⅜⅝⅞]+'
        r'(cups?|tbsps?|tsps?|tablespoons?|teaspoons?|oz|ounces?|lbs?|pounds?|g|grams?|kg|ml|liters?|pinch(es)?|cloves?|slices?|cans?|pieces?|large|medium|small|bunch|dash|pkg|package)?\s+'
        r'(of\s+)?',
        caseSensitive: false,
      ),
      '',
    ).trim();

    return clean.isEmpty ? raw.trim() : clean;
  }

  /// Generates a consolidated grocery list from all pinned meals across the week,
  /// deduplicating against existing grocery items using Feature 2's bulk add API.
  Future<Map<String, dynamic>> generateConsolidatedGroceryList({
    required String token,
  }) async {
    // 1. Fetch current weekly meal plan
    final plan = await getWeeklyMealPlan(token);
    final rawIngredients = plan.allConsolidatedIngredients;

    if (rawIngredients.isEmpty) {
      return {'count': 0, 'items': []};
    }

    // 2. Extract and deduplicate clean ingredient names
    final seen = <String>{};
    final bulkPayload = <Map<String, dynamic>>[];

    for (final raw in rawIngredients) {
      final clean = extractCleanIngredientName(raw);
      if (clean.isNotEmpty && !seen.contains(clean.toLowerCase())) {
        seen.add(clean.toLowerCase());
        bulkPayload.add({
          'label': clean,
          'qty': 1,
          'category': 'Pantry',
          'isBought': false,
        });
      }
    }

    // 3. Dispatch to GroceryService bulk endpoint (Feature 2)
    final added = await GroceryService.instance.addBulkItems(
      token: token,
      items: bulkPayload,
    );

    return {
      'count': added.length,
      'items': added,
    };
  }
}
