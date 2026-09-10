import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/sync_operation.dart';
import '../models/sync_conflict.dart';

/// Central offline storage service powered by Hive.
/// Caches fridge items, recipes, grocery list, sync queue, and conflict records.
class OfflineStorageService {
  OfflineStorageService._();
  static final OfflineStorageService instance = OfflineStorageService._();

  static const String boxFridge = 'bitez_fridge_box';
  static const String boxRecipes = 'bitez_recipes_box';
  static const String boxGrocery = 'bitez_grocery_box';
  static const String boxQueue = 'bitez_sync_queue_box';
  static const String boxConflicts = 'bitez_conflicts_box';

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize Hive for standard app launch
  Future<void> init() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      await _openBoxes();
      _initialized = true;
    } catch (e) {
      debugPrint('Hive initFlutter error (may already be initialized): $e');
      await _openBoxes();
      _initialized = true;
    }
  }

  /// Initialize Hive for testing with a specified directory path
  Future<void> initForTesting(String dirPath) async {
    Hive.init(dirPath);
    await _openBoxes();
    _initialized = true;
  }

  Future<void> _openBoxes() async {
    await Future.wait([
      if (!Hive.isBoxOpen(boxFridge)) Hive.openBox<dynamic>(boxFridge),
      if (!Hive.isBoxOpen(boxRecipes)) Hive.openBox<dynamic>(boxRecipes),
      if (!Hive.isBoxOpen(boxGrocery)) Hive.openBox<dynamic>(boxGrocery),
      if (!Hive.isBoxOpen(boxQueue)) Hive.openBox<String>(boxQueue),
      if (!Hive.isBoxOpen(boxConflicts)) Hive.openBox<String>(boxConflicts),
    ]);
  }

  Box<dynamic> get _fridgeBox => Hive.box<dynamic>(boxFridge);
  Box<dynamic> get _recipesBox => Hive.box<dynamic>(boxRecipes);
  Box<dynamic> get _groceryBox => Hive.box<dynamic>(boxGrocery);
  Box<String> get _queueBox => Hive.box<String>(boxQueue);
  Box<String> get _conflictsBox => Hive.box<String>(boxConflicts);

  // ── Fridge Cache ──────────────────────────────────────────────────────────

  Future<void> cacheFridgeData({
    required Map<String, List<Map<String, dynamic>>> grouped,
    required List<Map<String, dynamic>> items,
  }) async {
    if (!_initialized) return;
    await _fridgeBox.put('grouped', jsonEncode(grouped));
    await _fridgeBox.put('items', jsonEncode(items));
    await _fridgeBox.put('cachedAt', DateTime.now().toIso8601String());
  }

  Map<String, List<Map<String, dynamic>>>? getCachedGroupedFridge() {
    if (!_initialized) return null;
    final raw = _fridgeBox.get('grouped') as String?;
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((section, list) {
        final items = ((list as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        return MapEntry(section, items);
      });
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>>? getCachedFlatFridge() {
    if (!_initialized) return null;
    final raw = _fridgeBox.get('items') as String?;
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  // ── Recipes Cache ─────────────────────────────────────────────────────────

  Future<void> cacheRecipeDetail(String recipeId, Map<String, dynamic> detail) async {
    if (!_initialized) return;
    await _recipesBox.put('recipe_$recipeId', jsonEncode(detail));
  }

  Map<String, dynamic>? getCachedRecipeDetail(String recipeId) {
    if (!_initialized) return null;
    final raw = _recipesBox.get('recipe_$recipeId') as String?;
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheSearchResults(String queryKey, List<Map<String, dynamic>> recipes) async {
    if (!_initialized) return;
    await _recipesBox.put('search_$queryKey', jsonEncode(recipes));
  }

  List<Map<String, dynamic>>? getCachedSearchResults(String queryKey) {
    if (!_initialized) return null;
    final raw = _recipesBox.get('search_$queryKey') as String?;
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  // ── Grocery Cache ─────────────────────────────────────────────────────────

  Future<void> cacheGroceryList(List<Map<String, dynamic>> items) async {
    if (!_initialized) return;
    await _groceryBox.put('items', jsonEncode(items));
    await _groceryBox.put('cachedAt', DateTime.now().toIso8601String());
  }

  List<Map<String, dynamic>>? getCachedGroceryList() {
    if (!_initialized) return null;
    final raw = _groceryBox.get('items') as String?;
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  // ── Sync Queue ────────────────────────────────────────────────────────────

  Future<void> enqueueOperation(SyncOperation op) async {
    if (!_initialized) return;
    await _queueBox.put(op.id, op.serialize());
  }

  List<SyncOperation> getQueuedOperations() {
    if (!_initialized) return [];
    final ops = <SyncOperation>[];
    for (final raw in _queueBox.values) {
      try {
        ops.add(SyncOperation.deserialize(raw));
      } catch (e) {
        debugPrint('Error deserializing sync op: $e');
      }
    }
    ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return ops;
  }

  Future<void> removeOperation(String opId) async {
    if (!_initialized) return;
    await _queueBox.delete(opId);
  }

  Future<void> clearQueue() async {
    if (!_initialized) return;
    await _queueBox.clear();
  }

  // ── Sync Conflicts ────────────────────────────────────────────────────────

  Future<void> recordConflict(SyncConflict conflict) async {
    if (!_initialized) return;
    await _conflictsBox.put(conflict.id, conflict.serialize());
  }

  List<SyncConflict> getActiveConflicts() {
    if (!_initialized) return [];
    final list = <SyncConflict>[];
    for (final raw in _conflictsBox.values) {
      try {
        final c = SyncConflict.deserialize(raw);
        if (!c.isDismissed) list.add(c);
      } catch (_) {}
    }
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> dismissConflict(String conflictId) async {
    if (!_initialized) return;
    final raw = _conflictsBox.get(conflictId);
    if (raw != null) {
      final c = SyncConflict.deserialize(raw);
      c.isDismissed = true;
      await _conflictsBox.put(conflictId, c.serialize());
    }
  }

  Future<void> clearConflicts() async {
    if (!_initialized) return;
    await _conflictsBox.clear();
  }
}
