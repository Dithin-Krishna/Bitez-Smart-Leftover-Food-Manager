import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/server_status_indicator.dart';
import 'home_screen.dart';

/// Sign-up form: name, email, age, gender, phone number, then a Sign up
/// button that takes the user straight into the home screen.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController  = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController   = TextEditingController();
  final _phoneController = TextEditingController();
  String? _gender;
  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (ApiService.connectionStatus.value != ServerConnectionStatus.connected) {
      ApiService.instance.checkHealth();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().register(
        name:     _nameController.text.trim(),
        email:    _emailController.text.trim(),
        password: _passwordController.text,
        age:      int.tryParse(_ageController.text),
        gender:   _gender,
        phone:    _phoneController.text.trim().isEmpty
                      ? null
                      : _phoneController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect to server: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7EF),
      body: SafeArea(
        child: Stack(
          children: [
            // 🚦 Connection status dot in TOP-LEFT corner
            const Positioned(
              top: 16,
              left: 20,
              child: ServerStatusIndicator(),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 64, 28, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Create your account',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Join BITEZ and start cutting food waste today.',
                        style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
                      ),
                      const SizedBox(height: 24),

                      TextFormField(
                        controller: _nameController,
                    style: const TextStyle(color: Colors.blue),
                    decoration: _fieldDecoration('Full name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.blue),
                    decoration: _fieldDecoration('Email'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter your email';
                      if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.blue),
                    decoration: _fieldDecoration(
                      'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a password';
                      if (v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.blue),
                          decoration: _fieldDecoration('Age'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            final age = int.tryParse(v);
                            if (age == null || age <= 0 || age > 120) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _gender,
                          style: const TextStyle(color: Colors.blue, fontSize: 16),
                          decoration: _fieldDecoration('Gender'),
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
                          validator: (v) => v == null ? 'Select one' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: Colors.blue),
                    decoration: _fieldDecoration('Phone number'),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Enter your number';
                      if (v.trim().length < 7) return 'Enter a valid number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  ValueListenableBuilder<ServerConnectionStatus>(
                    valueListenable: ApiService.connectionStatus,
                    builder: (context, status, _) {
                      final isConnected = status == ServerConnectionStatus.connected;
                      final isConnecting = status == ServerConnectionStatus.connecting;

                      VoidCallback? onPressed;
                      String buttonLabel = 'Sign up';
                      Color buttonColor = const Color(0xFF2A4E7C);

                      if (_loading) {
                        onPressed = null;
                      } else if (isConnected) {
                        onPressed = _submit;
                        buttonLabel = 'Sign up';
                        buttonColor = const Color(0xFF2A4E7C);
                      } else if (isConnecting) {
                        onPressed = () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⏳ Connecting to server on Render... Please wait a few seconds.'),
                              backgroundColor: Color(0xFFD97706),
                            ),
                          );
                        };
                        buttonLabel = 'Connecting to server...';
                        buttonColor = const Color(0xFFD97706);
                      } else {
                        onPressed = () {
                          ApiService.instance.checkHealth();
                        };
                        buttonLabel = 'Server Offline - Tap to Retry';
                        buttonColor = const Color(0xFFDC2626);
                      }

                      return ElevatedButton(
                        onPressed: onPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: buttonColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isConnecting) ...[
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(buttonLabel),
                                ],
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)),
                          children: [
                            TextSpan(
                              text: 'Log in',
                              style: TextStyle(
                                color: Color(0xFF185FA5),
                                fontWeight: FontWeight.w500,
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
          ),
        ),
      ],
    ),
  ),
);
  }

  InputDecoration _fieldDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      suffixIcon: suffixIcon,
    );
  }
}