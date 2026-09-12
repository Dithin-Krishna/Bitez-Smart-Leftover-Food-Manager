// Dart model representing Food Waste Records and Aggregated Statistics
// Mirrors Sections 12.3, 18, and 19 in the MCA Project Report.

class WasteRecordModel {
  final String id;
  final String? foodItemId;
  final String foodName;
  final String category;
  final double quantity;
  final String unit;
  final String reason;
  final double estimatedCost;
  final DateTime date;

  const WasteRecordModel({
    required this.id,
    this.foodItemId,
    required this.foodName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.reason,
    required this.estimatedCost,
    required this.date,
  });

  factory WasteRecordModel.fromJson(Map<String, dynamic> json) {
    return WasteRecordModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      foodItemId: json['foodItemId']?.toString(),
      foodName: json['foodName']?.toString() ?? 'Food item',
      category: json['category']?.toString() ?? 'Other',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit']?.toString() ?? 'item',
      reason: json['reason']?.toString() ?? 'Expired',
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 2.0,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foodItemId': foodItemId,
      'foodName': foodName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'reason': reason,
      'estimatedCost': estimatedCost,
      'date': date.toIso8601String(),
    };
  }
}

class WasteStatsModel {
  final int totalWastedCount;
  final int totalWastedItems;
  final double totalCostLost;
  final Map<String, int> reasonBreakdown;
  final Map<String, int> categoryBreakdown;
  final int avoidablePercentage;
  final List<WasteRecordModel> recentRecords;

  const WasteStatsModel({
    required this.totalWastedCount,
    required this.totalWastedItems,
    required this.totalCostLost,
    required this.reasonBreakdown,
    required this.categoryBreakdown,
    required this.avoidablePercentage,
    required this.recentRecords,
  });

  factory WasteStatsModel.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'] as Map<String, dynamic>? ?? json;

    final rawRecent = rawStats['recentRecords'] as List<dynamic>? ?? [];
    final recent = rawRecent
        .map((e) => WasteRecordModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    int toInt(dynamic v) {
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    double toDouble(dynamic v) {
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0.0;
      return 0.0;
    }

    final rawReasons = rawStats['reasonBreakdown'] as Map<String, dynamic>? ?? {};
    final reasonBreakdown = rawReasons.map((k, v) => MapEntry(k, toInt(v)));

    final rawCategories = rawStats['categoryBreakdown'] as Map<String, dynamic>? ?? {};
    final categoryBreakdown = rawCategories.map((k, v) => MapEntry(k, toInt(v)));

    return WasteStatsModel(
      totalWastedCount: toInt(rawStats['totalWastedCount']),
      totalWastedItems: toInt(rawStats['totalWastedItems']),
      totalCostLost: toDouble(rawStats['totalCostLost']),
      reasonBreakdown: reasonBreakdown,
      categoryBreakdown: categoryBreakdown,
      avoidablePercentage: toInt(rawStats['avoidablePercentage']),
      recentRecords: recent,
    );
  }

  factory WasteStatsModel.empty() {
    return const WasteStatsModel(
      totalWastedCount: 0,
      totalWastedItems: 0,
      totalCostLost: 0.0,
      reasonBreakdown: {},
      categoryBreakdown: {},
      avoidablePercentage: 0,
      recentRecords: [],
    );
  }
}
