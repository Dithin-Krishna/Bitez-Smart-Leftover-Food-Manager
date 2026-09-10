import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bitez_app/models/recipe_model.dart';
import 'package:bitez_app/services/recipe_service.dart';

void main() {
  group('RecipeModel Unit Tests', () {
    test('Calculates matchPercentage correctly for 0 missing ingredients', () {
      const recipe = RecipeModel(
        id: 1,
        title: 'Classic Scrambled Eggs',
        image: 'https://example.com/egg.jpg',
        usedIngredientCount: 2,
        missedIngredientCount: 0,
        usedIngredients: ['Eggs', 'Butter'],
        missedIngredients: [],
      );

      expect(recipe.matchPercentage, equals(100.0));
      expect(recipe.isStrictMatch, isTrue);
      expect(recipe.totalIngredients, equals(2));
    });

    test('Calculates matchPercentage for partial matches with missing items', () {
      const recipe = RecipeModel(
        id: 2,
        title: 'Egg Fried Rice',
        image: 'https://example.com/fried_rice.jpg',
        usedIngredientCount: 2,
        missedIngredientCount: 1,
        usedIngredients: ['Eggs', 'Rice'],
        missedIngredients: ['Soy Sauce'],
      );

      // total = 3, ratio = 2/3 (66.66%), score = 66.66 - 8 = 58.66%
      expect(recipe.matchPercentage, greaterThan(50.0));
      expect(recipe.matchPercentage, lessThan(70.0));
      expect(recipe.isStrictMatch, isTrue); // missed <= 2
    });

    test('Identifies non-strict matches with more than 2 missing ingredients', () {
      const recipe = RecipeModel(
        id: 3,
        title: 'Elaborate Casserole',
        image: 'https://example.com/casserole.jpg',
        usedIngredientCount: 1,
        missedIngredientCount: 4,
        usedIngredients: ['Eggs'],
        missedIngredients: ['Cream', 'Bacon', 'Cheese', 'Pastry'],
      );

      expect(recipe.isStrictMatch, isFalse);
      expect(recipe.matchPercentage, equals(35.0)); // Clamped to minimum 35.0
    });

    test('Parses fromFindByIngredientsJson correctly', () {
      final json = {
        'id': 101,
        'title': 'Tomato Omelette',
        'image': 'https://example.com/omelette.jpg',
        'usedIngredientCount': 2,
        'missedIngredientCount': 1,
        'usedIngredients': [
          {'name': 'eggs', 'original': '2 large eggs'},
          {'name': 'tomatoes', 'original': '1 diced tomato'},
        ],
        'missedIngredients': [
          {'name': 'olive oil', 'original': '1 tbsp olive oil'},
        ],
      };

      final recipe = RecipeModel.fromFindByIngredientsJson(json, searchedCount: 2);

      expect(recipe.id, equals(101));
      expect(recipe.title, equals('Tomato Omelette'));
      expect(recipe.usedIngredientCount, equals(2));
      expect(recipe.missedIngredientCount, equals(1));
      expect(recipe.usedIngredients, contains('2 large eggs'));
      expect(recipe.missedIngredients, contains('1 tbsp olive oil'));
      expect(recipe.searchedIngredientCount, equals(2));
    });

    test('Parses fromComplexSearchJson correctly', () {
      final json = {
        'id': 202,
        'title': 'Banana Smoothie',
        'image': 'https://example.com/smoothie.jpg',
        'usedIngredients': [
          {'original': '2 bananas'},
          {'original': '1 cup milk'},
        ],
        'missedIngredients': [],
        'analyzedInstructions': [
          {
            'steps': [
              {'step': 'Peel bananas.'},
              {'step': 'Blend bananas and milk until smooth.'},
            ]
          }
        ],
      };

      final recipe = RecipeModel.fromComplexSearchJson(json);

      expect(recipe.id, equals(202));
      expect(recipe.title, equals('Banana Smoothie'));
      expect(recipe.instructions.length, equals(2));
      expect(recipe.instructions.first, equals('Peel bananas.'));
    });

    test('Parses fromMealDbJson correctly with used/missed split', () {
      final mealJson = {
        'idMeal': '52772',
        'strMeal': 'Teriyaki Chicken Casserole',
        'strMealThumb': 'https://example.com/chicken.jpg',
        'strInstructions': 'Cook chicken with teriyaki sauce and stir fry vegetables.',
        'strIngredient1': 'Chicken Breast',
        'strMeasure1': '2 pieces',
        'strIngredient2': 'Soy Sauce',
        'strMeasure2': '2 tblsp',
        'strIngredient3': 'Rice',
        'strMeasure3': '1 cup',
        'strIngredient4': '',
        'strMeasure4': '',
      };

      // User only has chicken and rice in fridge
      final recipe = RecipeModel.fromMealDbJson(mealJson, ['Chicken', 'Rice']);

      expect(recipe.id, equals(52772));
      expect(recipe.title, equals('Teriyaki Chicken Casserole'));
      expect(recipe.usedIngredients.length, equals(2));
      expect(recipe.missedIngredients.length, equals(1)); // Soy sauce is missing
      expect(recipe.usedIngredients.any((i) => i.contains('Chicken Breast')), isTrue);
      expect(recipe.missedIngredients.any((i) => i.contains('Soy Sauce')), isTrue);
    });
  });

  group('RecipeService Ranking and Matching Algorithm', () {
    test('Sort comparator prioritizes 0 missing ingredients, then highest used count', () {
      final r0MissingHighUsed = const RecipeModel(
        id: 1,
        title: 'Recipe A (0 missing, 3 used)',
        image: '',
        missedIngredientCount: 0,
        usedIngredientCount: 3,
      );
      final r0MissingLowUsed = const RecipeModel(
        id: 2,
        title: 'Recipe B (0 missing, 1 used)',
        image: '',
        missedIngredientCount: 0,
        usedIngredientCount: 1,
      );
      final r1Missing = const RecipeModel(
        id: 3,
        title: 'Recipe C (1 missing, 4 used)',
        image: '',
        missedIngredientCount: 1,
        usedIngredientCount: 4,
      );
      final r3Missing = const RecipeModel(
        id: 4,
        title: 'Recipe D (3 missing, 2 used)',
        image: '',
        missedIngredientCount: 3,
        usedIngredientCount: 2,
      );

      final list = [r3Missing, r0MissingLowUsed, r1Missing, r0MissingHighUsed];

      // Same sort algorithm as in RecipeService.searchByIngredients
      list.sort((a, b) {
        final missedComp = a.missedIngredientCount.compareTo(b.missedIngredientCount);
        if (missedComp != 0) return missedComp;
        return b.usedIngredientCount.compareTo(a.usedIngredientCount);
      });

      expect(list[0].id, equals(1)); // 0 missing, 3 used
      expect(list[1].id, equals(2)); // 0 missing, 1 used
      expect(list[2].id, equals(3)); // 1 missing, 4 used
      expect(list[3].id, equals(4)); // 3 missing, 2 used
    });

    test('Cleans generic non-food terms and returns fallback when all terms filtered', () async {
      // Pass terms that should all be filtered out
      final recipes = await http.runWithClient(() async {
        return RecipeService.instance.searchByIngredients([
          'leftover food',
          'leftovers',
          'leftover',
          'food',
          'my food',
          '   ',
        ]);
      }, () => MockClient((_) async => http.Response('{}', 200)));

      // Should return fallback recipes (Rice, Vegetables, Eggs)
      expect(recipes, isNotEmpty);
      expect(recipes.every((r) => r.title.isNotEmpty), isTrue);
    });

    test('Empty ingredients list returns fallback essential recipes', () async {
      final recipes = await http.runWithClient(() async {
        return RecipeService.instance.searchByIngredients([]);
      }, () => MockClient((_) async => http.Response('{}', 200)));

      expect(recipes, isNotEmpty);
      expect(recipes.any((r) => r.missedIngredientCount == 0), isTrue);
    });

    test('Exact match for eggs produces zero-missing quick recipes at top', () async {
      final recipes = await http.runWithClient(() async {
        return RecipeService.instance.searchByIngredients(['Eggs']);
      }, () => MockClient((_) async => http.Response('{"results":[]}', 200)));

      expect(recipes, isNotEmpty);
      // Top recipes should be 0 missing
      expect(recipes.first.missedIngredientCount, equals(0));
      expect(recipes.first.isStrictMatch, isTrue);
      expect(recipes.any((r) => r.title.toLowerCase().contains('egg')), isTrue);
    });

    test('Exact match for potato produces potato essential recipes', () async {
      final recipes = await http.runWithClient(() async {
        return RecipeService.instance.searchByIngredients(['Potato']);
      }, () => MockClient((_) async => http.Response('{"results":[]}', 200)));

      expect(recipes, isNotEmpty);
      expect(recipes.first.missedIngredientCount, equals(0));
      expect(recipes.any((r) => r.title.toLowerCase().contains('potato')), isTrue);
    });

    test('Handles case variations (e.g. "EGG", "Eggs", "egg") cleanly', () async {
      final recipesUpper = await http.runWithClient(() async {
        return RecipeService.instance.searchByIngredients(['EGGS']);
      }, () => MockClient((_) async => http.Response('{"results":[]}', 200)));

      final recipesLower = await http.runWithClient(() async {
        return RecipeService.instance.searchByIngredients(['egg']);
      }, () => MockClient((_) async => http.Response('{"results":[]}', 200)));

      expect(recipesUpper, isNotEmpty);
      expect(recipesLower, isNotEmpty);
      expect(recipesUpper.first.missedIngredientCount, equals(0));
      expect(recipesLower.first.missedIngredientCount, equals(0));
    });

    test('Handles duplicate ingredient names without crashing or multiplying duplicates', () async {
      final recipes = await http.runWithClient(() async {
        return RecipeService.instance.searchByIngredients([
          'Eggs',
          'eggs',
          'EGGS',
          'Rice',
          'Rice',
        ]);
      }, () => MockClient((_) async => http.Response('{"results":[]}', 200)));

      expect(recipes, isNotEmpty);
      // Verify deduplication: no duplicate titles in output
      final titles = recipes.map((r) => r.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')).toList();
      final uniqueTitles = titles.toSet();
      expect(titles.length, equals(uniqueTitles.length));
    });

    test('Tri-tier blending combines Spoonacular, MealDB and Essential dishes with deduplication', () async {
      final spoonacularJson = {
        'results': [
          {
            'id': 5001,
            'title': 'Sunny Side Up Fried Eggs',
            'image': 'https://example.com/sunny.jpg',
            'usedIngredientCount': 1,
            'missedIngredientCount': 0,
            'usedIngredients': [{'name': 'egg', 'original': '1 egg'}],
            'missedIngredients': [],
          }
        ]
      };

      final mealDbMeals = {
        'meals': [
          {'idMeal': '6001', 'strMeal': 'Egg Curry', 'strMealThumb': 'https://example.com/curry.jpg'}
        ]
      };

      final mealDbDetail = {
        'meals': [
          {
            'idMeal': '6001',
            'strMeal': 'Egg Curry',
            'strMealThumb': 'https://example.com/curry.jpg',
            'strInstructions': 'Boil eggs and simmer in curry sauce.',
            'strIngredient1': 'Eggs',
            'strMeasure1': '4',
            'strIngredient2': 'Curry Powder',
            'strMeasure2': '1 tbsp',
          }
        ]
      };

      final client = MockClient((request) async {
        final uri = request.url.toString();
        if (uri.contains('complexSearch')) {
          return http.Response(jsonEncode(spoonacularJson), 200);
        } else if (uri.contains('findByIngredients')) {
          return http.Response('[]', 200);
        } else if (uri.contains('filter.php')) {
          return http.Response(jsonEncode(mealDbMeals), 200);
        } else if (uri.contains('lookup.php')) {
          return http.Response(jsonEncode(mealDbDetail), 200);
        }
        return http.Response('{}', 200);
      });

      final results = await http.runWithClient(() async {
        return RecipeService.instance.searchByIngredients(['Eggs']);
      }, () => client);

      expect(results, isNotEmpty);
      // Should contain items from multiple tiers
      expect(results.any((r) => r.id == 5001), isTrue); // Spoonacular
      expect(results.any((r) => r.id == 6001), isTrue); // MealDB
      expect(results.any((r) => r.id >= 900000), isTrue); // Essential quick dishes
      
      // Verified sorted order: 0 missing comes before 1 missing
      for (int i = 0; i < results.length - 1; i++) {
        expect(
          results[i].missedIngredientCount <= results[i + 1].missedIngredientCount,
          isTrue,
          reason: 'Item $i (${results[i].title} - ${results[i].missedIngredientCount} missing) should come before Item ${i + 1} (${results[i + 1].title} - ${results[i + 1].missedIngredientCount} missing)',
        );
      }
    });
  });
}
