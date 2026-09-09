import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe_model.dart';
import '../providers/saved_recipes_provider.dart';
import '../services/recipe_service.dart';
import 'recipe_detail_screen.dart';

const List<Map<String, String>> _kCuisines = [
  {'label': 'All', 'code': 'All', 'icon': '🌐'},
  {'label': 'Indian', 'code': 'Indian', 'icon': '🇮🇳'},
  {'label': 'Mexican', 'code': 'Mexican', 'icon': '🇲🇽'},
  {'label': 'Arabian', 'code': 'Middle Eastern', 'icon': '🧆'},
  {'label': 'Italian', 'code': 'Italian', 'icon': '🇮🇹'},
  {'label': 'Asian', 'code': 'Asian', 'icon': '🥢'},
  {'label': 'American', 'code': 'American', 'icon': '🍔'},
];

class RecipeResultsScreen extends StatefulWidget {
  final List<String> ingredients;

  const RecipeResultsScreen({super.key, required this.ingredients});

  @override
  State<RecipeResultsScreen> createState() => _RecipeResultsScreenState();
}

class _RecipeResultsScreenState extends State<RecipeResultsScreen> {
  List<RecipeModel> _allRecipes = [];
  bool _loading = true;
  String? _errorMessage;
  String _selectedCuisineCode = 'All';
  int _matchTab = 0; // 0 = High Match (Left), 1 = Low Match (Right)

  @override
  void initState() {
    super.initState();
    _fetchRecipes();
  }

  Future<void> _fetchRecipes() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final results = await RecipeService.instance.searchByIngredients(
        widget.ingredients,
        cuisine: _selectedCuisineCode,
      );
      if (mounted) {
        setState(() {
          _allRecipes = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _onSelectCuisine(String code) {
    if (_selectedCuisineCode == code) return;
    setState(() {
      _selectedCuisineCode = code;
    });
    _fetchRecipes();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    // Sort all recipes by fewest missing ingredients first
    final sortedRecipes = List<RecipeModel>.from(_allRecipes)
      ..sort((a, b) => a.missedIngredientCount.compareTo(b.missedIngredientCount));

    final List<RecipeModel> strictMatches = [];
    final List<RecipeModel> otherMatches = [];

    for (final r in sortedRecipes) {
      if (r.isStrictMatch) {
        strictMatches.add(r);
      } else {
        otherMatches.add(r);
      }
    }

    // Safety fallback: If strictMatches is empty, assign top half (fewest missing items) to strictMatches
    if (strictMatches.isEmpty && sortedRecipes.isNotEmpty) {
      final mid = (sortedRecipes.length / 2).ceil();
      strictMatches.addAll(sortedRecipes.take(mid));
      otherMatches.clear();
      otherMatches.addAll(sortedRecipes.skip(mid));
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: theme.appBarTheme.foregroundColor,
        title: Text(
          'Recipe Suggestions',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: theme.appBarTheme.foregroundColor,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Active Leftovers Search Bar ────────────────────────────────────
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E2D42), const Color(0xFF131E2F)]
                    : [primary.withValues(alpha: 0.12), primary.withValues(alpha: 0.04)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.bolt, color: primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Your Input: ',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: primary),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: widget.ingredients
                          .where((ing) => !['leftover food', 'leftovers', 'leftover', 'food', 'my food'].contains(ing.toLowerCase().trim()))
                          .map((ing) {
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: primary.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            ing,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Regional Cuisines Filter Selector ─────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
            child: Text(
              'REGIONAL CUISINES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: primary,
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _kCuisines.length,
              itemBuilder: (context, index) {
                final item = _kCuisines[index];
                final code = item['code']!;
                final selected = _selectedCuisineCode == code;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    showCheckmark: false,
                    avatar: Text(item['icon']!, style: const TextStyle(fontSize: 13)),
                    label: Text(item['label']!),
                    selected: selected,
                    selectedColor: primary,
                    backgroundColor: theme.cardColor,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: selected ? primary : (isDark ? Colors.white12 : Colors.black12),
                      ),
                    ),
                    onSelected: (_) => _onSelectCuisine(code),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // ── Dual Match Section Tabs (Left: High Match | Right: Low Match) ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131E2F) : const Color(0xFFEBF1F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // Left: High Match (0 extra ingredients)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _matchTab = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _matchTab == 0
                            ? const Color(0xFF27AE60)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _matchTab == 0
                            ? const [BoxShadow(color: Colors.black12, blurRadius: 4)]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            size: 16,
                            color: _matchTab == 0 ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'High Match (${strictMatches.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _matchTab == 0 ? Colors.white : (isDark ? Colors.white60 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Right: Low Match (Requires extra ingredients like sausage, flour)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _matchTab = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: _matchTab == 1
                            ? primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _matchTab == 1
                            ? const [BoxShadow(color: Colors.black12, blurRadius: 4)]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 15,
                            color: _matchTab == 1 ? Colors.white : (isDark ? Colors.white60 : Colors.black54),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Low Match (${otherMatches.length})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _matchTab == 1 ? Colors.white : (isDark ? Colors.white60 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Recipe List View for Selected Section ─────────────────────────
          Expanded(
            child: _loading
                ? _buildLoadingState(isDark)
                : _errorMessage != null
                    ? _buildErrorState(theme, primary)
                    : _allRecipes.isEmpty
                        ? _buildEmptyState(theme)
                        : _buildTabList(
                            _matchTab == 0 ? strictMatches : otherMatches,
                            isStrictSection: _matchTab == 0,
                            theme: theme,
                            primary: primary,
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabList(
    List<RecipeModel> recipes, {
    required bool isStrictSection,
    required ThemeData theme,
    required Color primary,
  }) {
    if (recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isStrictSection ? Icons.no_food_outlined : Icons.restaurant_outlined,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                isStrictSection
                    ? 'No pure 0-extra ingredient recipes for this selection.\nTry checking the Low Match tab!'
                    : 'No recipes requiring extra ingredients.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
      children: [
        _sectionHeader(
          isStrictSection
              ? '🔥 HIGH MATCHES (COOKABLE WITH ONLY YOUR INPUT)'
              : '🛒 LOW & OTHER MATCHES (NEEDS EXTRA INGREDIENTS)',
          isStrictSection
              ? 'Dishes like Bullseye Egg, Omelette & Boiled Eggs requiring 0 extra items'
              : 'Dishes like Scotch Eggs, Egg Curry & Shakshuka requiring extra ingredients',
          isStrictSection ? const Color(0xFF27AE60) : primary,
        ),
        const SizedBox(height: 10),
        ...recipes.map(
          (r) => _ElevatedRecipeCard(
            recipe: r,
            isStrict: isStrictSection,
            onTap: () => _openDetail(r),
          ),
        ),
      ],
    );
  }

  void _openDetail(RecipeModel recipe) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, _, _) => RecipeDetailScreen(recipe: recipe),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: child,
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: 20),
          Text(
            'Filtering exact matches & regional cuisines…',
            style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : const Color(0xFF5F5E5A)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, Color primary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 54, color: Colors.orangeAccent),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchRecipes,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, size: 54, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No matching recipes found for this cuisine.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

// ── Elevated Recipe Card Component ───────────────────────────────────────────
class _ElevatedRecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final bool isStrict;
  final VoidCallback onTap;

  const _ElevatedRecipeCard({
    required this.recipe,
    required this.isStrict,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final savedProvider = context.watch<SavedRecipesProvider>();
    final isSaved = savedProvider.isSaved(recipe.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isStrict
              ? const Color(0xFF27AE60).withValues(alpha: 0.6)
              : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
          width: isStrict ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Image Header
              Stack(
                children: [
                  Hero(
                    tag: 'recipe_image_${recipe.id}',
                    child: SizedBox(
                      height: 170,
                      width: double.infinity,
                      child: recipe.image.isNotEmpty
                          ? Image.network(
                              recipe.image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _fallbackImage(primary),
                            )
                          : _fallbackImage(primary),
                    ),
                  ),

                  // Overlay Gradient
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black45, Colors.transparent, Colors.black54],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Top Left: Match Badge (Strict vs Other)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isStrict
                              ? [const Color(0xFF27AE60), const Color(0xFF1D9E75)]
                              : [const Color(0xFF2A4E7C), const Color(0xFF4A90D9)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Row(
                        children: [
                          Icon(isStrict ? Icons.star : Icons.bolt, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            isStrict ? '100% ONLY INPUT' : '${recipe.matchPercentage.toInt()}% Match',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top Right: Bookmark Button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black38,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? Colors.amber : Colors.white,
                          size: 18,
                        ),
                      ),
                      onPressed: () => savedProvider.toggleSave(recipe),
                    ),
                  ),

                  // Bottom Overlay: Prep time
                  if (recipe.readyInMinutes != null)
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${recipe.readyInMinutes} mins',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Body details
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Badges row
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF27AE60)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    recipe.usedIngredients.where((i) => !['leftover food', 'leftovers', 'leftover', 'food', 'my food'].contains(i.toLowerCase().trim())).isNotEmpty
                                        ? recipe.usedIngredients.where((i) => !['leftover food', 'leftovers', 'leftover', 'food', 'my food'].contains(i.toLowerCase().trim())).join(', ')
                                        : 'Input ingredients ready',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF27AE60)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (recipe.missedIngredientCount > 0) const SizedBox(width: 8),
                        if (recipe.missedIngredientCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${recipe.missedIngredientCount} extra',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange.shade800),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackImage(Color primary) {
    return Container(
      color: primary.withValues(alpha: 0.15),
      child: Center(child: Icon(Icons.restaurant, size: 54, color: primary)),
    );
  }
}
