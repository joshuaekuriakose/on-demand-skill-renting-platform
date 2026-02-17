import 'package:flutter/material.dart';

import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/auth/screens/login_screen.dart';
import '../skills/screens/skill_list_screen.dart';
import '../bookings/screens/seeker_bookings_screen.dart';
import '../bookings/screens/provider_bookings_screen.dart';
import '../skills/screens/my_skills_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../notifications/screens/notification_screen.dart';
import '../notifications/notification_service.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}
class _MainDashboardState extends State<MainDashboard> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    final count = await NotificationService.fetchUnreadCount();
    if (!mounted) return;

    setState(() {
      _unreadCount = count;
    });
  }


  Future<void> _logout(BuildContext context) async {
    await AuthStorage.clear();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 4, // 4 icons in one row
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: [
            DashboardIcon(
              icon: Icons.search,
              label: "Browse",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SkillListScreen(),
                  ),
                );
              },
            ),
            DashboardIcon(
              icon: Icons.calendar_today,
              label: "Bookings",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SeekerBookingsScreen(),
                  ),
                );
              },
            ),
            DashboardIcon(
              icon: Icons.add_business,
              label: "My Skills",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MySkillsScreen(),
                  ),
                );
              },
            ),
            DashboardIcon(
              icon: Icons.list_alt,
              label: "Requests",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProviderBookingsScreen(),
                  ),
                );
              },
            ),
            DashboardIcon(
  icon: Icons.person,
  label: "Profile",
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );
  },
),
DashboardIcon(
  icon: Icons.notifications,
  label: "Alerts",
  badgeCount: _unreadCount, // 👈 connects badge
  onTap: () async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationScreen(),
      ),
    );

    _loadCount(); // refresh after returning
  },
),




          ],
        ),
      ),
    );
  }
}

class DashboardIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badgeCount; 

  const DashboardIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,

      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        child: Stack(
          children: [

            // Main icon + text
            Center(
              child: Padding(
                padding: const EdgeInsets.all(10),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    Icon(
                      icon,
                      size: 28,
                      color: Theme.of(context).primaryColor,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Badge
            if (badgeCount != null && badgeCount! > 0)
              Positioned(
                right: 6,
                top: 6,

                child: Container(
                  padding: const EdgeInsets.all(4),

                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),

                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),

                  child: Text(
                    badgeCount! > 9 ? "9+" : "$badgeCount",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

