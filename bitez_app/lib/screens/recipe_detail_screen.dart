import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe_model.dart';
import '../providers/saved_recipes_provider.dart';
import '../services/recipe_service.dart';

class RecipeDetailScreen extends StatefulWidget {
  final RecipeModel recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  late RecipeModel _detail;
  bool _loading = true;
  late TabController _tabController;

  // Interactive step checking state
  final Set<int> _completedSteps = {};
  final Set<String> _checkedIngredients = {};

  @override
  void initState() {
    super.initState();
    _detail = widget.recipe;
    _tabController = TabController(length: 3, vsync: this);
    _fetchDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    if (_detail.instructions.isNotEmpty && _detail.readyInMinutes != null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final fetched = await RecipeService.instance.getRecipeInformation(widget.recipe.id);
      if (mounted) {
        setState(() {
          _detail = fetched;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCookingModeModal() {
    if (_detail.instructions.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CookingModeSheet(instructions: _detail.instructions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final savedProvider = context.watch<SavedRecipesProvider>();
    final isSaved = savedProvider.isSaved(_detail.id);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Hero Banner App Bar ────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: theme.scaffoldBackgroundColor,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? Colors.amber : Colors.white,
                    size: 22,
                  ),
                ),
                onPressed: () => savedProvider.toggleSave(_detail),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'recipe_image_${_detail.id}',
                    child: _detail.image.isNotEmpty
                        ? Image.network(
                            _detail.image,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _bannerFallback(primary),
                          )
                        : _bannerFallback(primary),
                  ),

                  // Gradient protection overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black54, Colors.transparent, Colors.black87],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Recipe Title Overlay
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_detail.totalIngredients > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_detail.matchPercentage.toInt()}% Ingredient Match',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Text(
                          _detail.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Quick Info Bar (Time, Servings, Cal) ──────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _quickStat(Icons.timer_outlined, '${_detail.readyInMinutes ?? 25} mins', 'Prep Time', primary),
                  _dividerVertical(theme),
                  _quickStat(Icons.people_outline, '${_detail.servings ?? 2} Servings', 'Yield', primary),
                  _dividerVertical(theme),
                  _quickStat(Icons.local_fire_department_outlined, '${_detail.calories ?? 380} kcal', 'Calories', primary),
                ],
              ),
            ),
          ),

          // ── Sticky Tab Bar ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: primary,
                labelColor: primary,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.grey.shade600,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'Ingredients 🥗'),
                  Tab(text: 'Instructions 👩‍🍳'),
                  Tab(text: 'Nutrition 📊'),
                ],
              ),
            ),
          ),

          // ── Tab Views ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Ingredients List
                  _buildIngredientsTab(theme, isDark, primary),

                  // Tab 2: Instructions Step List
                  _buildInstructionsTab(theme, isDark, primary),

                  // Tab 3: Nutrition Breakdown
                  _buildNutritionTab(theme, isDark, primary),
                ],
              ),
            ),
          ),
        ],
      ),

      // Floating Cooking Mode Action Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _showCookingModeModal,
            icon: const Icon(Icons.play_circle_fill),
            label: const Text(
              'Start Cooking Mode',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }

  // ── Tab 1: Ingredients ─────────────────────────────────────────────────────
  Widget _buildIngredientsTab(ThemeData theme, bool isDark, Color primary) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_detail.summary != null && _detail.summary!.isNotEmpty) ...[
          Text(
            _detail.summary!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF5F5E5A),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text(
          'Available in your Fridge',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),

        () {
          final cleanAvailable = _detail.usedIngredients
              .where((ing) => !['leftover food', 'leftovers', 'leftover', 'food', 'my food'].contains(ing.toLowerCase().trim()))
              .toList();

          if (cleanAvailable.isEmpty) {
            return Text(
              'Check main ingredient list below.',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
            );
          }

          return Column(
            children: cleanAvailable.map((ing) {
              final checked = _checkedIngredients.contains(ing);
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: primary,
                value: checked,
                title: Text(
                  ing,
                  style: TextStyle(
                    fontSize: 14,
                    decoration: checked ? TextDecoration.lineThrough : null,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _checkedIngredients.add(ing);
                    } else {
                      _checkedIngredients.remove(ing);
                    }
                  });
                },
              );
            }).toList(),
          );
        }(),

        if (_detail.missedIngredients.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Missing Ingredients (+To Buy)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ..._detail.missedIngredients.map((ing) {
            final checked = _checkedIngredients.contains(ing);
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: Colors.orange.shade800,
              value: checked,
              title: Text(
                ing,
                style: TextStyle(
                  fontSize: 14,
                  decoration: checked ? TextDecoration.lineThrough : null,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _checkedIngredients.add(ing);
                  } else {
                    _checkedIngredients.remove(ing);
                  }
                });
              },
            );
          }),
        ],
      ],
    );
  }

  // ── Tab 2: Instructions ────────────────────────────────────────────────────
  Widget _buildInstructionsTab(ThemeData theme, bool isDark, Color primary) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_detail.instructions.isEmpty) {
      return Center(
        child: Text(
          'No detailed steps available for this recipe.',
          style: TextStyle(color: isDark ? Colors.white60 : Colors.grey),
        ),
      );
    }

    final totalSteps = _detail.instructions.length;
    final doneCount = _completedSteps.length;
    final progress = totalSteps > 0 ? (doneCount / totalSteps) : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Progress Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress ($doneCount of $totalSteps steps done)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(primary),
          ),
        ),
        const SizedBox(height: 16),

        // Steps List
        ...List.generate(totalSteps, (index) {
          final isDone = _completedSteps.contains(index);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isDone
                ? primary.withValues(alpha: isDark ? 0.15 : 0.08)
                : theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDone ? primary : (isDark ? Colors.white12 : Colors.black12),
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                setState(() {
                  if (isDone) {
                    _completedSteps.remove(index);
                  } else {
                    _completedSteps.add(index);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: isDone ? primary : (isDark ? const Color(0xFF2A3D54) : Colors.grey.shade200),
                      child: isDone
                          ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _detail.instructions[index],
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── Tab 3: Nutrition ───────────────────────────────────────────────────────
  Widget _buildNutritionTab(ThemeData theme, bool isDark, Color primary) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Nutritional Estimate (per serving)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
        const SizedBox(height: 16),

        _macroBar('Calories', '${_detail.calories ?? 380} kcal', 0.65, Colors.deepOrange, theme, isDark),
        const SizedBox(height: 12),
        _macroBar('Protein', '${_detail.proteinGrams ?? 24} g', 0.80, const Color(0xFF27AE60), theme, isDark),
        const SizedBox(height: 12),
        _macroBar('Carbohydrates', '${_detail.carbsGrams ?? 42} g', 0.55, Colors.amber.shade800, theme, isDark),
        const SizedBox(height: 12),
        _macroBar('Fats', '${_detail.fatGrams ?? 14} g', 0.35, Colors.purple, theme, isDark),
      ],
    );
  }

  Widget _macroBar(String label, String value, double percent, Color accentColor, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _quickStat(IconData icon, String value, String label, Color primary) {
    return Column(
      children: [
        Icon(icon, size: 20, color: primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: primary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _dividerVertical(ThemeData theme) {
    return Container(
      height: 30,
      width: 1,
      color: theme.dividerColor,
    );
  }

  Widget _bannerFallback(Color primary) {
    return Container(
      color: primary.withValues(alpha: 0.2),
      child: Center(
        child: Icon(Icons.restaurant, size: 64, color: primary),
      ),
    );
  }
}

// ── Interactive Cooking Mode Bottom Sheet ────────────────────────────────────
class _CookingModeSheet extends StatefulWidget {
  final List<String> instructions;

  const _CookingModeSheet({required this.instructions});

  @override
  State<_CookingModeSheet> createState() => __CookingModeSheetState();
}

class __CookingModeSheetState extends State<_CookingModeSheet> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final total = widget.instructions.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cooking Mode',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Step ${_currentIndex + 1} of $total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: primary,
                    child: Text(
                      '${_currentIndex + 1}',
                      style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.instructions[_currentIndex],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Navigation buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentIndex--),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Previous Step'),
                    ),
                  ),
                if (_currentIndex > 0) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentIndex < total - 1) {
                        setState(() => _currentIndex++);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_currentIndex < total - 1 ? 'Next Step' : 'Finish Cooking 🎉'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


