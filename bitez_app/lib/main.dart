import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_intro_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const BitezApp(),
    ),
  );
}

class BitezApp extends StatelessWidget {
  const BitezApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BITEZ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F6F1),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D9E75),
        ),
        fontFamily: 'Roboto',
      ),
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
    await context.read<AuthProvider>().tryAutoLogin();
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F6F1),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    return isLoggedIn ? const HomeScreen() : const LoginIntroScreen();
  }
}