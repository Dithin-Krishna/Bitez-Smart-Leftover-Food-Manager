import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'offline_storage_service.dart';
import 'sync_service.dart';
import '../models/sync_operation.dart';

/// Data class representing a Grocery Item
class GroceryItemData {
  final String id;
  final String label;
  final String emoji;
  final int qty;
  final String category;
  final String section;
  final bool isBought;
  final bool isAiSuggested;
  final String? reason;

  GroceryItemData({
    required this.id,
    required this.label,
    this.emoji = '🛒',
    this.qty = 1,
    this.category = 'Produce',
    this.section = 'veggies',
    this.isBought = false,
    this.isAiSuggested = false,
    this.reason,
  });

  factory GroceryItemData.fromJson(Map<String, dynamic> json) {
    return GroceryItemData(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? 'Item',
      emoji: json['emoji']?.toString() ?? '🛒',
      qty: (json['qty'] as num?)?.toInt() ?? 1,
      category: json['category']?.toString() ?? 'Produce',
      section: json['section']?.toString() ?? 'veggies',
      isBought: json['isBought'] == true,
      isAiSuggested: json['isAiSuggested'] == true,
      reason: json['reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'label': label,
        'emoji': emoji,
        'qty': qty,
        'category': category,
        'section': section,
        'isBought': isBought,
        'isAiSuggested': isAiSuggested,
        if (reason != null) 'reason': reason,
      };
}

/// Service managing API communication for the Smart Grocery List with Offline-First support.
class GroceryService {
  GroceryService._();
  static final GroceryService instance = GroceryService._();

  /// Fetch all grocery items for user
  Future<List<GroceryItemData>> getGroceryList({required String token}) async {
    SyncService.instance.setAuthToken(token);
    try {
      final response = await ApiService.instance.get('/api/grocery', token: token);
      final items = response['items'] as List<dynamic>? ?? [];
      final list = items.map((i) => GroceryItemData.fromJson(i as Map<String, dynamic>)).toList();

      // Cache locally
      await OfflineStorageService.instance.cacheGroceryList(
        list.map((i) => i.toJson()).toList(),
      );

      return list;
    } catch (e) {
      debugPrint('GroceryService: Server offline ($e). Loading cached items...');
      final cached = OfflineStorageService.instance.getCachedGroceryList();
      if (cached != null) {
        return cached.map((i) => GroceryItemData.fromJson(i)).toList();
      }
      return [];
    }
  }

  /// Add custom grocery item
  Future<GroceryItemData> addItem({
    required String token,
    required String label,
    String? emoji,
    int qty = 1,
    String? category,
    String? section,
  }) async {
    SyncService.instance.setAuthToken(token);
    final payload = {
      'label': label,
      'emoji': ?emoji,
      'qty': qty,
      'category': ?category,
      'section': ?section,
    };

    try {
      final response = await ApiService.instance.post('/api/grocery', payload, token: token);
      final item = GroceryItemData.fromJson(response['item'] as Map<String, dynamic>);
      _appendLocalCache(item);
      return item;
    } catch (e) {
      // Offline
      final localId = 'local_grocery_${DateTime.now().millisecondsSinceEpoch}';
      final item = GroceryItemData(
        id: localId,
        label: label,
        emoji: emoji ?? '🛒',
        qty: qty,
        category: category ?? 'Produce',
        section: section ?? 'veggies',
      );
      _appendLocalCache(item);

      await SyncService.instance.queueMutation(
        type: SyncOpType.addGroceryItem,
        payload: payload,
        customId: localId,
      );

      return item;
    }
  }

  /// Bulk-add items to grocery list with server-side deduplication.
  Future<Map<String, dynamic>> addBulkItems({
    required String token,
    required List<Map<String, dynamic>> items,
  }) async {
    SyncService.instance.setAuthToken(token);
    try {
      return await ApiService.instance.post(
        '/api/grocery/bulk',
        {'items': items},
        token: token,
      );
    } catch (e) {
      // Offline: queue bulk add
      await SyncService.instance.queueMutation(
        type: SyncOpType.bulkGroceryItems,
        payload: {'items': items},
      );
      return {'success': true, 'offline': true};
    }
  }

  /// Generate AI Smart Restock suggestions based on current Virtual Fridge
  Future<List<GroceryItemData>> generateAiSuggestions({required String token}) async {
    final response = await ApiService.instance.post(
      '/api/grocery/generate',
      {},
      token: token,
    );
    final items = response['items'] as List<dynamic>? ?? [];
    return items.map((i) => GroceryItemData.fromJson(i as Map<String, dynamic>)).toList();
  }

  /// Toggle item bought status or update quantity
  Future<GroceryItemData> updateItem({
    required String token,
    required String id,
    bool? isBought,
    int? qty,
  }) async {
    SyncService.instance.setAuthToken(token);
    final payload = {
      'id': id,
      'isBought': ?isBought,
      'qty': ?qty,
    };

    try {
      final response = await ApiService.instance.put(
        '/api/grocery/$id',
        {
          'isBought': ?isBought,
          'qty': ?qty,
        },
        token: token,
      );
      final item = GroceryItemData.fromJson(response['item'] as Map<String, dynamic>);
      _updateLocalCache(item);
      return item;
    } catch (e) {
      // Offline update
      _updateLocalCachePartial(id: id, isBought: isBought, qty: qty);
      await SyncService.instance.queueMutation(
        type: SyncOpType.updateGroceryItem,
        payload: payload,
      );
      return GroceryItemData(
        id: id,
        label: 'Updated Item',
        isBought: isBought ?? false,
        qty: qty ?? 1,
      );
    }
  }

  /// Delete a grocery item
  Future<void> deleteItem({required String token, required String id}) async {
    SyncService.instance.setAuthToken(token);
    try {
      await ApiService.instance.delete('/api/grocery/$id', token: token);
      _removeLocalCache(id);
    } catch (e) {
      _removeLocalCache(id);
      await SyncService.instance.queueMutation(
        type: SyncOpType.deleteGroceryItem,
        payload: {'id': id},
      );
    }
  }

  /// Transfer all bought grocery items directly into Virtual Fridge
  Future<int> moveBoughtToFridge({required String token}) async {
    final response = await ApiService.instance.post('/api/grocery/move-to-fridge', {}, token: token);
    return (response['movedCount'] as num?)?.toInt() ?? 0;
  }

  // ── Local Cache Helpers ───────────────────────────────────────────────────

  void _appendLocalCache(GroceryItemData item) {
    final list = OfflineStorageService.instance.getCachedGroceryList() ?? [];
    list.add(item.toJson());
    OfflineStorageService.instance.cacheGroceryList(list);
  }

  void _updateLocalCache(GroceryItemData item) {
    final list = OfflineStorageService.instance.getCachedGroceryList() ?? [];
    final idx = list.indexWhere((i) => i['_id'] == item.id || i['id'] == item.id);
    if (idx != -1) {
      list[idx] = item.toJson();
    }
    OfflineStorageService.instance.cacheGroceryList(list);
  }

  void _updateLocalCachePartial({required String id, bool? isBought, int? qty}) {
    final list = OfflineStorageService.instance.getCachedGroceryList() ?? [];
    final idx = list.indexWhere((i) => i['_id'] == id || i['id'] == id);
    if (idx != -1) {
      if (isBought != null) list[idx]['isBought'] = isBought;
      if (qty != null) list[idx]['qty'] = qty;
    }
    OfflineStorageService.instance.cacheGroceryList(list);
  }

  void _removeLocalCache(String id) {
    final list = OfflineStorageService.instance.getCachedGroceryList() ?? [];
    list.removeWhere((i) => i['_id'] == id || i['id'] == id);
    OfflineStorageService.instance.cacheGroceryList(list);
  }
}
