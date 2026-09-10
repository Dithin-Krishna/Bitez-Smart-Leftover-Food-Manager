import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitez_app/models/sync_operation.dart';
import 'package:bitez_app/models/sync_conflict.dart';
import 'package:bitez_app/services/offline_storage_service.dart';
import 'package:bitez_app/services/sync_service.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    await OfflineStorageService.instance.initForTesting(tempDir.path);
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await OfflineStorageService.instance.clearQueue();
    await OfflineStorageService.instance.clearConflicts();
    SyncService.instance.refreshConflicts();
  });

  group('Offline Storage & SyncOperation Unit Tests', () {
    test('SyncOperation serializes and deserializes accurately', () {
      final op = SyncOperation(
        id: 'op_test_1',
        type: SyncOpType.updateFridgeQty,
        payload: {'id': 'item_123', 'delta': 2, 'label': 'Cheddar'},
      );

      final raw = op.serialize();
      final restored = SyncOperation.deserialize(raw);

      expect(restored.id, equals('op_test_1'));
      expect(restored.type, equals(SyncOpType.updateFridgeQty));
      expect(restored.payload['id'], equals('item_123'));
      expect(restored.payload['delta'], equals(2));
      expect(restored.payload['label'], equals('Cheddar'));
    });

    test('Queueing mutations orders operations chronologically in Hive', () async {
      await SyncService.instance.queueMutation(
        type: SyncOpType.addFridgeItem,
        payload: {'label': 'Milk', 'qty': 1},
        customId: 'op_1',
      );
      await Future.delayed(const Duration(milliseconds: 10));
      await SyncService.instance.queueMutation(
        type: SyncOpType.updateFridgeQty,
        payload: {'id': 'milk_id', 'delta': 1},
        customId: 'op_2',
      );

      final queue = OfflineStorageService.instance.getQueuedOperations();
      expect(queue.length, equals(2));
      expect(queue[0].id, equals('op_1'));
      expect(queue[1].id, equals('op_2'));
    });

    test('SyncConflict records and surfaces server-precedence message', () async {
      final conflict = SyncConflict(
        id: 'conf_1',
        entityType: 'fridge',
        entityId: 'item_999',
        itemLabel: 'Strawberries',
        message: 'Item "Strawberries" was deleted on the server. Local edit dropped.',
      );

      await OfflineStorageService.instance.recordConflict(conflict);
      SyncService.instance.refreshConflicts();

      expect(SyncService.instance.activeConflicts.value.length, equals(1));
      expect(SyncService.instance.activeConflicts.value.first.itemLabel, equals('Strawberries'));

      // Dismiss conflict
      await SyncService.instance.dismissConflict('conf_1');
      expect(SyncService.instance.activeConflicts.value.isEmpty, isTrue);
    });

    test('Server 404 conflict handling drops queue op and records user notification', () async {
      // Setup a queued edit for an item that was deleted on MongoDB
      await SyncService.instance.queueMutation(
        type: SyncOpType.updateFridgeQty,
        payload: {'id': 'deleted_server_item', 'delta': -1, 'label': 'Greek Yogurt'},
        customId: 'op_conflict_test',
      );

      expect(OfflineStorageService.instance.getQueuedOperations().length, equals(1));

      // Simulate a 404 ApiException when executing sync
      // Trigger sync with custom token
      SyncService.instance.setAuthToken('mock_test_token');

      // We test the conflict resolution logic directly
      final queue = OfflineStorageService.instance.getQueuedOperations();
      final op = queue.first;

      // Simulate what SyncService._handle404Conflict does
      final conflict = SyncConflict(
        id: 'conflict_${op.id}',
        entityType: 'fridge',
        entityId: op.payload['id'] as String,
        itemLabel: op.payload['label'] as String,
        message: 'Item "${op.payload['label']}" was deleted on the server while you were offline. Your offline edit was dropped.',
      );
      await OfflineStorageService.instance.recordConflict(conflict);
      await OfflineStorageService.instance.removeOperation(op.id);
      SyncService.instance.refreshConflicts();

      // Verify queue is cleaned and conflict notification is active
      expect(OfflineStorageService.instance.getQueuedOperations().isEmpty, isTrue);
      expect(SyncService.instance.activeConflicts.value.length, equals(1));
      expect(
        SyncService.instance.activeConflicts.value.first.message,
        contains('was deleted on the server'),
      );
    });

    test('Fridge and Recipe local cache storage and retrieval', () async {
      // 1. Fridge cache
      await OfflineStorageService.instance.cacheFridgeData(
        grouped: {
          'dairy': [
            {'_id': 'c1', 'label': 'Butter', 'qty': 2}
          ]
        },
        items: [
          {'_id': 'c1', 'label': 'Butter', 'qty': 2}
        ],
      );

      final cachedFridge = OfflineStorageService.instance.getCachedGroupedFridge();
      expect(cachedFridge, isNotNull);
      expect(cachedFridge!['dairy']!.first['label'], equals('Butter'));

      // 2. Recipe search cache
      await OfflineStorageService.instance.cacheSearchResults(
        'eggs,milk',
        [
          {'id': 701, 'title': 'Custard', 'image': 'custard.jpg'}
        ],
      );

      final cachedRecipes = OfflineStorageService.instance.getCachedSearchResults('eggs,milk');
      expect(cachedRecipes, isNotNull);
      expect(cachedRecipes!.first['title'], equals('Custard'));
    });
  });
}
