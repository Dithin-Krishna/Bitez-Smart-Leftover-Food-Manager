import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/ngo_model.dart';
import '../providers/auth_provider.dart';
import '../services/donation_service.dart';
import '../services/fridge_service.dart';
import 'fridge_screen.dart';

/// Screen managing surplus food donations and community food banks.
/// Directly mirrors Section 12.8 & 22 (Surplus Food Donation & Food Bank Directory)
/// in the MCA Mini Project Report.
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});

  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  bool _loading = true;
  String? _error;
  int _selectedTab = 0; // 0: My Food Pledges, 1: Food Banks & NGOs

  List<Map<String, dynamic>> _pledgedItems = [];
  List<NgoModel> _ngos = [];
  String _selectedNgoCategory = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
    DonationService.instance.donationUpdatedNotifier.addListener(_onDonationUpdated);
  }

  void _onDonationUpdated() {
    if (mounted) _fetchData(silent: true);
  }

  @override
  void dispose() {
    DonationService.instance.donationUpdatedNotifier.removeListener(_onDonationUpdated);
    super.dispose();
  }

  Future<void> _fetchData({bool silent = false}) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      setState(() {
        _loading = false;
        _pledgedItems = [];
        _ngos = [];
      });
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final pledgesFuture = FridgeService.instance.getDonationItems(token);
      final ngosFuture = DonationService.instance.getNgos(token);

      final results = await Future.wait([pledgesFuture, ngosFuture]);

      if (!mounted) return;
      setState(() {
        _pledgedItems = results[0] as List<Map<String, dynamic>>;
        _ngos = results[1] as List<NgoModel>;
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
        title: const Row(
          children: [
            Text('🎉 ', style: TextStyle(fontSize: 22)),
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
          'Mark "$label" as successfully delivered/donated? This will complete your donation record and deduct it from your fridge.',
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
      _fetchData(silent: true);
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
      _fetchData(silent: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _openNgoPickerForPledge(Map<String, dynamic> item) {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    final itemId = item['_id']?.toString() ?? item['id']?.toString() ?? '';
    final label = item['label']?.toString() ?? 'Item';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.volunteer_activism_rounded, color: Color(0xFFE05275), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Assign "$label" to Food Bank',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose a verified local food shelter or community fridge:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _ngos.length,
                  itemBuilder: (ctx, idx) {
                    final ngo = _ngos[idx];
                    return Card(
                      color: const Color(0xFF16253D),
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF2A4E7C),
                          foregroundColor: Colors.white,
                          child: Text(ngo.type == 'Community Fridge' ? '🧊' : '🏢'),
                        ),
                        title: Text(ngo.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text('${ngo.type} • ${ngo.distanceKm} km away\n${ngo.address}', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                        trailing: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
                        onTap: () async {
                          Navigator.pop(ctx);
                          await DonationService.instance.assignPledge(
                            token: token,
                            itemId: itemId,
                            ngoName: ngo.name,
                          );
                          _fetchData(silent: true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('📍 "$label" assigned to ${ngo.name}!'),
                                backgroundColor: const Color(0xFF10B981),
                              ),
                            );
                          }
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

  void _openPledgeFromFridgeSheet(NgoModel ngo) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final allItems = await FridgeService.instance.getAllItems(token: token);
      if (!mounted) return;

      if (allItems.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your fridge is currently empty! Add items to pledge food.')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🤝 ', style: TextStyle(fontSize: 22)),
                    Expanded(
                      child: Text(
                        'Pledge to ${ngo.name}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select an item from your fridge to route to this ${ngo.type}:',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: ListView.builder(
                    itemCount: allItems.length,
                    itemBuilder: (ctx, idx) {
                      final item = allItems[idx];
                      final id = item['_id']?.toString() ?? item['id']?.toString() ?? '';
                      final label = item['label']?.toString() ?? 'Food Item';
                      final emoji = item['emoji']?.toString() ?? '📦';
                      final qty = item['qty'] ?? 1;
                      final isAlreadyPledged = item['isDonation'] == true || item['donationStatus'] == 'pledged';

                      return Card(
                        color: const Color(0xFF16253D),
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Text(emoji, style: const TextStyle(fontSize: 24)),
                          title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text('Qty: $qty • ${isAlreadyPledged ? "Currently Pledged" : "In Fridge"}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE05275),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await FridgeService.instance.toggleDonation(
                                token: token,
                                itemId: id,
                                isDonation: true,
                                donationStatus: 'pledged',
                                itemLabel: label,
                              );
                              await DonationService.instance.assignPledge(
                                token: token,
                                itemId: id,
                                ngoName: ngo.name,
                              );
                              _fetchData(silent: true);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🎉 "$label" pledged to ${ngo.name}!'),
                                    backgroundColor: const Color(0xFF10B981),
                                  ),
                                );
                              }
                            },
                            child: const Text('Pledge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading fridge items: $e')),
      );
    }
  }

  void _showNgoContactDialog(NgoModel ngo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2A4E7C).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on_rounded, color: Color(0xFF60A5FA), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ngo.name,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ngo.description, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3)),
              const SizedBox(height: 14),
              _contactInfoRow(Icons.pin_drop_rounded, 'Address', ngo.address),
              const SizedBox(height: 10),
              _contactInfoRow(Icons.access_time_rounded, 'Operating Hours', ngo.operatingHours),
              const SizedBox(height: 10),
              _contactInfoRow(Icons.phone_rounded, 'Contact Phone', ngo.phone),
              const SizedBox(height: 10),
              _contactInfoRow(Icons.email_outlined, 'Email', ngo.email),
              const SizedBox(height: 14),
              const Text('Accepted Food Types:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ngo.acceptedItems.map((cat) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Text(cat, style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '${ngo.name}\n${ngo.address}\nPhone: ${ngo.phone}'));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📋 Address & Phone copied to clipboard!')),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy_rounded, size: 16, color: Color(0xFF60A5FA)),
                SizedBox(width: 4),
                Text('Copy Info', style: TextStyle(color: Color(0xFF60A5FA))),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A4E7C),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _contactInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
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
            onPressed: () => _fetchData(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _error != null && _pledgedItems.isEmpty && _ngos.isEmpty
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
                        onPressed: () => _fetchData(),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _fetchData(),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    children: [
                      _buildHeaderBanner(primary, accentPink),
                      const SizedBox(height: 14),

                      // ── Segmented Tab Switcher ──────────────────────────────
                      _buildSegmentedTabs(),

                      const SizedBox(height: 16),

                      if (_selectedTab == 0)
                        ..._buildPledgesTabContent(isDark, primary)
                      else
                        ..._buildNgosTabContent(isDark, primary),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A47),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 0),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? const Color(0xFFE05275) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE05275).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🧺', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'My Pledges (${_pledgedItems.length})',
                      style: TextStyle(
                        color: _selectedTab == 0 ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 1),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? const Color(0xFF2A4E7C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2A4E7C).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🏢', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'Food Banks & NGOs',
                      style: TextStyle(
                        color: _selectedTab == 1 ? Colors.white : Colors.white60,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: MY PLEDGES CONTENT
  // ───────────────────────────────────────────────────────────────────────────
  List<Widget> _buildPledgesTabContent(bool isDark, Color primary) {
    return [
      _buildStatsRow(_pledgedItems.length, isDark),
      const SizedBox(height: 18),
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
              ).then((_) => _fetchData(silent: true));
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Pledge More'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE05275)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      if (_pledgedItems.isEmpty)
        _buildEmptyState(isDark)
      else
        ..._pledgedItems.map((item) => _buildDonationCard(item, isDark, primary)),
      const SizedBox(height: 20),
      _buildGuidelinesCard(isDark),
    ];
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: NGOS & COMMUNITY FOOD BANKS DIRECTORY CONTENT
  // ───────────────────────────────────────────────────────────────────────────
  List<Widget> _buildNgosTabContent(bool isDark, Color primary) {
    final categories = ['All', 'Food Bank', 'Community Fridge', 'Shelter & Kitchen', 'NGO / Rescue'];

    final filteredNgos = _ngos.where((ngo) {
      final matchesCat = _selectedNgoCategory == 'All' || ngo.type == _selectedNgoCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          ngo.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          ngo.address.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    return [
      // Search field
      TextField(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search food banks, community fridges...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white60, size: 20),
          filled: true,
          fillColor: const Color(0xFF1B2738),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
      ),
      const SizedBox(height: 12),

      // Category filter chips
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((cat) {
            final isSelected = _selectedNgoCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(cat),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF2A4E7C),
                backgroundColor: const Color(0xFF16253D),
                side: BorderSide(color: isSelected ? const Color(0xFF60A5FA) : Colors.white10),
                onSelected: (_) => setState(() => _selectedNgoCategory = cat),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 16),

      if (filteredNgos.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text(
                  'No community food centers match your search.',
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
        )
      else
        ...filteredNgos.map((ngo) => _buildNgoDirectoryCard(ngo, isDark, primary)),
    ];
  }

  Widget _buildNgoDirectoryCard(NgoModel ngo, bool isDark, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFF2A4E7C).withValues(alpha: 0.2),
                child: Text(
                  ngo.type == 'Community Fridge' ? '🧊' : (ngo.type == 'Shelter & Kitchen' ? '🏠' : '🏢'),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            ngo.name,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (ngo.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ngo.type} • ${ngo.distanceKm} km away',
                      style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Open', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ngo.description,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontSize: 12, height: 1.3),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  ngo.address,
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 13, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                ngo.operatingHours,
                style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: ngo.acceptedItems.map((cat) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cat,
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade800, fontSize: 10),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showNgoContactDialog(ngo),
                  icon: const Icon(Icons.info_outline_rounded, size: 16),
                  label: const Text('Contact & Info'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF60A5FA),
                    side: const BorderSide(color: Color(0xFF60A5FA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openPledgeFromFridgeSheet(ngo),
                  icon: const Icon(Icons.volunteer_activism_rounded, size: 16),
                  label: const Text('Pledge Food'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE05275),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
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
                  'Route safe surplus food to local shelters, community fridges, and charity drives.',
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
            'Select ingredients from your fridge to route safe surplus food to local community fridges and shelters.',
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
              ).then((_) => _fetchData(silent: true));
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
    final ngoName = item['donationNgoName']?.toString() ?? '';

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

          // Destination Food Bank info or picker
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ngoName.isNotEmpty
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ngoName.isNotEmpty
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : Colors.amber.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  ngoName.isNotEmpty ? Icons.check_circle_rounded : Icons.place_outlined,
                  size: 14,
                  color: ngoName.isNotEmpty ? const Color(0xFF10B981) : Colors.amber,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ngoName.isNotEmpty ? 'Destination: $ngoName' : 'No Food Bank assigned yet',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: ngoName.isNotEmpty ? const Color(0xFF6EE7B7) : Colors.amber,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _openNgoPickerForPledge(item),
                  child: Text(
                    ngoName.isNotEmpty ? 'Change' : 'Assign Center',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF60A5FA),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
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
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => _cancelPledge(item),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Cancel Pledge', style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => _markDonated(item),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Mark Donated', style: TextStyle(fontSize: 12)),
                ),
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
              const Icon(Icons.info_outline_rounded, color: Color(0xFF2A4E7C), size: 20),
              const SizedBox(width: 8),
              Text(
                'Safe Food Donation Guidelines',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _guidelineItem('✅ Only donate food that is fresh, unexpired, and safe for consumption.', isDark),
          _guidelineItem('✅ Keep cooked food refrigerated until drop-off or pickup.', isDark),
          _guidelineItem('✅ Ensure packaging is intact and properly labeled.', isDark),
          _guidelineItem('❌ Do not donate expired, spoiled, or foul-smelling items.', isDark),
        ],
      ),
    );
  }

  Widget _guidelineItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white70 : Colors.grey.shade700,
          height: 1.3,
        ),
      ),
    );
  }
}
