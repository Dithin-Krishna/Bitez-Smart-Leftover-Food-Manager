import 'package:flutter_test/flutter_test.dart';
import 'package:bitez_app/models/meal_plan_model.dart';
import 'package:bitez_app/services/meal_planner_service.dart';

void main() {
  group('WeeklyMealPlan & MealPlannerService Unit Tests', () {
    test('Parses WeeklyMealPlan and groups items by day of the week', () {
      final json = {
        'success': true,
        'totalPinned': 3,
        'mealPlan': {
          'monday': [
            {
              'id': 'mp_01',
              'dayOfWeek': 'monday',
              'recipeTitle': 'Avocado Toast & Poached Egg',
              'ingredients': ['2 slices bread', '1 ripe avocado', '2 eggs'],
              'cookTime': 10,
              'mealType': 'breakfast',
              'servings': 1,
            },
            {
              'id': 'mp_02',
              'dayOfWeek': 'monday',
              'recipeTitle': 'Chicken Noodle Soup',
              'ingredients': ['Chicken breast', 'Egg noodles', 'Carrots', 'Celery'],
              'cookTime': 30,
              'mealType': 'dinner',
              'servings': 2,
            },
          ],
          'wednesday': [
            {
              'id': 'mp_03',
              'dayOfWeek': 'wednesday',
              'recipeTitle': 'Greek Salad',
              'ingredients': ['Cucumbers', 'Tomatoes', 'Feta cheese', 'Olives'],
              'cookTime': 12,
              'mealType': 'lunch',
              'servings': 2,
            },
          ],
        },
      };

      final plan = WeeklyMealPlan.fromJson(json);

      expect(plan.totalPinned, 3);
      expect(plan.days['monday']!.length, 2);
      expect(plan.days['tuesday']!.length, 0);
      expect(plan.days['wednesday']!.length, 1);
      expect(plan.days['thursday']!.length, 0);

      final breakfast = plan.days['monday']!.first;
      expect(breakfast.recipeTitle, 'Avocado Toast & Poached Egg');
      expect(breakfast.mealType, 'breakfast');
      expect(breakfast.cookTime, 10);
      expect(breakfast.ingredients.length, 3);
    });

    test('Consolidates ingredients across all days and deduplicates case-insensitively', () {
      final plan = WeeklyMealPlan(
        days: {
          'monday': [
            const MealPlanItem(
              id: '1',
              dayOfWeek: 'monday',
              recipeTitle: 'Dish A',
              ingredients: ['Eggs', 'Butter', 'Bread'],
            ),
          ],
          'wednesday': [
            const MealPlanItem(
              id: '2',
              dayOfWeek: 'wednesday',
              recipeTitle: 'Dish B',
              ingredients: ['bread', 'milk', 'EGGS'],
            ),
          ],
          'friday': [
            const MealPlanItem(
              id: '3',
              dayOfWeek: 'friday',
              recipeTitle: 'Dish C',
              ingredients: ['Tomato', 'Butter'],
            ),
          ],
        },
        totalPinned: 3,
      );

      final consolidated = plan.allConsolidatedIngredients;

      // Unique items: Eggs, Butter, Bread, milk, Tomato (case-insensitively deduplicated)
      expect(consolidated.length, 5);
      final lower = consolidated.map((e) => e.toLowerCase()).toList();
      expect(lower, containsAll(['eggs', 'butter', 'bread', 'milk', 'tomato']));
    });

    test('MealPlannerService.extractCleanIngredientName cleans quantities and units', () {
      expect(MealPlannerService.extractCleanIngredientName('2 large eggs'), 'eggs');
      expect(MealPlannerService.extractCleanIngredientName('1 1/2 cups of all-purpose flour'), 'all-purpose flour');
      expect(MealPlannerService.extractCleanIngredientName('500g chicken breasts (diced)'), 'chicken breasts');
      expect(MealPlannerService.extractCleanIngredientName('3 cloves garlic'), 'garlic');
      expect(MealPlannerService.extractCleanIngredientName('Olive oil'), 'Olive oil');
      expect(MealPlannerService.extractCleanIngredientName('1 pinch salt'), 'salt');
    });
  });
}
