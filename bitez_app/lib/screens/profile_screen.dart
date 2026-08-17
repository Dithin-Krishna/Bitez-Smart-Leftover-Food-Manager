import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/user_prefs_provider.dart';
import '../services/api_service.dart';
import '../widgets/avatar_widget.dart';

const List<String> _kFoodEmojis = [
  '🍕', '🍔', '🌮', '🌯', '🥗', '🍣', '🍜', '🍛',
  '🥘', '🍲', '🥙', '🌽', '🥑', '🍇', '🍓', '🍉',
  '🍎', '🍋', '🥝', '🍒', '🧁', '🍩', '🍦', '🥞',
  '🧆', '🍤', '🥚', '🧀', '🥕', '🫑',
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _phoneCtrl;
  String? _gender;
  bool _loading = false;

  // Tab controller for Edit Profile / Settings sections
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.name ?? '');
    _ageCtrl = TextEditingController(text: user?.age?.toString() ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _gender = user?.gender;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Profile picture picker ─────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: source, imageQuality: 80);
      if (xfile != null && mounted) {
        await context.read<UserPrefsProvider>().setLocalAvatar(xfile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open picker: $e')),
        );
      }
    }
  }

  // ── Show Full Avatar Customizer & Picker Sheet ─────────────────────────────
  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ComprehensiveAvatarSheet(
        onPickCamera: () {
          Navigator.pop(ctx);
          _pickImage(ImageSource.camera);
        },
        onPickGallery: () {
          Navigator.pop(ctx);
          _pickImage(ImageSource.gallery);
        },
        onPickEmoji: (emoji) {
          Navigator.pop(ctx);
          context.read<UserPrefsProvider>().setFoodEmoji(emoji);
        },
        onPickPresetIndex: (index) {
          Navigator.pop(ctx);
          context.read<UserPrefsProvider>().setAvatar(index);
        },
        onSaveCustomConfig: (config) {
          Navigator.pop(ctx);
          context.read<UserPrefsProvider>().setCustomAvatar(config);
        },
        onClear: () {
          Navigator.pop(ctx);
          context.read<UserPrefsProvider>().clearAvatar();
        },
      ),
    );
  }

  // ── Save profile ───────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().updateProfile(
        name: _nameCtrl.text.trim(),
        age: int.tryParse(_ageCtrl.text),
        gender: _gender,
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to server.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.watch<AuthProvider>().user;
    final prefs = context.watch<UserPrefsProvider>();

    final customCfg = prefs.customAvatarConfig;
    final avatarIdx = prefs.selectedAvatarIndex;
    final avatarFile = prefs.localAvatarFile;
    final emoji = prefs.foodEmojiAvatar;

    final displayName = user?.name ?? 'My Profile';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        foregroundColor: theme.appBarTheme.foregroundColor,
        title: Text(
          displayName,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: theme.appBarTheme.foregroundColor,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Profile Header Card ────────────────────────────────────────────
          _buildProfileHeader(
            user,
            prefs,
            customCfg,
            avatarIdx,
            avatarFile,
            emoji,
            theme,
            isDark,
          ),

          // ── Tab bar ───────────────────────────────────────────────────────
          Container(
            color: theme.cardColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [
                Tab(text: 'Edit Profile'),
                Tab(text: 'Settings'),
              ],
            ),
          ),

          // ── Tab views ─────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEditProfileTab(theme, isDark),
                _buildSettingsTab(prefs, theme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile header with avatar ─────────────────────────────────────────────
  Widget _buildProfileHeader(
    UserModel? user,
    UserPrefsProvider prefs,
    AvatarConfig? customCfg,
    int? avatarIdx,
    File? avatarFile,
    String? emoji,
    ThemeData theme,
    bool isDark,
  ) {
    final primary = theme.colorScheme.primary;

    return Container(
      color: theme.cardColor,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Row(
        children: [
          // Avatar with edit button (shown first as food icon/profile pic, flippable on tap/swipe)
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: () {
                  context.read<UserPrefsProvider>().toggleShowAvatar();
                },
                onHorizontalDragEnd: (_) {
                  context.read<UserPrefsProvider>().toggleShowAvatar();
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) {
                    return RotationTransition(
                      turns: anim.drive(Tween(begin: 0.5, end: 1.0)),
                      child: FadeTransition(opacity: anim, child: child),
                    );
                  },
                  child: prefs.showAvatarMode && (customCfg != null || avatarIdx != null)
                      ? (customCfg != null
                          ? AvatarWidget(key: ValueKey('custom_${customCfg.toJson().hashCode}'), config: customCfg, size: 84)
                          : AvatarWidget(key: ValueKey('bitmoji_$avatarIdx'), index: avatarIdx, size: 84))
                      : CircleAvatar(
                          key: const ValueKey('profile_pic_circle'),
                          radius: 42,
                          backgroundColor: isDark ? const Color(0xFF2A3D54) : const Color(0xFFE1E8F2),
                          backgroundImage: avatarFile != null ? FileImage(avatarFile) : null,
                          child: avatarFile != null
                              ? null
                              : emoji != null
                                  ? Text(emoji, style: const TextStyle(fontSize: 38))
                                  : user?.avatarUrl != null
                                      ? ClipOval(
                                          child: Image.network(
                                            user!.avatarUrl!,
                                            width: 84,
                                            height: 84,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Icon(Icons.person, size: 44, color: primary),
                        ),
                ),
              ),
              GestureDetector(
                onTap: _showAvatarOptions,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.cardColor, width: 2),
                  ),
                  child: const Icon(Icons.edit, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Name & email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? 'Your Name',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF5F5E5A),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _showAvatarOptions,
                  child: Text(
                    'Change photo',
                    style: TextStyle(
                      fontSize: 12,
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit Profile tab ───────────────────────────────────────────────────────
  Widget _buildEditProfileTab(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Full Name (above)
            _fieldLabel('Full Name', theme),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: _fieldDecoration('Enter your name', theme, isDark),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            // 2. Email Address (under Full Name)
            _fieldLabel('Email Address', theme),
            const SizedBox(height: 6),
            TextFormField(
              initialValue: context.read<AuthProvider>().user?.email ?? '',
              readOnly: true,
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
              decoration: _fieldDecoration('', theme, isDark).copyWith(
                fillColor: isDark ? const Color(0xFF131E2F) : Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 16),

            // Age + Gender row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Age', theme),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: _fieldDecoration('Age', theme, isDark),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final age = int.tryParse(v);
                          if (age == null || age <= 0 || age > 120) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Gender', theme),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        dropdownColor: theme.cardColor,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: _fieldDecoration('Gender', theme, isDark),
                        items: const [
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                          DropdownMenuItem(
                            value: 'Prefer not to say',
                            child: Text('Prefer not to say'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _gender = v),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Phone
            _fieldLabel('Phone Number', theme),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: _fieldDecoration('Enter your phone number', theme, isDark),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _loading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Settings tab ──────────────────────────────────────────────────────────
  Widget _buildSettingsTab(UserPrefsProvider prefs, ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // ── Notifications section ──────────────────────────────────────────
        _sectionHeader('Notifications', primary),
        SwitchListTile(
          secondary: Icon(Icons.notifications_outlined, color: primary),
          title: Text('Push Notifications',
              style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
          subtitle: Text('Receive alerts for expiry & recipe tips',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
          value: prefs.notificationsEnabled,
          activeThumbColor: primary,
          onChanged: (v) => prefs.setNotifications(v),
        ),

        Divider(indent: 16, endIndent: 16, color: theme.dividerColor),

        // ── Appearance section (Dark / Light Mode) ─────────────────────────
        _sectionHeader('Appearance', primary),
        SwitchListTile(
          secondary: Icon(
            prefs.darkModeEnabled ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: primary,
          ),
          title: Text('Dark Mode',
              style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
          subtitle: Text(
            prefs.darkModeEnabled ? 'Dark theme enabled' : 'Light theme enabled',
            style: TextStyle(color: isDark ? Colors.white60 : Colors.black54),
          ),
          value: prefs.darkModeEnabled,
          activeThumbColor: primary,
          onChanged: (v) => prefs.setDarkMode(v),
        ),

        Divider(indent: 16, endIndent: 16, color: theme.dividerColor),

        // ── Avatar section ─────────────────────────────────────────────────
        _sectionHeader('Avatar', primary),
        ListTile(
          leading: Icon(Icons.face_outlined, color: primary),
          title: Text('Choose avatar',
              style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
          subtitle: Text('Customize avatar, choose preset, upload photo or pick food emoji',
              style: TextStyle(color: isDark ? Colors.white60 : Colors.black54)),
          trailing: Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.grey),
          onTap: _showAvatarOptions,
        ),
        if (prefs.customAvatarConfig != null ||
            prefs.selectedAvatarIndex != null ||
            prefs.localAvatarFile != null ||
            prefs.foodEmojiAvatar != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextButton.icon(
              onPressed: () => prefs.clearAvatar(),
              icon: const Icon(Icons.clear, size: 16, color: Colors.redAccent),
              label: const Text('Reset avatar to default',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: primary,
        ),
      ),
    );
  }

  Widget _fieldLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint, ThemeData theme, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
      filled: true,
      fillColor: theme.cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? const Color(0xFF2A3D54) : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: theme.colorScheme.primary),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

// ── Comprehensive Avatar Customizer Sheet ──────────────────────────────────
class _ComprehensiveAvatarSheet extends StatefulWidget {
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final ValueChanged<String> onPickEmoji;
  final ValueChanged<int> onPickPresetIndex;
  final ValueChanged<AvatarConfig> onSaveCustomConfig;
  final VoidCallback onClear;

  const _ComprehensiveAvatarSheet({
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onPickEmoji,
    required this.onPickPresetIndex,
    required this.onSaveCustomConfig,
    required this.onClear,
  });

  @override
  State<_ComprehensiveAvatarSheet> createState() =>
      __ComprehensiveAvatarSheetState();
}

class __ComprehensiveAvatarSheetState
    extends State<_ComprehensiveAvatarSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Custom avatar builder state
  late bool _isBoy;
  late Color _skinTone;
  late Color _hairColor;
  late Color _shirtColor;
  late int _hairStyle;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final currentCfg =
        context.read<UserPrefsProvider>().customAvatarConfig ?? kAvatarPresets[0];
    _isBoy = currentCfg.isBoy;
    _skinTone = currentCfg.skinTone;
    _hairColor = currentCfg.hairColor;
    _shirtColor = currentCfg.shirtColor;
    _hairStyle = currentCfg.hairStyle;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  AvatarConfig get _currentCustomConfig => AvatarConfig(
        isBoy: _isBoy,
        skinTone: _skinTone,
        hairColor: _hairColor,
        shirtColor: _shirtColor,
        hairStyle: _hairStyle,
        label: 'My Custom Avatar',
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Text(
                  'Choose & Customize Avatar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),

              // Tab bar: Builder | Presets | Photo & Emoji
              TabBar(
                controller: _tabController,
                indicatorColor: primary,
                labelColor: primary,
                unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: const [
                  Tab(text: 'Builder 🎨'),
                  Tab(text: 'Presets 👦👧'),
                  Tab(text: 'Photo & Emoji 📷'),
                ],
              ),
              Divider(height: 1, color: theme.dividerColor),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Custom Avatar Builder (Select each feature!)
                    _buildBuilderTab(theme, isDark, primary, scrollCtrl),

                    // Tab 2: Presets Grid
                    _buildPresetsTab(theme, isDark, primary, scrollCtrl),

                    // Tab 3: Photo Upload & Food Emojis
                    _buildPhotoAndEmojiTab(theme, isDark, primary, scrollCtrl),
                  ],
                ),
              ),

              Divider(height: 1, color: theme.dividerColor),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextButton.icon(
                  onPressed: widget.onClear,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  label: const Text(
                    'Remove / Reset Avatar',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Builder Tab (Select each feature interactively!) ───────────────────────
  Widget _buildBuilderTab(
    ThemeData theme,
    bool isDark,
    Color primary,
    ScrollController scrollCtrl,
  ) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      children: [
        // Live Preview
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: primary, width: 3),
                ),
                child: AvatarWidget(
                  config: _currentCustomConfig,
                  size: 90,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Live Avatar Preview',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Gender Selection
        _builderSectionTitle('1. GENDER / MODEL', primary),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Boy 👦')),
                selected: _isBoy,
                selectedColor: primary,
                labelStyle: TextStyle(
                  color: _isBoy ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (val) {
                  if (val) setState(() => _isBoy = true);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: const Center(child: Text('Girl 👧')),
                selected: !_isBoy,
                selectedColor: primary,
                labelStyle: TextStyle(
                  color: !_isBoy ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (val) {
                  if (val) setState(() => _isBoy = false);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Hair Style
        _builderSectionTitle('2. HAIR STYLE', primary),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Center(
                  child: Text(_isBoy ? 'Neat Dome 👦' : 'Long Hair 👩'),
                ),
                selected: _hairStyle == 0,
                selectedColor: primary,
                labelStyle: TextStyle(
                  color: _hairStyle == 0 ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (val) {
                  if (val) setState(() => _hairStyle = 0);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChoiceChip(
                label: Center(
                  child: Text(_isBoy ? 'Spiky ⚡' : 'Cute Bun 👱‍♀️'),
                ),
                selected: _hairStyle == 1,
                selectedColor: primary,
                labelStyle: TextStyle(
                  color: _hairStyle == 1 ? Colors.white : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (val) {
                  if (val) setState(() => _hairStyle = 1);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Skin Tone
        _builderSectionTitle('3. SKIN TONE', primary),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: AvatarOptions.skinTones.map((c) {
              final isSel = _skinTone == c;
              return GestureDetector(
                onTap: () => setState(() => _skinTone = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? primary : Colors.black26,
                      width: isSel ? 3.5 : 1,
                    ),
                  ),
                  child: isSel
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // 4. Hair Color
        _builderSectionTitle('4. HAIR COLOR', primary),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: AvatarOptions.hairColors.map((c) {
              final isSel = _hairColor == c;
              return GestureDetector(
                onTap: () => setState(() => _hairColor = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? primary : Colors.black26,
                      width: isSel ? 3.5 : 1,
                    ),
                  ),
                  child: isSel
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // 5. Shirt Color
        _builderSectionTitle('5. SHIRT COLOR', primary),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: AvatarOptions.shirtColors.map((c) {
              final isSel = _shirtColor == c;
              return GestureDetector(
                onTap: () => setState(() => _shirtColor = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? primary : Colors.black26,
                      width: isSel ? 3.5 : 1,
                    ),
                  ),
                  child: isSel
                      ? const Icon(Icons.check, size: 20, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),

        // Save Custom Avatar Button
        ElevatedButton.icon(
          onPressed: () => widget.onSaveCustomConfig(_currentCustomConfig),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Use Custom Avatar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  // ── Presets Tab ────────────────────────────────────────────────────────────
  Widget _buildPresetsTab(
    ThemeData theme,
    bool isDark,
    Color primary,
    ScrollController scrollCtrl,
  ) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      children: [
        _builderSectionTitle('CUTE BOYS', primary),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: 6,
          itemBuilder: (ctx, i) {
            return _AvatarItemCard(
              index: i,
              theme: theme,
              isDark: isDark,
              onTap: () => widget.onPickPresetIndex(i),
            );
          },
        ),
        const SizedBox(height: 16),

        _builderSectionTitle('CUTE GIRLS', primary),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: 6,
          itemBuilder: (ctx, i) {
            final idx = i + 6;
            return _AvatarItemCard(
              index: idx,
              theme: theme,
              isDark: isDark,
              onTap: () => widget.onPickPresetIndex(idx),
            );
          },
        ),
      ],
    );
  }

  // ── Photo & Food Emoji Tab ─────────────────────────────────────────────────
  Widget _buildPhotoAndEmojiTab(
    ThemeData theme,
    bool isDark,
    Color primary,
    ScrollController scrollCtrl,
  ) {
    return ListView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(16),
      children: [
        _builderSectionTitle('UPLOAD PHOTO', primary),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: widget.onPickCamera,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131E2F) : const Color(0xFFF4F7FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.camera_alt_outlined, color: primary, size: 28),
                      const SizedBox(height: 6),
                      Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: widget.onPickGallery,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131E2F) : const Color(0xFFF4F7FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.photo_library_outlined, color: primary, size: 28),
                      const SizedBox(height: 6),
                      Text('Choose Gallery', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _builderSectionTitle('FOOD EMOJI AVATARS', primary),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _kFoodEmojis.length,
          itemBuilder: (ctx, i) {
            final emoji = _kFoodEmojis[i];
            return GestureDetector(
              onTap: () => widget.onPickEmoji(emoji),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131E2F) : const Color(0xFFE1E8F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  emoji,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _builderSectionTitle(String title, Color primary) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
        color: primary,
      ),
    );
  }
}

class _AvatarItemCard extends StatelessWidget {
  final int index;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onTap;

  const _AvatarItemCard({
    required this.index,
    required this.theme,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = kAvatarPresets[index];
    final selected = context.watch<UserPrefsProvider>().selectedAvatarIndex == index;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131E2F) : const Color(0xFFF4F7FA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : (isDark ? Colors.white12 : Colors.black12),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AvatarWidget(index: index, size: 54),
            const SizedBox(height: 6),
            Text(
              cfg.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
