import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/fridge_service.dart';
import 'fridge_screen.dart';

class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pledgedItems = [];

  @override
  void initState() {
    super.initState();
    _fetchDonations();
  }

  Future<void> _fetchDonations() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      setState(() {
        _loading = false;
        _pledgedItems = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await FridgeService.instance.getDonationItems(token);
      if (!mounted) return;
      setState(() {
        _pledgedItems = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markDonated(Map<String, dynamic> item) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final itemId = item['_id']?.toString() ?? item['id']?.toString() ?? '';
    final label = item['label']?.toString() ?? 'Item';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Text('🎉 ', style: TextStyle(fontSize: 22)),
            Expanded(
              child: Text(
                'Confirm Donation',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Mark "$label" as successfully donated? This will complete your donation and update your fridge inventory.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark Donated'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FridgeService.instance.toggleDonation(
        token: token,
        itemId: itemId,
        isDonation: true,
        donationStatus: 'donated',
        itemLabel: label,
      );

      // If donated, deduct/remove from fridge to keep inventory updated
      await FridgeService.instance.deductItems(
        token: token,
        deductions: [
          {'itemId': itemId, 'label': label, 'quantity': item['qty'] ?? 1},
        ],
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❤️ Thank you! "$label" marked as donated!'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
      _fetchDonations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating donation: $e')),
      );
    }
  }

  Future<void> _cancelPledge(Map<String, dynamic> item) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final itemId = item['_id']?.toString() ?? item['id']?.toString() ?? '';
    final label = item['label']?.toString() ?? 'Item';

    try {
      await FridgeService.instance.toggleDonation(
        token: token,
        itemId: itemId,
        isDonation: false,
        donationStatus: 'none',
        itemLabel: label,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "$label" from donation pledges.'),
          backgroundColor: Colors.blueGrey,
        ),
      );
      _fetchDonations();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const primary = Color(0xFF2A4E7C);
    const accentPink = Color(0xFFE05275);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101924) : const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF131E2F) : Colors.white,
        elevation: 0.5,
        title: const Row(
          children: [
            Icon(Icons.volunteer_activism_rounded, color: accentPink, size: 22),
            SizedBox(width: 8),
            Text(
              'Food Bank Donations',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchDonations,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchDonations,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchDonations,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    children: [
                      _buildHeaderBanner(primary, accentPink),
                      const SizedBox(height: 16),
                      _buildStatsRow(_pledgedItems.length, isDark),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pledged Items (${_pledgedItems.length})',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FridgeScreen()),
                              ).then((_) => _fetchDonations());
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Pledge More'),
                            style: TextButton.styleFrom(foregroundColor: primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_pledgedItems.isEmpty)
                        _buildEmptyState(isDark)
                      else
                        ..._pledgedItems.map((item) => _buildDonationCard(item, isDark, primary)),
                      const SizedBox(height: 24),
                      _buildGuidelinesCard(isDark),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderBanner(Color primary, Color accent) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A4E7C), Color(0xFF3F699A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A4E7C).withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🤝', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Food Sharing',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Rescue surplus food before it spoils by pledging it to local food shelters and neighbors.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int pledgedCount, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            title: 'Pledged to Donate',
            value: '$pledgedCount items',
            emoji: '🎁',
            color: const Color(0xFFE05275),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            title: 'Food Waste Prevented',
            value: '${pledgedCount * 2} meals',
            emoji: '🥗',
            color: const Color(0xFF2E7D32),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String emoji,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2738) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2738) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🥫', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            'No Items Pledged for Donation Yet',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Mark ingredients from your fridge as donation items to share surplus food with charities and community fridges.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A4E7C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FridgeScreen()),
              ).then((_) => _fetchDonations());
            },
            icon: const Icon(Icons.kitchen_outlined, size: 18),
            label: const Text('Open Fridge to Select Items'),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationCard(Map<String, dynamic> item, bool isDark, Color primary) {
    final emoji = item['emoji']?.toString() ?? '📦';
    final label = item['label']?.toString() ?? 'Food Item';
    final qty = item['qty'] ?? 1;
    final section = item['section']?.toString() ?? 'General';
    final notes = item['donationNotes']?.toString() ?? '';

    DateTime? expiresAt;
    if (item['expiresAt'] != null) {
      expiresAt = DateTime.tryParse(item['expiresAt'].toString())?.toLocal();
    }

    String expiryText = 'No expiry set';
    Color expiryColor = Colors.grey;
    if (expiresAt != null) {
      final days = expiresAt.difference(DateTime.now()).inDays;
      if (days < 0) {
        expiryText = 'Expired';
        expiryColor = Colors.red;
      } else if (days <= 2) {
        expiryText = 'Expiring in $days day${days == 1 ? "" : "s"}';
        expiryColor = Colors.orange.shade800;
      } else {
        expiryText = 'Fresh ($days days left)';
        expiryColor = Colors.green.shade700;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2738) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            section.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Qty: $qty',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: expiryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  expiryText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: expiryColor,
                  ),
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '📝 Notes: $notes',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _cancelPledge(item),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: const Text('Cancel Pledge', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _markDonated(item),
                icon: const Icon(Icons.check_circle_outline, size: 14),
                label: const Text('Mark Donated', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2738) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📋 ', style: TextStyle(fontSize: 18)),
              Text(
                'Food Bank Donation Guidelines',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bulletPoint('✅ Ideal for donation:', 'Unopened packaged foods, canned goods, whole intact fruits & vegetables with shelf life remaining.', Colors.green),
          const SizedBox(height: 6),
          _bulletPoint('❌ Not accepted:', 'Expired foods, opened containers, home-cooked perishables without labels or storage date.', Colors.redAccent),
          const SizedBox(height: 6),
          _bulletPoint('💡 Best Practice:', 'Pledge food 2-3 days before expiry to allow time for charity pickup and redistribution.', const Color(0xFF2A4E7C)),
        ],
      ),
    );
  }

  Widget _bulletPoint(String heading, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
        const SizedBox(width: 4),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3)),
        ),
      ],
    );
  }
}
