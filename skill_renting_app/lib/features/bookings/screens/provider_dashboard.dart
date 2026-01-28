import 'package:flutter/material.dart';
import '../../../core/services/auth_storage.dart';
import '../../auth/screens/login_screen.dart';

class ProviderDashboard extends StatelessWidget {
  const ProviderDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthStorage.clear();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Provider Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: const Center(
        child: Text("Welcome, Provider"),
      ),
    );
  }
}
