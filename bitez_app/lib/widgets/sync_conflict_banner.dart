import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../models/sync_conflict.dart';

/// A dismissible banner that alerts users when offline changes collided with
/// changes on the server (server state takes precedence).
class SyncConflictBanner extends StatelessWidget {
  const SyncConflictBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SyncConflict>>(
      valueListenable: SyncService.instance.activeConflicts,
      builder: (context, conflicts, child) {
        if (conflicts.isEmpty) return const SizedBox.shrink();

        final topConflict = conflicts.first;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF2C220E), // Warm dark amber background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5A93C).withValues(alpha: 0.6), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.sync_problem_rounded,
                  color: Color(0xFFFFB84D),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Sync Conflict Resolved',
                            style: TextStyle(
                              color: Color(0xFFFFB84D),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (conflicts.length > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5A93C).withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '+${conflicts.length - 1} more',
                                style: const TextStyle(
                                  color: Color(0xFFFFD599),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        topConflict.message,
                        style: const TextStyle(
                          color: Color(0xFFE0E0E0),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                      if (conflicts.length > 1) ...[
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => _showAllConflictsModal(context, conflicts),
                          child: const Text(
                            'View all conflict details →',
                            style: TextStyle(
                              color: Color(0xFFFFB84D),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('dismiss_conflict_btn'),
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  onPressed: () => SyncService.instance.dismissConflict(topConflict.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAllConflictsModal(BuildContext context, List<SyncConflict> conflicts) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141E28),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Sync Conflicts (Server Precedence)',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () async {
                      for (final c in conflicts) {
                        await SyncService.instance.dismissConflict(c.id);
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('Dismiss All', style: TextStyle(color: Color(0xFFFFB84D))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: conflicts.length,
                  separatorBuilder: (_, _) => const Divider(color: Colors.white12),
                  itemBuilder: (context, index) {
                    final c = conflicts[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.info_outline, color: Color(0xFFFFB84D)),
                      title: Text(
                        c.itemLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        c.message,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.check, color: Colors.white60, size: 20),
                        onPressed: () async {
                          await SyncService.instance.dismissConflict(c.id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
