import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/analytics_model.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';

/// Screen displaying food waste reduction metrics, money saved,
/// monthly streak badges, and recent cooking history.
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  WasteSavingsAnalytics? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      setState(() {
        _loading = false;
        _error = 'Please log in to view your savings analytics.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await AnalyticsService.instance.getWasteSavingsAnalytics(token);
      if (!mounted) return;
      setState(() {
        _data = data;
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
          'Waste & Savings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF10B981)),
      );
    }

    if (_error != null && _data == null) {
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
                onPressed: _loadAnalytics,
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

    final data = _data ?? WasteSavingsAnalytics.empty();

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      color: const Color(0xFF10B981),
      backgroundColor: const Color(0xFF1B2A47),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Top Highlight: Money Saved Banner ──────────────────────────────
          _buildHeroSavingsCard(data),

          const SizedBox(height: 16),

          // ── Streak Badge & Monthly Goal Progress ───────────────────────────
          _buildStreakAndProgressCard(data),

          const SizedBox(height: 16),

          // ── Category Savings Breakdown ─────────────────────────────────────
          _buildCategoryBreakdown(data),

          const SizedBox(height: 20),

          // ── Recent Cooking History ─────────────────────────────────────────
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

          const SizedBox(height: 32),
        ],
      ),
    );
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
                  label: 'Recipes Cooked',
                  value: '${data.totalRecipesPrepared}',
                ),
              ),
              Container(width: 1, height: 32, color: Colors.white12),
              Expanded(
                child: _buildMetricMini(
                  icon: '🥦',
                  label: 'Leftovers Saved',
                  value: '${data.totalLeftoversSaved}',
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
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _buildStreakAndProgressCard(WasteSavingsAnalytics data) {
    final progress = data.monthlyGoalProgress.clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();

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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🔥', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly Streak',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            '${data.monthlyStreakDays} Days Cooked',
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400.withValues(alpha: 0.5)),
                ),
                child: Text(
                  data.streakBadge,
                  style: TextStyle(
                    color: Colors.amber.shade300,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Waste-Reduction Goal',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${data.currentMonthSaved} / ${data.monthlyGoal} items ($percent%)',
                style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.currentMonthSaved >= data.monthlyGoal
                ? '🎉 Congratulations! You achieved your monthly zero-waste goal!'
                : 'Save ${data.monthlyGoal - data.currentMonthSaved} more items to reach this month\'s target!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(WasteSavingsAnalytics data) {
    if (data.categoryCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    final categoryIcons = {
      'dairy': '🥛',
      'veggies': '🥦',
      'fruits': '🍎',
      'frozen': '🥟',
      'meat': '🥩',
      'pantry': '🌾',
      'drinks': '🧃',
      'condiments': '🧂',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Leftovers Saved by Shelf',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: data.categoryCounts.entries.map((entry) {
              final emoji = categoryIcons[entry.key.toLowerCase()] ?? '🥗';
              final label = entry.key[0].toUpperCase() + entry.key.substring(1);

              return Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16253D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          '${entry.value} saved',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(CookHistoryEvent event) {
    final dateStr = '${event.cookedAt.month}/${event.cookedAt.day}/${event.cookedAt.year}';

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
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
}
