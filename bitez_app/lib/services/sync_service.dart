import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/sync_operation.dart';
import '../models/sync_conflict.dart';
import 'api_service.dart';
import 'offline_storage_service.dart';

/// Background and on-demand synchronization manager.
/// Replays offline write mutations back to MongoDB and handles server conflicts.
class SyncService {
  SyncService._() {
    _initConnectionListener();
  }
  static final SyncService instance = SyncService._();

  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);
  final ValueNotifier<List<SyncConflict>> activeConflicts = ValueNotifier<List<SyncConflict>>([]);

  String? _authToken;

  /// Update active auth token used for sync replays.
  void setAuthToken(String? token) {
    _authToken = token;
  }

  void _initConnectionListener() {
    ApiService.connectionStatus.addListener(() {
      if (ApiService.connectionStatus.value == ServerConnectionStatus.connected) {
        syncNow();
      }
    });
  }

  /// Refreshes in-memory conflict list from local storage.
  void refreshConflicts() {
    activeConflicts.value = OfflineStorageService.instance.getActiveConflicts();
  }

  /// Dismisses a conflict notice.
  Future<void> dismissConflict(String conflictId) async {
    await OfflineStorageService.instance.dismissConflict(conflictId);
    refreshConflicts();
  }

  /// Queues a mutation operation when offline or as write-ahead log.
  Future<void> queueMutation({
    required SyncOpType type,
    required Map<String, dynamic> payload,
    String? customId,
  }) async {
    final op = SyncOperation(
      id: customId ?? 'op_${DateTime.now().millisecondsSinceEpoch}_${payload['id'] ?? ''}',
      type: type,
      payload: payload,
    );
    await OfflineStorageService.instance.enqueueOperation(op);
  }

  /// Replays queued offline changes in FIFO order against MongoDB.
  Future<int> syncNow({String? token}) async {
    final effectiveToken = token ?? _authToken;
    if (effectiveToken == null || effectiveToken.isEmpty) {
      debugPrint('SyncService: No auth token available, skipping sync replay.');
      return 0;
    }

    if (isSyncing.value) return 0;

    isSyncing.value = true;
    int processedCount = 0;

    try {
      final queue = OfflineStorageService.instance.getQueuedOperations();
      if (queue.isEmpty) {
        refreshConflicts();
        return 0;
      }

      debugPrint('🔄 SyncService: Starting replay of ${queue.length} offline operations...');

      for (final op in queue) {
        try {
          await _executeOperation(op, effectiveToken);
          await OfflineStorageService.instance.removeOperation(op.id);
          processedCount++;
        } on ApiException catch (apiErr) {
          // Conflict: Item was deleted server-side while client edited it offline (404)
          if (apiErr.statusCode == 404) {
            await _handle404Conflict(op);
            await OfflineStorageService.instance.removeOperation(op.id);
            processedCount++;
          } else {
            // Server rejected with other client error, remove to prevent endless failure
            debugPrint('⚠️ Server error on sync op ${op.id} (${apiErr.statusCode}): ${apiErr.message}');
            await _handleGenericConflict(op, apiErr.message);
            await OfflineStorageService.instance.removeOperation(op.id);
            processedCount++;
          }
        } catch (netErr) {
          // Network connection drop or timeout during sync replay — pause and preserve queue
          debugPrint('📡 Network interruption during sync replay: $netErr. Halting replay.');
          break;
        }
      }

      refreshConflicts();
      debugPrint('✅ SyncService: Replay completed. Processed $processedCount operations.');
    } finally {
      isSyncing.value = false;
    }

    return processedCount;
  }

  Future<void> _executeOperation(SyncOperation op, String token) async {
    switch (op.type) {
      case SyncOpType.addFridgeItem:
        await ApiService.instance.post('/api/fridge', op.payload, token: token);
        break;

      case SyncOpType.updateFridgeQty:
        final id = op.payload['id'] as String;
        final delta = (op.payload['delta'] as num).toInt();
        await ApiService.instance.patch('/api/fridge/$id/qty', {'delta': delta}, token: token);
        break;

      case SyncOpType.deleteFridgeItem:
        final id = op.payload['id'] as String;
        await ApiService.instance.delete('/api/fridge/$id', token: token);
        break;

      case SyncOpType.deductFridgeItems:
        await ApiService.instance.patch('/api/fridge/deduct', op.payload, token: token);
        break;

      case SyncOpType.addGroceryItem:
        await ApiService.instance.post('/api/grocery', op.payload, token: token);
        break;

      case SyncOpType.updateGroceryItem:
        final id = op.payload['id'] as String;
        final updateData = Map<String, dynamic>.from(op.payload)..remove('id');
        await ApiService.instance.put('/api/grocery/$id', updateData, token: token);
        break;

      case SyncOpType.deleteGroceryItem:
        final id = op.payload['id'] as String;
        await ApiService.instance.delete('/api/grocery/$id', token: token);
        break;

      case SyncOpType.bulkGroceryItems:
        await ApiService.instance.post('/api/grocery/bulk', op.payload, token: token);
        break;
    }
  }

  /// Handles 404 conflict when item no longer exists on MongoDB server.
  /// Server state takes precedence: local edit is cancelled and conflict notice is surfaced.
  Future<void> _handle404Conflict(SyncOperation op) async {
    final label = op.payload['label']?.toString() ?? 'Item';
    final entityId = op.payload['id']?.toString() ?? '';
    final isFridge = op.type == SyncOpType.updateFridgeQty ||
        op.type == SyncOpType.deleteFridgeItem ||
        op.type == SyncOpType.deductFridgeItems;

    // If delete was queued and server returned 404, item is already gone (no notice needed)
    if (op.type == SyncOpType.deleteFridgeItem || op.type == SyncOpType.deleteGroceryItem) {
      return;
    }

    final conflict = SyncConflict(
      id: 'conflict_${DateTime.now().millisecondsSinceEpoch}_${op.id}',
      entityType: isFridge ? 'fridge' : 'grocery',
      entityId: entityId,
      itemLabel: label,
      message: 'Item "$label" was deleted on the server while you were offline. Your offline edit was dropped.',
    );

    await OfflineStorageService.instance.recordConflict(conflict);
    debugPrint('⚠️ Sync Conflict recorded (Server Precedence): ${conflict.message}');
  }

  Future<void> _handleGenericConflict(SyncOperation op, String reason) async {
    final label = op.payload['label']?.toString() ?? 'Item';
    final entityId = op.payload['id']?.toString() ?? '';
    final isFridge = op.type.name.contains('Fridge');

    final conflict = SyncConflict(
      id: 'conflict_${DateTime.now().millisecondsSinceEpoch}_${op.id}',
      entityType: isFridge ? 'fridge' : 'grocery',
      entityId: entityId,
      itemLabel: label,
      message: 'Could not sync "$label": $reason. Server state preserved.',
    );

    await OfflineStorageService.instance.recordConflict(conflict);
  }
}
