import 'package:flutter/material.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/auth/auth_service.dart';
import 'package:skill_renting_app/features/auth/screens/login_screen.dart';
import '../skills/screens/skill_list_screen.dart';
import '../bookings/screens/seeker_bookings_screen.dart';
import '../bookings/screens/provider_bookings_screen.dart';
import '../skills/screens/my_skills_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../notifications/Screens/notification_screen.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';
import 'package:skill_renting_app/features/skills/models/skill_model.dart';
import 'package:skill_renting_app/features/skills/skill_service.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import 'package:skill_renting_app/features/bookings/models/booking_model.dart';
import '../skills/screens/skill_detail_screen.dart';
import 'package:skill_renting_app/features/chat/chat_list_screen.dart';
import 'package:skill_renting_app/features/chat/message_service.dart';
import 'package:skill_renting_app/core/widgets/dark_theme_toggle.dart';
import 'package:skill_renting_app/core/theme/theme_toggle_controller.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  String _userName = "";
  int _unreadCount = 0;
  int _unreadMessageCount = 0;

  List<SkillModel> _featuredSkills = [];
  bool _loadingSkills = true;

  // Raw booking lists kept so bottom sheets can show details
  List<BookingModel> _allBookings = [];
  int _mySkillsCount = 0;
  bool _loadingActivity = true;

  static const _activeBadgeStatuses = {"accepted", "in_progress", "completed"};

  // Activity cards — "Active" = accepted only, "Pending" = requested only
  int get _activeBookings =>
      _allBookings.where((b) => b.status == "accepted").length;
  int get _pendingBookings =>
      _allBookings.where((b) => b.status == "requested").length;

  // Single static set shared with ProviderBookingsScreen so both screens
  // read and write the same seen state.
  static final Set<String> _seenRequestIds = {};

  int get _unseenRequestsCount => _allBookings
      .where((b) => b.status == "requested" && !_seenRequestIds.contains(b.id))
      .length;

  int get _unseenBookingsCount => _allBookings
      .where((b) => _activeBadgeStatuses.contains(b.status) &&
          !ProviderBookingsScreen.seenBookingIds.contains(b.id))
      .length;

  int get _dashboardRequestsBadge => _unseenRequestsCount + _unseenBookingsCount;

  void _markRequestsSeen() {
    setState(() {
      _seenRequestIds.addAll(
          _allBookings.where((b) => b.status == "requested").map((b) => b.id));
      ProviderBookingsScreen.seenBookingIds.addAll(
          _allBookings.where((b) => _activeBadgeStatuses.contains(b.status)).map((b) => b.id));
    });
  }

  String _getGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good Morning";
    if (h < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadNotificationCount();
    _loadMessageCount();
    _loadFeaturedSkills();
    _loadActivity();
  }

  Future<void> _loadUserName() async {
    final name = await AuthStorage.getName();
    if (name != null && mounted) setState(() => _userName = name);
  }

  Future<void> _loadNotificationCount() async {
    try {
      final token = await AuthStorage.getToken();
      final res = await ApiService.get("/notifications/unread-count",
          token: token);
      if (res["statusCode"] == 200 && mounted) {
        setState(() => _unreadCount =
            (res["data"]?["count"] as num?)?.toInt() ?? 0);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load notifications: $e")),
      );
    }
  }

  Future<void> _loadMessageCount() async {
    try {
      final count = await MessageService.getTotalUnread();
      if (mounted) setState(() => _unreadMessageCount = count);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load messages: $e")),
      );
    }
  }

  Future<void> _loadFeaturedSkills() async {
    setState(() => _loadingSkills = true);
    try {
      final skills = await SkillService.fetchSkills();
      skills.sort((a, b) => b.rating.compareTo(a.rating));
      if (mounted) {
        setState(() {
          _featuredSkills = skills.take(5).toList();
          _loadingSkills = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingSkills = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load skills: $e")),
        );
      }
    }
  }

  Future<void> _loadActivity() async {
    setState(() => _loadingActivity = true);
    try {
      final bookings = await BookingService.fetchMyBookings();
      final mySkills = await SkillService.fetchMySkills();
      if (mounted) {
        setState(() {
          _allBookings = bookings;
          _mySkillsCount = mySkills.length;
          _loadingActivity = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingActivity = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load activity: $e")),
        );
      }
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadNotificationCount(),
      _loadMessageCount(),
      _loadFeaturedSkills(),
      _loadActivity(),
    ]);
  }

  Future<void> _logout(BuildContext context) async {
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── Bottom sheet: list of bookings filtered by status ─────────────────────
  void _showBookingSheet({
    required String title,
    required List<BookingModel> bookings,
    required Color color,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingBottomSheet(
        title: title,
        bookings: bookings,
        color: color,
      ),
    );
  }

  // ── Bottom sheet: my skills list ──────────────────────────────────────────
  void _showSkillsSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MySkillsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Home"),
        leading: IconButton(
          icon: const Icon(Icons.person),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: "Toggle theme",
            onPressed: () =>
                ThemeToggleController.setDarkEnabled(!ThemeToggleController.isDark),
          ),
          // ── Messages icon ─────────────────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () async {
                  setState(() => _unreadMessageCount = 0);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ChatListScreen()),
                  );
                  _loadMessageCount();
                },
              ),
              if (_unreadMessageCount > 0)
                Positioned(
                  right: 6, top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10)),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadMessageCount > 9 ? "9+" : "$_unreadMessageCount",
                      style: TextStyle(
                        color: theme.colorScheme.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // ── Notifications icon ────────────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () async {
                  // Clear badge immediately — feels instant
                  setState(() => _unreadCount = 0);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationScreen()),
                  );
                  // Re-fetch in case new ones arrived while screen was open
                  _loadNotificationCount();
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
                        borderRadius: BorderRadius.circular(10)),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadCount > 9 ? "9+" : "$_unreadCount",
                      style: TextStyle(
                        color: theme.colorScheme.onError,
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
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHero(context),
                const SizedBox(height: 24),
                _buildFeatured(context),
                const SizedBox(height: 24),
                _buildActivity(context),
                const SizedBox(height: 24),
                _buildActionGrid(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${_getGreeting()} 👋",
              style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(_userName,
              style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text("Find skilled professionals or share your expertise.",
              style: TextStyle(
                  color: scheme.onPrimary.withOpacity(0.7), fontSize: 14)),
        ],
      ),
    );
  }

  // ── Featured ───────────────────────────────────────────────────────────────

  Widget _buildFeatured(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Featured Services",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SkillListScreen())),
              child: const Text("See all"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: _loadingSkills
              ? const Center(child: CircularProgressIndicator())
              : _featuredSkills.isEmpty
                  ? Center(
                      child: Text("No services yet",
                          style: TextStyle(color: scheme.onSurfaceVariant)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _featuredSkills.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final skill = _featuredSkills[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    SkillDetailScreen(skill: skill)),
                          ),
                          child: Container(
                            width: 130,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 6)
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(skill.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Row(children: [
                                  const Icon(Icons.star,
                                      size: 13, color: Colors.amber),
                                  const SizedBox(width: 3),
                                  Text(skill.rating.toStringAsFixed(1),
                                      style: const TextStyle(fontSize: 11)),
                                  const Spacer(),
                                  Text("₹${skill.price.toStringAsFixed(0)}",
                                      style: TextStyle(
                                          fontSize: 11,
                                          color:
                                              Theme.of(context).primaryColor,
                                          fontWeight: FontWeight.w600)),
                                ]),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── Activity ───────────────────────────────────────────────────────────────

  Widget _buildActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Your Activity",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SeekerBookingsScreen()),
              ).then((_) => _loadActivity()),
              child: const Text("View all"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _loadingActivity
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(),
                ))
            : Row(
                children: [
                  // Active bookings → show bottom sheet with accepted list
                  _ActivityCard(
                    title: "Active",
                    value: "$_activeBookings",
                    color: Colors.blue,
                    icon: Icons.check_circle_outline,
                    onTap: () => _showBookingSheet(
                      title: "Active Bookings",
                      bookings: _allBookings
                          .where((b) => b.status == "accepted")
                          .toList(),
                      color: Colors.blue,
                    ),
                  ),

                  // Pending bookings → show bottom sheet with requested list
                  _ActivityCard(
                    title: "Pending",
                    value: "$_pendingBookings",
                    color: Colors.orange,
                    icon: Icons.hourglass_empty,
                    onTap: () => _showBookingSheet(
                      title: "Pending Requests",
                      bookings: _allBookings
                          .where((b) => b.status == "requested")
                          .toList(),
                      color: Colors.orange,
                    ),
                  ),

                  // My skills → navigate to My Skills screen
                  _ActivityCard(
                    title: "My Skills",
                    value: "$_mySkillsCount",
                    color: Colors.green,
                    icon: Icons.build_outlined,
                    onTap: _showSkillsSheet,
                  ),
                ],
              ),
      ],
    );
  }

  // ── Quick Actions ──────────────────────────────────────────────────────────

  Widget _buildActionGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quick Actions",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SkillListScreen())),
            ),
            _DashboardIcon(
              icon: Icons.calendar_today,
              label: "Bookings",
              onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SeekerBookingsScreen()))
                  .then((_) => _loadActivity()),
            ),
            _DashboardIcon(
              icon: Icons.add_business,
              label: "My Skills",
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const MySkillsScreen())),
            ),
            _DashboardIcon(
              icon: Icons.list_alt,
              label: "Requests",
              badge: _dashboardRequestsBadge,
              onTap: () {
                _markRequestsSeen();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ProviderBookingsScreen()),
                ).then((_) => _loadActivity());
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── Bottom Sheet: Booking list ────────────────────────────────────────────────

class _BookingBottomSheet extends StatelessWidget {
  final String title;
  final List<BookingModel> bookings;
  final Color color;

  const _BookingBottomSheet({
    required this.title,
    required this.bookings,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: scheme.outlineVariant.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(2)),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 10),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text("${bookings.length} booking${bookings.length != 1 ? 's' : ''}",
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),

            const Divider(height: 1),

            // List
            Expanded(
              child: bookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined,
                              size: 48,
                              color: scheme.onSurfaceVariant.withOpacity(0.7)),
                          const SizedBox(height: 10),
                          Text("Nothing here",
                              style: TextStyle(
                                  color: scheme.onSurfaceVariant.withOpacity(0.85))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _BookingSheetTile(booking: bookings[i], color: color),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile inside bottom sheet ──────────────────────────────────────────────────

class _BookingSheetTile extends StatelessWidget {
  final BookingModel booking;
  final Color color;
  const _BookingSheetTile({required this.booking, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final b = booking;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skill + status chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(b.skillTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(b.status.toUpperCase(),
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Provider
          Row(children: [
            Icon(Icons.person_outline, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(b.providerName,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 4),

          // Slot
          Row(children: [
            Icon(Icons.access_time, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Expanded(
              child: Text(b.slotRangeFormatted,
                  style: TextStyle(fontSize: 13, color: scheme.onSurface)),
            ),
          ]),
          const SizedBox(height: 4),

          // Address
          Row(children: [
            Icon(Icons.location_on, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 5),
            Expanded(
              child: Text(b.jobAddressFormatted,
                  style: TextStyle(fontSize: 13, color: scheme.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 4),

          // Price
          Row(children: [
            const Icon(Icons.currency_rupee, size: 14, color: Colors.grey),
            const SizedBox(width: 5),
            Text(
              "₹${b.pricingUnit}",
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500),
            ),
          ]),

          // GPS status (for accepted)
          if (b.status == "accepted") ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(
                b.gpsLocationStatus == "provided"
                    ? Icons.location_on
                    : Icons.location_searching,
                size: 14,
                color: b.gpsLocationStatus == "provided"
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 5),
              Text(
                b.gpsLocationStatus == "provided"
                    ? "GPS location shared"
                    : "Awaiting GPS location",
                style: TextStyle(
                    fontSize: 12,
                    color: b.gpsLocationStatus == "provided"
                        ? Colors.green
                        : Colors.orange),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ── Activity Card ─────────────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 6),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color)),
              const SizedBox(height: 4),
              Text(title,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dashboard Icon ─────────────────────────────────────────────────────────────

class _DashboardIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge; // 0 = hidden

  const _DashboardIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                      Icon(icon, size: 26, color: scheme.primary),
                  const SizedBox(height: 8),
                  Text(label,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface)),
                ],
              ),
            ),
            if (badge > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10)),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text(
                    badge > 9 ? "9+" : "$badge",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
