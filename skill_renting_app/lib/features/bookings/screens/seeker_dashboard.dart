import 'package:flutter/material.dart';
import '../../../core/services/auth_storage.dart';
import '../../auth/screens/login_screen.dart';
import '../../skills/screens/skill_list_screen.dart';

class SeekerDashboard extends StatelessWidget {
  const SeekerDashboard({super.key});

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
        title: const Text("Seeker Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
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
                builder: (_) => const SkillListScreen(),
              ),
            );
          },
          child: const Text("Browse Skills"),
        ),
      ),
    );
  }
}
