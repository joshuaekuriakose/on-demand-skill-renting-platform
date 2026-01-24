import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'register_screen.dart';
import '../../../core/services/auth_storage.dart';
import '../../bookings/screens/seeker_dashboard.dart';
import '../../bookings/screens/provider_dashboard.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final user = await AuthService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;

    if (user == null) {
      setState(() {
        _error = "Invalid email or password";
        _isLoading = false;
      });
      return;
    }

    await AuthStorage.saveAuthData(user.token, user.role);

if (!mounted) return;

if (user.role == "provider") {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const ProviderDashboard()),
  );
} else {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => const SeekerDashboard()),
  );
}

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Login"),
            ),
            TextButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
      ),
    );
  },
  child: const Text("Create an account"),
),

          ],
        ),
      ),
    );
  }
}
