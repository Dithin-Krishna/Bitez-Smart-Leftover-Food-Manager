import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/offline_storage_service.dart';
import '../services/sync_service.dart';

/// Non-intrusive banner indicating offline status, queued changes,
/// and live synchronization progress with MongoDB.
/// Mirrors Section 14 (Offline-First Architecture & Sync) in the MCA Report.
class SyncStatusBanner extends StatefulWidget {
  const SyncStatusBanner({super.key});

  @override
  State<SyncStatusBanner> createState() => _SyncStatusBannerState();
}

class _SyncStatusBannerState extends State<SyncStatusBanner> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SyncService.instance.isSyncing,
      builder: (context, syncing, _) {
        return ValueListenableBuilder<ServerConnectionStatus>(
          valueListenable: ApiService.connectionStatus,
          builder: (context, status, _) {
            final queuedCount = OfflineStorageService.instance.getQueuedOperations().length;
            final isOffline = status == ServerConnectionStatus.disconnected;

            if (!isOffline && queuedCount == 0 && !syncing) {
              return const SizedBox.shrink();
            }

            Color bg;
            Color fg;
            IconData icon;
            String message;

            if (syncing) {
              bg = const Color(0xFF1E3A8A);
              fg = const Color(0xFF93C5FD);
              icon = Icons.sync_rounded;
              message = 'Syncing $queuedCount offline changes with server...';
            } else if (isOffline) {
              bg = const Color(0xFF332014);
              fg = const Color(0xFFFDBA74);
              icon = Icons.cloud_off_rounded;
              message = queuedCount > 0
                  ? 'Offline Mode • $queuedCount changes saved locally'
                  : 'Offline Mode • Viewing cached data';
            } else {
              bg = const Color(0xFF1E293B);
              fg = Colors.white70;
              icon = Icons.cloud_queue_rounded;
              message = '$queuedCount changes pending upload';
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: fg.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  syncing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                        )
                      : Icon(icon, color: fg, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!syncing && queuedCount > 0 && !isOffline) ...[
                    InkWell(
                      onTap: () {
                        final token = context.read<AuthProvider>().token;
                        SyncService.instance.syncNow(token: token);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: fg.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Sync Now',
                          style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
