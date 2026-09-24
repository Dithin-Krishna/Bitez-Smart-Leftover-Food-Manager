import 'package:flutter_test/flutter_test.dart';
import 'package:bitez_app/models/user_model.dart';
import 'package:bitez_app/models/recipe_model.dart';
import 'package:bitez_app/services/recipe_service.dart';

void main() {
  group('User Dietary Preferences Tests', () {
    test('UserModel correctly serializes and deserializes dietary preferences', () {
      final json = {
        'id': 'user_123',
        'name': 'Dithin',
        'email': 'dithin@example.com',
        'dietaryRestrictions': ['Vegetarian', 'Gluten-Free'],
        'allergies': ['Peanuts', 'Dairy / Milk'],
        'maxCookingTime': 25,
      };

      final user = UserModel.fromJson(json);

      expect(user.dietaryRestrictions, containsAll(['Vegetarian', 'Gluten-Free']));
      expect(user.allergies, containsAll(['Peanuts', 'Dairy / Milk']));
      expect(user.maxCookingTime, equals(25));

      final serialized = user.toJson();
      expect(serialized['dietaryRestrictions'], equals(['Vegetarian', 'Gluten-Free']));
      expect(serialized['allergies'], equals(['Peanuts', 'Dairy / Milk']));
      expect(serialized['maxCookingTime'], equals(25));
    });

    test('UserModel uses default values when dietary preferences are omitted', () {
      final json = {
        'id': 'user_456',
        'name': 'Alice',
        'email': 'alice@example.com',
      };

      final user = UserModel.fromJson(json);

      expect(user.dietaryRestrictions, isEmpty);
      expect(user.allergies, isEmpty);
      expect(user.maxCookingTime, equals(45));
    });

    test('UserModel.copyWith updates dietary preferences correctly', () {
      const initial = UserModel(
        id: 'u1',
        name: 'Bob',
        email: 'bob@example.com',
        dietaryRestrictions: ['Vegan'],
        allergies: ['Soy'],
        maxCookingTime: 30,
      );

      final updated = initial.copyWith(
        dietaryRestrictions: ['Keto', 'Halal'],
        allergies: ['Tree Nuts'],
        maxCookingTime: 20,
      );

      expect(updated.dietaryRestrictions, equals(['Keto', 'Halal']));
      expect(updated.allergies, equals(['Tree Nuts']));
      expect(updated.maxCookingTime, equals(20));
      expect(updated.name, equals('Bob'));
    });
  });
}
