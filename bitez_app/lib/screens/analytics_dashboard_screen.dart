import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analytics_model.dart';
import '../models/waste_record_model.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../services/waste_service.dart';

/// Screen displaying food waste reduction metrics, money saved,
/// monthly streak badges, cooking history, and food waste tracking analytics.
/// Covers Sections 12.3, 18, and 19 in the MCA Project Report.
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  WasteSavingsAnalytics? _savedData;
  WasteStatsModel? _wasteStats;
  bool _loading = true;
  String? _error;
  int _selectedTab = 0; // 0: Food Rescued & Savings, 1: Waste Tracker & Losses

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
    WasteService.instance.wasteUpdatedNotifier.addListener(_onWasteUpdated);
  }

  void _onWasteUpdated() {
    if (mounted) {
      _loadAnalytics(silent: true);
    }
  }

  @override
  void dispose() {
    WasteService.instance.wasteUpdatedNotifier.removeListener(_onWasteUpdated);
    super.dispose();
  }

  Future<void> _loadAnalytics({bool silent = false}) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Please log in to view your analytics.';
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
      final savedFuture = AnalyticsService.instance.getWasteSavingsAnalytics(token);
      final wasteFuture = WasteService.instance.getWasteStats(token);

      final results = await Future.wait([savedFuture, wasteFuture]);

      if (!mounted) return;
      setState(() {
        _savedData = results[0] as WasteSavingsAnalytics;
        _wasteStats = results[1] as WasteStatsModel;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load analytics: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Waste & Savings Analytics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => _loadAnalytics(),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton.extended(
              onPressed: _openManualWasteDialog,
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Log Waste Item', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  void _openManualWasteDialog() async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController(text: '2.00');
    String selectedCategory = 'Veggies';
    String selectedReason = 'Expired';

    final categories = ['Veggies', 'Fruits', 'Dairy', 'Frozen', 'Meat', 'Bakery', 'Pantry', 'Other'];
    final reasons = ['Expired', 'Spoiled', 'Excess quantity', 'Forgotten food', 'Preparation error', 'Other'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Log Discarded Food', style: TextStyle(color: Colors.white, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Food Item Name *',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'e.g. Milk, Spinach, Bread',
                        hintStyle: TextStyle(color: Colors.white38),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedCategory = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedReason,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Discard Reason',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedReason = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: costCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Est. Cost (\$) *',
                              labelStyle: TextStyle(color: Colors.white70),
                              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Record'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      final token = context.read<AuthProvider>().token;
      if (token == null) return;
      try {
        final q = double.tryParse(qtyCtrl.text) ?? 1.0;
        final c = double.tryParse(costCtrl.text) ?? 2.0;
        await WasteService.instance.recordWaste(
          token: token,
          foodName: nameCtrl.text.trim(),
          category: selectedCategory,
          quantity: q,
          reason: selectedReason,
          estimatedCost: c,
        );
        _loadAnalytics(silent: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗑️ Waste record added: ${nameCtrl.text.trim()}'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to record waste: $e')),
          );
        }
      }
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }

    if (_error != null && _savedData == null && _wasteStats == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadAnalytics(),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A4E7C),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadAnalytics(),
      color: const Color(0xFF10B981),
      backgroundColor: const Color(0xFF1B2A47),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Segmented Control: Rescued vs Wasted ─────────────────────────────
          _buildSegmentedTabToggle(),

          const SizedBox(height: 16),

          if (_selectedTab == 0)
            ..._buildRescuedFoodContent()
          else
            ..._buildWasteTrackerContent(),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ── Segmented Control ───────────────────────────────────────────────────────
  Widget _buildSegmentedTabToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A47),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _selectedTab = 0),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? const Color(0xFF10B981) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🌱', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'Food Rescued',
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
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? const Color(0xFFE11D48) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: const Color(0xFFE11D48).withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🗑️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      'Waste Tracker',
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
  // TAB 1: FOOD RESCUED & SAVINGS (EXISTING FEATURES)
  // ───────────────────────────────────────────────────────────────────────────
  List<Widget> _buildRescuedFoodContent() {
    final data = _savedData ?? WasteSavingsAnalytics.empty();

    return [
      _buildHeroSavingsCard(data),
      const SizedBox(height: 16),
      _buildStreakAndProgressCard(data),
      const SizedBox(height: 16),
      _buildCategoryBreakdown(data),
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recent Cooking Events',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${data.recentEvents.length} recorded',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (data.recentEvents.isEmpty)
        _buildEmptyHistoryCard()
      else
        ...data.recentEvents.map(_buildHistoryCard),
    ];
  }

  Widget _buildHeroSavingsCard(WasteSavingsAnalytics data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D5E4A), Color(0xFF0B4636), Color(0xFF0F2B26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🌱', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 4),
                    Text(
                      'ESTIMATED SAVINGS',
                      style: TextStyle(
                        color: Color(0xFF6EE7B7),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.savings_rounded, color: Color(0xFF6EE7B7), size: 26),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '\$${data.totalMoneySaved.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Saved by turning leftovers into delicious homemade meals',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricMini(
                  icon: '🍳',
                  label: 'Meals Cooked',
                  value: '${data.totalRecipesPrepared}',
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white12),
              Expanded(
                child: _buildMetricMini(
                  icon: '🥕',
                  label: 'Items Rescued',
                  value: '${data.totalLeftoversSaved}',
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white12),
              Expanded(
                child: _buildMetricMini(
                  icon: '📅',
                  label: 'This Month',
                  value: '\$${data.currentMonthMoney.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricMini({
    required String icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildStreakAndProgressCard(WasteSavingsAnalytics data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16253D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_fire_department_rounded, color: Colors.amber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Rescue Streak',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Text(
                        '${data.monthlyStreakDays} day streak running!',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Text(
                  data.streakBadge,
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monthly Goal: ${data.currentMonthSaved} / ${data.monthlyGoal} items',
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                '${(data.monthlyGoalProgress * 100).toInt()}%',
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: data.monthlyGoalProgress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(WasteSavingsAnalytics data) {
    if (data.categoryCounts.isEmpty) return const SizedBox.shrink();

    final maxCount = data.categoryCounts.values.fold(1, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16253D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_outline_rounded, color: Color(0xFF60A5FA), size: 18),
              SizedBox(width: 8),
              Text(
                'Saved Leftovers by Section',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...data.categoryCounts.entries.map((e) {
            final fraction = (e.value / maxCount).clamp(0.05, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key[0].toUpperCase() + e.key.substring(1),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '${e.value} items',
                        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(CookHistoryEvent event) {
    final dateStr = '${event.cookedAt.month}/${event.cookedAt.day} at ${event.cookedAt.hour.toString().padLeft(2, '0')}:${event.cookedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16253D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  event.recipeTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+\$${event.estimatedMoneySaved.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white38),
              const SizedBox(width: 4),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.eco_rounded, size: 12, color: Color(0xFF10B981)),
              const SizedBox(width: 4),
              Text(
                '${event.totalItemsSaved} items saved',
                style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 11),
              ),
            ],
          ),
          if (event.deductions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: event.deductions.map((d) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${d.label} ×${d.quantityUsed}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16253D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: Column(
          children: [
            const Text('🍳', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            const Text(
              'No cooked meals recorded yet',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "I Cooked This!" on any recipe to auto-deduct leftovers, earn streak badges, and track your financial savings!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 2: FOOD WASTE TRACKER & LOSSES (SECTIONS 12.3, 18, 19)
  // ───────────────────────────────────────────────────────────────────────────
  List<Widget> _buildWasteTrackerContent() {
    final stats = _wasteStats ?? WasteStatsModel.empty();

    return [
      // Hero Card: Total Cost Lost & Wasted items
      _buildHeroWasteLossCard(stats),

      const SizedBox(height: 16),

      // Avoidable Waste Banner (if avoidable waste exists)
      if (stats.avoidablePercentage > 0) ...[
        _buildAvoidableWasteAlert(stats),
        const SizedBox(height: 16),
      ],

      // Waste by Reason Breakdown
      _buildWasteReasonBreakdown(stats),

      const SizedBox(height: 16),

      // Waste by Category Breakdown
      _buildWasteCategoryBreakdown(stats),

      const SizedBox(height: 20),

      // Recent Discard Records
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recent Waste Logs',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '${stats.recentRecords.length} recorded',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
      const SizedBox(height: 10),

      if (stats.recentRecords.isEmpty)
        _buildEmptyWasteRecordsCard()
      else
        ...stats.recentRecords.map(_buildWasteRecordCard),
    ];
  }

  Widget _buildHeroWasteLossCard(WasteStatsModel stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF501925), Color(0xFF38121B), Color(0xFF220B11)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🗑️', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 4),
                    Text(
                      'ESTIMATED FINANCIAL LOSS',
                      style: TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.trending_down_rounded, color: Color(0xFFFCA5A5), size: 28),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '-\$${stats.totalCostLost.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Total value of discarded food that could not be consumed',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricMini(
                  icon: '📦',
                  label: 'Items Wasted',
                  value: '${stats.totalWastedItems}',
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white12),
              Expanded(
                child: _buildMetricMini(
                  icon: '⚠️',
                  label: 'Avoidable %',
                  value: '${stats.avoidablePercentage}%',
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white12),
              Expanded(
                child: _buildMetricMini(
                  icon: '📋',
                  label: 'Discard Logs',
                  value: '${stats.totalWastedCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvoidableWasteAlert(WasteStatsModel stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C1E14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lightbulb_outline_rounded, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stats.avoidablePercentage}% Avoidable Waste',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Most waste occurred due to expiration or forgotten items. Check your "Expiring Soon" tab daily to cook them on time!',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteReasonBreakdown(WasteStatsModel stats) {
    if (stats.reasonBreakdown.isEmpty) return const SizedBox.shrink();

    final total = stats.totalWastedItems > 0 ? stats.totalWastedItems : 1;

    final reasonColors = <String, Color>{
      'Expired': Colors.redAccent,
      'Spoiled': Colors.orangeAccent,
      'Excess quantity': Colors.blueAccent,
      'Forgotten food': Colors.amber,
      'Preparation error': Colors.purpleAccent,
      'Other': Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16253D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: Colors.redAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Waste Reasons Breakdown',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...stats.reasonBreakdown.entries.map((e) {
            final count = e.value;
            final percent = ((count / total) * 100).round();
            final color = reasonColors[e.key] ?? Colors.redAccent;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        '$count items ($percent%)',
                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (count / total).clamp(0.04, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWasteCategoryBreakdown(WasteStatsModel stats) {
    if (stats.categoryBreakdown.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF16253D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.category_rounded, color: Color(0xFFF472B6), size: 18),
              SizedBox(width: 8),
              Text(
                'Waste by Food Category',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stats.categoryBreakdown.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      e.key[0].toUpperCase() + e.key.substring(1),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${e.value}',
                        style: const TextStyle(
                          color: Color(0xFFFCA5A5),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWasteRecordCard(WasteRecordModel record) {
    final dateStr = '${record.date.month}/${record.date.day} at ${record.date.hour.toString().padLeft(2, '0')}:${record.date.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16253D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.foodName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record.reason,
                        style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${record.quantity.toInt()} ${record.unit}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $dateStr',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '-\$${record.estimatedCost.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWasteRecordsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16253D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 10),
            const Text(
              'Zero food waste logged!',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'You are keeping food waste down. When you do have to discard expired items, log them here to analyze your waste trends over time.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
