import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/grocery_service.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  List<GroceryItemData> _items = [];
  bool _loading = true;
  bool _generatingAi = false;
  bool _hideCompleted = false;

  // Track collapsed categories
  final Set<String> _collapsedCategories = {};

  // Controllers for in-category quick add inputs
  final Map<String, TextEditingController> _categoryControllers = {};

  // Standard Apple-style grocery category definitions
  final List<Map<String, String>> _categoryDefs = [
    {'name': 'Bakery', 'emoji': '🥖'},
    {'name': 'Dairy & Eggs', 'emoji': '🥛'},
    {'name': 'Fruits & Vegetables', 'emoji': '🍎'},
    {'name': 'Protein & Meat', 'emoji': '🍗'},
    {'name': 'Staples & Pantry', 'emoji': '🌾'},
    {'name': 'Snacks & Beverages', 'emoji': '🥤'},
    {'name': 'Other', 'emoji': '🛒'},
  ];

  @override
  void initState() {
    super.initState();
    for (final cat in _categoryDefs) {
      _categoryControllers[cat['name']!] = TextEditingController();
    }
    _fetchItems();
  }

  @override
  void dispose() {
    for (final controller in _categoryControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchItems() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    try {
      final items = await GroceryService.instance.getGroceryList(token: token);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _generateAiSuggestions() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() => _generatingAi = true);
    try {
      final updatedList = await GroceryService.instance.generateAiSuggestions(token: token);
      if (mounted) {
        setState(() {
          _items = updatedList;
          _generatingAi = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ AI generated restock list from your Virtual Fridge!'),
            backgroundColor: Color(0xFF2A4E7C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generatingAi = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate restock list: $e')),
        );
      }
    }
  }

  Future<void> _addItemToCategory(String label, String categoryName) async {
    final text = label.trim();
    if (text.isEmpty) return;

    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final item = await GroceryService.instance.addItem(
        token: token,
        label: text,
        category: categoryName,
      );
      _categoryControllers[categoryName]?.clear();
      if (mounted) {
        setState(() {
          _items.insert(0, item);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add item: $e')),
        );
      }
    }
  }

  Future<void> _toggleBought(GroceryItemData item) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final newStatus = !item.isBought;
    setState(() {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        _items[idx] = GroceryItemData(
          id: item.id,
          label: item.label,
          emoji: item.emoji,
          qty: item.qty,
          category: item.category,
          section: item.section,
          isBought: newStatus,
          isAiSuggested: item.isAiSuggested,
          reason: item.reason,
        );
      }
    });

    try {
      await GroceryService.instance.updateItem(token: token, id: item.id, isBought: newStatus);
    } catch (_) {}
  }

  Future<void> _changeQty(GroceryItemData item, int delta) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    final newQty = item.qty + delta;
    if (newQty < 1) return;

    setState(() {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        _items[idx] = GroceryItemData(
          id: item.id,
          label: item.label,
          emoji: item.emoji,
          qty: newQty,
          category: item.category,
          section: item.section,
          isBought: item.isBought,
          isAiSuggested: item.isAiSuggested,
          reason: item.reason,
        );
      }
    });

    try {
      await GroceryService.instance.updateItem(token: token, id: item.id, qty: newQty);
    } catch (_) {}
  }

  Future<void> _deleteItem(String id) async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    setState(() {
      _items.removeWhere((i) => i.id == id);
    });

    try {
      await GroceryService.instance.deleteItem(token: token, id: id);
    } catch (_) {}
  }

  Future<void> _moveBoughtToFridge() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;

    try {
      final movedCount = await GroceryService.instance.moveBoughtToFridge(token: token);
      await _fetchItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🧊 Moved $movedCount completed item${movedCount == 1 ? "" : "s"} to Virtual Fridge!'),
            backgroundColor: const Color(0xFF2A4E7C),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to transfer items: $e')),
        );
      }
    }
  }

  /// Maps an item category string to one of our defined group names
  String _normalizeCategory(String cat) {
    final lower = cat.toLowerCase();
    if (lower.contains('bakery') || lower.contains('bread')) return 'Bakery';
    if (lower.contains('dairy') || lower.contains('egg') || lower.contains('milk')) return 'Dairy & Eggs';
    if (lower.contains('produce') || lower.contains('fruit') || lower.contains('veg')) return 'Fruits & Vegetables';
    if (lower.contains('meat') || lower.contains('seafood') || lower.contains('chicken') || lower.contains('protein')) return 'Protein & Meat';
    if (lower.contains('staple') || lower.contains('pantry') || lower.contains('grain')) return 'Staples & Pantry';
    if (lower.contains('snack') || lower.contains('drink') || lower.contains('beverage')) return 'Snacks & Beverages';
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final boughtItems = _items.where((i) => i.isBought).toList();
    final totalCount = _items.length;
    final boughtCount = boughtItems.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _generatingAi
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, color: Colors.amberAccent),
            tooltip: 'Generate AI Restock',
            onPressed: _generatingAi ? null : _generateAiSuggestions,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh List',
            onPressed: _fetchItems,
          ),
        ],
      ),
      body: Column(
        children: [
          // Apple-style Header: Groceries (Primary Theme Title) + Counter
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Groceries',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      '$totalCount',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$boughtCount Completed',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                        if (boughtCount > 0) ...[
                          Text(
                            '  •  ',
                            style: TextStyle(fontSize: 13, color: isDark ? Colors.white30 : Colors.black26),
                          ),
                          GestureDetector(
                            onTap: _moveBoughtToFridge,
                            child: Text(
                              'Clear (Move to Fridge)',
                              style: TextStyle(
                                fontSize: 13,
                                color: primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _hideCompleted = !_hideCompleted),
                      child: Text(
                        _hideCompleted ? 'Show' : 'Hide',
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
              ],
            ),
          ),

          // Categorized Lists Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                    children: _categoryDefs.map((catDef) {
                      final categoryName = catDef['name']!;
                      final categoryEmoji = catDef['emoji']!;

                      // Filter items belonging to this category
                      final categoryItems = _items.where((i) {
                        final norm = _normalizeCategory(i.category);
                        if (_hideCompleted && i.isBought) return false;
                        return norm == categoryName;
                      }).toList();

                      final isCollapsed = _collapsedCategories.contains(categoryName);

                      return _buildCategorySection(
                        categoryName: categoryName,
                        categoryEmoji: categoryEmoji,
                        items: categoryItems,
                        isCollapsed: isCollapsed,
                        isDark: isDark,
                        theme: theme,
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),

      // Bottom Bar for moving bought items to fridge
      bottomNavigationBar: boughtCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: _moveBoughtToFridge,
                  icon: const Icon(Icons.kitchen_outlined),
                  label: Text('Move $boughtCount Bought Item${boughtCount == 1 ? "" : "s"} to Virtual Fridge'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  /// Builds a single collapsible category block matching Apple Reminders
  Widget _buildCategorySection({
    required String categoryName,
    required String categoryEmoji,
    required List<GroceryItemData> items,
    required bool isCollapsed,
    required bool isDark,
    required ThemeData theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header (Title + Chevron)
        InkWell(
          onTap: () {
            setState(() {
              if (isCollapsed) {
                _collapsedCategories.remove(categoryName);
              } else {
                _collapsedCategories.add(categoryName);
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      categoryName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (items.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${items.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Icon(
                  isCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ],
            ),
          ),
        ),

        // Items in Category (if not collapsed)
        if (!isCollapsed) ...[
          ...items.map((item) => _buildGroceryItemRow(item, isDark, theme)),

          // Apple-style In-Category Quick Add Row at the bottom of each section
          _buildQuickAddRow(categoryName, isDark, theme),
        ],

        const SizedBox(height: 12),
        Divider(height: 1, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)),
        const SizedBox(height: 4),
      ],
    );
  }

  /// Single Apple Reminders item row: [◯ Checkbox] [Emoji] [Label] [AI Badge] [Qty Controls] [Delete]
  Widget _buildGroceryItemRow(GroceryItemData item, bool isDark, ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Circular Radio Checkbox
          GestureDetector(
            onTap: () => _toggleBought(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isBought ? primaryColor : Colors.transparent,
                border: Border.all(
                  color: item.isBought ? primaryColor : (isDark ? Colors.white38 : Colors.black26),
                  width: 1.5,
                ),
              ),
              child: item.isBought
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),

          // Emoji
          Text(item.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),

          // Label + Reason
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: item.isBought
                              ? (isDark ? Colors.white38 : Colors.black38)
                              : (isDark ? Colors.white : Colors.black87),
                          decoration: item.isBought ? TextDecoration.lineThrough : null,
                          decorationColor: isDark ? Colors.white38 : Colors.black38,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.isAiSuggested && !item.isBought) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '✨ AI',
                          style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                if (item.reason != null && !item.isBought) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.reason!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Qty Stepper
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () => _changeQty(item, -1),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(Icons.remove, size: 14),
                  ),
                ),
                Text(
                  '${item.qty}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                InkWell(
                  onTap: () => _changeQty(item, 1),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Icon(Icons.add, size: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),

          // Delete Action
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            color: isDark ? Colors.white30 : Colors.black26,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: () => _deleteItem(item.id),
          ),
        ],
      ),
    );
  }

  /// Apple-style Quick Add row at the bottom of each category
  Widget _buildQuickAddRow(String categoryName, bool isDark, ThemeData theme) {
    final controller = _categoryControllers[categoryName]!;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Dotted / subtle circle
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: (isDark ? Colors.white24 : Colors.black26),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.add,
              size: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(width: 12),

          // Text Field for quick adding to this category
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Add item...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white30 : Colors.black38,
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
              onSubmitted: (text) => _addItemToCategory(text, categoryName),
            ),
          ),
        ],
      ),
    );
  }
}
