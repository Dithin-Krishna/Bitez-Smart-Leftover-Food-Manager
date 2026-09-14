import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bitez_app/services/suggestion_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSuggestion Model Tests', () {
    test('Correctly parses suggestion from JSON', () {
      final json = {
        '_id': 'sug_123',
        'title': 'Add smart fridge widgets',
        'description': 'It would be helpful to have home screen widgets for expiring items.',
        'category': 'feature',
        'rating': 5,
        'status': 'planned',
        'userName': 'Chef Alex',
        'createdAt': '2026-09-14T10:00:00.000Z',
      };

      final suggestion = AppSuggestion.fromJson(json);

      expect(suggestion.id, equals('sug_123'));
      expect(suggestion.title, equals('Add smart fridge widgets'));
      expect(suggestion.category, equals('feature'));
      expect(suggestion.categoryDisplayName, equals('Feature Request'));
      expect(suggestion.status, equals('planned'));
      expect(suggestion.statusDisplayName, contains('Planned'));
      expect(suggestion.rating, equals(5));
      expect(suggestion.userName, equals('Chef Alex'));
    });

    test('Handles default fallbacks gracefully', () {
      final json = <String, dynamic>{};
      final suggestion = AppSuggestion.fromJson(json);

      expect(suggestion.title, isEmpty);
      expect(suggestion.category, equals('feature'));
      expect(suggestion.status, equals('under_review'));
      expect(suggestion.statusDisplayName, contains('Under Review'));
      expect(suggestion.rating, equals(5));
    });

    test('Serializes to JSON accurately', () {
      final now = DateTime.now();
      final item = AppSuggestion(
        id: 'test_1',
        title: 'Dark mode theme tweak',
        description: 'Make contrast slightly higher.',
        category: 'ui_ux',
        rating: 4,
        status: 'implemented',
        userName: 'Priya',
        createdAt: now,
      );

      final json = item.toJson();
      expect(json['id'], equals('test_1'));
      expect(json['title'], equals('Dark mode theme tweak'));
      expect(json['category'], equals('ui_ux'));
      expect(item.categoryDisplayName, equals('UI & Design'));
      expect(item.statusDisplayName, contains('Implemented'));
    });
  });

  group('SuggestionService Local Offline Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Stores and retrieves local suggestions when offline', () async {
      final service = SuggestionService.instance;

      // Submit suggestion (will fallback to local cache since no server mock)
      final submitted = await service.submitSuggestion(
        title: 'Voice cooking timer',
        description: 'Allow hands-free cooking timers in step-by-step mode.',
        category: 'feature',
        rating: 5,
        isAnonymous: false,
        userName: 'Tester',
      );

      expect(submitted.title, equals('Voice cooking timer'));
      expect(submitted.category, equals('feature'));

      // Retrieve cached items
      final list = await service.getLocalSuggestions();
      expect(list.isNotEmpty, isTrue);
      expect(list.first.title, equals('Voice cooking timer'));
    });
  });
}
