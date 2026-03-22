import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/auth/auth_service.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';
import 'package:skill_renting_app/features/auth/screens/login_screen.dart';
import 'admin_service.dart';
import 'admin_pdf_builder.dart';
import 'package:skill_renting_app/core/widgets/dark_theme_toggle.dart';
import 'package:skill_renting_app/core/theme/theme_toggle_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers shared across the file
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
    case "accepted":    return Colors.blue;
    case "in_progress": return Colors.purple;
    case "completed":   return Colors.green;
    case "rejected":    return Colors.red;
    case "cancelled":   return Colors.grey;
    default:            return Colors.orange;
  }
}

const _kPrimary = Color(0xFF1A237E);

// ─────────────────────────────────────────────────────────────────────────────
// Root dashboard
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
    return AppScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.admin_panel_settings,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Text("Admin Panel",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        actions: [
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Logout",
              onPressed: _logout),
          IconButton(
              icon: const Icon(Icons.brightness_6),
              tooltip: "Toggle theme",
              onPressed: () =>
                  ThemeToggleController.setDarkEnabled(!ThemeToggleController.isDark)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: _kPrimary,
            child: Row(
              children: [
                _TabItem("Overview",  Icons.dashboard,     0, _tab, (i) => setState(() => _tab = i)),
                _TabItem("Users",     Icons.people,        1, _tab, (i) => setState(() => _tab = i)),
                _TabItem("Bookings",  Icons.calendar_today, 2, _tab, (i) => setState(() => _tab = i)),
              ],
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: const [
          _OverviewTab(),
          _UsersTab(),
          _BookingsTab(),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final int index, current;
  final void Function(int) onTap;
  const _TabItem(this.label, this.icon, this.index, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
              color: sel ? Colors.white : Colors.transparent, width: 3)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: sel ? Colors.white : Colors.white60),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
              color: sel ? Colors.white : Colors.white60,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              fontSize: 13)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OVERVIEW TAB
// ═══════════════════════════════════════════════════════════════════════════
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

  void _navigate(String statKey) {
    switch (statKey) {
      case "totalUsers":
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => const _UsersListScreen(roleFilter: "all")));
        break;
      case "totalProviders":
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => const _UsersListScreen(roleFilter: "provider")));
        break;
      case "totalBookings":
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => const _AllBookingsScreen(statusFilter: null)));
        break;
      case "completedBookings":
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => const _AllBookingsScreen(statusFilter: "completed")));
        break;
      case "pendingBookings":
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => const _AllBookingsScreen(statusFilter: "requested")));
        break;
      case "revenue":
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => const _RevenueScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_kPrimary, Color(0xFF3949AB)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Welcome, Admin",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("joshuakuriakose1712@gmail.com",
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 24),
            const Text("Platform Statistics",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12, crossAxisSpacing: 12,
              childAspectRatio: 1.7,
              children: [
                _StatCard("Total Users",    "${_stats["totalUsers"]        ?? 0}", Icons.people,          const Color(0xFF1565C0), () => _navigate("totalUsers")),
                _StatCard("Providers",      "${_stats["totalProviders"]    ?? 0}", Icons.work,             const Color(0xFF6A1B9A), () => _navigate("totalProviders")),
                _StatCard("Total Bookings", "${_stats["totalBookings"]     ?? 0}", Icons.calendar_today,   const Color(0xFF2E7D32), () => _navigate("totalBookings")),
                _StatCard("Completed",      "${_stats["completedBookings"] ?? 0}", Icons.task_alt,         const Color(0xFF00695C), () => _navigate("completedBookings")),
                _StatCard("Pending",        "${_stats["pendingBookings"]   ?? 0}", Icons.hourglass_empty,  const Color(0xFFE65100), () => _navigate("pendingBookings")),
                _StatCard("Revenue",
                    "Rs. ${(_stats["totalRevenue"] ?? 0).toStringAsFixed(0)}",
                    Icons.currency_rupee, const Color(0xFF1B5E20), () => _navigate("revenue")),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// USERS TAB
// ═══════════════════════════════════════════════════════════════════════════
class _UsersTab extends StatefulWidget {
  const _UsersTab();
  @override State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List _users = [];
  int _total = 0;
  bool _loading = true;
  String _roleFilter = "all";
  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose()   { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getUsers(
        role: _roleFilter == "all" ? null : _roleFilter,
        search: _searchCtrl.text.trim());
    if (mounted) setState(() {
      _users  = res["users"] as List? ?? [];
      _total  = res["total"] as int?  ?? 0;
      _loading = false;
    });
  }

  Future<void> _showBulkReportDialog() async {
    String? role, district, pricingUnit;
    DateTime? from, to;
    List<String> districts = [];
    bool loadingDistricts = true;

    // Load districts
    AdminService.getDistricts().then((d) {
      districts = d;
      loadingDistricts = false;
    });

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Bulk User Report",
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Role
              _FilterDropdown("Role", ["all","seeker","provider"],
                  ["All","Customers","Providers"], role ?? "all",
                  (v) => setS(() => role = v == "all" ? null : v)),
              const SizedBox(height: 10),
              // District
              loadingDistricts
                  ? const LinearProgressIndicator()
                  : _FilterDropdown(
                      "District",
                      ["all", ...districts],
                      ["All Districts", ...districts],
                      district ?? "all",
                      (v) => setS(() => district = v == "all" ? null : v)),
              const SizedBox(height: 10),
              // Pricing unit
              _FilterDropdown("Service Type",
                  ["all","hour","day","task"],
                  ["All Types","Hourly","Daily","Per Task"],
                  pricingUnit ?? "all",
                  (v) => setS(() => pricingUnit = v == "all" ? null : v)),
              const SizedBox(height: 12),
              _DateTile("From", from, () async {
                final d = await showDatePicker(context: ctx,
                    initialDate: DateTime.now().subtract(const Duration(days: 30)),
                    firstDate: DateTime(2024), lastDate: DateTime.now());
                if (d != null) setS(() => from = d);
              }),
              const SizedBox(height: 8),
              _DateTile("To", to, () async {
                final d = await showDatePicker(context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: from ?? DateTime(2024), lastDate: DateTime.now());
                if (d != null) setS(() => to = d);
              }),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: (from == null || to == null) ? null : () => Navigator.pop(dCtx),
              child: const Text("Generate"),
            ),
          ],
        ),
      ),
    );

    if (from == null || to == null) return;

    if (!mounted) return;
    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(const SnackBar(
        content: Text("Generating report…"),
        duration: Duration(seconds: 30)));

    final result = await AdminService.generateBulkUserReport(
        role: role, district: district, pricingUnit: pricingUnit,
        dateFrom: from!, dateTo: to!);

    snack.hideCurrentSnackBar();
    if (!mounted) return;

    if (result["empty"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No users match the selected filters")));
      return;
    }
    if (result.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result["error"].toString())));
      return;
    }

    final bytes = await AdminPdfBuilder.buildBulkUserReport(
        result["reportData"] as Map<String, dynamic>);
    await Printing.sharePdf(bytes: bytes, filename: "bulk_user_report.pdf");
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: "Search by name, email or phone…",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear),
                          onPressed: () { _searchCtrl.clear(); _load(); })
                      : null,
                  filled: true, fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
            const SizedBox(width: 8),
            // Bulk report button
            ElevatedButton.icon(
              onPressed: _showBulkReportDialog,
              icon: const Icon(Icons.download, size: 16),
              label: const Text("Report", style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text("$_total users",
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            const Spacer(),
            ...[["all","All"],["seeker","Customers"],["provider","Providers"]].map((f) {
              final sel = _roleFilter == f[0];
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: FilterChip(
                  label: Text(f[1], style: TextStyle(
                      fontSize: 12, color: sel ? Colors.white : null)),
                  selected: sel, selectedColor: _kPrimary,
                  onSelected: (_) { setState(() => _roleFilter = f[0]); _load(); },
                ),
              );
            }),
          ]),
        ]),
      ),
      Divider(height: 1, color: Colors.grey.shade200),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
                ? const Center(child: Text("No users found"))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final u = _users[i] as Map;
                        return _UserCard(
                          user: u,
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => _UserDetailScreen(
                                  userId: u["_id"].toString()))),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOOKINGS TAB — lists skills, not bookings
// ═══════════════════════════════════════════════════════════════════════════
class _BookingsTab extends StatefulWidget {
  const _BookingsTab();
  @override State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  List _skills = [];
  bool _loading = true;
  DateTime? _dateFrom, _dateTo;
  final _searchCtrl = TextEditingController();

  @override void initState() { super.initState(); _load(); }
  @override void dispose()   { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getBookingsBySkill(
      search:   _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      dateFrom: _dateFrom?.toIso8601String(),
      dateTo:   _dateTo?.toIso8601String(),
    );
    if (mounted) setState(() { _skills = res; _loading = false; });
  }

  Future<void> _downloadReport() async {
    DateTime? from = _dateFrom, to = _dateTo;

    if (from == null || to == null) {
      // Ask for date range if not already filtered
      await showDialog(
        context: context,
        builder: (dCtx) => StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: const Text("Bookings Report"),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              _DateTile("From", from, () async {
                final d = await showDatePicker(context: ctx,
                    initialDate: DateTime.now().subtract(const Duration(days: 30)),
                    firstDate: DateTime(2024), lastDate: DateTime.now());
                if (d != null) setS(() => from = d);
              }),
              const SizedBox(height: 8),
              _DateTile("To", to, () async {
                final d = await showDatePicker(context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: from ?? DateTime(2024), lastDate: DateTime.now());
                if (d != null) setS(() => to = d);
              }),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancel")),
              ElevatedButton(
                  onPressed: (from == null || to == null) ? null : () => Navigator.pop(dCtx),
                  child: const Text("Generate")),
            ],
          ),
        ),
      );
    }

    if (from == null || to == null) return;

    if (!mounted) return;
    final snack = ScaffoldMessenger.of(context);
    snack.showSnackBar(const SnackBar(
        content: Text("Generating report…"), duration: Duration(seconds: 30)));

    final result = await AdminService.generateBookingsReport(
        dateFrom: from!, dateTo: to!);
    snack.hideCurrentSnackBar();
    if (!mounted) return;

    if (result["empty"] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No bookings found in selected range")));
      return;
    }
    if (result.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result["error"].toString())));
      return;
    }

    final bytes = await AdminPdfBuilder.buildBookingsReport(
        result["reportData"] as Map<String, dynamic>);
    await Printing.sharePdf(bytes: bytes, filename: "bookings_report.pdf");
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: "Search by skill or provider…",
                  prefixIcon: const Icon(Icons.search),
                  filled: true, fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _downloadReport,
              icon: const Icon(Icons.download, size: 16),
              label: const Text("Report", style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary, foregroundColor: Colors.white,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
            ),
          ]),
          const SizedBox(height: 8),
          // Date range filter
          Row(children: [
            Expanded(child: _SmallDateTile("From", _dateFrom, () async {
              final d = await showDatePicker(context: context,
                  initialDate: _dateFrom ?? DateTime.now().subtract(const Duration(days: 30)),
                  firstDate: DateTime(2024), lastDate: DateTime.now());
              if (d != null) setState(() { _dateFrom = d; _load(); });
            })),
            const SizedBox(width: 8),
            Expanded(child: _SmallDateTile("To", _dateTo, () async {
              final d = await showDatePicker(context: context,
                  initialDate: _dateTo ?? DateTime.now(),
                  firstDate: _dateFrom ?? DateTime(2024), lastDate: DateTime.now());
              if (d != null) setState(() { _dateTo = d; _load(); });
            })),
            if (_dateFrom != null || _dateTo != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => setState(() { _dateFrom = null; _dateTo = null; _load(); }),
                tooltip: "Clear dates",
              ),
            ],
          ]),
        ]),
      ),
      Divider(height: 1, color: Colors.grey.shade200),
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _skills.isEmpty
                ? const Center(child: Text("No bookings found"))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _skills.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final s = _skills[i] as Map;
                        return _SkillBookingCard(
                          skillGroup: s,
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => _SkillBookingsScreen(
                                skillId: s["_id"].toString(),
                                skillTitle: (s["skill"] as Map?)
                                    ?["title"]?.toString() ?? "-",
                                dateFrom: _dateFrom,
                                dateTo: _dateTo,
                              ))),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Revenue screen
// ═══════════════════════════════════════════════════════════════════════════
class _RevenueScreen extends StatefulWidget {
  const _RevenueScreen();
  @override State<_RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<_RevenueScreen> {
  List _bookings = [];
  double _grandTotal = 0;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getRevenue();
    if (mounted) setState(() {
      _bookings   = res["bookings"]   as List?   ?? [];
      _grandTotal = (res["grandTotal"] as num?)?.toDouble() ?? 0;
      _loading    = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: _kPrimary, foregroundColor: Colors.white,
        title: const Text("Revenue — Completed Payments"),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: const Color(0xFF1B5E20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Total Revenue",
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text("Rs. ${_grandTotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                          color: Colors.white, fontSize: 28,
                          fontWeight: FontWeight.bold)),
                  Text("${_bookings.length} paid bookings",
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _RevenueTile(booking: _bookings[i] as Map),
                  ),
                ),
              ),
            ]),
    );
  }
}

class _RevenueTile extends StatelessWidget {
  final Map booking;
  const _RevenueTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final seeker   = (booking["seeker"]   as Map?)?["name"]?.toString() ?? "-";
    final provider = (booking["provider"] as Map?)?["name"]?.toString() ?? "-";
    final skill    = (booking["skill"]    as Map?)?["title"]?.toString() ?? "-";
    final amount   = (booking["totalAmount"] as num?)?.toDouble() ?? 0;
    final date     = _fmtDate(booking["startDate"]?.toString());

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: Colors.green.shade50, shape: BoxShape.circle),
          child: Icon(Icons.currency_rupee, color: Colors.green.shade700, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(skill, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 3),
            Text("$seeker  →  $provider",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            Text(date, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ]),
        ),
        Text("Rs. ${amount.toStringAsFixed(0)}",
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold,
                color: Colors.green.shade700)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Simple filtered user list (from stat card taps)
// ═══════════════════════════════════════════════════════════════════════════
class _UsersListScreen extends StatefulWidget {
  final String roleFilter;
  const _UsersListScreen({required this.roleFilter});
  @override State<_UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<_UsersListScreen> {
  List _users = [];
  int _total  = 0;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getUsers(
        role: widget.roleFilter == "all" ? null : widget.roleFilter);
    if (mounted) setState(() {
      _users  = res["users"] as List? ?? [];
      _total  = res["total"] as int?  ?? 0;
      _loading = false;
    });
  }

  String get _title {
    switch (widget.roleFilter) {
      case "provider": return "Providers ($_total)";
      case "seeker":   return "Customers ($_total)";
      default:         return "All Users ($_total)";
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(backgroundColor: _kPrimary, foregroundColor: Colors.white,
          title: Text(_title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _users.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final u = _users[i] as Map;
                return _UserCard(user: u, onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) =>
                        _UserDetailScreen(userId: u["_id"].toString()))));
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// All bookings screen (flat list — from stat card taps)
// ═══════════════════════════════════════════════════════════════════════════
class _AllBookingsScreen extends StatefulWidget {
  final String? statusFilter;
  const _AllBookingsScreen({this.statusFilter});
  @override State<_AllBookingsScreen> createState() => _AllBookingsScreenState();
}

class _AllBookingsScreenState extends State<_AllBookingsScreen> {
  List _bookings = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getBookings(status: widget.statusFilter);
    if (mounted) setState(() {
      _bookings = res["bookings"] as List? ?? [];
      _loading  = false;
    });
  }

  String get _title {
    if (widget.statusFilter == null) return "All Bookings";
    return "${widget.statusFilter!.replaceAll('_',' ').capitalize()} Bookings";
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(backgroundColor: _kPrimary, foregroundColor: Colors.white,
          title: Text(_title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _BookingDetailCard(
                  booking: _bookings[i] as Map, showDownload: false),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Skill bookings screen — bookings within a single skill
// ═══════════════════════════════════════════════════════════════════════════
class _SkillBookingsScreen extends StatefulWidget {
  final String skillId, skillTitle;
  final DateTime? dateFrom, dateTo;
  const _SkillBookingsScreen({
    required this.skillId, required this.skillTitle,
    this.dateFrom, this.dateTo,
  });
  @override State<_SkillBookingsScreen> createState() => _SkillBookingsScreenState();
}

class _SkillBookingsScreenState extends State<_SkillBookingsScreen> {
  List _bookings = [];
  bool _loading = true;
  String? _statusFilter;
  bool _generating = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await AdminService.getBookingsForSkill(
      widget.skillId,
      status:   _statusFilter,
      dateFrom: widget.dateFrom?.toIso8601String(),
      dateTo:   widget.dateTo?.toIso8601String(),
    );
    if (mounted) setState(() { _bookings = res; _loading = false; });
  }

  Future<void> _downloadReport() async {
    final from = widget.dateFrom ?? DateTime.now().subtract(const Duration(days: 30));
    final to   = widget.dateTo   ?? DateTime.now();

    setState(() => _generating = true);
    final result = await AdminService.generateBookingsReport(
        skillId: widget.skillId, dateFrom: from, dateTo: to,
        status: _statusFilter);
    setState(() => _generating = false);
    if (!mounted) return;

    if (result["empty"] == true || result.containsKey("error")) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result["empty"] == true
              ? "No bookings in range" : result["error"].toString())));
      return;
    }

    final bytes = await AdminPdfBuilder.buildBookingsReport(
        result["reportData"] as Map<String, dynamic>);
    await Printing.sharePdf(
        bytes: bytes,
        filename: "report_${widget.skillTitle.replaceAll(' ','_')}.pdf");
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: _kPrimary, foregroundColor: Colors.white,
        title: Text(widget.skillTitle),
        actions: [
          _generating
              ? const Padding(padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: "Download PDF",
                  onPressed: _downloadReport),
        ],
      ),
      body: Column(children: [
        // Status filter
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ...[
                [null, "All"],
                ["requested", "Pending"],
                ["accepted", "Accepted"],
                ["in_progress", "In Progress"],
                ["completed", "Completed"],
                ["rejected", "Rejected"],
              ].map((f) {
                final sel = _statusFilter == f[0];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(f[1]!, style: TextStyle(
                        fontSize: 12, color: sel ? Colors.white : null)),
                    selected: sel, selectedColor: _kPrimary,
                    onSelected: (_) { setState(() => _statusFilter = f[0]); _load(); },
                  ),
                );
              }),
            ]),
          ),
        ),
        Divider(height: 1, color: Colors.grey.shade200),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _bookings.isEmpty
                  ? const Center(child: Text("No bookings found"))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: _bookings.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _BookingDetailCard(
                            booking: _bookings[i] as Map, showDownload: true),
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Booking detail card — tappable, shows full detail in bottom sheet
// ═══════════════════════════════════════════════════════════════════════════
class _BookingDetailCard extends StatelessWidget {
  final Map booking;
  final bool showDownload;
  const _BookingDetailCard({required this.booking, required this.showDownload});

  @override
  Widget build(BuildContext context) {
    final status   = booking["status"]?.toString() ?? "";
    final seeker   = (booking["seeker"]   as Map?)?["name"]?.toString()  ?? "N/A";
    final provider = (booking["provider"] as Map?)?["name"]?.toString()  ?? "N/A";
    final skill    = (booking["skill"]    as Map?)?["title"]?.toString() ?? "N/A";
    final fee      = (booking["pricingSnapshot"] as Map?)?["amount"] ?? 0;
    final date     = _fmtDate(booking["startDate"]?.toString());
    final color    = _statusColor(status);

    return InkWell(
      onTap: () => _showDetail(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(skill,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(status.replaceAll("_"," ").toUpperCase(),
                  style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.person_outline, size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Expanded(child: Text("$seeker  →  $provider",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
            Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.currency_rupee, size: 13, color: Colors.grey.shade400),
            Text("Rs. $fee",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Spacer(),
            Text("Tap for details →",
                style: TextStyle(fontSize: 11, color: Colors.indigo.shade300)),
          ]),
        ]),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingDetailSheet(booking: booking),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Booking detail bottom sheet
// ═══════════════════════════════════════════════════════════════════════════
class _BookingDetailSheet extends StatelessWidget {
  final Map booking;
  const _BookingDetailSheet({required this.booking});

  @override
  Widget build(BuildContext context) {
    final status   = booking["status"]?.toString() ?? "";
    final seeker   = booking["seeker"]   as Map? ?? {};
    final provider = booking["provider"] as Map? ?? {};
    final skill    = booking["skill"]    as Map? ?? {};
    final addr     = booking["jobAddress"] as Map? ?? {};
    final review   = booking["review"]   as Map?;
    final color    = _statusColor(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Expanded(child: Text(skill["title"]?.toString() ?? "-",
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(status.replaceAll("_"," ").toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ]),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.all(20),
              children: [
                _SheetSection("Customer", [
                  _SheetRow(Icons.person, seeker["name"]?.toString() ?? "-"),
                  _SheetRow(Icons.phone, seeker["phone"]?.toString() ?? "-"),
                ]),
                _SheetSection("Provider", [
                  _SheetRow(Icons.work, provider["name"]?.toString() ?? "-"),
                  _SheetRow(Icons.phone, provider["phone"]?.toString() ?? "-"),
                ]),
                _SheetSection("Job Details", [
                  _SheetRow(Icons.description, booking["jobDescription"]?.toString() ?? "-"),
                  _SheetRow(Icons.location_on,
                      [addr["locality"], addr["district"]]
                          .where((s) => s != null && s.toString().isNotEmpty)
                          .join(", ").ifEmpty("-")),
                  _SheetRow(Icons.calendar_today, _fmtDateTime(booking["startDate"]?.toString())),
                  _SheetRow(Icons.timer, _fmtDateTime(booking["endDate"]?.toString())),
                ]),
                _SheetSection("Payment", [
                  _SheetRow(Icons.currency_rupee,
                      "Base: Rs. ${(booking["pricingSnapshot"] as Map?)?["amount"] ?? 0}"),
                  if ((booking["extraCharges"] as num? ?? 0) > 0)
                    _SheetRow(Icons.add, "Extra: Rs. ${booking["extraCharges"]}"),
                  _SheetRow(Icons.payments,
                      "Total: Rs. ${booking["totalAmount"] ?? (booking["pricingSnapshot"] as Map?)?["amount"] ?? 0}"),
                  _SheetRow(Icons.check_circle,
                      booking["paymentStatus"] == "paid" ? "Received" : "Pending"),
                ]),
                if (review != null)
                  _SheetSection("Review", [
                    _SheetRow(Icons.star,
                        "${List.generate(5, (i) => i < (review["rating"] as num).toInt() ? "*" : "-").join()}  ${review["rating"]}/5"),
                    if ((review["comment"]?.toString() ?? "").isNotEmpty)
                      _SheetRow(Icons.comment, review["comment"].toString()),
                  ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SheetSection(this.title, this.children);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 13,
          color: _kPrimary)),
      const SizedBox(height: 8),
      ...children,
      const SizedBox(height: 16),
    ]);
  }
}

class _SheetRow extends StatelessWidget {
  final IconData icon;
  final String value;
  const _SheetRow(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(child: Text(value,
            style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// User detail screen
// ═══════════════════════════════════════════════════════════════════════════
class _UserDetailScreen extends StatefulWidget {
  final String userId;
  const _UserDetailScreen({required this.userId});
  @override State<_UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<_UserDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true, _generating = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    final d = await AdminService.getUserDetail(widget.userId);
    if (mounted) setState(() { _data = d; _loading = false; });
  }

  Future<void> _generateReport({required bool asProvider}) async {
    DateTime? from, to;
    await showDialog(
      context: context,
      builder: (dCtx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(asProvider ? "Provider Report" : "Customer Report"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _DateTile("From", from, () async {
              final d = await showDatePicker(context: ctx,
                  initialDate: DateTime.now().subtract(const Duration(days: 30)),
                  firstDate: DateTime(2024), lastDate: DateTime.now());
              if (d != null) setS(() => from = d);
            }),
            const SizedBox(height: 10),
            _DateTile("To", to, () async {
              final d = await showDatePicker(context: ctx,
                  initialDate: DateTime.now(),
                  firstDate: from ?? DateTime(2024), lastDate: DateTime.now());
              if (d != null) setS(() => to = d);
            }),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: (from == null || to == null) ? null : () => Navigator.pop(dCtx),
              child: const Text("Generate"),
            ),
          ],
        ),
      ),
    );
    if (from == null || to == null) return;

    setState(() => _generating = true);
    try {
      Map<String, dynamic> result;
      if (asProvider) {
        result = await AdminService.generateProviderReport(
            providerId: widget.userId, dateFrom: from!, dateTo: to!);
      } else {
        result = await AdminService.generateUserReport(
            userId: widget.userId, dateFrom: from!, dateTo: to!);
      }
      if (!mounted) return;
      if (result["empty"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No activity in selected range")));
        return;
      }
      if (result.containsKey("error")) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result["error"].toString())));
        return;
      }
      final rd = result["reportData"] as Map<String, dynamic>;
      final bytes = asProvider
          ? await AdminPdfBuilder.buildProviderReport(rd)
          : await AdminPdfBuilder.buildUserReport(rd);
      final name = _data?["user"]?["name"]?.toString() ?? "user";
      await Printing.sharePdf(bytes: bytes,
          filename: "${asProvider ? 'provider' : 'customer'}_${name.replaceAll(' ','_')}.pdf");
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_data == null) {
      return const AppScaffold(
        body: Center(child: Text("Failed to load")),
      );
    }

    final user      = _data!["user"]             as Map? ?? {};
    final skills    = _data!["skills"]           as List? ?? [];
    final seekBk    = _data!["seekerBookings"]   as List? ?? [];
    final provBk    = _data!["providerBookings"] as List? ?? [];
    final reviews   = _data!["reviewsReceived"]  as List? ?? [];
    final isProvider = skills.isNotEmpty;

    return AppScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: _kPrimary, foregroundColor: Colors.white,
        title: Text(user["name"]?.toString() ?? "User"),
        actions: [
          _generating
              ? const Padding(padding: EdgeInsets.all(14),
                  child: SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  onSelected: (v) {
                    if (v == "customer") _generateReport(asProvider: false);
                    if (v == "provider") _generateReport(asProvider: true);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: "customer",
                        child: ListTile(leading: Icon(Icons.person_outline),
                            title: Text("Customer Report"), contentPadding: EdgeInsets.zero)),
                    if (isProvider)
                      const PopupMenuItem(value: "provider",
                          child: ListTile(leading: Icon(Icons.work_outline),
                              title: Text("Provider Report"), contentPadding: EdgeInsets.zero)),
                  ],
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _DetailSection("User Details", Column(children: [
            _DetailRow("Name",     user["name"]?.toString()  ?? "-"),
            _DetailRow("Email",    user["email"]?.toString() ?? "-"),
            _DetailRow("Phone",    user["phone"]?.toString() ?? "-"),
            _DetailRow("Role",     isProvider ? "Provider + Customer" : "Customer"),
            _DetailRow("Locality", (user["address"] as Map?)?["locality"]?.toString() ?? "-"),
            _DetailRow("District", (user["address"] as Map?)?["district"]?.toString() ?? "-"),
            _DetailRow("Rating",   "${user["rating"] ?? 0} (${user["totalReviews"] ?? 0} reviews)"),
            _DetailRow("Joined",   _fmtDate(user["createdAt"]?.toString())),
          ])),
          if (isProvider) ...[
            const SizedBox(height: 16),
            _DetailSection("Services Offered (${skills.length})", Column(
              children: skills.map((s) {
                final sk = s as Map;
                return _DetailRow(sk["title"]?.toString() ?? "-",
                    "Rs. ${sk["pricing"]?["amount"]} / ${sk["pricing"]?["unit"]}  •  ${sk["isActive"] == true ? "Active" : "Inactive"}");
              }).toList(),
            )),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _MiniStat("As Customer", "${seekBk.length}", Colors.blue)),
            const SizedBox(width: 10),
            Expanded(child: _MiniStat("As Provider", "${provBk.length}", Colors.purple)),
            const SizedBox(width: 10),
            Expanded(child: _MiniStat("Reviews", "${reviews.length}", Colors.amber.shade700)),
          ]),
          if (seekBk.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailSection("Recent Bookings as Customer", Column(
              children: seekBk.take(5).map((b) {
                final bk = b as Map;
                return _DetailRow(
                    bk["skill"]?["title"]?.toString() ?? "-",
                    "${_fmtDate(bk["startDate"]?.toString())}  •  ${bk["status"] ?? "-"}");
              }).toList(),
            )),
          ],
          if (provBk.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailSection("Recent Jobs as Provider", Column(
              children: provBk.take(5).map((b) {
                final bk = b as Map;
                return _DetailRow(
                    bk["seeker"]?["name"]?.toString() ?? "-",
                    "${_fmtDate(bk["startDate"]?.toString())}  •  ${bk["status"] ?? "-"}");
              }).toList(),
            )),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Reusable small widgets
// ═══════════════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _StatCard(this.label, this.value, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            ],
          )),
          Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 18),
        ]),
      ),
    );
  }
}

class _SkillBookingCard extends StatelessWidget {
  final Map skillGroup;
  final VoidCallback onTap;
  const _SkillBookingCard({required this.skillGroup, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final skill      = skillGroup["skill"]   as Map? ?? {};
    final provider   = skill["provider"]     as Map? ?? {};
    final total      = skillGroup["totalBookings"] as int? ?? 0;
    final completed  = skillGroup["completed"] as int? ?? 0;
    final pending    = skillGroup["pending"]   as int? ?? 0;
    final revenue    = (skillGroup["revenue"] as num?)?.toDouble() ?? 0;
    final unit       = (skill["pricing"] as Map?)?["unit"]?.toString() ?? "hour";

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(skill["title"]?.toString() ?? "-",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(unit, style: TextStyle(
                  fontSize: 11, color: Colors.indigo.shade700,
                  fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Text("by ${provider["name"]?.toString() ?? "-"}",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 10),
          Row(children: [
            _MiniChip("$total total",     Colors.indigo),
            const SizedBox(width: 6),
            _MiniChip("$completed done",  Colors.green),
            const SizedBox(width: 6),
            _MiniChip("$pending pending", Colors.orange),
            const Spacer(),
            Text("Rs. ${revenue.toStringAsFixed(0)}",
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: Colors.green.shade700, fontSize: 13)),
          ]),
        ]),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String text;
  final Color color;
  const _MiniChip(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
  );
}

class _UserCard extends StatelessWidget {
  final Map user;
  final VoidCallback onTap;
  const _UserCard({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name       = user["name"]?.toString()  ?? "User";
    final email      = user["email"]?.toString() ?? "";
    final phone      = user["phone"]?.toString() ?? "";
    final isProvider = user["isProvider"] == true;
    final district   = (user["address"] as Map?)?["district"]?.toString() ?? "";

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isProvider ? Colors.purple.shade100 : Colors.blue.shade100,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : "U",
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: isProvider ? Colors.purple.shade700 : Colors.blue.shade700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: isProvider ? Colors.purple.shade50 : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(isProvider ? "Provider" : "Customer",
                  style: TextStyle(fontSize: 11,
                      color: isProvider ? Colors.purple.shade700 : Colors.blue.shade700,
                      fontWeight: FontWeight.w500)),
            ),
            if (district.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(district, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
            ],
          ]),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
        ]),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _DetailSection(this.title, this.child);
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 6, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade500))),
      Expanded(child: Text(value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ]),
  );
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _DateTile(this.label, this.date, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: date != null ? Colors.indigo.shade200 : Colors.grey.shade200),
      ),
      child: Row(children: [
        Icon(Icons.calendar_today, size: 16, color: date != null ? Colors.indigo : Colors.grey),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          Text(date != null
              ? "${date!.day.toString().padLeft(2,'0')}/${date!.month.toString().padLeft(2,'0')}/${date!.year}"
              : "Tap to pick",
              style: TextStyle(fontSize: 14,
                  fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                  color: date != null ? Colors.indigo.shade700 : Colors.grey.shade400)),
        ]),
      ]),
    ),
  );
}

class _SmallDateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  const _SmallDateTile(this.label, this.date, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: date != null ? Colors.indigo.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: date != null ? Colors.indigo.shade200 : Colors.grey.shade200),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.calendar_today, size: 13,
            color: date != null ? Colors.indigo : Colors.grey.shade400),
        const SizedBox(width: 6),
        Text(date != null
            ? "$label: ${date!.day.toString().padLeft(2,'0')}/${date!.month.toString().padLeft(2,'0')}/${date!.year}"
            : label,
            style: TextStyle(fontSize: 12,
                color: date != null ? Colors.indigo.shade700 : Colors.grey.shade400)),
      ]),
    ),
  );
}

class _FilterDropdown extends StatelessWidget {
  final String label;
  final List<String> values, labels;
  final String current;
  final void Function(String) onChanged;
  const _FilterDropdown(this.label, this.values, this.labels, this.current, this.onChanged);

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: current,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      filled: true, fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    items: List.generate(values.length, (i) =>
        DropdownMenuItem(value: values[i], child: Text(labels[i]))),
    onChanged: (v) { if (v != null) onChanged(v); },
  );
}

// String extension
extension _StringExt on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
