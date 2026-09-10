import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitez_app/models/sync_conflict.dart';
import 'package:bitez_app/services/sync_service.dart';
import 'package:bitez_app/widgets/sync_conflict_banner.dart';

void main() {
  setUp(() {
    SyncService.instance.activeConflicts.value = [];
  });

  Widget buildTestApp() {
    return const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            SyncConflictBanner(),
            Text('Screen Content'),
          ],
        ),
      ),
    );
  }

  group('SyncConflictBanner Widget Tests', () {
    testWidgets('Renders nothing when there are no active conflicts', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Sync Conflict Resolved'), findsNothing);
      expect(find.byIcon(Icons.sync_problem_rounded), findsNothing);
      expect(find.text('Screen Content'), findsOneWidget);
    });

    testWidgets('Renders conflict banner with message and dismisses on close tap', (tester) async {
      final conflict = SyncConflict(
        id: 'conf_widget_1',
        entityType: 'fridge',
        entityId: 'item_101',
        itemLabel: 'Fresh Milk',
        message: 'Item "Fresh Milk" was deleted on the server. Your offline edit was dropped.',
      );

      SyncService.instance.activeConflicts.value = [conflict];

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Sync Conflict Resolved'), findsOneWidget);
      expect(find.textContaining('Fresh Milk'), findsOneWidget);
      expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);

      // Tap dismiss icon
      final dismissBtn = find.byKey(const Key('dismiss_conflict_btn'));
      expect(dismissBtn, findsOneWidget);

      // Dismiss updates activeConflicts
      SyncService.instance.activeConflicts.value = [];
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Banner should disappear
      expect(find.text('Sync Conflict Resolved'), findsNothing);
    });

    testWidgets('Displays "+1 more" for multiple conflicts', (tester) async {
      final conflict1 = SyncConflict(
        id: 'c1',
        entityType: 'fridge',
        entityId: 'i1',
        itemLabel: 'Cheddar',
        message: 'Item "Cheddar" was deleted on the server.',
      );
      final conflict2 = SyncConflict(
        id: 'c2',
        entityType: 'grocery',
        entityId: 'i2',
        itemLabel: 'Avocados',
        message: 'Item "Avocados" was updated on the server.',
      );

      SyncService.instance.activeConflicts.value = [conflict1, conflict2];

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('+1 more'), findsOneWidget);
      expect(find.text('View all conflict details →'), findsOneWidget);
    });
  });
}
