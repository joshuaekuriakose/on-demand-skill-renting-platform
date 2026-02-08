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
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [

      // Welcome Card
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome 👋",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text("Manage your skills and bookings"),
            ],
          ),
        ),
      ),

      const SizedBox(height: 20),

      // View Bookings
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.book_online),
          ),
          title: const Text("View Bookings"),
          subtitle: const Text("Manage customer requests"),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProviderBookingsScreen(),
              ),
            );
          },
        ),
      ),

      const SizedBox(height: 16),

      // My Skills
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: const CircleAvatar(
            child: Icon(Icons.build),
          ),
          title: const Text("My Skills"),
          subtitle: const Text("View and manage your services"),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MySkillsScreen(),
              ),
            );
          },
        ),
      ),
    ],
  ),
),

);
  }
}
