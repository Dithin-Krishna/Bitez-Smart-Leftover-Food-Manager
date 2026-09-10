import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe_model.dart';
import '../providers/auth_provider.dart';
import '../providers/saved_recipes_provider.dart';
import '../services/fridge_service.dart';
import '../services/grocery_service.dart';
import '../services/recipe_service.dart';
import '../services/meal_planner_service.dart';

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

  // ── Feature 1: Fridge matching state ────────────────────────────────────────
  List<Map<String, dynamic>> _fridgeItems = [];
  bool _fridgeLoaded = false;
  bool _deducting = false;

  // ── Feature 2: Grocery export state ─────────────────────────────────────────
  bool _addingToGrocery = false;

  @override
  void initState() {
    super.initState();
    _detail = widget.recipe;
    _tabController = TabController(length: 3, vsync: this);
    _fetchDetails();
    _loadFridgeItems();
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

  // ── Feature 1: Load fridge inventory for matching ──────────────────────────
  Future<void> _loadFridgeItems() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final items = await FridgeService.instance.getAllItems(token: token);
      if (mounted) {
        setState(() {
          _fridgeItems = items;
          _fridgeLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _fridgeLoaded = true);
    }
  }

  /// Matches recipe usedIngredients to fridge items via fuzzy label comparison.
  /// Returns list of { fridgeItem, matchedIngredientName }.
  List<Map<String, dynamic>> _getMatchedFridgeItems() {
    if (_fridgeItems.isEmpty) return [];

    final cleanUsed = _detail.usedIngredients
        .where((ing) => !['leftover food', 'leftovers', 'leftover', 'food', 'my food']
            .contains(ing.toLowerCase().trim()))
        .toList();

    final matches = <Map<String, dynamic>>[];
    final usedFridgeIds = <String>{};

    for (final ingredient in cleanUsed) {
      final ingLower = ingredient.toLowerCase().trim();

      for (final fridgeItem in _fridgeItems) {
        final fridgeId = fridgeItem['_id']?.toString() ?? '';
        if (usedFridgeIds.contains(fridgeId)) continue;

        final fridgeLabel = (fridgeItem['label']?.toString() ?? '').toLowerCase().trim();
        if (fridgeLabel.isEmpty) continue;

        // Fuzzy match: fridge label appears in recipe ingredient string, or vice versa
        if (ingLower.contains(fridgeLabel) || fridgeLabel.contains(ingLower)) {
          usedFridgeIds.add(fridgeId);
          matches.add({
            'fridgeItem': fridgeItem,
            'ingredientName': ingredient,
          });
          break;
        }
      }
    }

    return matches;
  }

  // ── Feature 1: Show deduction confirmation dialog ──────────────────────────
  Future<void> _showDeductionDialog() async {
    final matches = _getMatchedFridgeItems();
    if (matches.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No matching fridge items found for this recipe.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final result = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CookDeductionDialog(matches: matches),
    );

    if (result == null || result.isEmpty || !mounted) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _deducting = true);

    try {
      await FridgeService.instance.deductItems(
        token: token,
        deductions: result,
        recipeTitle: widget.recipe.title,
        recipeId: widget.recipe.id.toString(),
      );

      // Refresh local fridge items
      await _loadFridgeItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Deducted ${result.length} ingredient${result.length == 1 ? "" : "s"} from your fridge!'),
            backgroundColor: const Color(0xFF2A4E7C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deduct items: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deducting = false);
    }
  }

  // ── Feature 2: Add missing ingredients to grocery list ─────────────────────
  Future<void> _addMissingToGrocery() async {
    final missing = _detail.missedIngredients;
    if (missing.isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _addingToGrocery = true);

    try {
      // Extract clean ingredient names for grocery list
      final items = missing.map((ing) {
        // Try to extract just the ingredient name from strings like "2 cups flour"
        final cleanName = _extractIngredientName(ing);
        return {'label': cleanName, 'qty': 1};
      }).toList();

      final response = await GroceryService.instance.addBulkItems(
        token: token,
        items: items,
      );

      if (mounted) {
        final addedCount = response['addedCount'] ?? 0;
        final updatedCount = response['updatedCount'] ?? 0;
        String message;
        if (addedCount > 0 && updatedCount > 0) {
          message = '🛒 Added $addedCount new + updated $updatedCount existing item(s) in Grocery List!';
        } else if (updatedCount > 0) {
          message = '🛒 Updated $updatedCount existing item(s) in Grocery List!';
        } else {
          message = '🛒 Added $addedCount item(s) to Grocery List!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to grocery list: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToGrocery = false);
    }
  }

  /// Extract core ingredient name from recipe strings like "2 large eggs" → "Eggs"
  String _extractIngredientName(String raw) {
    // Remove leading quantities and measurements
    String cleaned = raw.replaceAll(RegExp(r'^[\d/.\s]+'), '');
    // Remove common measurement words
    cleaned = cleaned.replaceAll(
      RegExp(r'^(cups?|tbsps?|tsps?|tablespoons?|teaspoons?|oz|ounces?|lbs?|pounds?|g|grams?|kg|ml|liters?|large|medium|small|pieces?|slices?|cloves?|cans?|bunch|pinch|dash)\s+', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s*\(.*?\)\s*'), '');
    cleaned = cleaned.trim();
    if (cleaned.isEmpty) cleaned = raw.trim();
    // Capitalize first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    return cleaned;
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

  Future<void> _showPinToMealPlanDialog() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    String selectedDay = 'monday';
    String mealType = 'dinner';

    final days = {
      'monday': 'Monday',
      'tuesday': 'Tuesday',
      'wednesday': 'Wednesday',
      'thursday': 'Thursday',
      'friday': 'Friday',
      'saturday': 'Saturday',
      'sunday': 'Sunday',
    };

    final pinned = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF16253D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: Color(0xFF4A90C4)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pin to Meal Plan',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add "${_detail.title}" to your weekly schedule:',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text('Day of the Week', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedDay,
                    dropdownColor: const Color(0xFF16253D),
                    isExpanded: true,
                    items: days.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: const TextStyle(color: Colors.white))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedDay = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Meal Type', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: mealType,
                    dropdownColor: const Color(0xFF16253D),
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'breakfast', child: Text('🥞 Breakfast', style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'lunch',     child: Text('🥪 Lunch',     style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'dinner',    child: Text('🍽️ Dinner',    style: TextStyle(color: Colors.white))),
                      DropdownMenuItem(value: 'snack',     child: Text('🍎 Snack',     style: TextStyle(color: Colors.white))),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => mealType = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A4E7C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                try {
                  final allIngredients = [
                    ..._detail.usedIngredients,
                    ..._detail.missedIngredients,
                  ];
                  await MealPlannerService.instance.pinRecipe(
                    token: token,
                    dayOfWeek: selectedDay,
                    recipeTitle: _detail.title,
                    recipeId: _detail.id.toString(),
                    imageUrl: _detail.image,
                    ingredients: allIngredients,
                    cookTime: _detail.readyInMinutes ?? 20,
                    mealType: mealType,
                    servings: _detail.servings ?? 2,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (_) {
                  if (ctx.mounted) Navigator.pop(ctx, false);
                }
              },
              child: const Text('Pin Recipe'),
            ),
          ],
        ),
      ),
    );

    if (pinned == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📌 Pinned to ${days[selectedDay]}!'),
          backgroundColor: const Color(0xFF2A4E7C),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final savedProvider = context.watch<SavedRecipesProvider>();
    final isSaved = savedProvider.isSaved(_detail.id);

    final hasMatchedItems = _fridgeLoaded && _getMatchedFridgeItems().isNotEmpty;

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
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                tooltip: 'Pin to Meal Plan',
                onPressed: _showPinToMealPlanDialog,
              ),
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

      // ── Bottom Action Bar (Cooking Mode + I Cooked This!) ─────────────────
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
          child: Row(
            children: [
              // "I Cooked This!" button — only when matched fridge items exist
              if (hasMatchedItems) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deducting ? null : _showDeductionDialog,
                    icon: _deducting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('🍳', style: TextStyle(fontSize: 18)),
                    label: Text(
                      _deducting ? 'Updating…' : 'I Cooked This!',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primary,
                      side: BorderSide(color: primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // "Start Cooking Mode" button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showCookingModeModal,
                  icon: const Icon(Icons.play_circle_fill),
                  label: const Text(
                    'Start Cooking Mode',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
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
          // ── Feature 2: Missing section header + "Add to Grocery" button ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Missing Ingredients (+To Buy)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addingToGrocery ? null : _addMissingToGrocery,
                icon: _addingToGrocery
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.add_shopping_cart, size: 16, color: Colors.green.shade700),
                label: Text(
                  _addingToGrocery ? 'Adding…' : 'Add All to Grocery',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _addingToGrocery ? Colors.grey : Colors.green.shade700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
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

// ── Feature 1: Cook Deduction Confirmation Dialog ────────────────────────────
class _CookDeductionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> matches;

  const _CookDeductionDialog({required this.matches});

  @override
  State<_CookDeductionDialog> createState() => _CookDeductionDialogState();
}

class _CookDeductionDialogState extends State<_CookDeductionDialog> {
  late List<bool> _selected;
  late List<int> _quantities;

  @override
  void initState() {
    super.initState();
    _selected = List.filled(widget.matches.length, true);
    _quantities = widget.matches.map((m) {
      final qty = (m['fridgeItem']['qty'] as num?)?.toInt() ?? 1;
      // Default deduction: 1 (or available qty if less)
      return qty >= 1 ? 1 : qty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final selectedCount = _selected.where((s) => s).length;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F1A2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 550, maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🍳', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'I Cooked This!',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deduct used ingredients from your fridge',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.grey),
                  onPressed: () => Navigator.pop(context, null),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white24 : Colors.grey.shade300, height: 1),
            const SizedBox(height: 12),

            // Item list
            Expanded(
              child: ListView.separated(
                itemCount: widget.matches.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final match = widget.matches[index];
                  final fridgeItem = match['fridgeItem'] as Map<String, dynamic>;
                  final ingredientName = match['ingredientName'] as String;
                  final emoji = fridgeItem['emoji']?.toString() ?? '🥗';
                  final label = fridgeItem['label']?.toString() ?? ingredientName;
                  final availableQty = (fridgeItem['qty'] as num?)?.toInt() ?? 1;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selected[index]
                          ? primary.withValues(alpha: isDark ? 0.15 : 0.06)
                          : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selected[index]
                            ? primary.withValues(alpha: 0.4)
                            : (isDark ? Colors.white10 : Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _selected[index],
                          activeColor: primary,
                          onChanged: (val) {
                            setState(() => _selected[index] = val ?? false);
                          },
                        ),
                        Text(emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Available: $availableQty',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Qty stepper
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove_circle_outline,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700, size: 20),
                              onPressed: _quantities[index] > 1
                                  ? () => setState(() => _quantities[index]--)
                                  : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                            SizedBox(
                              width: 24,
                              child: Text(
                                '${_quantities[index]}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.add_circle_outline,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700, size: 20),
                              onPressed: _quantities[index] < availableQty
                                  ? () => setState(() => _quantities[index]++)
                                  : null,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Confirm button
            ElevatedButton.icon(
              onPressed: selectedCount == 0
                  ? null
                  : () {
                      final deductions = <Map<String, dynamic>>[];
                      for (int i = 0; i < widget.matches.length; i++) {
                        if (!_selected[i]) continue;
                        final fridgeItem = widget.matches[i]['fridgeItem'] as Map<String, dynamic>;
                        final itemId = (fridgeItem['_id'] ?? fridgeItem['id'])?.toString() ?? '';
                        final label = fridgeItem['label']?.toString() ?? '';
                        deductions.add({
                          'itemId': itemId,
                          'label': label,
                          'quantityUsed': _quantities[i],
                        });
                      }
                      Navigator.pop(context, deductions);
                    },
              icon: const Text('✅', style: TextStyle(fontSize: 16)),
              label: Text(
                'Deduct $selectedCount Ingredient${selectedCount == 1 ? "" : "s"}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
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


