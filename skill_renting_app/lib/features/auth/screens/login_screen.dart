import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'register_screen.dart';
import '../../../core/services/auth_storage.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import 'package:skill_renting_app/features/dashboard/main_dashboard.dart';
import 'package:skill_renting_app/features/admin/admin_dashboard.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading     = false;
  bool _obscure       = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final user = await AuthService.login(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );

      if (user == null) {
        _showError("Invalid email or password");
        return;
      }

      // Save FCM token (non-admin only)
      if (user.role != "admin") {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          final token = await AuthStorage.getToken();
          if (token != null) {
            await ApiService.post(
              "/users/save-token",
              {"token": fcmToken},
              token: token,
            );
          }
        }
      }

      if (!mounted) return;

      // Route based on role
      if (user.role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainDashboard()),
        );
      }
    } catch (e) {
      _showError("Login failed. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo / brand mark
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.handshake,
                    size: 44, color: theme.colorScheme.onPrimary),
              ),
              const SizedBox(height: 24),
              const Text("Welcome",
                  style: TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("Sign in to continue",
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 32),

              // Card
              AppCard(
                elevation: 2,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    AppTextField(
                      controller: _emailCtrl,
                      label: "Email",
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordCtrl,
                      label: "Password",
                      obscureText: _obscure,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: "Sign In",
                      onPressed: _isLoading ? null : _login,
                      isLoading: _isLoading,
                      icon: Icons.login,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, "/register"),
                child: const Text("Don't have an account? Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
