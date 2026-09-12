import 'package:flutter/foundation.dart';
import '../models/waste_record_model.dart';
import 'api_service.dart';

/// Service managing Food Waste logging and waste analytics retrieval.
class WasteService {
  WasteService._();
  static final WasteService instance = WasteService._();

  /// Reactive notifier triggered whenever a waste item is logged.
  final ValueNotifier<int> wasteUpdatedNotifier = ValueNotifier<int>(0);

  /// Log a discarded food item
  Future<bool> recordWaste({
    required String token,
    String? foodItemId,
    required String foodName,
    required String category,
    required double quantity,
    String unit = 'item',
    required String reason,
    double estimatedCost = 2.0,
  }) async {
    try {
      final res = await ApiService.instance.post(
        '/api/waste',
        {
          'foodItemId': ?foodItemId,
          'foodName': foodName,
          'category': category,
          'quantity': quantity,
          'unit': unit,
          'reason': reason,
          'estimatedCost': estimatedCost,
        },
        token: token,
      );

      if (res['success'] == true) {
        wasteUpdatedNotifier.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('WasteService.recordWaste error: $e');
      rethrow;
    }
  }

  /// Fetch user's waste logs
  Future<List<WasteRecordModel>> getWasteRecords(String token) async {
    try {
      final res = await ApiService.instance.get('/api/waste', token: token);
      final raw = res['records'] as List<dynamic>? ?? [];
      return raw
          .map((e) => WasteRecordModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('WasteService.getWasteRecords error: $e');
      return [];
    }
  }

  /// Fetch aggregated waste statistics
  Future<WasteStatsModel> getWasteStats(String token) async {
    try {
      final res = await ApiService.instance.get('/api/waste/stats', token: token);
      return WasteStatsModel.fromJson(res);
    } catch (e) {
      debugPrint('WasteService.getWasteStats error: $e');
      return WasteStatsModel.empty();
    }
  }
}
