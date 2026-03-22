import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'register_screen.dart';
import '../../../core/services/auth_storage.dart';
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
  bool _isLoading = false;
  bool _obscure   = true;

  @override
  void dispose() { _emailCtrl.dispose(); _passwordCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_isLoading) return;
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError("Please enter your email and password");
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.login(email, password);
      if (!mounted) return;
      if (user == null) {
        _showError("Incorrect email or password");
        return;
      }
      // Save FCM token for this account (non-admin only)
      if (user.role != "admin") {
        try {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            final savedToken = await AuthStorage.getToken();
            if (savedToken != null) {
              await ApiService.post("/users/save-token", {"token": fcmToken}, token: savedToken);
            }
          }
        } catch (_) {
          // FCM token save is best-effort — don't block login
        }
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => user.role == "admin" ? const AdminDashboard() : const MainDashboard()));
    } catch (e) {
      if (!mounted) return;
      // Show a more helpful message based on error type
      final msg = e.toString().toLowerCase();
      if (msg.contains('socketexception') || msg.contains('connection refused') ||
          msg.contains('network') || msg.contains('timeout')) {
        _showError("Cannot connect to server. Check your network.");
      } else {
        _showError("Something went wrong. Please try again.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 60),

            // Brand mark
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.secondary],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.handshake_rounded, size: 26, color: Colors.white),
            ),
            const SizedBox(height: 28),

            // Headline — "Welcome" not "Welcome back"
            Text("Welcome", style: tt.headlineMedium),
            const SizedBox(height: 6),
            Text("Sign in to continue",
                style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 36),

            // Form card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.8),
                  width: isDark ? 0.6 : 0.8),
              ),
              child: Column(children: [
                _Field(ctrl: _emailCtrl, label: "Email address",
                    icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _Field(
                  ctrl: _passwordCtrl, label: "Password",
                  icon: Icons.lock_outline_rounded, obscure: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18, color: cs.onSurfaceVariant),
                    onPressed: () => setState(() => _obscure = !_obscure)),
                ),
              ]),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity, height: 52,
              child: FilledButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                    : const Text("Sign In"),
              ),
            ),

            const SizedBox(height: 24),
            Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text("Don't have an account? ",
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, "/register"),
                child: Text("Sign up", style: tt.bodyMedium?.copyWith(
                    color: cs.primary, fontWeight: FontWeight.w600))),
            ])),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final Widget? suffix;
  final bool obscure;
  final TextInputType keyboardType;
  const _Field({required this.ctrl, required this.label, required this.icon,
      this.suffix, this.obscure = false, this.keyboardType = TextInputType.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: ctrl, obscureText: obscure, keyboardType: keyboardType,
      style: TextStyle(color: cs.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        suffixIcon: suffix,
      ),
    );
  }
}
