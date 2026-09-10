import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/recipe_model.dart';
import 'offline_storage_service.dart';

/// Multi-API Recipe Service:
/// Blends recipes from:
/// 1. Spoonacular API (Complex search + ingredient search)
/// 2. TheMealDB API (Free open global recipe database)
/// 3. Essential 1 & 2 Ingredient Quick Dishes Dataset (Guarantees pure matches for eggs, bananas, potatoes, bread, rice, etc.)
class RecipeService {
  RecipeService._();
  static final RecipeService instance = RecipeService._();

  // ===========================================================================
  // 🔑 SPOONACULAR API KEY & BASE URLS
  // ===========================================================================
  static const String apiKey = '647c41feef6f4bf8ab9b75b1b52597e5';
  static const String _spoonacularBaseUrl = 'https://api.spoonacular.com/recipes';
  static const String _mealDbBaseUrl = 'https://www.themealdb.com/api/json/v1/1';

  /// Main recipe search method combining Spoonacular, TheMealDB, and Pure Single/Dual Ingredient Recipes.
  Future<List<RecipeModel>> searchByIngredients(
    List<String> ingredients, {
    String? cuisine,
  }) async {
    final queryClean = ingredients
        .map((e) => e.trim())
        .where((s) => s.isNotEmpty && !['leftover food', 'leftovers', 'leftover', 'food', 'my food'].contains(s.toLowerCase()))
        .toList();
    if (queryClean.isEmpty) {
      return _getFallbackRecipes(['Rice', 'Vegetables', 'Eggs'], cuisine: cuisine);
    }

    // Fetch from all sources in parallel
    final resultsFuture = Future.wait<List<RecipeModel>>([
      _fetchSpoonacularRecipes(queryClean, cuisine: cuisine),
      _fetchMealDbRecipes(queryClean),
      Future.value(_getEssentialQuickRecipes(queryClean, cuisine: cuisine)),
    ]);

    try {
      final multiResults = await resultsFuture;
      final combined = <RecipeModel>[];
      final seenTitles = <String>{};

      for (final list in multiResults) {
        for (final recipe in list) {
          final normalizedTitle = recipe.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (!seenTitles.contains(normalizedTitle)) {
            seenTitles.add(normalizedTitle);
            combined.add(recipe);
          }
        }
      }

      if (combined.isEmpty) {
        return _getFallbackRecipes(queryClean, cuisine: cuisine);
      }

      // Sort by missing extra ingredients (0 missing first), then used count ratio
      combined.sort((a, b) {
        final missedComp = a.missedIngredientCount.compareTo(b.missedIngredientCount);
        if (missedComp != 0) return missedComp;
        return b.usedIngredientCount.compareTo(a.usedIngredientCount);
      });

      // Cache search results for offline access
      final queryKey = queryClean.join(',').toLowerCase();
      await OfflineStorageService.instance.cacheSearchResults(
        queryKey,
        combined.map((r) => r.toJson()).toList(),
      );

      return combined;
    } catch (_) {
      // Check offline cache
      final queryKey = queryClean.join(',').toLowerCase();
      final cached = OfflineStorageService.instance.getCachedSearchResults(queryKey);
      if (cached != null && cached.isNotEmpty) {
        return cached.map((j) => RecipeModel.fromJson(j)).toList();
      }
      return _getFallbackRecipes(queryClean, cuisine: cuisine);
    }
  }

  // ── 1. Spoonacular API ───────────────────────────────────────────────────
  Future<List<RecipeModel>> _fetchSpoonacularRecipes(
    List<String> ingredients, {
    String? cuisine,
  }) async {
    if (apiKey == 'YOUR_SPOONACULAR_API_KEY_HERE' || apiKey.trim().isEmpty) {
      return [];
    }

    final queryStr = ingredients.join(',');
    final queryText = ingredients.join(' ');
    final cuisineParam = (cuisine != null && cuisine.isNotEmpty && cuisine != 'All')
        ? '&cuisine=${Uri.encodeComponent(cuisine)}'
        : '';

    final list = <RecipeModel>[];
    try {
      final complexUrl = Uri.parse(
        '$_spoonacularBaseUrl/complexSearch?query=${Uri.encodeComponent(queryText)}&includeIngredients=${Uri.encodeComponent(queryStr)}$cuisineParam&sort=min-missing-ingredients&fillIngredients=true&addRecipeInformation=true&ignorePantry=true&number=10&apiKey=$apiKey',
      );
      final complexRes = await http.get(complexUrl).timeout(const Duration(seconds: 5));
      if (complexRes.statusCode == 200) {
        final data = jsonDecode(complexRes.body);
        if (data['results'] is List) {
          for (final json in data['results']) {
            list.add(RecipeModel.fromComplexSearchJson(json, searchedCount: ingredients.length));
          }
        }
      }

      final findUrl = Uri.parse(
        '$_spoonacularBaseUrl/findByIngredients?ingredients=${Uri.encodeComponent(queryStr)}&number=10&ranking=2&ignorePantry=true&apiKey=$apiKey',
      );
      final findRes = await http.get(findUrl).timeout(const Duration(seconds: 5));
      if (findRes.statusCode == 200) {
        final List data = jsonDecode(findRes.body);
        for (final json in data) {
          list.add(RecipeModel.fromFindByIngredientsJson(json, searchedCount: ingredients.length));
        }
      }
    } catch (_) {}
    return list;
  }

  // ── 2. TheMealDB API ─────────────────────────────────────────────────────
  Future<List<RecipeModel>> _fetchMealDbRecipes(List<String> ingredients) async {
    final list = <RecipeModel>[];
    final mainItem = ingredients.first.toLowerCase();

    try {
      final url = Uri.parse('$_mealDbBaseUrl/filter.php?i=${Uri.encodeComponent(mainItem)}');
      final res = await http.get(url).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['meals'] is List) {
          final List meals = data['meals'];
          for (final m in meals.take(6)) {
            final mealId = m['idMeal']?.toString();
            if (mealId != null) {
              final detailUrl = Uri.parse('$_mealDbBaseUrl/lookup.php?i=$mealId');
              final detailRes = await http.get(detailUrl).timeout(const Duration(seconds: 3));
              if (detailRes.statusCode == 200) {
                final detailData = jsonDecode(detailRes.body);
                if (detailData['meals'] is List && (detailData['meals'] as List).isNotEmpty) {
                  list.add(RecipeModel.fromMealDbJson(detailData['meals'][0], ingredients));
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return list;
  }

  // ── 3. Essential 1 & 2 Ingredient Quick Dishes Dataset ────────────────────
  List<RecipeModel> _getEssentialQuickRecipes(List<String> ingredients, {String? cuisine}) {
    final list = <RecipeModel>[];
    
    // Generates pure 0-extra ingredient recipes for ANY input item (e.g. 2 banana, apple, chicken, etc.)
    list.addAll(_generatePureSingleIngredientRecipes(ingredients));

    final queryText = ingredients.map((e) => e.toLowerCase()).join(' ');
    
    final isEgg = queryText.contains('egg');
    final isPotato = queryText.contains('potato');
    final isBread = queryText.contains('bread') || queryText.contains('toast');
    final isCheese = queryText.contains('cheese');

    if (isEgg) {
      list.addAll([
        const RecipeModel(
          id: 715538,
          title: 'Classic French Omelette',
          image: 'https://img.spoonacular.com/recipes/715538-556x370.jpg',
          usedIngredientCount: 1,
          missedIngredientCount: 0,
          usedIngredients: ['2 Eggs'],
          missedIngredients: [],
          readyInMinutes: 5,
          servings: 1,
          summary: 'Silky smooth golden omelette made pure with just 2 eggs.',
          instructions: [
            'Whisk 2 eggs thoroughly with 1 pinch of salt.',
            'Melt 1 tsp butter in non-stick skillet over medium-low heat.',
            'Pour in whisked eggs and stir constantly until creamy.',
            'Fold gently and slide onto plate for a soft, silky omelette.',
          ],
          searchedIngredientCount: 1,
        ),
        const RecipeModel(
          id: 716429,
          title: 'Fluffy Scrambled Eggs',
          image: 'https://img.spoonacular.com/recipes/716429-556x370.jpg',
          usedIngredientCount: 1,
          missedIngredientCount: 0,
          usedIngredients: ['2 Eggs'],
          missedIngredients: [],
          readyInMinutes: 4,
          servings: 1,
          summary: 'Light and fluffy scrambled eggs cooked gently in 4 minutes.',
          instructions: [
            'Crack 2 eggs into a small bowl and whisk until homogenous.',
            'Heat skillet on low heat with a tiny drop of oil or butter.',
            'Pour in eggs and sweep gently with a spatula from edges to center.',
            'Remove from heat immediately while soft and moist. Season & serve.',
          ],
          searchedIngredientCount: 1,
        ),
        const RecipeModel(
          id: 716428,
          title: 'Sunny-Side Up Fried Egg (Bullseye)',
          image: 'https://img.spoonacular.com/recipes/716428-556x370.jpg',
          usedIngredientCount: 1,
          missedIngredientCount: 0,
          usedIngredients: ['2 Eggs'],
          missedIngredients: [],
          readyInMinutes: 3,
          servings: 1,
          summary: 'Crispy golden bottom with a warm runny yolk center.',
          instructions: [
            'Heat 1 tsp oil in skillet over medium heat.',
            'Crack 2 eggs carefully into pan without breaking yolk.',
            'Cook 3 minutes until white is firm. Season with black pepper & salt.',
          ],
          searchedIngredientCount: 1,
        ),
        const RecipeModel(
          id: 642583,
          title: 'Perfect Soft & Hard Boiled Eggs',
          image: 'https://img.spoonacular.com/recipes/642583-556x370.jpg',
          usedIngredientCount: 1,
          missedIngredientCount: 0,
          usedIngredients: ['2 Eggs'],
          missedIngredients: [],
          readyInMinutes: 7,
          servings: 1,
          summary: 'Pure boiled eggs cooked to perfection.',
          instructions: [
            'Bring pot of water to a boil.',
            'Lower 2 eggs into boiling water.',
            'Boil 6 mins for soft jammy yolk, or 9 mins for hard boiled. Peel & serve.',
          ],
          searchedIngredientCount: 1,
        ),
      ]);

      if (isCheese) {
        list.add(
          const RecipeModel(
            id: 716434,
            title: 'Gourmet Cheese Omelette',
            image: 'https://img.spoonacular.com/recipes/715538-556x370.jpg',
            usedIngredientCount: 2,
            missedIngredientCount: 0,
            usedIngredients: ['2 Eggs', 'Cheese'],
            missedIngredients: [],
            readyInMinutes: 6,
            servings: 1,
            summary: 'Fluffy egg omelette loaded with melted warm cheese.',
            instructions: [
              'Whisk 2 eggs and pour into warm buttered skillet.',
              'Sprinkle shredded cheese over half the setting eggs.',
              'Fold over and let cheese melt 1 minute before serving.',
            ],
            searchedIngredientCount: 2,
          ),
        );
      }

      if (isBread) {
        list.add(
          const RecipeModel(
            id: 716435,
            title: 'Classic Egg Toast',
            image: 'https://img.spoonacular.com/recipes/716428-556x370.jpg',
            usedIngredientCount: 2,
            missedIngredientCount: 0,
            usedIngredients: ['2 Eggs', 'Bread'],
            missedIngredients: [],
            readyInMinutes: 6,
            servings: 1,
            summary: 'Toasted bread topped with fried or scrambled eggs.',
            instructions: [
              'Toast slices of bread until golden.',
              'Fry or scramble eggs in skillet.',
              'Place eggs on top of warm toast, season and serve.',
            ],
            searchedIngredientCount: 2,
          ),
        );
      }
    }

    if (isPotato) {
      list.addAll([
        const RecipeModel(
          id: 716440,
          title: 'Pan-Seared Crispy Potato Fry',
          image: 'https://img.spoonacular.com/recipes/716429-556x370.jpg',
          usedIngredientCount: 1,
          missedIngredientCount: 0,
          usedIngredients: ['Potato'],
          missedIngredients: [],
          readyInMinutes: 10,
          servings: 1,
          summary: 'Diced potatoes pan-fried to golden crispy perfection.',
          instructions: [
            'Dice potatoes into small cubes.',
            'Heat 1 tbsp oil in pan over medium heat.',
            'Fry potatoes 8-10 minutes, flipping occasionally until golden brown and tender.',
          ],
          searchedIngredientCount: 1,
        ),
        const RecipeModel(
          id: 716441,
          title: 'Creamy Mashed Potatoes',
          image: 'https://img.spoonacular.com/recipes/642583-556x370.jpg',
          usedIngredientCount: 1,
          missedIngredientCount: 0,
          usedIngredients: ['Potato'],
          missedIngredients: [],
          readyInMinutes: 15,
          servings: 2,
          summary: 'Soft, buttery mashed potatoes.',
          instructions: [
            'Boil peeled potato cubes in salted water for 12 minutes until fork tender.',
            'Drain and mash thoroughly with butter, salt and pepper.',
          ],
          searchedIngredientCount: 1,
        ),
      ]);
    }

    if (isBread) {
      list.add(
        const RecipeModel(
          id: 716445,
          title: 'Golden Garlic Butter Toast',
          image: 'https://img.spoonacular.com/recipes/715538-556x370.jpg',
          usedIngredientCount: 1,
          missedIngredientCount: 0,
          usedIngredients: ['Bread'],
          missedIngredients: [],
          readyInMinutes: 5,
          servings: 1,
          summary: 'Crispy toasted bread brushed with warm butter.',
          instructions: [
            'Spread butter on bread slices.',
            'Toast on hot pan for 2 minutes each side until golden crisp.',
          ],
          searchedIngredientCount: 1,
        ),
      );
    }

    return list;
  }

  /// Dynamic 100% Pure Zero-Extra Ingredient Recipe Generator for ANY input ingredient!
  List<RecipeModel> _generatePureSingleIngredientRecipes(List<String> ingredients) {
    if (ingredients.isEmpty) return [];

    final list = <RecipeModel>[];
    for (int idx = 0; idx < ingredients.length; idx++) {
      final rawItem = ingredients[idx].trim();
      if (rawItem.isEmpty) continue;

      // Clean leading numbers/quantities (e.g. "2 banana" -> "banana", "1 cup rice" -> "rice")
      final cleanName = rawItem
          .replaceAll(RegExp(r'^\d+\s*'), '')
          .replaceAll(RegExp(r'^(one|two|three|four|five|1|2|3|4|5)\s+(cup|cups|kg|g|lb|piece|pieces)?\s*', caseSensitive: false), '')
          .trim();

      final capitalized = cleanName.isNotEmpty
          ? '${cleanName[0].toUpperCase()}${cleanName.substring(1)}'
          : 'Ingredient';

      final itemLower = cleanName.toLowerCase();

      // 🌾 1. Rice & Grains (steamed, boiled kanji, toasted)
      if (itemLower.contains('rice') || itemLower.contains('basmati') || itemLower.contains('poha') || itemLower.contains('quinoa')) {
        list.add(
          RecipeModel(
            id: 900051 + idx * 10,
            title: 'Fluffy Steamed $capitalized',
            image: 'https://img.spoonacular.com/recipes/716429-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 12,
            servings: 2,
            summary: 'Soft, tender, fluffy steamed $cleanName prepared pure with water.',
            instructions: [
              'Rinse 1 cup of $cleanName in cold water until clear.',
              'Add to a pot with 2 cups of water and a pinch of salt.',
              'Bring to a rolling boil, then cover with lid and reduce heat to low.',
              'Simmer 12 minutes undisturbed until water is fully absorbed.',
              'Fluff gently with a fork and serve hot.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
        list.add(
          RecipeModel(
            id: 900052 + idx * 10,
            title: 'Comforting $capitalized Kanji (Porridge)',
            image: 'https://img.spoonacular.com/recipes/642583-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 18,
            servings: 2,
            summary: 'Warm, highly digestible, soothing $cleanName porridge.',
            instructions: [
              'Add $cleanName to pot with 4 cups of water.',
              'Boil over medium heat for 18-20 minutes until grains are soft and broken down.',
              'Season with a pinch of salt and serve warm in a bowl.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
        list.add(
          RecipeModel(
            id: 900053 + idx * 10,
            title: 'Crispy Pan-Toasted $capitalized',
            image: 'https://img.spoonacular.com/recipes/715538-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 5,
            servings: 1,
            summary: 'Nutty, warm pan-roasted $cleanName snack.',
            instructions: [
              'Heat a dry skillet over medium heat.',
              'Add $cleanName and dry-roast for 4-5 minutes, stirring continuously until golden and crunchy.',
              'Enjoy as a light crunchy grain snack.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
      }
      // 🥣 2. Oats
      else if (itemLower.contains('oat') || itemLower.contains('oatmeal')) {
        list.add(
          RecipeModel(
            id: 900061 + idx * 10,
            title: 'Classic Steamed Oatmeal',
            image: 'https://img.spoonacular.com/recipes/716429-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 5,
            servings: 1,
            summary: 'Warm, thick, creamy 100% oats porridge.',
            instructions: [
              'Combine oats and water in a saucepan over medium heat.',
              'Simmer for 5 minutes, stirring occasionally until thick and soft.',
              'Serve hot in a bowl.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
      }
      // 🥛 3. Milk & Liquids
      else if (itemLower.contains('milk') || itemLower.contains('curd') || itemLower.contains('yogurt')) {
        list.add(
          RecipeModel(
            id: 900071 + idx * 10,
            title: 'Warm Comforting $capitalized',
            image: 'https://img.spoonacular.com/recipes/716429-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 3,
            servings: 1,
            summary: 'Gently warmed $cleanName for a relaxing drink.',
            instructions: [
              'Pour $cleanName into a saucepan.',
              'Warm over low-medium heat for 2-3 minutes until steam gently rises.',
              'Pour into a mug and enjoy warm.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
      }
      // 🍌 4. Bananas
      else if (itemLower.contains('banana')) {
        list.add(
          RecipeModel(
            id: 900101 + idx * 10,
            title: 'Pure Frozen Banana Pops & Bites',
            image: 'https://img.spoonacular.com/recipes/716429-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 5,
            servings: 1,
            summary: '100% pure $cleanName snack. Slice and freeze for 15 minutes for a natural creamy banana ice-cream bite.',
            instructions: [
              'Peel the $cleanName and slice into 1/2-inch round coins.',
              'Arrange slices on a plate or tray.',
              'Freeze for 15-20 minutes until firm and chilled.',
              'Enjoy as a 100% natural, guilt-free creamy fruit treat.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
        list.add(
          RecipeModel(
            id: 900102 + idx * 10,
            title: 'Warm Caramelized Banana Slices',
            image: 'https://img.spoonacular.com/recipes/715538-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 4,
            servings: 1,
            summary: 'Pan-seared warm $cleanName slices releasing natural fruit sugars.',
            instructions: [
              'Peel $cleanName and slice diagonally.',
              'Heat a dry non-stick skillet over medium-low heat.',
              'Sear banana slices 2 minutes on each side until warm, soft, and lightly golden.',
              'Serve warm as a quick healthy dessert.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
        list.add(
          RecipeModel(
            id: 900103 + idx * 10,
            title: 'Fresh Mashed Banana Puree',
            image: 'https://img.spoonacular.com/recipes/642583-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 2,
            servings: 1,
            summary: 'Silky smooth fresh $cleanName puree.',
            instructions: [
              'Peel $cleanName and place in a bowl.',
              'Mash thoroughly with a fork until smooth and creamy.',
              'Enjoy fresh as a quick nutritious snack.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
      }
      // 🍎 5. Apples
      else if (itemLower.contains('apple')) {
        list.add(
          RecipeModel(
            id: 900201 + idx * 10,
            title: 'Crispy Fresh Apple Wedges',
            image: 'https://img.spoonacular.com/recipes/642583-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 3,
            servings: 1,
            summary: 'Refreshing sliced crisp $cleanName.',
            instructions: [
              'Wash $cleanName thoroughly under cold water.',
              'Core and slice into thin even wedges.',
              'Serve immediately for a crisp, refreshing snack.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
        list.add(
          RecipeModel(
            id: 900202 + idx * 10,
            title: 'Warm Stewed Apples',
            image: 'https://img.spoonacular.com/recipes/716428-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 7,
            servings: 1,
            summary: 'Tender warm cooked $cleanName slices.',
            instructions: [
              'Peel, core, and dice $cleanName into small cubes.',
              'Place in saucepan with 1 tbsp water on low heat.',
              'Cover and simmer 5-7 minutes until soft and fragrant.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
      }
      // 🍗 6. Chicken / Poultry / Meat
      else if (itemLower.contains('chicken') || itemLower.contains('meat') || itemLower.contains('fish')) {
        list.add(
          RecipeModel(
            id: 900301 + idx * 10,
            title: 'Simple Pan-Seared $capitalized',
            image: 'https://img.spoonacular.com/recipes/716429-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 12,
            servings: 1,
            summary: 'Tender pan-seared $cleanName cooked in its own natural juices.',
            instructions: [
              'Clean and slice $cleanName into cutlets.',
              'Heat pan over medium heat with light oil.',
              'Sear 5-6 minutes per side until golden brown and cooked through.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
      }
      // 🥔 7. Potatoes & Tubers
      else if (itemLower.contains('potato')) {
        list.add(
          RecipeModel(
            id: 900401 + idx * 10,
            title: 'Pan-Seared Crispy $capitalized Fry',
            image: 'https://img.spoonacular.com/recipes/716429-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 10,
            servings: 1,
            summary: 'Diced $cleanName pan-fried to golden crispy perfection.',
            instructions: [
              'Dice $cleanName into small cubes.',
              'Heat pan over medium heat with oil.',
              'Fry 8-10 minutes until golden brown and tender.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
        list.add(
          RecipeModel(
            id: 900402 + idx * 10,
            title: 'Creamy Mashed $capitalized',
            image: 'https://img.spoonacular.com/recipes/642583-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 14,
            servings: 2,
            summary: 'Soft, tender mashed $cleanName.',
            instructions: [
              'Boil peeled $cleanName cubes in water for 12 minutes until fork tender.',
              'Drain and mash thoroughly until creamy.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
      }
      // 🍞 8. Bread & Bakery
      else if (itemLower.contains('bread') || itemLower.contains('toast') || itemLower.contains('roti')) {
        list.add(
          RecipeModel(
            id: 900501 + idx * 10,
            title: 'Golden Pan-Toasted $capitalized',
            image: 'https://img.spoonacular.com/recipes/715538-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 4,
            servings: 1,
            summary: 'Crispy warm pan-toasted $cleanName.',
            instructions: [
              'Place $cleanName on a dry skillet over medium heat.',
              'Toast for 2 minutes on each side until golden and crispy.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
      }
      // 🍲 9. Generic Fallback for Other Uncategorized Ingredients
      else {
        list.add(
          RecipeModel(
            id: 900901 + idx * 10,
            title: 'Steamed & Tender $capitalized',
            image: 'https://img.spoonacular.com/recipes/716429-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 8,
            servings: 1,
            summary: '100% pure $cleanName prepared simply with zero extra ingredients.',
            instructions: [
              'Wash and chop your $cleanName.',
              'Steam or boil gently for 6-8 minutes until tender.',
              'Serve hot as a pure 100% single-ingredient meal.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
        list.add(
          RecipeModel(
            id: 900902 + idx * 10,
            title: 'Fresh Prep $capitalized Bowl',
            image: 'https://img.spoonacular.com/recipes/715538-556x370.jpg',
            usedIngredientCount: 1,
            missedIngredientCount: 0,
            usedIngredients: [rawItem],
            missedIngredients: [],
            readyInMinutes: 4,
            servings: 1,
            summary: 'Freshly prepared pure $cleanName bowl.',
            instructions: [
              'Clean and slice your $cleanName.',
              'Arrange neatly in a bowl.',
              'Serve fresh directly without any extra ingredients.',
            ],
            searchedIngredientCount: ingredients.length,
          ),
        );
      }
    }

    return list;
  }

  /// Get recipe detail lookup (Spoonacular or TheMealDB)
  Future<RecipeModel> getRecipeInformation(int recipeId) async {
    // If ID is from TheMealDB (typically 50000..999999)
    if (recipeId >= 50000 && recipeId <= 899999) {
      try {
        final url = Uri.parse('$_mealDbBaseUrl/lookup.php?i=$recipeId');
        final response = await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['meals'] is List && (data['meals'] as List).isNotEmpty) {
            return RecipeModel.fromMealDbJson(data['meals'][0], []);
          }
        }
      } catch (_) {}
    }

    if (apiKey == 'YOUR_SPOONACULAR_API_KEY_HERE' || apiKey.trim().isEmpty) {
      return _getFallbackDetails(recipeId);
    }

    final url = Uri.parse(
      '$_spoonacularBaseUrl/$recipeId/information?includeInstructions=true&apiKey=$apiKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final recipe = RecipeModel.fromDetailJson(json);
        await OfflineStorageService.instance.cacheRecipeDetail('$recipeId', recipe.toJson());
        return recipe;
      } else {
        final cached = OfflineStorageService.instance.getCachedRecipeDetail('$recipeId');
        if (cached != null) return RecipeModel.fromJson(cached);
        return _getFallbackDetails(recipeId);
      }
    } catch (e) {
      final cached = OfflineStorageService.instance.getCachedRecipeDetail('$recipeId');
      if (cached != null) return RecipeModel.fromJson(cached);
      return _getFallbackDetails(recipeId);
    }
  }

  List<RecipeModel> _getFallbackRecipes(List<String> ingredients, {String? cuisine}) {
    return _getEssentialQuickRecipes(ingredients, cuisine: cuisine);
  }

  RecipeModel _getFallbackDetails(int id) {
    return RecipeModel(
      id: id,
      title: 'Delicious Quick Recipe',
      image: 'https://img.spoonacular.com/recipes/716429-556x370.jpg',
      readyInMinutes: 10,
      servings: 1,
      summary: 'A quick meal prepared with minimal ingredients.',
      usedIngredients: ['Main Ingredients', 'Salt & Pepper'],
      instructions: [
        'Prepare and clean your input ingredients.',
        'Heat pan over medium heat with oil or butter.',
        'Sauté or cook ingredients until golden and tender.',
        'Season to taste and enjoy hot.',
      ],
    );
  }
}
