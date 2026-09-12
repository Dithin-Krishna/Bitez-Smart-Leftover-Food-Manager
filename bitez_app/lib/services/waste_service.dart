import 'package:flutter/foundation.dart';
import '../models/sync_operation.dart';
import '../models/waste_record_model.dart';
import 'api_service.dart';
import 'offline_storage_service.dart';
import 'sync_service.dart';

/// Service managing Food Waste logging and waste analytics retrieval.
/// Features offline-first persistence using Hive and automatic sync queueing.
class WasteService {
  WasteService._();
  static final WasteService instance = WasteService._();

  /// Reactive notifier triggered whenever a waste item is logged.
  final ValueNotifier<int> wasteUpdatedNotifier = ValueNotifier<int>(0);

  /// Log a discarded food item. If offline, stores locally and queues sync mutation.
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
    final payload = {
      'foodItemId': ?foodItemId,
      'foodName': foodName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'reason': reason,
      'estimatedCost': estimatedCost,
    };

    final localRecord = {
      '_id': 'waste_local_${DateTime.now().millisecondsSinceEpoch}',
      'foodItemId': foodItemId,
      'foodName': foodName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'reason': reason,
      'estimatedCost': estimatedCost,
      'date': DateTime.now().toIso8601String(),
    };

    try {
      final res = await ApiService.instance.post('/api/waste', payload, token: token);
      if (res['success'] == true) {
        final serverRecord = res['record'] != null
            ? Map<String, dynamic>.from(res['record'] as Map)
            : localRecord;
        await OfflineStorageService.instance.addLocalWasteRecord(serverRecord);
        wasteUpdatedNotifier.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('WasteService.recordWaste: Server unreachable ($e). Storing offline.');
      // Persist offline in Hive
      await OfflineStorageService.instance.addLocalWasteRecord(localRecord);
      // Queue sync mutation for when internet returns
      await SyncService.instance.queueMutation(
        type: SyncOpType.recordWaste,
        payload: payload,
      );
      wasteUpdatedNotifier.value++;
      return true;
    }
  }

  /// Fetch user's waste logs with Hive offline fallback
  Future<List<WasteRecordModel>> getWasteRecords(String token) async {
    try {
      final res = await ApiService.instance.get('/api/waste', token: token);
      final raw = res['records'] as List<dynamic>? ?? [];
      final recordsMap = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      await OfflineStorageService.instance.cacheWasteRecords(recordsMap);

      return recordsMap.map(WasteRecordModel.fromJson).toList();
    } catch (e) {
      debugPrint('WasteService.getWasteRecords offline fallback: $e');
      final cached = OfflineStorageService.instance.getCachedWasteRecords() ?? [];
      return cached.map(WasteRecordModel.fromJson).toList();
    }
  }

  /// Fetch aggregated waste statistics with offline computation fallback
  Future<WasteStatsModel> getWasteStats(String token) async {
    try {
      final res = await ApiService.instance.get('/api/waste/stats', token: token);
      return WasteStatsModel.fromJson(res);
    } catch (e) {
      debugPrint('WasteService.getWasteStats offline fallback: $e');
      return _computeOfflineWasteStats();
    }
  }

  WasteStatsModel _computeOfflineWasteStats() {
    final cached = OfflineStorageService.instance.getCachedWasteRecords() ?? [];
    if (cached.isEmpty) return WasteStatsModel.empty();

    final records = cached.map(WasteRecordModel.fromJson).toList();

    int totalWastedItems = 0;
    double totalCostLost = 0.0;
    final reasonBreakdown = <String, int>{};
    final categoryBreakdown = <String, int>{};
    int avoidableCount = 0;

    const avoidableReasons = {'Expired', 'Forgotten food', 'Excess quantity'};

    for (final r in records) {
      final q = r.quantity.toInt();
      totalWastedItems += q;
      totalCostLost += q * r.estimatedCost;

      reasonBreakdown[r.reason] = (reasonBreakdown[r.reason] ?? 0) + q;
      categoryBreakdown[r.category] = (categoryBreakdown[r.category] ?? 0) + q;

      if (avoidableReasons.contains(r.reason)) {
        avoidableCount += q;
      }
    }

    final avoidablePercentage = totalWastedItems > 0
        ? ((avoidableCount / totalWastedItems) * 100).round()
        : 0;

    return WasteStatsModel(
      totalWastedCount: records.length,
      totalWastedItems: totalWastedItems,
      totalCostLost: totalCostLost,
      reasonBreakdown: reasonBreakdown,
      categoryBreakdown: categoryBreakdown,
      avoidablePercentage: avoidablePercentage,
      recentRecords: records.take(10).toList(),
    );
  }
}
