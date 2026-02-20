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
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:skill_renting_app/core/services/api_service.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {

  String _getGreeting() {
  final hour = DateTime.now().hour;

  if (hour < 12) {
    return "Good Morning";
  } else if (hour < 17) {
    return "Good Afternoon";
  } else {
    return "Good Evening";
  }
}

String _userName = "";

@override
void initState() {
  super.initState();
  _loadCount();
  _loadUserName();
}

  int _unreadCount = 0;

  Future<void> _logout(BuildContext context) async {
    await AuthStorage.clear();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

Future<void> _loadUserName() async {
  final name = await AuthStorage.getName();
  if (name != null) {
    setState(() {
      _userName = name;
    });
  }
}

  Future<void> _loadCount() async {
  try {
    final response = await ApiService.get("/notifications/unread-count");

    if (response["statusCode"] == 200) {
      setState(() {
        _unreadCount = response["data"]["count"];
      });
    }
  } catch (e) {
    debugPrint("Notification count error: $e");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  centerTitle: true,
  title: const Text("Home"),

  // 👈 Profile on Left
  leading: IconButton(
    icon: const Icon(Icons.person),
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        ),
      );
    },
  ),

  // 👉 Right Side Icons
  actions: [

    // Logout (move here)
    IconButton(
      icon: const Icon(Icons.logout),
      onPressed: () => _logout(context),
    ),

    // Notifications (keep existing logic)
    Stack(
      alignment: Alignment.center,
      children: [

        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationScreen(),
              ),
            );

            _loadCount(); // refresh badge
          },
        ),

        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _unreadCount > 9 ? "9+" : "$_unreadCount",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    ),
  ],
),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // ================= HERO =================
              _buildHeroSection(context),

              const SizedBox(height: 24),

              // ============== FEATURED ================
              _buildFeaturedSection(),

              const SizedBox(height: 24),

              // ============== ACTIVITY =================
              _buildActivitySection(),

              const SizedBox(height: 24),

              // ============== ACTIONS ==================
              _buildActionGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  // ================= HERO ===================

  Widget _buildHeroSection(BuildContext context) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),

    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Theme.of(context).primaryColor,
          Colors.indigo.shade400,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),

    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text(
          "${_getGreeting()} 👋",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          _userName.isNotEmpty ? _userName : "",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        const Text(
          "Find skilled professionals or share your expertise.",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    ),
  );
}

  // ================= FEATURED ===================

  Widget _buildFeaturedSection() {
    final dummy = [
      "Tutor",
      "Electrician",
      "Designer",
      "Plumber",
      "AC Repair",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        const Text(
          "Featured Services",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 90,

          child: ListView.separated(
            scrollDirection: Axis.horizontal,

            itemCount: dummy.length,

            separatorBuilder: (_, __) => const SizedBox(width: 12),

            itemBuilder: (context, index) {
              return Container(
                width: 120,

                alignment: Alignment.center,

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(14),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 6,
                    ),
                  ],
                ),

                child: Text(
                  dummy[index],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ================= ACTIVITY ===================

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        const Text(
          "Your Activity",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,

          children: const [

            _ActivityCard(
              title: "Active",
              value: "2",
            ),

            _ActivityCard(
              title: "Pending",
              value: "1",
            ),

            _ActivityCard(
              title: "Skills",
              value: "3",
            ),
          ],
        ),
      ],
    );
  }

  // ================= ACTION GRID ===================

  Widget _buildActionGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        GridView.count(
          crossAxisCount: 4,

          shrinkWrap: true,

          physics: const NeverScrollableScrollPhysics(),

          mainAxisSpacing: 12,
          crossAxisSpacing: 12,

          childAspectRatio: 0.9,

          children: [

            _DashboardIcon(
              icon: Icons.search,
              label: "Explore",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SkillListScreen(),
                  ),
                );
              },
            ),

            _DashboardIcon(
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

            _DashboardIcon(
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

            _DashboardIcon(
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
          ],
        ),
      ],
    );
  }
}


// ================= ACTIVITY CARD ===================

class _ActivityCard extends StatelessWidget {
  final String title;
  final String value;

  const _ActivityCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius: BorderRadius.circular(14),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
            ),
          ],
        ),

        child: Column(
          children: [

            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ================= ICON CARD ===================

class _DashboardIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DashboardIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Icon(
              icon,
              size: 26,
              color: Theme.of(context).primaryColor,
            ),

            const SizedBox(height: 8),

            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}