// Data models for the Food Waste & Savings Analytics Dashboard.

class WasteSavingsAnalytics {
  final int totalRecipesPrepared;
  final int totalLeftoversSaved;
  final double totalMoneySaved;
  final int monthlyStreakDays;
  final int currentMonthSaved;
  final double currentMonthMoney;
  final int monthlyGoal;
  final double monthlyGoalProgress;
  final String streakBadge;
  final Map<String, int> categoryCounts;
  final List<CookHistoryEvent> recentEvents;

  const WasteSavingsAnalytics({
    required this.totalRecipesPrepared,
    required this.totalLeftoversSaved,
    required this.totalMoneySaved,
    required this.monthlyStreakDays,
    required this.currentMonthSaved,
    required this.currentMonthMoney,
    required this.monthlyGoal,
    required this.monthlyGoalProgress,
    required this.streakBadge,
    required this.categoryCounts,
    required this.recentEvents,
  });

  factory WasteSavingsAnalytics.fromJson(Map<String, dynamic> json) {
    final rawAnalytics = json['analytics'] as Map<String, dynamic>? ?? json;

    final rawEvents = rawAnalytics['recentEvents'] as List<dynamic>? ?? [];
    final recentEvents = rawEvents
        .map((e) => CookHistoryEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    int toInt(dynamic val, [int fallback = 0]) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? fallback;
      return fallback;
    }

    double toDouble(dynamic val, [double fallback = 0.0]) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? fallback;
      return fallback;
    }

    final rawCategories = rawAnalytics['categoryCounts'] as Map<String, dynamic>? ?? {};
    final categoryCounts = rawCategories.map(
      (key, value) => MapEntry(key, toInt(value)),
    );

    return WasteSavingsAnalytics(
      totalRecipesPrepared: toInt(rawAnalytics['totalRecipesPrepared']),
      totalLeftoversSaved:  toInt(rawAnalytics['totalLeftoversSaved']),
      totalMoneySaved:      toDouble(rawAnalytics['totalMoneySaved']),
      monthlyStreakDays:    toInt(rawAnalytics['monthlyStreakDays']),
      currentMonthSaved:    toInt(rawAnalytics['currentMonthSaved']),
      currentMonthMoney:    toDouble(rawAnalytics['currentMonthMoney']),
      monthlyGoal:          toInt(rawAnalytics['monthlyGoal'], 20),
      monthlyGoalProgress:  toDouble(rawAnalytics['monthlyGoalProgress']),
      streakBadge:          rawAnalytics['streakBadge']?.toString() ?? 'Leftover Starter ⭐',
      categoryCounts:       categoryCounts,
      recentEvents:         recentEvents,
    );
  }

  factory WasteSavingsAnalytics.empty() {
    return const WasteSavingsAnalytics(
      totalRecipesPrepared: 0,
      totalLeftoversSaved: 0,
      totalMoneySaved: 0.0,
      monthlyStreakDays: 0,
      currentMonthSaved: 0,
      currentMonthMoney: 0.0,
      monthlyGoal: 20,
      monthlyGoalProgress: 0.0,
      streakBadge: 'Leftover Starter ⭐',
      categoryCounts: {},
      recentEvents: [],
    );
  }
}

class CookHistoryEvent {
  final String id;
  final String recipeTitle;
  final int totalItemsSaved;
  final double estimatedMoneySaved;
  final DateTime cookedAt;
  final List<DeductionItemSummary> deductions;

  const CookHistoryEvent({
    required this.id,
    required this.recipeTitle,
    required this.totalItemsSaved,
    required this.estimatedMoneySaved,
    required this.cookedAt,
    required this.deductions,
  });

  factory CookHistoryEvent.fromJson(Map<String, dynamic> json) {
    final rawDeductions = json['deductions'] as List<dynamic>? ?? [];
    final deductions = rawDeductions
        .map((d) => DeductionItemSummary.fromJson(Map<String, dynamic>.from(d as Map)))
        .toList();

    return CookHistoryEvent(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      recipeTitle: json['recipeTitle']?.toString() ?? 'Cooked Meal',
      totalItemsSaved: (json['totalItemsSaved'] as num?)?.toInt() ?? 0,
      estimatedMoneySaved: (json['estimatedMoneySaved'] as num?)?.toDouble() ?? 0.0,
      cookedAt: DateTime.tryParse(json['cookedAt']?.toString() ?? '') ?? DateTime.now(),
      deductions: deductions,
    );
  }
}

class DeductionItemSummary {
  final String label;
  final int quantityUsed;
  final String section;

  const DeductionItemSummary({
    required this.label,
    required this.quantityUsed,
    required this.section,
  });

  factory DeductionItemSummary.fromJson(Map<String, dynamic> json) {
    return DeductionItemSummary(
      label: json['label']?.toString() ?? 'Ingredient',
      quantityUsed: (json['quantityUsed'] as num?)?.toInt() ?? 1,
      section: json['section']?.toString() ?? 'pantry',
    );
  }
}
