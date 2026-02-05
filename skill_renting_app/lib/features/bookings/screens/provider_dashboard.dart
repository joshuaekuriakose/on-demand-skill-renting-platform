import 'package:flutter/material.dart';
import '../../../core/services/auth_storage.dart';
import '../../auth/screens/login_screen.dart';
import 'provider_bookings_screen.dart';
import 'package:skill_renting_app/features/skills/screens/my_skills_screen.dart';



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

  body: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        ElevatedButton(
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

        const SizedBox(height: 16),

        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MySkillsScreen(),
              ),
            );
          },
          child: const Text("My Skills"),
        ),

      ],
    ),
  ),
);
  }
}
