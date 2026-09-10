import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/meal_plan_model.dart';
import '../providers/auth_provider.dart';
import '../services/meal_planner_service.dart';
import 'grocery_list_screen.dart';

/// Screen displaying the Monday–Sunday Weekly Meal Planner,
/// pinning recipes to days, and generating consolidated grocery lists.
class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  final List<String> _days = const [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  String _selectedDay = 'monday';
  WeeklyMealPlan? _plan;
  bool _loading = true;
  bool _generatingGrocery = false;

  @override
  void initState() {
    super.initState();
    _loadMealPlan();
  }

  Future<void> _loadMealPlan() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final plan = await MealPlannerService.instance.getWeeklyMealPlan(token);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _unpinMeal(MealPlanItem item) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      await MealPlannerService.instance.unpinRecipe(token: token, id: item.id);
      await _loadMealPlan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${item.recipeTitle} from meal plan'),
            backgroundColor: const Color(0xFF2A4E7C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showAddMealDialog() async {
    final titleCtrl = TextEditingController();
    final ingredientsCtrl = TextEditingController();
    String mealType = 'dinner';
    int cookTime = 25;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF16253D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Pin Meal for ${_capitalize(_selectedDay)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Recipe / Meal Name',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'e.g. Scrambled Eggs & Toast',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ingredientsCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Ingredients (comma-separated)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'e.g. 2 eggs, butter, bread, salt',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Meal Type:', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: mealType,
                        dropdownColor: const Color(0xFF16253D),
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
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A4E7C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  if (title.isEmpty) return;

                  final rawIng = ingredientsCtrl.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  final messenger = ScaffoldMessenger.of(context);
                  final token = context.read<AuthProvider>().token;
                  if (token == null) return;

                  Navigator.pop(ctx);

                  try {
                    await MealPlannerService.instance.pinRecipe(
                      token: token,
                      dayOfWeek: _selectedDay,
                      recipeTitle: title,
                      ingredients: rawIng,
                      cookTime: cookTime,
                      mealType: mealType,
                    );
                    await _loadMealPlan();
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Failed to pin: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                child: const Text('Pin Meal'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _generateConsolidatedGrocery() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _generatingGrocery = true);

    try {
      final res = await MealPlannerService.instance.generateConsolidatedGroceryList(token: token);
      final count = res['count'] as int? ?? 0;

      if (!mounted) return;
      setState(() => _generatingGrocery = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF16253D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('🛒', style: TextStyle(fontSize: 22)),
              SizedBox(width: 8),
              Text(
                'Consolidated Grocery',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: Text(
            count > 0
                ? 'Added or updated $count ingredients across your planned meals into your grocery list!'
                : 'No missing ingredients found in your meal plan for this week.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done', style: TextStyle(color: Colors.grey)),
            ),
            if (count > 0)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A4E7C),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GroceryListScreen()),
                  );
                },
                child: const Text('View Grocery List'),
              ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _generatingGrocery = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate grocery: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _capitalize(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final plan = _plan ?? WeeklyMealPlan.empty();
    final dayMeals = plan.days[_selectedDay] ?? [];

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
          'Weekly Meal Planner',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadMealPlan,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A90C4)))
          : Column(
              children: [
                // ── Day Selector (Monday – Sunday) ───────────────────────────
                _buildDaySelector(plan),

                const SizedBox(height: 12),

                // ── Consolidated Grocery List Banner ─────────────────────────
                _buildGroceryActionBanner(plan),

                const SizedBox(height: 12),

                // ── Active Day Meals List ────────────────────────────────────
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_capitalize(_selectedDay)}\'s Menu',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showAddMealDialog,
                            icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF4A90C4)),
                            label: const Text('Add Meal', style: TextStyle(color: Color(0xFF4A90C4), fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (dayMeals.isEmpty)
                        _buildEmptyDayCard()
                      else
                        ...dayMeals.map(_buildMealCard),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDaySelector(WeeklyMealPlan plan) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          final isSelected = day == _selectedDay;
          final count = plan.days[day]?.length ?? 0;
          final shortName = day.substring(0, 3).toUpperCase();

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: Container(
              width: 50,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2A4E7C) : const Color(0xFF16253D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? const Color(0xFF4A90C4) : Colors.white10,
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shortName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white24 : const Color(0xFF4A90C4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroceryActionBanner(WeeklyMealPlan plan) {
    final ingCount = plan.allConsolidatedIngredients.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B3A60), Color(0xFF152A47)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4A90C4).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Text('🛒', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weekly Consolidated Grocery',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    ingCount > 0 ? '$ingCount ingredients needed this week' : 'No meals planned yet',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: (_generatingGrocery || ingCount == 0) ? null : _generateConsolidatedGrocery,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90C4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _generatingGrocery
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Add to List', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(MealPlanItem meal) {
    final mealEmoji = {
      'breakfast': '🥞',
      'lunch': '🥪',
      'dinner': '🍽️',
      'snack': '🍎',
    }[meal.mealType] ?? '🍽️';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16253D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 54,
              height: 54,
              color: const Color(0xFF2A4E7C).withValues(alpha: 0.3),
              child: Center(
                child: Text(mealEmoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.recipeTitle,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _capitalize(meal.mealType),
                        style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '⏱️ ${meal.cookTime} min',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${meal.ingredients.length} items',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
                if (meal.ingredients.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meal.ingredients.join(', '),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // Unpin button
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
            tooltip: 'Unpin meal',
            onPressed: () => _unpinMeal(meal),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDayCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF16253D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Center(
        child: Column(
          children: [
            const Text('📅', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              'No meals planned for ${_capitalize(_selectedDay)}',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap "Add Meal" to plan your breakfast, lunch, or dinner!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
