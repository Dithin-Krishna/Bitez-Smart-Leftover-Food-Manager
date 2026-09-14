import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/suggestion_service.dart';

class AppSuggestionScreen extends StatefulWidget {
  const AppSuggestionScreen({super.key});

  @override
  State<AppSuggestionScreen> createState() => _AppSuggestionScreenState();
}

class _AppSuggestionScreenState extends State<AppSuggestionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String _selectedCategory = 'feature';
  int _selectedRating = 5;
  bool _isAnonymous = false;
  bool _isSubmitting = false;

  List<AppSuggestion> _mySuggestions = [];
  bool _isLoadingHistory = false;

  final List<Map<String, dynamic>> _categories = const [
    {'key': 'feature', 'label': 'Feature Request', 'icon': Icons.auto_awesome},
    {'key': 'ui_ux', 'label': 'UI & Design', 'icon': Icons.palette_outlined},
    {'key': 'recipe_idea', 'label': 'Recipe Ideas', 'icon': Icons.restaurant_menu},
    {'key': 'bug_report', 'label': 'Bug Report', 'icon': Icons.bug_report_outlined},
    {'key': 'general', 'label': 'General Feedback', 'icon': Icons.chat_bubble_outline},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSuggestionsHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestionsHistory() async {
    setState(() => _isLoadingHistory = true);
    final auth = context.read<AuthProvider>();
    final token = auth.token;
    final user = auth.user;
    final items = await SuggestionService.instance.getMySuggestions(
      token: token,
      userId: user?.id,
    );
    if (!mounted) return;
    setState(() {
      _mySuggestions = items;
      _isLoadingHistory = false;
    });
  }

  String _getRatingSentiment(int rating) {
    switch (rating) {
      case 1:
        return 'Needs Work 😕';
      case 2:
        return 'Fair 😐';
      case 3:
        return 'Good 🙂';
      case 4:
        return 'Very Good 😊';
      case 5:
      default:
        return 'Loved it! 🌟';
    }
  }

  Future<void> _submitSuggestion() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final token = auth.token;
    final user = auth.user;

    try {
      final suggestion = await SuggestionService.instance.submitSuggestion(
        token: token,
        userId: user?.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        category: _selectedCategory,
        rating: _selectedRating,
        isAnonymous: _isAnonymous,
        userName: user?.name,
        userEmail: user?.email,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _titleController.clear();
        _descController.clear();
        _selectedRating = 5;
        _selectedCategory = 'feature';
      });

      // Reload history
      await _loadSuggestionsHistory();

      if (!mounted) return;
      _showSuccessDialog(suggestion);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit suggestion: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSuccessDialog(AppSuggestion suggestion) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Text('🎉', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Thank You!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your suggestion "${suggestion.title}" has been recorded!',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 10),
            Text(
              'Our team reviews every piece of user feedback to shape future updates of Bitez.',
              style: TextStyle(
                color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 16, color: primary),
                  const SizedBox(width: 6),
                  Text(
                    'Status: ${suggestion.statusDisplayName}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _tabController.animateTo(1); // Switch to "My Suggestions" tab
            },
            child: const Text('View My Suggestions'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSuggestion(AppSuggestion item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Suggestion?'),
          ],
        ),
        content: Text('Are you sure you want to delete "${item.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              final token = auth.token;
              final user = auth.user;
              if (token == null) return;
              final ok = await SuggestionService.instance.deleteSuggestion(
                id: item.id,
                token: token,
                userId: user?.id,
              );
              if (ok) {
                await _loadSuggestionsHistory();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Suggestion deleted successfully'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.isAdmin == true;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isAdmin ? 'App Suggestions (Admin)' : 'Suggestion for App',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primary,
          labelColor: primary,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            const Tab(
              icon: Icon(Icons.lightbulb_outline),
              text: 'New Suggestion',
            ),
            Tab(
              icon: Icon(isAdmin ? Icons.admin_panel_settings_outlined : Icons.history_edu_outlined),
              text: isAdmin
                  ? 'All Suggestions (${_mySuggestions.length})'
                  : 'My Suggestions (${_mySuggestions.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFormTab(theme, isDark, primary),
          _buildHistoryTab(theme, isDark, primary, isAdmin: isAdmin),
        ],
      ),
    );
  }

  Widget _buildFormTab(ThemeData theme, bool isDark, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Banner ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E3A5F), const Color(0xFF132438)]
                      : [const Color(0xFF2A4E7C), const Color(0xFF4A74A5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('💡', style: TextStyle(fontSize: 26)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Help Us Make Bitez Better!',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Got an idea for a feature, recipe innovation, or design tweak? We review every suggestion!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Privacy Assurance Banner ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF132B20) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Private & Confidential: Your suggestions are only visible to you and Bitez app administrators.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Category Chips ───────────────────────────────────────────────
            Text(
              'Select Category',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['key'];
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(width: 6),
                      Text(cat['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: primary,
                  backgroundColor: theme.cardColor,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedCategory = cat['key'] as String);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Overall Experience Rating ────────────────────────────────────
            Text(
              'How satisfied are you with Bitez?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                children: [
                  Row(
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      return IconButton(
                        iconSize: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          starNum <= _selectedRating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedRating = starNum);
                        },
                      );
                    }),
                  ),
                  const Spacer(),
                  Text(
                    _getRatingSentiment(_selectedRating),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Suggestion Title ─────────────────────────────────────────────
            Text(
              'Suggestion Title',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'e.g., Add grocery price comparison or smart timers',
                filled: true,
                fillColor: theme.cardColor,
                prefixIcon: const Icon(Icons.title, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter a title for your suggestion';
                }
                if (v.trim().length < 4) {
                  return 'Title must be at least 4 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Detailed Description ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Details & Context',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
                Text(
                  'Max 1000 chars',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText:
                    'Explain what you’d like to see, why it’s useful, or what can be improved...',
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Please provide more details on your suggestion';
                }
                if (v.trim().length < 10) {
                  return 'Please write at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),

            // ── Anonymous Option ─────────────────────────────────────────────
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Submit anonymously',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Uncheck to include your name & email for follow-up updates',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
              ),
              value: _isAnonymous,
              activeColor: primary,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (val) => setState(() => _isAnonymous = val ?? false),
            ),
            const SizedBox(height: 20),

            // ── Submit Button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitSuggestion,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSubmitting ? 'Sending Suggestion...' : 'Submit Suggestion',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(ThemeData theme, bool isDark, Color primary, {bool isAdmin = false}) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_mySuggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lightbulb_outline, size: 48, color: primary),
              ),
              const SizedBox(height: 16),
              Text(
                isAdmin ? 'No User Suggestions Yet' : 'No Suggestions Yet',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                isAdmin
                    ? 'When users submit feedback or ideas for Bitez, they will appear here for admin review.'
                    : 'Have ideas to enhance Bitez? Switch to the "New Suggestion" tab and share your thoughts! Only you and admins can see them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              ),
              if (!isAdmin) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Write a Suggestion'),
                  onPressed: () => _tabController.animateTo(0),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSuggestionsHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _mySuggestions.length + (isAdmin ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (isAdmin && index == 0) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings, color: primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Admin Review: ${_mySuggestions.length} total suggestions submitted across users. Tap the status badge on any card to update it.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final itemIndex = isAdmin ? index - 1 : index;
          final item = _mySuggestions[itemIndex];

          Color badgeColor;
          switch (item.status) {
            case 'implemented':
              badgeColor = Colors.green;
              break;
            case 'planned':
              badgeColor = Colors.teal;
              break;
            case 'closed':
              badgeColor = Colors.blueGrey;
              break;
            case 'under_review':
            default:
              badgeColor = Colors.orange;
              break;
          }

          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: theme.cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.categoryDisplayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isAdmin)
                        PopupMenuButton<String>(
                          tooltip: 'Change Status',
                          onSelected: (newStatus) async {
                            final token = context.read<AuthProvider>().token;
                            if (token == null) return;
                            final ok = await SuggestionService.instance.updateSuggestionStatus(
                              id: item.id,
                              status: newStatus,
                              token: token,
                            );
                            if (ok) {
                              _loadSuggestionsHistory();
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Status updated to $newStatus'),
                                  backgroundColor: Colors.teal,
                                ),
                              );
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'under_review', child: Text('⏳ Under Review')),
                            const PopupMenuItem(value: 'planned', child: Text('💡 Planned')),
                            const PopupMenuItem(value: 'implemented', child: Text('✨ Implemented')),
                            const PopupMenuItem(value: 'closed', child: Text('✅ Closed / Resolved')),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  item.statusDisplayName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down, size: 14, color: badgeColor),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.statusDisplayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                        tooltip: 'Delete Suggestion',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDeleteSuggestion(item),
                      ),
                    ],
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_circle_outlined, size: 14, color: isDark ? Colors.white60 : Colors.black54),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Author: ${item.userName ?? "Anonymous"}${item.userEmail != null && item.userEmail!.isNotEmpty ? " • ${item.userEmail}" : ""}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: theme.dividerColor),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Row(
                        children: List.generate(
                          item.rating,
                          (i) => const Icon(Icons.star, size: 14, color: Colors.amber),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
