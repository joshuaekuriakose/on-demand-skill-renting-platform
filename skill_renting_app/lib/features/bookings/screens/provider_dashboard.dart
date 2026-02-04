import 'package:flutter/material.dart';
import '../../../core/services/auth_storage.dart';
import '../../auth/screens/login_screen.dart';
import 'provider_bookings_screen.dart';


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
      body: Center(
  child: ElevatedButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ProviderBookingsScreen(),
        ),
      );
    },
    child: const Text("View Bookings"),
  ),
),

    );
  }
}
