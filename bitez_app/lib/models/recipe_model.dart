/// Dart model representing a recipe fetched from Spoonacular API.
class RecipeModel {
  final int id;
  final String title;
  final String image;
  final int usedIngredientCount;
  final int missedIngredientCount;
  final List<String> usedIngredients;
  final List<String> missedIngredients;
  final int? readyInMinutes;
  final int? servings;
  final String? summary;
  final List<String> instructions;
  final int? calories;
  final int? proteinGrams;
  final int? carbsGrams;
  final int? fatGrams;
  final int searchedIngredientCount;

  const RecipeModel({
    required this.id,
    required this.title,
    required this.image,
    this.usedIngredientCount = 0,
    this.missedIngredientCount = 0,
    this.usedIngredients = const [],
    this.missedIngredients = const [],
    this.readyInMinutes,
    this.servings,
    this.summary,
    this.instructions = const [],
    this.calories,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
    this.searchedIngredientCount = 1,
  });

  int get totalIngredients => usedIngredientCount + missedIngredientCount;

  /// Calculate match percentage based on missing extra ingredients.
  /// 0 missing items = 100% Match (Omelette, Bullseye, Scrambled, Boiled)
  /// 1-2 missing items = 70-85% Match
  /// 3+ missing items = 40-55% Match (Scotch Eggs, Casseroles, Pies)
  double get matchPercentage {
    if (usedIngredientCount == 0) return 30.0;
    if (missedIngredientCount == 0) return 100.0;

    final total = usedIngredientCount + missedIngredientCount;
    final ratio = usedIngredientCount / total;
    final score = (ratio * 100.0) - (missedIngredientCount * 8.0);
    return score.clamp(35.0, 95.0);
  }

  /// Returns true if this recipe requires 2 or fewer extra ingredients (High Match!)
  bool get isStrictMatch => missedIngredientCount <= 2;

  factory RecipeModel.fromFindByIngredientsJson(Map<String, dynamic> json, {int searchedCount = 1}) {
    final usedList = (json['usedIngredients'] as List?)
            ?.map((i) => i['original']?.toString() ?? i['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    final missedList = (json['missedIngredients'] as List?)
            ?.map((i) => i['original']?.toString() ?? i['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    final usedCount = json['usedIngredientCount'] as int? ?? usedList.length;
    final missedCount = json['missedIngredientCount'] as int? ?? missedList.length;

    return RecipeModel(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ?? 'Untitled Recipe',
      image: json['image']?.toString() ?? '',
      usedIngredientCount: usedCount > 0 ? usedCount : (usedList.isNotEmpty ? usedList.length : 1),
      missedIngredientCount: missedCount,
      usedIngredients: usedList,
      missedIngredients: missedList,
      searchedIngredientCount: searchedCount,
    );
  }

  factory RecipeModel.fromComplexSearchJson(Map<String, dynamic> json, {int searchedCount = 1}) {
    final usedList = (json['usedIngredients'] as List?)
            ?.map((i) => i['original']?.toString() ?? i['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    final missedList = (json['missedIngredients'] as List?)
            ?.map((i) => i['original']?.toString() ?? i['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    // Extract instructions if available
    final List<String> stepsList = [];
    if (json['analyzedInstructions'] is List &&
        (json['analyzedInstructions'] as List).isNotEmpty) {
      final steps = json['analyzedInstructions'][0]['steps'] as List?;
      if (steps != null) {
        for (final step in steps) {
          final stepText = step['step']?.toString();
          if (stepText != null && stepText.isNotEmpty) {
            stepsList.add(stepText);
          }
        }
      }
    }

    final usedCount = json['usedIngredientCount'] as int? ?? (usedList.isNotEmpty ? usedList.length : 1);
    final missedCount = json['missedIngredientCount'] as int? ?? missedList.length;

    return RecipeModel(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ?? 'Untitled Recipe',
      image: json['image']?.toString() ?? '',
      usedIngredientCount: usedCount,
      missedIngredientCount: missedCount,
      usedIngredients: usedList,
      missedIngredients: missedList,
      readyInMinutes: json['readyInMinutes'] as int?,
      servings: json['servings'] as int?,
      summary: json['summary']?.toString().replaceAll(RegExp(r'<[^>]*>'), ''),
      instructions: stepsList,
      searchedIngredientCount: searchedCount,
    );
  }

  factory RecipeModel.fromDetailJson(Map<String, dynamic> json) {
    // Extract step-by-step instructions
    final List<String> stepsList = [];
    if (json['analyzedInstructions'] is List &&
        (json['analyzedInstructions'] as List).isNotEmpty) {
      final steps = json['analyzedInstructions'][0]['steps'] as List?;
      if (steps != null) {
        for (final step in steps) {
          final stepText = step['step']?.toString();
          if (stepText != null && stepText.isNotEmpty) {
            stepsList.add(stepText);
          }
        }
      }
    }

    // Fallback to html/plain text instructions if analyzedInstructions is empty
    if (stepsList.isEmpty && json['instructions'] != null) {
      final rawStr = json['instructions'].toString().replaceAll(RegExp(r'<[^>]*>'), '');
      if (rawStr.trim().isNotEmpty) {
        stepsList.addAll(rawStr.split('. ').where((s) => s.trim().isNotEmpty));
      }
    }

    final usedList = (json['extendedIngredients'] as List?)
            ?.map((i) => i['original']?.toString() ?? i['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];

    return RecipeModel(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ?? 'Untitled Recipe',
      image: json['image']?.toString() ?? '',
      usedIngredients: usedList,
      readyInMinutes: json['readyInMinutes'] as int?,
      servings: json['servings'] as int?,
      summary: json['summary']?.toString().replaceAll(RegExp(r'<[^>]*>'), ''),
      instructions: stepsList,
      calories: json['healthScore'] != null ? (json['healthScore'] * 4 + 250).toInt() : 380,
      proteinGrams: 24,
      carbsGrams: 42,
      fatGrams: 14,
    );
  }

  factory RecipeModel.fromMealDbJson(Map<String, dynamic> json, List<String> searchedIngredients) {
    final int mealId = int.tryParse(json['idMeal']?.toString() ?? '0') ?? 0;
    final String title = json['strMeal']?.toString() ?? 'Untitled Recipe';
    final String image = json['strMealThumb']?.toString() ?? '';

    final List<String> ingredientsList = [];
    for (int i = 1; i <= 20; i++) {
      final ing = json['strIngredient$i']?.toString().trim();
      final meas = json['strMeasure$i']?.toString().trim();
      if (ing != null && ing.isNotEmpty) {
        if (meas != null && meas.isNotEmpty) {
          ingredientsList.add('$meas $ing');
        } else {
          ingredientsList.add(ing);
        }
      }
    }

    final String rawInstructions = json['strInstructions']?.toString() ?? '';
    final List<String> instructions = rawInstructions
        .split(RegExp(r'\r?\n+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final searchedLower = searchedIngredients.map((s) => s.toLowerCase().trim()).toList();
    final List<String> used = [];
    final List<String> missed = [];

    if (ingredientsList.isNotEmpty) {
      for (final item in ingredientsList) {
        final itemLower = item.toLowerCase();
        if (searchedLower.any((s) => itemLower.contains(s) || s.contains(itemLower))) {
          used.add(item);
        } else {
          missed.add(item);
        }
      }
    } else {
      used.addAll(searchedIngredients);
    }

    return RecipeModel(
      id: mealId > 0 ? mealId : (title.hashCode.abs()),
      title: title,
      image: image,
      usedIngredientCount: used.isNotEmpty ? used.length : 1,
      missedIngredientCount: missed.length,
      usedIngredients: used.isNotEmpty ? used : searchedIngredients,
      missedIngredients: missed,
      readyInMinutes: 15,
      servings: 2,
      summary: '$title - Flavorful recipe from TheMealDB database.',
      instructions: instructions,
      searchedIngredientCount: searchedIngredients.length,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'image': image,
        'usedIngredientCount': usedIngredientCount,
        'missedIngredientCount': missedIngredientCount,
        'usedIngredients': usedIngredients,
        'missedIngredients': missedIngredients,
        'readyInMinutes': readyInMinutes,
        'servings': servings,
        'summary': summary,
        'instructions': instructions,
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbsGrams': carbsGrams,
        'fatGrams': fatGrams,
        'searchedIngredientCount': searchedIngredientCount,
      };

  factory RecipeModel.fromJson(Map<String, dynamic> json) {
    return RecipeModel(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      image: json['image']?.toString() ?? '',
      usedIngredientCount: json['usedIngredientCount'] as int? ?? 0,
      missedIngredientCount: json['missedIngredientCount'] as int? ?? 0,
      usedIngredients: List<String>.from(json['usedIngredients'] ?? []),
      missedIngredients: List<String>.from(json['missedIngredients'] ?? []),
      readyInMinutes: json['readyInMinutes'] as int?,
      servings: json['servings'] as int?,
      summary: json['summary']?.toString(),
      instructions: List<String>.from(json['instructions'] ?? []),
      calories: json['calories'] as int?,
      proteinGrams: json['proteinGrams'] as int?,
      carbsGrams: json['carbsGrams'] as int?,
      fatGrams: json['fatGrams'] as int?,
      searchedIngredientCount: json['searchedIngredientCount'] as int? ?? 1,
    );
  }
}
