import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/user_prefs_provider.dart';
import '../services/food_recognition_service.dart';
import '../services/fridge_service.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/bowl_painter.dart';
import '../widgets/food_confirmation_dialog.dart';
import 'fridge_screen.dart';
import 'login_intro_screen.dart';
import 'profile_screen.dart';
import 'recipe_results_screen.dart';
import 'saved_recipes_screen.dart';
import 'chat_screen.dart';
import 'grocery_list_screen.dart';
import 'expiry_tracker_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'meal_planner_screen.dart';
import '../providers/expiry_provider.dart';

/// Main home screen: logo bar, food photo / text input, fridge shortcut,
/// bottom navigation bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();
  File? _pickedImage;
  bool _generating = false;
  bool _analyzingPhoto = false;
  List<String> _detectedItems = [];

  static const indigo = Color(0xFF2A4E7C);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().token;
      context.read<ExpiryProvider>().fetchExpiryData(token);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final token = context.read<AuthProvider>().token;
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: source, imageQuality: 80);
      if (xfile != null) {
        final file = File(xfile.path);
        setState(() {
          _pickedImage = file;
          _analyzingPhoto = true;
          _detectedItems.clear();
        });

        // Phase 2, 3, 4: Hybrid recognition pipeline
        final pipelineResults = await FoodRecognitionService.instance.recognizeFoodPipeline(file, token: token);

        if (!mounted) return;
        setState(() {
          _analyzingPhoto = false;
        });

        if (pipelineResults.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No food items detected in image. Please try taking a clearer photo of food.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Phase 5: Show User Confirmation Dialog
        final confirmedItems = await FoodConfirmationDialog.show(
          context,
          imageFile: file,
          detectedItems: pipelineResults,
        );

        if (!mounted || confirmedItems == null || confirmedItems.isEmpty) return;

        // Phase 6: Save confirmed food items to MongoDB Virtual Fridge
        final names = confirmedItems.map((c) => c.label).toList();
        setState(() {
          _detectedItems = names;
          _textController.text = names.join(', ');
        });

        if (token != null) {
          final payload = confirmedItems.map((item) => {
            'emoji': item.emoji,
            'label': item.label,
            'qty': item.qty,
            'color': 0xFF2A4E7C,
            'section': item.section,
            if (item.expiresAt != null) 'expiresAt': item.expiresAt!.toIso8601String(),
          }).toList();

          await FridgeService.instance.addBulkItems(token: token, items: payload);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Saved ${confirmedItems.length} food item${confirmedItems.length == 1 ? "" : "s"} to Virtual Fridge!'),
              backgroundColor: indigo,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _analyzingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open camera/gallery: $e')),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  static bool _isGenericNonFood(String s) {
    final lower = s.toLowerCase().trim();
    const nonFoodWords = {
      'leftover food',
      'leftovers',
      'leftover',
      'food',
      'my food',
      'waste',
      'left over',
      'left over food',
      'item',
      'items',
    };
    return nonFoodWords.contains(lower);
  }

  Future<void> _generateRecipes() async {
    final textInput = _textController.text.trim();
    if (_pickedImage == null && textInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a photo or describe what you have first')),
      );
      return;
    }

    setState(() => _generating = true);

    // Split user text by commas or spaces into ingredient items
    List<String> ingredients = [];
    if (textInput.isNotEmpty) {
      ingredients = textInput
          .split(RegExp(r'[,;\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && !_isGenericNonFood(s))
          .toList();
    }

    // If no specific ingredients parsed from text, fetch active items from Virtual Fridge
    if (ingredients.isEmpty) {
      final token = context.read<AuthProvider>().token;
      if (token != null) {
        try {
          final fridgeItems = await FridgeService.instance.getAllItems(token: token);
          if (fridgeItems.isNotEmpty) {
            ingredients = fridgeItems
                .map((i) => i['label']?.toString().trim() ?? '')
                .where((l) => l.isNotEmpty && !_isGenericNonFood(l))
                .take(6)
                .toList();
          }
        } catch (_) {}
      }
    }

    // If still empty (fridge is empty and no text provided), fallback to real staple foods
    if (ingredients.isEmpty) {
      ingredients = ['Rice', 'Vegetables', 'Eggs'];
    }

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _generating = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeResultsScreen(ingredients: ingredients),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: theme.appBarTheme.foregroundColor,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 34, height: 22, child: const CustomPaint(painter: BowlPainter())),
            const SizedBox(width: 8),
            Text(
              'BITEZ',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: theme.appBarTheme.foregroundColor,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Smart Grocery List',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GroceryListScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Chef Bitez AI Assistant',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            ),
          ),
          Builder(
            builder: (ctx) {
              final prefs = ctx.watch<UserPrefsProvider>();
              return _TopRightFlippableIcon(
                prefs: prefs,
                isDark: isDark,
                primary: primary,
                onOpenProfile: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Consumer<ExpiryProvider>(
              builder: (context, expiry, _) {
                if (!expiry.hasUrgentAlerts) return const SizedBox.shrink();
                final count = expiry.expiredCount + expiry.expiringSoonCount;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFEEBA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFF856404), size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '⚠️ Expiry Notification ($count item${count == 1 ? "" : "s"})',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF856404), fontSize: 13),
                            ),
                            Text(
                              expiry.expiredCount > 0
                                  ? '${expiry.expiredCount} item(s) expired, ${expiry.expiringSoonCount} expiring soon!'
                                  : '${expiry.expiringSoonCount} item(s) in your fridge expire within 48h.',
                              style: const TextStyle(color: Color(0xFF856404), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ExpiryTrackerScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('View', style: TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              },
            ),
            Text(
              'What have you got leftover?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Snap a photo or tell us what\'s in the fridge.',
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color ?? const Color(0xFF5F5E5A),
              ),
            ),
            const SizedBox(height: 16),

            // ── Photo input ───────────────────────────────────────────────
            GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primary.withValues(alpha: 0.35), width: 1.4),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_pickedImage != null)
                      Image.file(_pickedImage!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 36, color: primary.withValues(alpha: 0.8)),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to take photo or upload image',
                            style: TextStyle(color: primary.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    if (_pickedImage != null && !_analyzingPhoto)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _pickedImage = null;
                              _detectedItems.clear();
                              _textController.clear();
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white38, width: 1),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    if (_analyzingPhoto)
                      Container(
                        color: Colors.black.withValues(alpha: 0.65),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              const SizedBox(height: 12),
                              const Text(
                                '🔍 AI Scanning & Recognizing Food...',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (_detectedItems.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    const Chip(
                      avatar: Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                      label: Text('AI Recognized', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      backgroundColor: Color(0xFF2A4E7C),
                    ),
                    ..._detectedItems.map(
                      (item) => Chip(
                        label: Text(item, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                        backgroundColor: primary.withValues(alpha: 0.12),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () {
                          setState(() {
                            _detectedItems.remove(item);
                            _textController.text = _detectedItems.join(', ');
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            TextField(
              controller: _textController,
              maxLines: 3,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Or type what you have, e.g. "half an onion, rice, 2 eggs"',
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _generating ? null : _generateRecipes,
                icon: _generating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_generating ? 'Generating…' : 'Generate recipes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Expiry Notification Alert Banner ──────────────────────────
            Consumer<ExpiryProvider>(
              builder: (context, expiryProv, _) {
                if (!expiryProv.hasUrgentAlerts) return const SizedBox.shrink();
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExpiryTrackerScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade900, Colors.deepOrange.shade800],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notification_important, color: Colors.white, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🚨 ${expiryProv.expiringSoonCount} item(s) expiring soon!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Tap to open Expiry Tracker & save food',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Fridge, Expiry Tracker & Grocery List Shortcuts ───────────
            Row(
              children: [
                Expanded(
                  child: _ShortcutCard(
                    icon: Icons.kitchen_outlined,
                    label: 'My Fridge',
                    subtitle: 'Inventory',
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, _, _) => const FridgeScreen(),
                          transitionsBuilder: (_, anim, _, child) =>
                              FadeTransition(opacity: anim, child: child),
                          transitionDuration: const Duration(milliseconds: 350),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Consumer<ExpiryProvider>(
                    builder: (context, expProv, _) {
                      final hasAlert = expProv.expiringSoonCount > 0 || expProv.expiredCount > 0;
                      return _ShortcutCard(
                        icon: Icons.timer_outlined,
                        label: 'Expiry Vault',
                        subtitle: hasAlert ? '🚨 ${expProv.expiringSoonCount} Expiring' : 'Date Tracker',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ExpiryTrackerScreen()),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShortcutCard(
                    icon: Icons.shopping_cart_outlined,
                    label: 'Grocery',
                    subtitle: 'Restock List',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GroceryListScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Chef Bitez AI', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
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
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // Left – Saved Items
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SavedRecipesScreen()),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, color: primary, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        'Saved',
                        style: TextStyle(
                          fontSize: 11,
                          color: primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Centre – Home
              Expanded(
                child: InkWell(
                  onTap: () {},
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2A4E7C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
              ),

              // Right – Back
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_back_ios_new_rounded, color: primary, size: 22),
                      const SizedBox(height: 4),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 11,
                          color: primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme   = Theme.of(context);
    final isDark  = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final user    = context.watch<AuthProvider>().user;
    final prefs   = context.watch<UserPrefsProvider>();

    final customCfg  = prefs.customAvatarConfig;
    final avatarIdx  = prefs.selectedAvatarIndex;
    final avatarFile = prefs.localAvatarFile;
    final emoji      = prefs.foodEmojiAvatar;
    final showAvatar = prefs.showAvatarMode;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile header
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    showAvatar && (customCfg != null || avatarIdx != null)
                        ? (customCfg != null
                            ? AvatarWidget(config: customCfg, size: 52)
                            : AvatarWidget(index: avatarIdx, size: 52))
                        : CircleAvatar(
                            radius: 26,
                            backgroundColor: isDark
                                ? const Color(0xFF2A3D54)
                                : const Color(0xFFE1E8F2),
                            backgroundImage: avatarFile != null ? FileImage(avatarFile) : null,
                            child: avatarFile != null
                                ? null
                                : emoji != null
                                    ? Text(emoji, style: const TextStyle(fontSize: 24))
                                    : user?.avatarUrl != null
                                        ? ClipOval(
                                            child: Image.network(
                                              user!.avatarUrl!,
                                              width: 52,
                                              height: 52,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Icon(Icons.person, size: 28, color: primary),
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Your Name',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'View profile',
                            style: TextStyle(
                              fontSize: 13,
                              color: primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: theme.dividerColor != Colors.white12
                        ? Colors.grey
                        : Colors.white38),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),

            ListTile(
              leading: const Text('🍳', style: TextStyle(fontSize: 20)),
              title: Text('Chef Bitez AI Assistant', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('AI', style: TextStyle(fontSize: 10, color: primary, fontWeight: FontWeight.bold)),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                );
              },
            ),

            Consumer<ExpiryProvider>(
              builder: (context, expProv, _) {
                final hasAlert = expProv.expiringSoonCount > 0 || expProv.expiredCount > 0;
                return ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.orange),
                  title: Text('Expiry Tracker & Vault', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
                  trailing: hasAlert
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${expProv.expiringSoonCount + expProv.expiredCount} Alert',
                            style: TextStyle(fontSize: 10, color: Colors.red.shade900, fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExpiryTrackerScreen()),
                    );
                  },
                );
              },
            ),

            ListTile(
              leading: const Text('🌱', style: TextStyle(fontSize: 20)),
              title: Text('Waste & Savings Analytics', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AnalyticsDashboardScreen()),
                );
              },
            ),

            ListTile(
              leading: const Text('📅', style: TextStyle(fontSize: 20)),
              title: Text('Weekly Meal Planner', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MealPlannerScreen()),
                );
              },
            ),

            ListTile(
              leading: Icon(Icons.volunteer_activism_outlined, color: primary),
              title: Text('Donations', style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () => Navigator.pop(context),
            ),

            const Spacer(),
            Divider(height: 1, color: theme.dividerColor),

            ListTile(
              leading: Icon(Icons.settings_outlined, color: primary),
              title: Text('Settings', style: TextStyle(color: theme.colorScheme.onSurface)),
              onTap: () => Navigator.pop(context),
            ),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context);
                await context.read<AuthProvider>().logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginIntroScreen()),
                  (_) => false,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Flippable top-right icon component:
///  - Profile Pic / Food Icon is SHOWN FIRST.
///  - Clicking OR Swiping flips/toggles between Profile Pic / Food Icon and Avatar!
///  - Double tapping or long pressing opens ProfileScreen directly.
class _TopRightFlippableIcon extends StatelessWidget {
  final UserPrefsProvider prefs;
  final bool isDark;
  final Color primary;
  final VoidCallback onOpenProfile;

  const _TopRightFlippableIcon({
    required this.prefs,
    required this.isDark,
    required this.primary,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final customCfg  = prefs.customAvatarConfig;
    final avatarIdx  = prefs.selectedAvatarIndex;
    final avatarFile = prefs.localAvatarFile;
    final emoji      = prefs.foodEmojiAvatar;
    final showAvatar = prefs.showAvatarMode;

    // Profile Pic / Food Icon Widget (Shown First!)
    final Widget profilePicWidget = avatarFile != null
        ? CircleAvatar(
            key: const ValueKey('profile_photo'),
            radius: 15,
            backgroundImage: FileImage(avatarFile),
          )
        : emoji != null
            ? CircleAvatar(
                key: const ValueKey('profile_emoji'),
                radius: 15,
                backgroundColor: const Color(0xFFE1E8F2),
                child: Text(emoji, style: const TextStyle(fontSize: 16)),
              )
            : CircleAvatar(
                key: const ValueKey('profile_default'),
                radius: 15,
                backgroundColor: isDark
                    ? const Color(0xFF2A3D54)
                    : const Color(0xFFE1E8F2),
                child: Icon(Icons.person, size: 18, color: primary),
              );

    // Bitmoji Avatar Widget
    final Widget avatarWidget = customCfg != null
        ? AvatarWidget(
            key: ValueKey('custom_${customCfg.toJson().hashCode}'),
            config: customCfg,
            size: 30,
          )
        : avatarIdx != null
            ? AvatarWidget(
                key: ValueKey('bitmoji_$avatarIdx'),
                index: avatarIdx,
                size: 30,
              )
            : CircleAvatar(
                key: const ValueKey('avatar_default'),
                radius: 15,
                backgroundColor: isDark
                    ? const Color(0xFF2A3D54)
                    : const Color(0xFFE1E8F2),
                child: Icon(Icons.face, size: 18, color: primary),
              );

    final currentDisplay = showAvatar ? avatarWidget : profilePicWidget;

    return GestureDetector(
      onTap: () {
        // Single click flips between profile pic / food icon and avatar
        prefs.toggleShowAvatar();
      },
      onDoubleTap: onOpenProfile,
      onLongPress: onOpenProfile,
      onHorizontalDragEnd: (_) {
        // Swiping left/right flips between profile pic / food icon and avatar!
        prefs.toggleShowAvatar();
      },
      child: Tooltip(
        message: 'Tap/Swipe to flip avatar • Double tap for profile',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, anim) {
              return RotationTransition(
                turns: anim.drive(Tween(begin: 0.5, end: 1.0)),
                child: FadeTransition(opacity: anim, child: child),
              );
            },
            child: currentDisplay,
          ),
        ),
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: primary, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: theme.textTheme.bodySmall?.color ?? const Color(0xFF5F5E5A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}