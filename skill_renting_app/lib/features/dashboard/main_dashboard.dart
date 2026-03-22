import 'package:flutter/material.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/auth/auth_service.dart';
import 'package:skill_renting_app/features/auth/screens/login_screen.dart';
import '../skills/screens/skill_list_screen.dart';
import '../bookings/screens/seeker_bookings_screen.dart';
import '../bookings/screens/provider_bookings_screen.dart';
import '../skills/screens/my_skills_screen.dart';
import '../profile/screens/profile_screen.dart';
import '../notifications/screens/notification_screen.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:skill_renting_app/features/skills/models/skill_model.dart';
import 'package:skill_renting_app/features/skills/skill_service.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import 'package:skill_renting_app/features/bookings/models/booking_model.dart';
import '../skills/screens/skill_detail_screen.dart';
import 'package:skill_renting_app/features/chat/chat_list_screen.dart';
import 'package:skill_renting_app/features/chat/message_service.dart';
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
  List<BookingModel> _allBookings = [];
  int _mySkillsCount = 0;
  bool _loadingActivity = true;

  static const _activeBadgeStatuses = {"accepted", "in_progress", "completed"};
  static final Set<String> _seenRequestIds = {};

  int get _activeBookings  => _allBookings.where((b) => b.status == "accepted").length;
  int get _pendingBookings => _allBookings.where((b) => b.status == "requested").length;
  int get _unseenRequestsCount => _allBookings
      .where((b) => b.status == "requested" && !_seenRequestIds.contains(b.id)).length;
  int get _unseenBookingsCount => _allBookings
      .where((b) => _activeBadgeStatuses.contains(b.status) &&
          !ProviderBookingsScreen.seenBookingIds.contains(b.id)).length;
  int get _dashboardRequestsBadge => _unseenRequestsCount + _unseenBookingsCount;

  void _markRequestsSeen() {
    setState(() {
      _seenRequestIds.addAll(_allBookings.where((b) => b.status == "requested").map((b) => b.id));
      ProviderBookingsScreen.seenBookingIds.addAll(
          _allBookings.where((b) => _activeBadgeStatuses.contains(b.status)).map((b) => b.id));
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return "Good morning";
    if (h < 17) return "Good afternoon";
    return "Good evening";
  }

  @override
  void initState() {
    super.initState();
    _loadUserName(); _loadNotificationCount(); _loadMessageCount();
    _loadFeaturedSkills(); _loadActivity();
  }

  Future<void> _loadUserName() async {
    final name = await AuthStorage.getName();
    if (name != null && mounted) setState(() => _userName = name);
  }

  Future<void> _loadNotificationCount() async {
    try {
      final token = await AuthStorage.getToken();
      final res   = await ApiService.get("/notifications/unread-count", token: token);
      if (res["statusCode"] == 200 && mounted)
        setState(() => _unreadCount = (res["data"]?["count"] as num?)?.toInt() ?? 0);
    } catch (_) {}
  }

  Future<void> _loadMessageCount() async {
    try {
      final count = await MessageService.getTotalUnread();
      if (mounted) setState(() => _unreadMessageCount = count);
    } catch (_) {}
  }

  Future<void> _loadFeaturedSkills() async {
    setState(() => _loadingSkills = true);
    try {
      final skills = await SkillService.fetchSkills();
      skills.sort((a, b) => b.rating.compareTo(a.rating));
      if (mounted) setState(() { _featuredSkills = skills.take(6).toList(); _loadingSkills = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSkills = false);
    }
  }

  Future<void> _loadActivity() async {
    setState(() => _loadingActivity = true);
    try {
      final bookings = await BookingService.fetchMyBookings();
      final mySkills = await SkillService.fetchMySkills();
      if (mounted) setState(() {
        _allBookings   = bookings;
        _mySkillsCount = mySkills.length;
        _loadingActivity = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingActivity = false);
    }
  }

  Future<void> _refreshAll() => Future.wait([
    _loadNotificationCount(), _loadMessageCount(),
    _loadFeaturedSkills(), _loadActivity(),
  ]);

  Future<void> _logout() async {
    // AuthService.logout() clears the FCM token from the server first,
    // then wipes local storage — prevents cross-account push notifications
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _showBookingSheet(String title, List<BookingModel> bookings, Color color) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _BookingSheet(title: title, bookings: bookings, color: color));
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final tt     = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF2A2740) : cs.outlineVariant, width: 0.6),
              ),
              child: Icon(Icons.person_outline_rounded, size: 16, color: cs.onSurfaceVariant),
            ),
          ),
        ),
        title: Text("Home", style: tt.titleLarge),
        actions: [
          // Theme toggle
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              size: 19, color: cs.onSurfaceVariant),
            onPressed: () => ThemeToggleController.setDarkEnabled(!isDark)),
          // Messages
          _NavIcon(
            icon: Icons.chat_bubble_outline_rounded,
            badge: _unreadMessageCount,
            cs: cs,
            onTap: () async {
              setState(() => _unreadMessageCount = 0);
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
              _loadMessageCount();
            },
          ),
          // Notifications
          _NavIcon(
            icon: Icons.notifications_outlined,
            badge: _unreadCount,
            cs: cs,
            onTap: () async {
              setState(() => _unreadCount = 0);
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
              _loadNotificationCount();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Hero ──────────────────────────────────────────────────────────
            _Hero(greeting: _greeting, name: _userName, isDark: isDark, cs: cs, tt: tt),
            const SizedBox(height: 24),

            // ── Stat row ──────────────────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("Activity", style: tt.titleSmall),
              TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SeekerBookingsScreen()))
                    .then((_) => _loadActivity()),
                child: const Text("View all")),
            ]),
            const SizedBox(height: 10),
            _loadingActivity
                ? _StatRowSkeleton(cs: cs)
                : Row(children: [
                    _StatCard(label: "Active",    value: "$_activeBookings",
                        icon: Icons.check_circle_outline_rounded, color: const Color(0xFF60A5FA),
                        cs: cs, tt: tt,
                        onTap: () => _showBookingSheet("Active Bookings",
                            _allBookings.where((b) => b.status == "accepted").toList(),
                            const Color(0xFF60A5FA))),
                    const SizedBox(width: 10),
                    _StatCard(label: "Pending",   value: "$_pendingBookings",
                        icon: Icons.hourglass_empty_rounded, color: const Color(0xFFFBBF24),
                        cs: cs, tt: tt,
                        onTap: () => _showBookingSheet("Pending",
                            _allBookings.where((b) => b.status == "requested").toList(),
                            const Color(0xFFFBBF24))),
                    const SizedBox(width: 10),
                    _StatCard(label: "My Skills", value: "$_mySkillsCount",
                        icon: Icons.build_outlined, color: const Color(0xFF34D399),
                        cs: cs, tt: tt,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const MySkillsScreen()))),
                  ]),

            const SizedBox(height: 28),

            // ── Quick actions ─────────────────────────────────────────────────
            Text("Quick actions", style: tt.titleSmall),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.88,
              children: [
                _QuickAction(icon: Icons.search_rounded,          label: "Explore",   cs: cs, tt: tt,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillListScreen()))),
                _QuickAction(icon: Icons.calendar_month_outlined, label: "Bookings",  cs: cs, tt: tt,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SeekerBookingsScreen()))
                        .then((_) => _loadActivity())),
                _QuickAction(icon: Icons.add_business_outlined,   label: "My Skills", cs: cs, tt: tt,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MySkillsScreen()))),
                _QuickAction(icon: Icons.inbox_outlined,           label: "Requests",  cs: cs, tt: tt,
                    badge: _dashboardRequestsBadge,
                    onTap: () {
                      _markRequestsSeen();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProviderBookingsScreen()))
                          .then((_) => _loadActivity());
                    }),
              ],
            ),

            const SizedBox(height: 28),

            // ── Featured ──────────────────────────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("Featured services", style: tt.titleSmall),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillListScreen())),
                child: const Text("See all")),
            ]),
            const SizedBox(height: 10),
            _loadingSkills
                ? _FeaturedSkeleton(cs: cs)
                : _featuredSkills.isEmpty
                    ? Center(child: Text("No services yet", style: tt.bodySmall))
                    : SizedBox(
                        height: 130,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _featuredSkills.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final s = _featuredSkills[i];
                            return _FeaturedCard(skill: s, cs: cs, tt: tt, isDark: isDark,
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => SkillDetailScreen(skill: s))));
                          },
                        ),
                      ),
          ]),
        ),
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  final String greeting, name;
  final bool isDark;
  final ColorScheme cs;
  final TextTheme tt;
  const _Hero({required this.greeting, required this.name, required this.isDark,
      required this.cs, required this.tt});
  @override
  Widget build(BuildContext context) {
    if (isDark) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0E17),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF1E1C30), width: 0.6),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row — greeting + glow indicator
          Row(children: [
            Text(greeting, style: TextStyle(
                fontSize: 12, color: cs.onSurfaceVariant, letterSpacing: 0.2)),
            const Spacer(),
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF34D399),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: const Color(0xFF34D399).withOpacity(0.5),
                    blurRadius: 6, spreadRadius: 1)],
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(name.isNotEmpty ? name : "...",
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700,
                  color: Color(0xFFEDE9FF), letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text("Find skilled professionals near you",
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 14),
          // Accent line
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary.withOpacity(0.6), Colors.transparent]),
            ),
          ),
        ]),
      );
    }
    // Light mode — gradient card
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [cs.primary, cs.secondary],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(greeting, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text("Find skilled professionals near you",
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4)),
      ]),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;
  const _StatCard({required this.label, required this.value, required this.icon,
      required this.color, required this.cs, required this.tt, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Color.alphaBlend(color.withOpacity(0.05), const Color(0xFF0F0E17)) : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? color.withOpacity(0.18) : cs.outlineVariant.withOpacity(0.8),
            width: 0.8),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(isDark ? 0.3 : 0.2), width: 0.8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        ]),
      ),
    ));
  }
}

// ── Quick action ──────────────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final int badge;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.cs,
      required this.tt, required this.onTap, this.badge = 0});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(14), onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF12101E) : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.8),
            width: isDark ? 0.6 : 0.8),
        ),
        child: Stack(children: [
          Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: cs.primary),
            ),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600,
                    color: cs.onSurface)),
          ])),
          if (badge > 0)
            Positioned(top: 7, right: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(badge > 9 ? "9+" : "$badge",
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              )),
        ]),
      ),
    );
  }
}

// ── Featured skill card ───────────────────────────────────────────────────────
class _FeaturedCard extends StatelessWidget {
  final SkillModel skill;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;
  final VoidCallback onTap;
  const _FeaturedCard({required this.skill, required this.cs, required this.tt,
      required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 136,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0E17) : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.8),
          width: isDark ? 0.6 : 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(skill.title, style: tt.labelLarge,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFBBF24)),
          const SizedBox(width: 3),
          Text(skill.rating.toStringAsFixed(1), style: tt.labelSmall),
          const Spacer(),
          Text("₹${skill.price.toStringAsFixed(0)}",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
        ]),
        const SizedBox(height: 4),
        Text(skill.providerName.isNotEmpty ? skill.providerName : "Provider",
            style: tt.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

// ── Nav icon with badge ────────────────────────────────────────────────────────
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final int badge;
  final ColorScheme cs;
  final VoidCallback onTap;
  const _NavIcon({required this.icon, required this.badge, required this.cs, required this.onTap});
  @override
  Widget build(BuildContext context) => Stack(alignment: Alignment.center, children: [
    IconButton(icon: Icon(icon, size: 20, color: cs.onSurfaceVariant), onPressed: onTap),
    if (badge > 0)
      Positioned(top: 8, right: 6,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
              color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(8)),
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          child: Text(badge > 9 ? "9+" : "$badge",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
        )),
  ]);
}

// ── Booking bottom sheet ──────────────────────────────────────────────────────
class _BookingSheet extends StatelessWidget {
  final String title;
  final List<BookingModel> bookings;
  final Color color;
  const _BookingSheet({required this.title, required this.bookings, required this.color});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.55, minChildSize: 0.3, maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.5), width: 0.5)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 36, height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Container(width: 4, height: 20,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: tt.titleSmall)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.3), width: 0.8)),
                child: Text("${bookings.length}",
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700))),
            ]),
          ),
          Divider(height: 1, color: cs.outlineVariant.withOpacity(0.5)),
          Expanded(
            child: bookings.isEmpty
                ? Center(child: Text("Nothing here", style: tt.bodySmall))
                : ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _BookingTile(booking: bookings[i], color: color, cs: cs, tt: tt)),
          ),
        ]),
      ),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final BookingModel booking;
  final Color color;
  final ColorScheme cs;
  final TextTheme tt;
  const _BookingTile({required this.booking, required this.color, required this.cs, required this.tt});
  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 0.8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(b.skillTitle, style: tt.titleSmall, overflow: TextOverflow.ellipsis)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3), width: 0.8)),
            child: Text(b.status.toUpperCase(),
                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.person_outline_rounded, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(b.providerName, style: tt.labelSmall),
        ]),
        const SizedBox(height: 3),
        Row(children: [
          Icon(Icons.access_time_rounded, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(b.slotRangeFormatted, style: tt.labelSmall),
        ]),
      ]),
    );
  }
}

// ── Skeletons ─────────────────────────────────────────────────────────────────
class _StatRowSkeleton extends StatelessWidget {
  final ColorScheme cs;
  const _StatRowSkeleton({required this.cs});
  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(3, (i) => Expanded(child: Container(
      margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
      height: 88,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4), width: 0.6)),
    ))));
}

class _FeaturedSkeleton extends StatelessWidget {
  final ColorScheme cs;
  const _FeaturedSkeleton({required this.cs});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 130,
    child: ListView.separated(
      scrollDirection: Axis.horizontal, itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (_, __) => Container(
        width: 136, height: 130,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.4), width: 0.6)))));
}
