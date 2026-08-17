import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fridge_item_model.dart';
import '../providers/auth_provider.dart';
import '../providers/expiry_provider.dart';
import '../widgets/expiry_scan_dialog.dart';
import '../widgets/expiry_vault_dialog.dart';
import 'recipe_results_screen.dart';

class ExpiryTrackerScreen extends StatefulWidget {
  const ExpiryTrackerScreen({super.key});

  @override
  State<ExpiryTrackerScreen> createState() => _ExpiryTrackerScreenState();
}

class _ExpiryTrackerScreenState extends State<ExpiryTrackerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().token;
      context.read<ExpiryProvider>().fetchExpiryData(token);
    });
  }

  void _generateRecipeWithExpiringItems(List<FridgeItemModel> items) {
    final expiringNames = items
        .where((i) => i.expiryStatus == ExpiryStatus.expiringSoon || i.expiryStatus == ExpiryStatus.expired)
        .map((i) => i.label)
        .toList();

    if (expiringNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expiring items found!')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeResultsScreen(ingredients: expiringNames),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<ExpiryProvider>();
    final token = context.read<AuthProvider>().token;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: Color(0xFF2A4E7C)),
            SizedBox(width: 8),
            Text('Expiry Tracker & Vault', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => provider.fetchExpiryData(token),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: () => ExpiryScanDialog.show(context),
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan Expiry Label',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchExpiryData(token),
        child: provider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // ── Alert Banner if items expiring soon ─────────────────────
                  if (provider.hasUrgentAlerts)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade700, Colors.red.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${provider.expiringSoonCount} Expiring Soon • ${provider.expiredCount} Expired',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Prevent food waste! Generate recipes using your items near expiration before they go bad.',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: () => _generateRecipeWithExpiringItems(provider.items),
                              icon: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('Cook Expiring Items Now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.deepOrange.shade900,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Summary Cards Grid ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatMetricCard(
                              title: 'Expired',
                              count: provider.expiredCount,
                              color: Colors.red,
                              icon: Icons.highlight_off,
                              onTap: () => provider.setFilter('expired'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatMetricCard(
                              title: 'Expiring Soon',
                              count: provider.expiringSoonCount,
                              color: Colors.orange.shade800,
                              icon: Icons.hourglass_top_rounded,
                              onTap: () => provider.setFilter('expiringSoon'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatMetricCard(
                              title: 'Fresh',
                              count: provider.freshCount,
                              color: Colors.green.shade700,
                              icon: Icons.check_circle_outline,
                              onTap: () => provider.setFilter('fresh'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Filter Segment Tabs ────────────────────────────────────
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _FilterChipButton(
                            label: 'All Items (${provider.items.length})',
                            isSelected: provider.activeFilter == 'all',
                            onTap: () => provider.setFilter('all'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChipButton(
                            label: '🚨 Expiring Soon (${provider.expiringSoonCount})',
                            isSelected: provider.activeFilter == 'expiringSoon',
                            activeColor: Colors.orange.shade800,
                            onTap: () => provider.setFilter('expiringSoon'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChipButton(
                            label: '❌ Expired (${provider.expiredCount})',
                            isSelected: provider.activeFilter == 'expired',
                            activeColor: Colors.red,
                            onTap: () => provider.setFilter('expired'),
                          ),
                          const SizedBox(width: 8),
                          _FilterChipButton(
                            label: '✅ Fresh (${provider.freshCount})',
                            isSelected: provider.activeFilter == 'fresh',
                            activeColor: Colors.green.shade700,
                            onTap: () => provider.setFilter('fresh'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Items List ─────────────────────────────────────────────
                  provider.filteredItems.isEmpty
                      ? SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inbox_outlined, size: 48, color: theme.dividerColor),
                                const SizedBox(height: 12),
                                Text(
                                  'No items found in filter "${provider.activeFilter}"',
                                  style: TextStyle(color: theme.textTheme.bodySmall?.color),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = provider.filteredItems[index];
                              return _ExpiryItemCard(item: item);
                            },
                            childCount: provider.filteredItems.length,
                          ),
                        ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ExpiryScanDialog.show(context),
        backgroundColor: const Color(0xFF2A4E7C),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Scan Expiry Label', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _StatMetricCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _StatMetricCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? activeColor;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.isSelected,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = activeColor ?? const Color(0xFF2A4E7C);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? color : theme.dividerColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ExpiryItemCard extends StatelessWidget {
  final FridgeItemModel item;

  const _ExpiryItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final token = context.read<AuthProvider>().token;
    final provider = context.read<ExpiryProvider>();

    Color badgeBg;
    Color badgeFg;
    String badgeLabel;

    switch (item.expiryStatus) {
      case ExpiryStatus.expired:
        badgeBg = Colors.red.shade100;
        badgeFg = Colors.red.shade900;
        badgeLabel = 'EXPIRED (${item.daysRemaining?.abs()}d ago)';
        break;
      case ExpiryStatus.expiringSoon:
        badgeBg = Colors.orange.shade100;
        badgeFg = Colors.orange.shade900;
        badgeLabel = 'EXPIRING IN ${item.daysRemaining} DAYS';
        break;
      case ExpiryStatus.fresh:
        badgeBg = Colors.green.shade100;
        badgeFg = Colors.green.shade900;
        badgeLabel = '${item.daysRemaining} days left';
        break;
      case ExpiryStatus.untracked:
        badgeBg = Colors.grey.shade200;
        badgeFg = Colors.grey.shade800;
        badgeLabel = 'No Expiry Date';
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 22))),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.isAutoExpiry) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text('⏱ est.', style: TextStyle(fontSize: 8, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeFg),
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.event, size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Expires: ${item.formattedExpiryDate}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (item.hasVaultPhoto)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield, size: 10, color: Colors.amber.shade900),
                        const SizedBox(width: 2),
                        Text('Vault Photo', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(item.hasVaultPhoto ? Icons.shield_outlined : Icons.add_a_photo_outlined, color: primary),
              tooltip: item.hasVaultPhoto ? 'View Vault Photo' : 'Upload Vault Photo',
              onPressed: () {
                if (item.hasVaultPhoto) {
                  ExpiryVaultDialog.show(
                    context,
                    item: item,
                    onReplacePhoto: () => ExpiryScanDialog.show(context, item: item),
                    onDeletePhoto: () => provider.updateItemExpiry(
                      token: token,
                      itemId: item.id,
                      expiryImage: '',
                    ),
                  );
                } else {
                  ExpiryScanDialog.show(context, item: item);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => ExpiryScanDialog.show(context, item: item),
            ),
          ],
        ),
      ),
    );
  }
}
