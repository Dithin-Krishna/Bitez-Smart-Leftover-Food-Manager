// Data models for the Weekly Meal Planner Calendar.

class MealPlanItem {
  final String id;
  final String dayOfWeek;
  final String? recipeId;
  final String recipeTitle;
  final String? imageUrl;
  final List<String> ingredients;
  final int cookTime;
  final String mealType;
  final int servings;

  const MealPlanItem({
    required this.id,
    required this.dayOfWeek,
    this.recipeId,
    required this.recipeTitle,
    this.imageUrl,
    required this.ingredients,
    this.cookTime = 20,
    this.mealType = 'dinner',
    this.servings = 2,
  });

  factory MealPlanItem.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'] as List<dynamic>? ?? [];
    return MealPlanItem(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      dayOfWeek: (json['dayOfWeek']?.toString() ?? 'monday').toLowerCase(),
      recipeId: json['recipeId']?.toString(),
      recipeTitle: json['recipeTitle']?.toString() ?? 'Delicious Meal',
      imageUrl: json['imageUrl']?.toString(),
      ingredients: rawIngredients.map((e) => e.toString()).toList(),
      cookTime: (json['cookTime'] as num?)?.toInt() ?? 20,
      mealType: json['mealType']?.toString() ?? 'dinner',
      servings: (json['servings'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dayOfWeek': dayOfWeek,
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      'imageUrl': imageUrl,
      'ingredients': ingredients,
      'cookTime': cookTime,
      'mealType': mealType,
      'servings': servings,
    };
  }
}

class WeeklyMealPlan {
  final Map<String, List<MealPlanItem>> days;
  final int totalPinned;

  const WeeklyMealPlan({
    required this.days,
    required this.totalPinned,
  });

  factory WeeklyMealPlan.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['mealPlan'] as Map<String, dynamic>? ?? {};

    final Map<String, List<MealPlanItem>> mappedDays = {
      'monday': [],
      'tuesday': [],
      'wednesday': [],
      'thursday': [],
      'friday': [],
      'saturday': [],
      'sunday': [],
    };

    int count = 0;
    for (final dayKey in mappedDays.keys) {
      final list = rawPlan[dayKey] as List<dynamic>? ?? [];
      mappedDays[dayKey] = list
          .map((e) => MealPlanItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      count += mappedDays[dayKey]!.length;
    }

    return WeeklyMealPlan(
      days: mappedDays,
      totalPinned: (json['totalPinned'] as num?)?.toInt() ?? count,
    );
  }

  factory WeeklyMealPlan.empty() {
    return const WeeklyMealPlan(
      days: {
        'monday': [],
        'tuesday': [],
        'wednesday': [],
        'thursday': [],
        'friday': [],
        'saturday': [],
        'sunday': [],
      },
      totalPinned: 0,
    );
  }

  List<String> get allConsolidatedIngredients {
    final seen = <String>{};
    final result = <String>[];

    for (final list in days.values) {
      for (final item in list) {
        for (final raw in item.ingredients) {
          final clean = raw.trim();
          if (clean.isNotEmpty && !seen.contains(clean.toLowerCase())) {
            seen.add(clean.toLowerCase());
            result.add(clean);
          }
        }
      }
    }

    return result;
  }
}
