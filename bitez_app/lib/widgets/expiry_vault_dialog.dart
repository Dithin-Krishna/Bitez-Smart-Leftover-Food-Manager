import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/fridge_item_model.dart';
import '../services/local_photo_storage.dart';

class ExpiryVaultDialog extends StatelessWidget {
  final FridgeItemModel item;
  final VoidCallback? onReplacePhoto;
  final VoidCallback? onDeletePhoto;

  const ExpiryVaultDialog({
    super.key,
    required this.item,
    this.onReplacePhoto,
    this.onDeletePhoto,
  });

  static Future<void> show(
    BuildContext context, {
    required FridgeItemModel item,
    VoidCallback? onReplacePhoto,
    VoidCallback? onDeletePhoto,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ExpiryVaultDialog(
        item: item,
        onReplacePhoto: onReplacePhoto,
        onDeletePhoto: onDeletePhoto,
      ),
    );
  }

  Widget _buildImage() {
    final raw = item.expiryImage;
    if (raw == null || raw.isEmpty) {
      return Container(
        height: 220,
        color: Colors.grey.withValues(alpha: 0.1),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text('No Expiry Photo in Vault', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    try {
      // ── Local file path (new approach) ──────────────────────────
      if (LocalPhotoStorage.isLocalPath(raw)) {
        final file = File(raw);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, e, __) => _errorPlaceholder('Photo file not found on device'),
          ),
        );
      }

      // ── Legacy Base64 blob (backward compat for older records) ──
      if (LocalPhotoStorage.isBase64(raw)) {
        final clean = raw.replaceFirst(RegExp(r'^data:image\/\w+;base64,'), '');
        final bytes = base64Decode(clean);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            height: 260,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      }

      // ── HTTP URL fallback ───────────────────────────────────────
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          raw,
          height: 260,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } catch (e) {
      return _errorPlaceholder('Failed to render photo: $e');
    }
  }

  Widget _errorPlaceholder(String msg) => Container(
    height: 200,
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Center(
      child: Text(msg, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    Color badgeColor;
    String statusText;
    switch (item.expiryStatus) {
      case ExpiryStatus.expired:
        badgeColor = Colors.red;
        statusText = 'EXPIRED (${item.daysRemaining?.abs()}d ago)';
        break;
      case ExpiryStatus.expiringSoon:
        badgeColor = Colors.orange.shade800;
        statusText = 'EXPIRING SOON (${item.daysRemaining}d left)';
        break;
      case ExpiryStatus.fresh:
        badgeColor = Colors.green.shade700;
        statusText = 'FRESH (${item.daysRemaining}d left)';
        break;
      case ExpiryStatus.untracked:
        badgeColor = Colors.grey;
        statusText = 'No Expiry Set';
        break;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Text(item.emoji, style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            'Expiry Vault Record',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Image Preview
            _buildImage(),

            const SizedBox(height: 16),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event, size: 16, color: badgeColor),
                  const SizedBox(width: 8),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: badgeColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Details Table
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF131E2F)
                    : const Color(0xFFF3F6FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _infoRow('Expiry Date:', item.formattedExpiryDate, theme),
                  const Divider(height: 12),
                  _infoRow('Mfg Date:', item.formattedMfgDate, theme),
                  const Divider(height: 12),
                  _infoRow('Storage Section:', item.section.toUpperCase(), theme),
                  if (item.expiryNotes != null && item.expiryNotes!.isNotEmpty) ...[
                    const Divider(height: 12),
                    _infoRow('Notes:', item.expiryNotes!, theme),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (item.hasVaultPhoto && onDeletePhoto != null)
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onDeletePhoto!();
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Remove photo',
                  ),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (onReplacePhoto != null) onReplacePhoto!();
                    },
                    icon: const Icon(Icons.center_focus_strong, size: 18),
                    label: Text(item.hasVaultPhoto ? 'Update Photo' : 'Upload Vault Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String val, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color)),
        Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
