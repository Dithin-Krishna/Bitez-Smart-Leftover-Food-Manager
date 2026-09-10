import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/user_prefs_provider.dart';
import 'providers/saved_recipes_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/expiry_provider.dart';
import 'screens/login_intro_screen.dart';
import 'screens/home_screen.dart';
import 'services/offline_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await OfflineStorageService.instance.init();
  } catch (e) {
    debugPrint('Failed to initialize offline storage: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserPrefsProvider()),
        ChangeNotifierProvider(create: (_) => SavedRecipesProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ExpiryProvider()),
      ],
      child: const BitezApp(),
    ),
  );
}

class BitezApp extends StatelessWidget {
  const BitezApp({super.key});

  // ── Light theme ────────────────────────────────────────────────────────────
  static final _lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFFBF7EF),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2A4E7C),
    ).copyWith(primary: const Color(0xFF2A4E7C)),
    cardColor: Colors.white,
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFBF7EF),
      foregroundColor: Color(0xFF2A4E7C),
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFF2A4E7C),
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'Roboto',
      ),
      iconTheme: IconThemeData(color: Color(0xFF2A4E7C)),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
    dividerColor: Colors.black12,
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF2A4E7C),
    ),
  );

  // ── Dark theme ─────────────────────────────────────────────────────────────
  static final _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F1826),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A90D9),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF6BAED6),
      surface: const Color(0xFF1A2433),
      onSurface: Colors.white,
    ),
    cardColor: const Color(0xFF1A2433),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F1826),
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        fontFamily: 'Roboto',
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF131E2F)),
    dividerColor: Colors.white12,
    listTileTheme: const ListTileThemeData(
      textColor: Colors.white,
      iconColor: Color(0xFF6BAED6),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      bodySmall: TextStyle(color: Colors.white60),
      titleLarge: TextStyle(color: Colors.white),
      titleMedium: TextStyle(color: Colors.white),
      titleSmall: TextStyle(color: Colors.white),
      labelLarge: TextStyle(color: Colors.white),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF6BAED6)
            : null,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF6BAED6).withValues(alpha: 0.5)
            : null,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1A2433),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2A3D54)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2A3D54)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<UserPrefsProvider>();
    return MaterialApp(
      title: 'BITEZ',
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
      themeMode: prefs.darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      home: const _AppRoot(),
    );
  }
}

/// Attempts auto-login on startup; shows home if already logged in,
/// otherwise falls through to the intro / login screen.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    await Future.wait([
      context.read<AuthProvider>().tryAutoLogin(),
      context.read<UserPrefsProvider>().load(),
      context.read<SavedRecipesProvider>().loadSavedRecipes(),
    ]);
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    return isLoggedIn ? const HomeScreen() : const LoginIntroScreen();
  }
}