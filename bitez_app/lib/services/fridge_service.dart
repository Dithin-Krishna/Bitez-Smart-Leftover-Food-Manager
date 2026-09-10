import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'offline_storage_service.dart';
import 'sync_service.dart';
import '../models/sync_operation.dart';

/// CRUD operations for the fridge via the Bitez backend with Offline-First caching & sync.
class FridgeService {
  FridgeService._();
  static final FridgeService instance = FridgeService._();

  // ── GET /api/fridge ────────────────────────────────────────────────────────
  /// Returns items grouped by section key.
  /// Uses server data when online and updates local cache.
  /// Falls back to Hive cache when offline.
  Future<Map<String, List<Map<String, dynamic>>>> getGrouped(String token) async {
    SyncService.instance.setAuthToken(token);
    try {
      final json = await ApiService.instance.get('/api/fridge', token: token);
      final raw  = (json['grouped'] as Map<String, dynamic>?) ?? {};
      final grouped = raw.map((section, list) {
        final items = ((list as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return MapEntry(section, items);
      });

      final flatList = (json['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Update offline cache
      await OfflineStorageService.instance.cacheFridgeData(
        grouped: grouped,
        items: flatList,
      );

      return grouped;
    } catch (e) {
      debugPrint('FridgeService.getGrouped: Server unreachable ($e). Checking offline cache...');
      final cached = OfflineStorageService.instance.getCachedGroupedFridge();
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  /// Returns flat list of all fridge items for the user.
  Future<List<Map<String, dynamic>>> getAllItems({required String token}) async {
    SyncService.instance.setAuthToken(token);
    try {
      final json = await ApiService.instance.get('/api/fridge', token: token);
      final rawList = json['items'] as List<dynamic>? ?? [];
      final flat = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final rawGrouped = (json['grouped'] as Map<String, dynamic>?) ?? {};
      final grouped = rawGrouped.map((section, list) {
        final items = ((list as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return MapEntry(section, items);
      });

      await OfflineStorageService.instance.cacheFridgeData(
        grouped: grouped,
        items: flat,
      );

      return flat;
    } catch (e) {
      final cached = OfflineStorageService.instance.getCachedFlatFridge();
      if (cached != null) return cached;
      rethrow;
    }
  }

  // ── POST /api/fridge ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> addItem({
    required String token,
    required String emoji,
    required String label,
    required int qty,
    required int color,
    required String section,
    DateTime? expiresAt,
  }) async {
    SyncService.instance.setAuthToken(token);
    final payload = {
      'emoji': emoji,
      'label': label,
      'qty': qty,
      'color': color,
      'section': section,
      if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
    };

    try {
      final json = await ApiService.instance.post('/api/fridge', payload, token: token);
      final item = Map<String, dynamic>.from(json['item'] as Map);
      _updateLocalCacheAddItem(item);
      return item;
    } catch (e) {
      // Offline fallback: create local item and queue sync operation
      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      final localItem = {
        '_id': localId,
        ...payload,
        'createdAt': DateTime.now().toIso8601String(),
      };
      _updateLocalCacheAddItem(localItem);

      await SyncService.instance.queueMutation(
        type: SyncOpType.addFridgeItem,
        payload: payload,
        customId: localId,
      );

      return localItem;
    }
  }

  // ── PATCH /api/fridge/:id/qty ──────────────────────────────────────────────
  Future<Map<String, dynamic>> updateQty({
    required String token,
    required String id,
    required int delta,
    String? itemLabel,
  }) async {
    SyncService.instance.setAuthToken(token);
    try {
      final json = await ApiService.instance.patch(
        '/api/fridge/$id/qty',
        {'delta': delta},
        token: token,
      );
      final item = Map<String, dynamic>.from(json['item'] as Map);
      _updateLocalCacheQty(id, (item['qty'] as num).toInt());
      return item;
    } catch (e) {
      // Offline fallback
      final updatedQty = _updateLocalCacheQtyDelta(id, delta);
      await SyncService.instance.queueMutation(
        type: SyncOpType.updateFridgeQty,
        payload: {
          'id': id,
          'delta': delta,
          'label': itemLabel ?? 'Item',
        },
      );
      return {'_id': id, 'qty': updatedQty};
    }
  }

  // ── POST /api/fridge/bulk ──────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> addBulkItems({
    required String token,
    required List<Map<String, dynamic>> items,
  }) async {
    SyncService.instance.setAuthToken(token);
    final json = await ApiService.instance.post(
      '/api/fridge/bulk',
      {'items': items},
      token: token,
    );
    final rawList = json['items'] as List<dynamic>? ?? [];
    return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ── PATCH /api/fridge/deduct ────────────────────────────────────────────────
  /// Batch-deduct ingredient quantities after cooking a recipe.
  /// Each entry: { 'itemId': String, 'label': String, 'quantityUsed': int }
  Future<Map<String, dynamic>> deductItems({
    required String token,
    required List<Map<String, dynamic>> deductions,
    String? recipeTitle,
    String? recipeId,
  }) async {
    SyncService.instance.setAuthToken(token);
    final payload = {
      'deductions': deductions,
      'recipeTitle': ?recipeTitle,
      'recipeId': ?recipeId,
    };

    // Immediately update local cache with deductions and removals
    for (final d in deductions) {
      final itemId = d['itemId']?.toString() ?? '';
      final label = d['label']?.toString() ?? '';
      final qtyUsed = (d['quantityUsed'] as num?)?.toInt() ?? 1;
      _deductFromLocalCache(id: itemId, label: label, qtyUsed: qtyUsed);
    }

    try {
      final result = await ApiService.instance.patch(
        '/api/fridge/deduct',
        payload,
        token: token,
      );
      return result;
    } catch (e) {
      // Offline / network fallback: queue mutation
      debugPrint('FridgeService.deductItems: Server unreachable ($e). Changes applied locally and queued.');
      await SyncService.instance.queueMutation(
        type: SyncOpType.deductFridgeItems,
        payload: payload,
      );
      return {'success': true, 'offline': true};
    }
  }

  // ── PATCH /api/fridge/:id/donate ───────────────────────────────────────────
  Future<Map<String, dynamic>> toggleDonation({
    required String token,
    String? id,
    String? itemId,
    required bool isDonation,
    String? notes,
    String? donationStatus,
    String? itemLabel,
  }) async {
    final effectiveId = (id ?? itemId ?? '').trim();
    SyncService.instance.setAuthToken(token);
    final payload = {
      'isDonation': isDonation,
      'donationStatus': donationStatus ?? (isDonation ? 'pledged' : 'none'),
      'notes': ?notes,
      if (itemLabel != null) 'label': itemLabel,
    };

    if (effectiveId.isNotEmpty) {
      _updateLocalCacheDonation(effectiveId, isDonation, notes);
    }

    try {
      final json = await ApiService.instance.patch(
        '/api/fridge/$effectiveId/donate',
        payload,
        token: token,
      );
      return Map<String, dynamic>.from(json['item'] as Map);
    } catch (e) {
      debugPrint('FridgeService.toggleDonation: Server unreachable ($e). Saved locally.');
      return {'_id': effectiveId, 'isDonation': isDonation, 'donationStatus': isDonation ? 'pledged' : 'none'};
    }
  }

  // ── GET /api/fridge/donations ──────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDonationItems(String token) async {
    if (token.isNotEmpty) {
      SyncService.instance.setAuthToken(token);
    }
    try {
      final json = await ApiService.instance.get('/api/fridge/donations', token: token);
      final items = json['items'] as List<dynamic>? ?? [];
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      final flat = OfflineStorageService.instance.getCachedFlatFridge() ?? [];
      return flat.where((i) => i['isDonation'] == true || i['donationStatus'] == 'pledged').toList();
    }
  }

  // ── DELETE /api/fridge/:id ─────────────────────────────────────────────────
  Future<void> deleteItem({
    required String token,
    required String id,
    String? itemLabel,
  }) async {
    SyncService.instance.setAuthToken(token);
    try {
      await ApiService.instance.delete('/api/fridge/$id', token: token);
      _removeLocalCacheItem(id);
    } catch (e) {
      // Offline: remove locally and queue sync
      _removeLocalCacheItem(id);
      await SyncService.instance.queueMutation(
        type: SyncOpType.deleteFridgeItem,
        payload: {'id': id, 'label': itemLabel ?? 'Item'},
      );
    }
  }

  // ── Cache Helpers ──────────────────────────────────────────────────────────

  void _updateLocalCacheAddItem(Map<String, dynamic> item) {
    final grouped = OfflineStorageService.instance.getCachedGroupedFridge() ?? {};
    final flat = OfflineStorageService.instance.getCachedFlatFridge() ?? [];

    final section = item['section']?.toString() ?? 'pantry';
    grouped.putIfAbsent(section, () => []);
    grouped[section]!.add(item);
    flat.add(item);

    OfflineStorageService.instance.cacheFridgeData(grouped: grouped, items: flat);
  }

  void _removeLocalCacheItem(String id) {
    final grouped = OfflineStorageService.instance.getCachedGroupedFridge() ?? {};
    final flat = OfflineStorageService.instance.getCachedFlatFridge() ?? [];

    for (final section in grouped.keys) {
      grouped[section]?.removeWhere((i) => i['_id'] == id || i['id'] == id);
    }
    flat.removeWhere((i) => i['_id'] == id || i['id'] == id);

    OfflineStorageService.instance.cacheFridgeData(grouped: grouped, items: flat);
  }

  void _updateLocalCacheQty(String id, int newQty) {
    final grouped = OfflineStorageService.instance.getCachedGroupedFridge() ?? {};
    final flat = OfflineStorageService.instance.getCachedFlatFridge() ?? [];

    for (final list in grouped.values) {
      for (final item in list) {
        if (item['_id'] == id || item['id'] == id) item['qty'] = newQty;
      }
    }
    for (final item in flat) {
      if (item['_id'] == id || item['id'] == id) item['qty'] = newQty;
    }

    OfflineStorageService.instance.cacheFridgeData(grouped: grouped, items: flat);
  }

  int _updateLocalCacheQtyDelta(String id, int delta) {
    final grouped = OfflineStorageService.instance.getCachedGroupedFridge() ?? {};
    final flat = OfflineStorageService.instance.getCachedFlatFridge() ?? [];
    int finalQty = 1;

    for (final list in grouped.values) {
      for (final item in list) {
        if (item['_id'] == id || item['id'] == id) {
          final current = (item['qty'] as num?)?.toInt() ?? 1;
          finalQty = (current + delta).clamp(0, 999);
          item['qty'] = finalQty;
        }
      }
    }
    for (final item in flat) {
      if (item['_id'] == id || item['id'] == id) {
        final current = (item['qty'] as num?)?.toInt() ?? 1;
        finalQty = (current + delta).clamp(0, 999);
        item['qty'] = finalQty;
      }
    }

    OfflineStorageService.instance.cacheFridgeData(grouped: grouped, items: flat);
    return finalQty;
  }

  void _deductFromLocalCache({required String id, required String label, required int qtyUsed}) {
    final grouped = OfflineStorageService.instance.getCachedGroupedFridge() ?? {};
    final flat = OfflineStorageService.instance.getCachedFlatFridge() ?? [];

    final labelLower = label.trim().toLowerCase();

    bool matchesItem(Map<String, dynamic> item) {
      final itemId = (item['_id'] ?? item['id'])?.toString() ?? '';
      if (id.isNotEmpty && itemId == id) return true;
      if (labelLower.isNotEmpty) {
        final itemLabel = (item['label']?.toString() ?? '').trim().toLowerCase();
        if (itemLabel == labelLower) return true;
      }
      return false;
    }

    // Process grouped
    for (final list in grouped.values) {
      for (int i = list.length - 1; i >= 0; i--) {
        final item = list[i];
        if (matchesItem(item)) {
          final current = (item['qty'] as num?)?.toInt() ?? 1;
          final finalQty = current - qtyUsed;
          if (finalQty <= 0) {
            list.removeAt(i);
          } else {
            item['qty'] = finalQty;
          }
        }
      }
    }

    // Process flat
    for (int i = flat.length - 1; i >= 0; i--) {
      final item = flat[i];
      if (matchesItem(item)) {
        final current = (item['qty'] as num?)?.toInt() ?? 1;
        final finalQty = current - qtyUsed;
        if (finalQty <= 0) {
          flat.removeAt(i);
        } else {
          item['qty'] = finalQty;
        }
      }
    }

    OfflineStorageService.instance.cacheFridgeData(grouped: grouped, items: flat);
  }

  void _updateLocalCacheDonation(String id, bool isDonation, String? notes) {
    final grouped = OfflineStorageService.instance.getCachedGroupedFridge() ?? {};
    final flat = OfflineStorageService.instance.getCachedFlatFridge() ?? [];

    for (final list in grouped.values) {
      for (final item in list) {
        if (item['_id'] == id || item['id'] == id) {
          item['isDonation'] = isDonation;
          item['donationStatus'] = isDonation ? 'pledged' : 'none';
          if (notes != null) item['donationNotes'] = notes;
        }
      }
    }
    for (final item in flat) {
      if (item['_id'] == id || item['id'] == id) {
        item['isDonation'] = isDonation;
        item['donationStatus'] = isDonation ? 'pledged' : 'none';
        if (notes != null) item['donationNotes'] = notes;
      }
    }

    OfflineStorageService.instance.cacheFridgeData(grouped: grouped, items: flat);
  }
}
