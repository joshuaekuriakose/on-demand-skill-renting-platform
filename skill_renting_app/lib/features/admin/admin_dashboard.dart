// admin_dashboard.dart — dark editorial reskin
// All logic preserved from original; only visual layer changed.
// Import this file as a DROP-IN replacement for the existing admin_dashboard.dart

import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/auth/auth_service.dart';
import 'package:printing/printing.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/auth/screens/login_screen.dart';
import 'admin_service.dart';
import 'admin_pdf_builder.dart';
import 'package:skill_renting_app/core/theme/theme_toggle_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _fmtDate(String? iso) {
  if (iso == null) return "-";
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return "-";
  return "${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}";
}

String _fmtDateTime(String? iso) {
  if (iso == null) return "-";
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return "-";
  return "${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}  "
      "${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}";
}

Color _statusColor(String s) {
  switch (s) {
    case "accepted":    return const Color(0xFF60A5FA);
    case "in_progress": return const Color(0xFFA78BFA);
    case "completed":   return const Color(0xFF34D399);
    case "rejected":    return const Color(0xFFF87171);
    case "cancelled":   return const Color(0xFF9CA3AF);
    default:            return const Color(0xFFFBBF24);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Root
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _tab = 0;

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        title: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.admin_panel_settings_outlined, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text("Admin", style: tt.titleLarge),
        ]),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 19, color: cs.onSurfaceVariant),
            onPressed: () => ThemeToggleController.setDarkEnabled(!isDark)),
          IconButton(
            icon: Icon(Icons.logout_rounded, size: 19, color: cs.onSurfaceVariant),
            onPressed: _logout),
        ],
        shape: Border(bottom: BorderSide(
          color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.5), width: 0.5)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Row(children: [
            _TabBtn("Overview",  Icons.dashboard_outlined,      0, _tab, (i) => setState(() => _tab = i), cs),
            _TabBtn("Users",     Icons.people_outline,          1, _tab, (i) => setState(() => _tab = i), cs),
            _TabBtn("Bookings",  Icons.calendar_today_outlined, 2, _tab, (i) => setState(() => _tab = i), cs),
          ]),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [_OverviewTab(), _UsersTab(), _BookingsTab()],
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label; final IconData icon;
  final int index, current; final void Function(int) onTap;
  final ColorScheme cs;
  const _TabBtn(this.label, this.icon, this.index, this.current, this.onTap, this.cs);
  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: sel ? cs.primary : Colors.transparent, width: 2))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: sel ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              fontSize: 12, color: sel ? cs.primary : cs.onSurfaceVariant,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewTab extends StatefulWidget {
  const _OverviewTab();
  @override State<_OverviewTab> createState() => _OverviewTabState();
}
class _OverviewTabState extends State<_OverviewTab> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    final s = await AdminService.getStats();
    if (mounted) setState(() { _stats = s; _loading = false; });
  }
  void _nav(String key) {
    switch (key) {
      case "totalUsers":      Navigator.push(context, MaterialPageRoute(builder: (_) => const _UsersListScreen(roleFilter: "all"))); break;
      case "totalProviders":  Navigator.push(context, MaterialPageRoute(builder: (_) => const _UsersListScreen(roleFilter: "provider"))); break;
      case "totalBookings":   Navigator.push(context, MaterialPageRoute(builder: (_) => const _AllBookingsScreen(statusFilter: null))); break;
      case "completedBookings": Navigator.push(context, MaterialPageRoute(builder: (_) => const _AllBookingsScreen(statusFilter: "completed"))); break;
      case "pendingBookings": Navigator.push(context, MaterialPageRoute(builder: (_) => const _AllBookingsScreen(statusFilter: "requested"))); break;
      case "revenue":         Navigator.push(context, MaterialPageRoute(builder: (_) => const _RevenueScreen())); break;
    }
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Welcome banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F0E17) : cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? cs.primary.withOpacity(0.2) : cs.outlineVariant.withOpacity(0.8),
                width: isDark ? 0.6 : 0.8),
              gradient: isDark ? LinearGradient(
                colors: [cs.primary.withOpacity(0.06), const Color(0xFF0F0E17)],
                begin: Alignment.topLeft, end: Alignment.bottomRight) : null),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Welcome, Admin", style: tt.titleLarge),
              const SizedBox(height: 4),
              Text("joshuakuriakose1712@gmail.com", style: tt.bodySmall),
            ]),
          ),
          const SizedBox(height: 20),
          Text("Platform overview", style: tt.titleSmall),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.8,
            children: [
              _StatCard("Users",       "${_stats["totalUsers"] ?? 0}",       Icons.people_outline,          const Color(0xFF60A5FA), isDark, cs, tt, () => _nav("totalUsers")),
              _StatCard("Providers",   "${_stats["totalProviders"] ?? 0}",   Icons.work_outline,            const Color(0xFFA78BFA), isDark, cs, tt, () => _nav("totalProviders")),
              _StatCard("Bookings",    "${_stats["totalBookings"] ?? 0}",    Icons.calendar_today_outlined, const Color(0xFF34D399), isDark, cs, tt, () => _nav("totalBookings")),
              _StatCard("Completed",   "${_stats["completedBookings"] ?? 0}",Icons.task_alt_outlined,       const Color(0xFF34D399), isDark, cs, tt, () => _nav("completedBookings")),
              _StatCard("Pending",     "${_stats["pendingBookings"] ?? 0}",  Icons.hourglass_empty_rounded, const Color(0xFFFBBF24), isDark, cs, tt, () => _nav("pendingBookings")),
              _StatCard("Revenue",     "₹${(_stats["totalRevenue"] ?? 0).toStringAsFixed(0)}",
                                                                              Icons.currency_rupee_rounded,  const Color(0xFF34D399), isDark, cs, tt, () => _nav("revenue")),
            ],
          ),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  final bool isDark; final ColorScheme cs; final TextTheme tt; final VoidCallback onTap;
  const _StatCard(this.label, this.value, this.icon, this.color, this.isDark, this.cs, this.tt, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Color.alphaBlend(color.withOpacity(0.05), const Color(0xFF0F0E17)) : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? color.withOpacity(0.18) : cs.outlineVariant.withOpacity(0.8), width: 0.8)),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 0.8)),
          child: Icon(icon, size: 18, color: color)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, size: 11, color: cs.onSurfaceVariant.withOpacity(0.4)),
      ]),
    ));
}

// ─────────────────────────────────────────────────────────────────────────────
// Users Tab
// ─────────────────────────────────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override State<_UsersTab> createState() => _UsersTabState();
}
class _UsersTabState extends State<_UsersTab> {
  List _users = []; int _total = 0; bool _loading = true;
  String _roleFilter = "all";
  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getUsers(
        role: _roleFilter == "all" ? null : _roleFilter,
        search: _searchCtrl.text.trim());
    if (mounted) setState(() {
      _users = res["users"] as List? ?? []; _total = res["total"] as int? ?? 0; _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF2A2740) : cs.outlineVariant, width: 0.8)),
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search users…", hintStyle: TextStyle(color: cs.onSurfaceVariant),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
                border: InputBorder.none, enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11)),
              onSubmitted: (_) => _load()),
          )),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(children: [
          Text("$_total users", style: tt.labelSmall),
          const Spacer(),
          for (final f in [["all","All"],["seeker","Customers"],["provider","Providers"]])
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () { setState(() => _roleFilter = f[0]); _load(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: _roleFilter == f[0]
                        ? cs.primary.withOpacity(isDark ? 0.2 : 0.1) : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _roleFilter == f[0]
                          ? cs.primary.withOpacity(0.4) : cs.outlineVariant.withOpacity(0.5),
                      width: 0.8)),
                  child: Text(f[1], style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500,
                      color: _roleFilter == f[0] ? cs.primary : cs.onSurfaceVariant)),
                ),
              ),
            ),
        ]),
      ),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? Center(child: Text("No users found", style: Theme.of(context).textTheme.bodySmall))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final u = _users[i] as Map;
                      return _UserCard(user: u, cs: cs, tt: tt, isDark: isDark,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => _UserDetailScreen(userId: u["_id"].toString()))));
                    }))),
    ]);
  }
}

class _UserCard extends StatelessWidget {
  final Map user; final ColorScheme cs; final TextTheme tt;
  final bool isDark; final VoidCallback onTap;
  const _UserCard({required this.user, required this.cs, required this.tt,
      required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final name = user["name"]?.toString() ?? "User";
    final email = user["email"]?.toString() ?? "";
    final phone = user["phone"]?.toString() ?? "";
    final isProvider = user["isProvider"] == true;
    final district = (user["address"] as Map?)?["district"]?.toString() ?? "";
    final color = isProvider ? const Color(0xFFA78BFA) : const Color(0xFF60A5FA);
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0E17) : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.8),
            width: isDark ? 0.6 : 0.8)),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12), shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.25), width: 0.8)),
            child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : "U",
                style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: tt.labelLarge),
            Text(email, style: tt.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (phone.isNotEmpty) Text(phone, style: tt.labelSmall),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.25), width: 0.6)),
              child: Text(isProvider ? "Provider" : "Customer",
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600))),
            if (district.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(district, style: tt.labelSmall),
            ],
          ]),
          const SizedBox(width: 6),
          Icon(Icons.arrow_forward_ios_rounded, size: 11, color: cs.onSurfaceVariant),
        ]),
      ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bookings Tab — kept same logic as original, dark skin
// ─────────────────────────────────────────────────────────────────────────────
class _BookingsTab extends StatefulWidget {
  const _BookingsTab();
  @override State<_BookingsTab> createState() => _BookingsTabState();
}
class _BookingsTabState extends State<_BookingsTab> {
  List _skills = []; bool _loading = true;
  DateTime? _dateFrom, _dateTo;
  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getBookingsBySkill(
      search:   _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      dateFrom: _dateFrom?.toIso8601String(),
      dateTo:   _dateTo?.toIso8601String());
    if (mounted) setState(() { _skills = res; _loading = false; });
  }

  Future<void> _downloadReport() async {
    DateTime? from = _dateFrom, to = _dateTo;
    if (from == null || to == null) {
      await showDialog(context: context,
        builder: (dCtx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
          title: const Text("Bookings Report"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _DateTile("From", from, () async {
              final d = await showDatePicker(context: ctx, initialDate: DateTime.now().subtract(const Duration(days: 30)),
                  firstDate: DateTime(2024), lastDate: DateTime.now());
              if (d != null) setS(() => from = d);
            }),
            const SizedBox(height: 8),
            _DateTile("To", to, () async {
              final d = await showDatePicker(context: ctx, initialDate: DateTime.now(),
                  firstDate: from ?? DateTime(2024), lastDate: DateTime.now());
              if (d != null) setS(() => to = d);
            }),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancel")),
            ElevatedButton(onPressed: (from == null || to == null) ? null : () => Navigator.pop(dCtx),
                child: const Text("Generate")),
          ])));
    }
    if (from == null || to == null) return;
    if (!mounted) return;
    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(const SnackBar(content: Text("Generating report…"), duration: Duration(seconds: 30)));
    final result = await AdminService.generateBookingsReport(dateFrom: from!, dateTo: to!);
    snack.hideCurrentSnackBar();
    if (!mounted) return;
    if (result["empty"] == true) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No bookings in range"))); return; }
    if (result.containsKey("error")) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result["error"].toString()))); return; }
    final bytes = await AdminPdfBuilder.buildBookingsReport(result["reportData"] as Map<String, dynamic>);
    await Printing.sharePdf(bytes: bytes, filename: "bookings_report.pdf");
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Expanded(child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF2A2740) : cs.outlineVariant, width: 0.8)),
            child: TextField(
              controller: _searchCtrl, style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: "Search by skill or provider…", hintStyle: TextStyle(color: cs.onSurfaceVariant),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
                border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 11)),
              onSubmitted: (_) => _load()),
          )),
          const SizedBox(width: 8),
          GestureDetector(onTap: _downloadReport, child: Container(
            height: 42, width: 42,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withOpacity(0.3), width: 0.8)),
            child: Icon(Icons.download_rounded, size: 18, color: cs.primary))),
        ]),
      ),
      Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _skills.isEmpty
              ? Center(child: Text("No bookings found", style: tt.bodySmall))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _skills.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = _skills[i] as Map;
                      return _SkillBookingCard(skillGroup: s, cs: cs, tt: tt, isDark: isDark,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => _SkillBookingsScreen(
                                skillId: s["_id"].toString(),
                                skillTitle: (s["skill"] as Map?)?["title"]?.toString() ?? "-",
                                dateFrom: _dateFrom, dateTo: _dateTo))));
                    }))),
    ]);
  }
}

class _SkillBookingCard extends StatelessWidget {
  final Map skillGroup; final ColorScheme cs; final TextTheme tt;
  final bool isDark; final VoidCallback onTap;
  const _SkillBookingCard({required this.skillGroup, required this.cs, required this.tt,
      required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final skill    = skillGroup["skill"]   as Map? ?? {};
    final provider = skill["provider"]     as Map? ?? {};
    final total    = skillGroup["totalBookings"] as int? ?? 0;
    final completed= skillGroup["completed"] as int? ?? 0;
    final pending  = skillGroup["pending"]   as int? ?? 0;
    final revenue  = (skillGroup["revenue"] as num?)?.toDouble() ?? 0;
    final unit     = (skill["pricing"] as Map?)?["unit"]?.toString() ?? "hour";
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F0E17) : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.8),
              width: isDark ? 0.6 : 0.8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(skill["title"]?.toString() ?? "-", style: tt.titleSmall)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.primary.withOpacity(0.3), width: 0.6)),
              child: Text(unit, style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 4),
          Text("by ${provider["name"] ?? "-"}", style: tt.labelSmall),
          const SizedBox(height: 10),
          Row(children: [
            _MiniChip("$total total",     cs.primary, cs),
            const SizedBox(width: 6),
            _MiniChip("$completed done",  const Color(0xFF34D399), cs),
            const SizedBox(width: 6),
            _MiniChip("$pending pending", const Color(0xFFFBBF24), cs),
            const Spacer(),
            Text("₹${revenue.toStringAsFixed(0)}",
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF34D399), fontSize: 13)),
          ]),
        ]),
      ));
  }
}

class _MiniChip extends StatelessWidget {
  final String text; final Color color; final ColorScheme cs;
  const _MiniChip(this.text, this.color, this.cs);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 0.6)),
    child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)));
}

// ─────────────────────────────────────────────────────────────────────────────
// Remaining screen stubs — internal navigation targets
// (full logic from original preserved, dark skin applied)
// ─────────────────────────────────────────────────────────────────────────────

class _RevenueScreen extends StatefulWidget {
  const _RevenueScreen();
  @override State<_RevenueScreen> createState() => _RevenueScreenState();
}
class _RevenueScreenState extends State<_RevenueScreen> {
  List _bookings = []; double _grandTotal = 0; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getRevenue();
    if (mounted) setState(() { _bookings = res["bookings"] as List? ?? []; _grandTotal = (res["grandTotal"] as num?)?.toDouble() ?? 0; _loading = false; });
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: Text("Revenue", style: tt.titleLarge), backgroundColor: cs.surfaceContainerLowest, surfaceTintColor: Colors.transparent),
      body: _loading ? const Center(child: CircularProgressIndicator()) : Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF0F0E17), border: Border(bottom: BorderSide(color: const Color(0xFF1E1C30), width: 0.5))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Total revenue", style: tt.labelSmall),
            const SizedBox(height: 4),
            Text("₹${_grandTotal.toStringAsFixed(0)}", style: const TextStyle(color: Color(0xFF34D399), fontSize: 28, fontWeight: FontWeight.w700)),
            Text("${_bookings.length} paid bookings", style: tt.labelSmall),
          ])),
        Expanded(child: RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            padding: const EdgeInsets.all(12), itemCount: _bookings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _RevenueTile(booking: _bookings[i] as Map, cs: cs, tt: tt),
          ))),
      ]),
    );
  }
}

class _RevenueTile extends StatelessWidget {
  final Map booking; final ColorScheme cs; final TextTheme tt;
  const _RevenueTile({required this.booking, required this.cs, required this.tt});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seeker   = (booking["seeker"]   as Map?)?["name"]?.toString() ?? "-";
    final provider = (booking["provider"] as Map?)?["name"]?.toString() ?? "-";
    final skill    = (booking["skill"]    as Map?)?["title"]?.toString() ?? "-";
    final amount   = (booking["totalAmount"] as num?)?.toDouble() ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0E17) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.8), width: isDark ? 0.6 : 0.8)),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFF34D399).withOpacity(0.1), shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF34D399).withOpacity(0.25), width: 0.8)),
          child: const Icon(Icons.currency_rupee_rounded, color: Color(0xFF34D399), size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(skill, style: tt.labelLarge),
          Text("$seeker → $provider", style: tt.labelSmall),
          Text(_fmtDate(booking["startDate"]?.toString()), style: tt.labelSmall),
        ])),
        Text("₹${amount.toStringAsFixed(0)}",
            style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF34D399), fontSize: 15)),
      ]),
    );
  }
}

class _UsersListScreen extends StatefulWidget {
  final String roleFilter;
  const _UsersListScreen({required this.roleFilter});
  @override State<_UsersListScreen> createState() => _UsersListScreenState();
}
class _UsersListScreenState extends State<_UsersListScreen> {
  List _users = []; int _total = 0; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getUsers(role: widget.roleFilter == "all" ? null : widget.roleFilter);
    if (mounted) setState(() { _users = res["users"] as List? ?? []; _total = res["total"] as int? ?? 0; _loading = false; });
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.roleFilter == "provider" ? "Providers" : widget.roleFilter == "seeker" ? "Customers" : "All Users";
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: Text("$title ($_total)", style: tt.titleLarge), backgroundColor: cs.surfaceContainerLowest, surfaceTintColor: Colors.transparent),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : ListView.separated(padding: const EdgeInsets.all(12), itemCount: _users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) { final u = _users[i] as Map;
                return _UserCard(user: u, cs: cs, tt: tt, isDark: isDark,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _UserDetailScreen(userId: u["_id"].toString()))));
              }));
  }
}

class _AllBookingsScreen extends StatefulWidget {
  final String? statusFilter;
  const _AllBookingsScreen({this.statusFilter});
  @override State<_AllBookingsScreen> createState() => _AllBookingsScreenState();
}
class _AllBookingsScreenState extends State<_AllBookingsScreen> {
  List _bookings = []; bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getBookings(status: widget.statusFilter);
    if (mounted) setState(() { _bookings = res["bookings"] as List? ?? []; _loading = false; });
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = widget.statusFilter == null ? "All Bookings"
        : widget.statusFilter!.replaceAll("_", " ").split(" ").map((w) => w.isEmpty ? "" : "${w[0].toUpperCase()}${w.substring(1)}").join(" ");
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: Text(title, style: tt.titleLarge), backgroundColor: cs.surfaceContainerLowest, surfaceTintColor: Colors.transparent),
      body: _loading ? const Center(child: CircularProgressIndicator())
          : ListView.separated(padding: const EdgeInsets.all(12), itemCount: _bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _BookingDetailCard(booking: _bookings[i] as Map)));
  }
}

class _BookingDetailCard extends StatelessWidget {
  final Map booking;
  const _BookingDetailCard({required this.booking});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status  = booking["status"]?.toString() ?? "";
    final seeker  = (booking["seeker"]   as Map?)?["name"]?.toString() ?? "N/A";
    final provider= (booking["provider"] as Map?)?["name"]?.toString() ?? "N/A";
    final skill   = (booking["skill"]    as Map?)?["title"]?.toString() ?? "N/A";
    final fee     = (booking["pricingSnapshot"] as Map?)?["amount"] ?? 0;
    final color   = _statusColor(status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0E17) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.8), width: isDark ? 0.6 : 0.8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(skill, style: tt.titleSmall)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withOpacity(0.3), width: 0.6)),
            child: Text(status.replaceAll("_"," ").toUpperCase(),
                style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        Text("$seeker  →  $provider", style: tt.labelSmall),
        Row(children: [
          Text(_fmtDate(booking["startDate"]?.toString()), style: tt.labelSmall),
          const Spacer(),
          Text("₹$fee", style: tt.labelSmall),
        ]),
      ]),
    );
  }
}

class _SkillBookingsScreen extends StatefulWidget {
  final String skillId, skillTitle;
  final DateTime? dateFrom, dateTo;
  const _SkillBookingsScreen({required this.skillId, required this.skillTitle, this.dateFrom, this.dateTo});
  @override State<_SkillBookingsScreen> createState() => _SkillBookingsScreenState();
}
class _SkillBookingsScreenState extends State<_SkillBookingsScreen> {
  List _bookings = []; bool _loading = true; String? _statusFilter; bool _generating = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getBookingsForSkill(widget.skillId, status: _statusFilter,
        dateFrom: widget.dateFrom?.toIso8601String(), dateTo: widget.dateTo?.toIso8601String());
    if (mounted) setState(() { _bookings = res; _loading = false; });
  }
  Future<void> _download() async {
    final from = widget.dateFrom ?? DateTime.now().subtract(const Duration(days: 30));
    final to   = widget.dateTo   ?? DateTime.now();
    setState(() => _generating = true);
    final result = await AdminService.generateBookingsReport(skillId: widget.skillId, dateFrom: from, dateTo: to, status: _statusFilter);
    setState(() => _generating = false);
    if (!mounted) return;
    if (result["empty"] == true || result.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result["empty"] == true ? "No bookings in range" : result["error"].toString())));
      return;
    }
    final bytes = await AdminPdfBuilder.buildBookingsReport(result["reportData"] as Map<String, dynamic>);
    await Printing.sharePdf(bytes: bytes, filename: "report_${widget.skillTitle.replaceAll(' ','_')}.pdf");
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(widget.skillTitle, style: tt.titleLarge),
        backgroundColor: cs.surfaceContainerLowest, surfaceTintColor: Colors.transparent,
        actions: [
          _generating
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(icon: const Icon(Icons.download_rounded), onPressed: _download),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              [null,"All"],["requested","Pending"],["accepted","Accepted"],
              ["in_progress","In Progress"],["completed","Completed"],
            ].map((f) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () { setState(() => _statusFilter = f[0]); _load(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusFilter == f[0] ? cs.primary.withOpacity(isDark ? 0.2 : 0.1) : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _statusFilter == f[0] ? cs.primary.withOpacity(0.4) : cs.outlineVariant.withOpacity(0.5), width: 0.8)),
                  child: Text(f[1]!, style: TextStyle(fontSize: 12, color: _statusFilter == f[0] ? cs.primary : cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                ),
              ),
            )).toList(),
          ),
        ),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
            : _bookings.isEmpty ? Center(child: Text("No bookings found", style: tt.bodySmall))
                : ListView.separated(padding: const EdgeInsets.all(12), itemCount: _bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _BookingDetailCard(booking: _bookings[i] as Map))),
      ]),
    );
  }
}

class _UserDetailScreen extends StatefulWidget {
  final String userId;
  const _UserDetailScreen({required this.userId});
  @override State<_UserDetailScreen> createState() => _UserDetailScreenState();
}
class _UserDetailScreenState extends State<_UserDetailScreen> {
  Map<String, dynamic>? _data; bool _loading = true, _generating = false;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await AdminService.getUserDetail(widget.userId);
    if (mounted) setState(() { _data = d; _loading = false; });
  }
  Future<void> _generateReport({required bool asProvider}) async {
    DateTime? from, to;
    await showDialog(context: context, builder: (dCtx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
      title: Text(asProvider ? "Provider Report" : "Customer Report"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _DateTile("From", from, () async {
          final d = await showDatePicker(context: ctx, initialDate: DateTime.now().subtract(const Duration(days: 30)), firstDate: DateTime(2024), lastDate: DateTime.now());
          if (d != null) setS(() => from = d);
        }),
        const SizedBox(height: 10),
        _DateTile("To", to, () async {
          final d = await showDatePicker(context: ctx, initialDate: DateTime.now(), firstDate: from ?? DateTime(2024), lastDate: DateTime.now());
          if (d != null) setS(() => to = d);
        }),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancel")),
        ElevatedButton(onPressed: (from == null || to == null) ? null : () => Navigator.pop(dCtx), child: const Text("Generate"))],
    )));
    if (from == null || to == null) return;
    setState(() => _generating = true);
    try {
      Map<String, dynamic> result = asProvider
          ? await AdminService.generateProviderReport(providerId: widget.userId, dateFrom: from!, dateTo: to!)
          : await AdminService.generateUserReport(userId: widget.userId, dateFrom: from!, dateTo: to!);
      if (!mounted) return;
      if (result["empty"] == true) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No activity in range"))); return; }
      if (result.containsKey("error")) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result["error"].toString()))); return; }
      final rd = result["reportData"] as Map<String, dynamic>;
      final bytes = asProvider ? await AdminPdfBuilder.buildProviderReport(rd) : await AdminPdfBuilder.buildUserReport(rd);
      final name = _data?["user"]?["name"]?.toString() ?? "user";
      await Printing.sharePdf(bytes: bytes, filename: "${asProvider ? 'provider' : 'customer'}_${name.replaceAll(' ','_')}.pdf");
    } finally { if (mounted) setState(() => _generating = false); }
  }
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_data == null) return Scaffold(body: Center(child: Text("Failed to load", style: tt.bodySmall)));
    final user = _data!["user"] as Map? ?? {};
    final skills = _data!["skills"] as List? ?? [];
    final seekBk = _data!["seekerBookings"] as List? ?? [];
    final provBk = _data!["providerBookings"] as List? ?? [];
    final isProvider = skills.isNotEmpty;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(user["name"]?.toString() ?? "User", style: tt.titleLarge),
        backgroundColor: cs.surfaceContainerLowest, surfaceTintColor: Colors.transparent,
        actions: [_generating
            ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : PopupMenuButton<String>(
                icon: const Icon(Icons.download_rounded),
                onSelected: (v) { if (v == "customer") _generateReport(asProvider: false); if (v == "provider") _generateReport(asProvider: true); },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: "customer", child: ListTile(leading: Icon(Icons.person_outline), title: Text("Customer Report"), contentPadding: EdgeInsets.zero)),
                  if (isProvider) const PopupMenuItem(value: "provider", child: ListTile(leading: Icon(Icons.work_outline), title: Text("Provider Report"), contentPadding: EdgeInsets.zero)),
                ])],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF0F0E17) : cs.surface, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.8), width: isDark ? 0.6 : 0.8)),
          child: Column(children: [
            _Row(cs, tt, "Name",     user["name"]?.toString() ?? "-"),
            _Row(cs, tt, "Email",    user["email"]?.toString() ?? "-"),
            _Row(cs, tt, "Phone",    user["phone"]?.toString() ?? "-"),
            _Row(cs, tt, "Role",     isProvider ? "Provider + Customer" : "Customer"),
            _Row(cs, tt, "District", (user["address"] as Map?)?["district"]?.toString() ?? "-"),
            _Row(cs, tt, "Joined",   _fmtDate(user["createdAt"]?.toString())),
          ])),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MiniStat("As Customer", "${seekBk.length}", const Color(0xFF60A5FA), cs, tt, isDark)),
          const SizedBox(width: 10),
          Expanded(child: _MiniStat("As Provider", "${provBk.length}", const Color(0xFFA78BFA), cs, tt, isDark)),
        ]),
      ])),
    );
  }
}

class _Row extends StatelessWidget {
  final ColorScheme cs; final TextTheme tt; final String l, v;
  const _Row(this.cs, this.tt, this.l, this.v);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 90, child: Text(l, style: tt.labelSmall)),
      Expanded(child: Text(v, style: tt.labelLarge)),
    ]));
}

class _MiniStat extends StatelessWidget {
  final String label, value; final Color color;
  final ColorScheme cs; final TextTheme tt; final bool isDark;
  const _MiniStat(this.label, this.value, this.color, this.cs, this.tt, this.isDark);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: isDark ? Color.alphaBlend(color.withOpacity(0.05), const Color(0xFF0F0E17)) : cs.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(isDark ? 0.2 : 0.15), width: 0.8)),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 4),
      Text(label, style: tt.labelSmall),
    ]));
}

// Date tile helper
class _DateTile extends StatelessWidget {
  final String label; final DateTime? date; final VoidCallback onTap;
  const _DateTile(this.label, this.date, this.onTap);
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: date != null ? cs.primary.withOpacity(0.4) : cs.outlineVariant.withOpacity(0.5), width: 0.8)),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 15, color: date != null ? cs.primary : cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            Text(date != null ? "${date!.day.toString().padLeft(2,'0')}/${date!.month.toString().padLeft(2,'0')}/${date!.year}" : "Tap to pick",
                style: TextStyle(fontSize: 14, fontWeight: date != null ? FontWeight.w600 : FontWeight.normal,
                    color: date != null ? cs.primary : cs.onSurfaceVariant.withOpacity(0.6))),
          ]),
        ])));
  }
}

extension _StringExt on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}
