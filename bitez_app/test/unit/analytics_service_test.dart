import 'package:flutter_test/flutter_test.dart';
import 'package:bitez_app/models/analytics_model.dart';

void main() {
  group('WasteSavingsAnalytics Model Unit Tests', () {
    test('Correctly parses full analytics payload from backend', () {
      final json = {
        'success': true,
        'analytics': {
          'totalRecipesPrepared': 6,
          'totalLeftoversSaved': 15,
          'totalMoneySaved': 22.50,
          'monthlyStreakDays': 4,
          'currentMonthSaved': 12,
          'currentMonthMoney': 18.00,
          'monthlyGoal': 20,
          'monthlyGoalProgress': 0.60,
          'streakBadge': 'Eco Chef 🔥',
          'categoryCounts': {
            'veggies': 7,
            'dairy': 4,
            'fruits': 3,
            'frozen': 1,
          },
          'recentEvents': [
            {
              'id': 'log_101',
              'recipeTitle': 'Veggie Frittata',
              'totalItemsSaved': 3,
              'estimatedMoneySaved': 4.50,
              'cookedAt': '2026-09-10T12:00:00.000Z',
              'deductions': [
                {'label': 'Eggs', 'quantityUsed': 2, 'section': 'dairy'},
                {'label': 'Carrots', 'quantityUsed': 1, 'section': 'veggies'},
              ],
            },
          ],
        },
      };

      final data = WasteSavingsAnalytics.fromJson(json);

      expect(data.totalRecipesPrepared, 6);
      expect(data.totalLeftoversSaved, 15);
      expect(data.totalMoneySaved, 22.50);
      expect(data.monthlyStreakDays, 4);
      expect(data.currentMonthSaved, 12);
      expect(data.currentMonthMoney, 18.00);
      expect(data.monthlyGoal, 20);
      expect(data.monthlyGoalProgress, 0.60);
      expect(data.streakBadge, 'Eco Chef 🔥');
      expect(data.categoryCounts['veggies'], 7);
      expect(data.categoryCounts['dairy'], 4);
      expect(data.recentEvents.length, 1);

      final event = data.recentEvents.first;
      expect(event.id, 'log_101');
      expect(event.recipeTitle, 'Veggie Frittata');
      expect(event.totalItemsSaved, 3);
      expect(event.estimatedMoneySaved, 4.50);
      expect(event.deductions.length, 2);
      expect(event.deductions.first.label, 'Eggs');
      expect(event.deductions.first.quantityUsed, 2);
    });

    test('WasteSavingsAnalytics.empty creates clean defaults', () {
      final empty = WasteSavingsAnalytics.empty();

      expect(empty.totalRecipesPrepared, 0);
      expect(empty.totalLeftoversSaved, 0);
      expect(empty.totalMoneySaved, 0.0);
      expect(empty.monthlyStreakDays, 0);
      expect(empty.monthlyGoal, 20);
      expect(empty.monthlyGoalProgress, 0.0);
      expect(empty.streakBadge, 'Leftover Starter ⭐');
      expect(empty.categoryCounts, isEmpty);
      expect(empty.recentEvents, isEmpty);
    });

    test('Handles malformed and missing values gracefully', () {
      final json = <String, dynamic>{
        'analytics': <String, dynamic>{
          'totalRecipesPrepared': null,
          'totalMoneySaved': 'not-a-number',
          'recentEvents': null,
          'categoryCounts': null,
        },
      };

      final data = WasteSavingsAnalytics.fromJson(json);

      expect(data.totalRecipesPrepared, 0);
      expect(data.totalMoneySaved, 0.0);
      expect(data.recentEvents, isEmpty);
      expect(data.categoryCounts, isEmpty);
    });
  });
}
