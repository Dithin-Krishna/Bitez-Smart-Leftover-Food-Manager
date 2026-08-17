import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/avatar_widget.dart';

/// Stores local-only user preferences (not synced to server):
///  - profile picture (local file path or food icon emoji)
///  - bitmoji avatar config / preset
///  - notifications enabled
///  - dark mode enabled
///  - avatar display toggle (flips between food icon/profile pic and avatar)
class UserPrefsProvider extends ChangeNotifier {
  static const _keyLocalAvatar    = 'local_avatar_path';
  static const _keyFoodEmoji      = 'food_emoji_avatar';
  static const _keyNotifications  = 'notifications_enabled';
  static const _keyDarkMode       = 'dark_mode_enabled';
  static const _keyAvatarIndex    = 'selected_avatar_index';
  static const _keyCustomAvatar   = 'custom_avatar_json';
  static const _keyShowAvatarMode = 'show_avatar_mode';

  String?       _localAvatarPath;
  String?       _foodEmojiAvatar;
  bool          _notificationsEnabled = true;
  bool          _darkModeEnabled      = false;
  int?          _selectedAvatarIndex;
  AvatarConfig? _customAvatarConfig;
  bool          _showAvatarMode       = false; // default false -> food icon / profile pic first

  String?       get localAvatarPath      => _localAvatarPath;
  String?       get foodEmojiAvatar      => _foodEmojiAvatar ?? '🥗'; // Default food icon if none chosen
  bool          get notificationsEnabled => _notificationsEnabled;
  bool          get darkModeEnabled      => _darkModeEnabled;
  int?          get selectedAvatarIndex  => _selectedAvatarIndex;
  AvatarConfig? get customAvatarConfig  => _customAvatarConfig;
  bool          get showAvatarMode       => _showAvatarMode;

  /// Returns true if a custom or preset avatar is configured.
  bool get hasAvatar => _customAvatarConfig != null || _selectedAvatarIndex != null;

  /// Returns the local File if set and valid, else null.
  File? get localAvatarFile {
    if (_localAvatarPath == null) return null;
    final f = File(_localAvatarPath!);
    return f.existsSync() ? f : null;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _localAvatarPath      = prefs.getString(_keyLocalAvatar);
    _foodEmojiAvatar      = prefs.getString(_keyFoodEmoji);
    _notificationsEnabled = prefs.getBool(_keyNotifications) ?? true;
    _darkModeEnabled      = prefs.getBool(_keyDarkMode)      ?? false;
    _showAvatarMode       = prefs.getBool(_keyShowAvatarMode) ?? false;
    _selectedAvatarIndex  =
        prefs.containsKey(_keyAvatarIndex) ? prefs.getInt(_keyAvatarIndex) : null;
    
    final customJsonStr = prefs.getString(_keyCustomAvatar);
    if (customJsonStr != null) {
      try {
        _customAvatarConfig = AvatarConfig.fromJson(jsonDecode(customJsonStr));
      } catch (_) {}
    }

    notifyListeners();
  }

  /// Toggle flip between Profile Picture / Food Icon and Bitmoji Avatar
  Future<void> toggleShowAvatar() async {
    _showAvatarMode = !_showAvatarMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowAvatarMode, _showAvatarMode);
    notifyListeners();
  }

  /// Set show avatar mode explicitly
  Future<void> setShowAvatarMode(bool show) async {
    _showAvatarMode = show;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowAvatarMode, show);
    notifyListeners();
  }

  Future<void> setLocalAvatar(String path) async {
    _localAvatarPath = path;
    _foodEmojiAvatar = null; // file photo overrides food emoji
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalAvatar, path);
    await prefs.remove(_keyFoodEmoji);
    notifyListeners();
  }

  Future<void> setFoodEmoji(String emoji) async {
    _foodEmojiAvatar = emoji;
    _localAvatarPath = null; // food emoji overrides file photo
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFoodEmoji, emoji);
    await prefs.remove(_keyLocalAvatar);
    notifyListeners();
  }

  /// Sets a bitmoji avatar by index into [kAvatarPresets].
  Future<void> setAvatar(int index) async {
    _selectedAvatarIndex = index;
    _customAvatarConfig  = kAvatarPresets[index.clamp(0, kAvatarPresets.length - 1)];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAvatarIndex, index);
    await prefs.setString(_keyCustomAvatar, jsonEncode(_customAvatarConfig!.toJson()));
    notifyListeners();
  }

  /// Sets a fully customized bitmoji avatar configuration.
  Future<void> setCustomAvatar(AvatarConfig config) async {
    _customAvatarConfig  = config;
    _selectedAvatarIndex = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomAvatar, jsonEncode(config.toJson()));
    await prefs.remove(_keyAvatarIndex);
    notifyListeners();
  }

  Future<void> clearAvatar() async {
    _selectedAvatarIndex = null;
    _customAvatarConfig  = null;
    _showAvatarMode      = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAvatarIndex);
    await prefs.remove(_keyCustomAvatar);
    await prefs.setBool(_keyShowAvatarMode, false);
    notifyListeners();
  }

  Future<void> clearProfilePic() async {
    _localAvatarPath = null;
    _foodEmojiAvatar = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLocalAvatar);
    await prefs.remove(_keyFoodEmoji);
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, value);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _darkModeEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, value);
    notifyListeners();
  }
}
