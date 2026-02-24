import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'register_screen.dart';
import '../../../core/services/auth_storage.dart';
//import '../../bookings/screens/seeker_dashboard.dart';
//import '../../bookings/screens/provider_dashboard.dart';
import 'package:skill_renting_app/features/dashboard/main_dashboard.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
  if (_isLoading) return;

  FocusScope.of(context).unfocus();

  setState(() => _isLoading = true);

  try {
    final user = await AuthService.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (user == null) {
      _showError("Invalid email or password");
      return;
    }

    // Save FCM token
    final fcmToken = await FirebaseMessaging.instance.getToken();

    if (fcmToken != null) {
      final token = await AuthStorage.getToken();

      if (token != null) {
        await ApiService.post(
          "/users/save-token",
          {
            "token": fcmToken,
          },
          token: token,
        );
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const MainDashboard(),
      ),
    );

  } catch (e) {
    _showError("Login failed. Try again.");
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Center(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            const Icon(
              Icons.lock_outline,
              size: 60,
              color: Colors.indigo,
            ),

            const SizedBox(height: 16),

            const Text(
              "Welcome Back",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              "Login to continue",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 24),

            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                prefixIcon: Icon(Icons.email),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Password",
                prefixIcon: Icon(Icons.lock),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Login"),
            ),

            const SizedBox(height: 16),

            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, "/register");
              },
              child: const Text("Create an account"),
            ),
          ],
        ),
      ),
    ),
  ),
),

    );
  }
  void _showError(String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ),
  );
}
}
