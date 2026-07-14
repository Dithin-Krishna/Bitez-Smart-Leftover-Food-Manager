import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/bowl_painter.dart';
import 'fridge_screen.dart';
import 'login_intro_screen.dart';

/// Main home screen: logo bar with a side drawer (profile + navigation),
/// a food photo / text input section with a "Generate recipes" button,
/// a fridge shortcut, and a bottom navigation bar with Saved Items / Home / Back.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textController = TextEditingController();
  File? _pickedImage;
  bool _generating = false;

  static const indigo = Color(0xFF2A4E7C);

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: source, imageQuality: 80);
      if (xfile != null) {
        setState(() => _pickedImage = File(xfile.path));
      }
    } catch (e) {
      if (mounted) {
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

  Future<void> _generateRecipes() async {
    if (_pickedImage == null && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a photo or describe what you have first')),
      );
      return;
    }
    setState(() => _generating = true);
    // TODO: send _pickedImage and/or _textController.text to your
    // TensorFlow/Python recognition service + recipe recommendation API.
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _generating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recipes generated! (wire this up to your API)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7EF),
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF7EF),
        elevation: 0,
        foregroundColor: indigo,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 34, height: 22, child: const CustomPaint(painter: BowlPainter())),
            const SizedBox(width: 8),
            const Text(
              'BITEZ',
              style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1, color: indigo),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFE1E8F2),
              child: Icon(Icons.person, size: 18, color: indigo),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What have you got leftover?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'Snap a photo or tell us what\'s in the fridge.',
              style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
            ),
            const SizedBox(height: 16),

            // ---- Input section ----
            GestureDetector(
              onTap: _showImageSourceSheet,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: indigo.withOpacity(0.35), width: 1.4),
                ),
                clipBehavior: Clip.antiAlias,
                child: _pickedImage != null
                    ? Image.file(_pickedImage!, fit: BoxFit.cover, width: double.infinity)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, size: 32, color: indigo.withOpacity(0.7)),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to add a food photo',
                            style: TextStyle(color: indigo.withOpacity(0.7), fontSize: 13),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Or type what you have, e.g. "half an onion, rice, 2 eggs"',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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

            const SizedBox(height: 28),

            // ---- Fridge shortcut ----
            _ShortcutCard(
              icon: Icons.kitchen_outlined,
              label: 'My Fridge',
              subtitle: '12 items tracked',
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const FridgeScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 350),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: open the AI assistant / voice-assistant chat.
        },
        backgroundColor: indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('AI Assistant'),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
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
                    // TODO: navigate to Saved Recipes screen.
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.bookmark_border, color: Color(0xFF2A4E7C), size: 24),
                      SizedBox(height: 4),
                      Text(
                        'Saved',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2A4E7C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Center – Home (highlighted pill)
              Expanded(
                child: InkWell(
                  onTap: () {
                    // Already on home; scroll to top if needed.
                  },
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
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF2A4E7C), size: 22),
                      SizedBox(height: 4),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2A4E7C),
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
    final user = context.watch<AuthProvider>().user;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Color(0xFFE1E8F2),
                    child: Icon(Icons.person, size: 28, color: indigo),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Your Name',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          user?.email ?? 'View profile',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF5F5E5A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Donations
            ListTile(
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: const Text('Donations'),
              onTap: () => Navigator.pop(context),
            ),

            const Spacer(),
            const Divider(height: 1),

            // Settings
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => Navigator.pop(context),
            ),

            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(context); // close drawer
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A4E7C).withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF2A4E7C), size: 26),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF5F5E5A))),
          ],
        ),
      ),
    );
  }
}