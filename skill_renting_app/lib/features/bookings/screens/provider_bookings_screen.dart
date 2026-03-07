import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import '../models/booking_model.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
import 'package:skill_renting_app/features/bookings/screens/navigation_screen.dart';

class ProviderBookingsScreen extends StatefulWidget {
  const ProviderBookingsScreen({super.key});

  @override
  State<ProviderBookingsScreen> createState() =>
      _ProviderBookingsScreenState();
}

class _ProviderBookingsScreenState extends State<ProviderBookingsScreen>
    with SingleTickerProviderStateMixin {
  List<BookingModel> _bookings = [];
  bool _loading = true;
  final Set<String> _busy = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    final data = await BookingService.fetchProviderBookings();
    // Sort latest first (createdAt desc)
    data.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) setState(() { _bookings = data; _loading = false; });
  }

  Future<void> _updateStatus(String id, String action) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final success = await BookingService.updateBookingStatus(id, action);
      if (!success || !mounted) return;
      setState(() {
        final i = _bookings.indexWhere((b) => b.id == id);
        if (i != -1) {
          final newStatus = action == "accept"
              ? "accepted"
              : action == "reject"
                  ? "rejected"
                  : "completed";
          _bookings[i] = _bookings[i].copyWith(status: newStatus);
        }
      });
      if (action == "accept") {
        final fresh = await BookingService.fetchProviderBookings();
        fresh.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (mounted) setState(() => _bookings = fresh);
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  List<BookingModel> get _requests =>
      _bookings.where((b) => b.status == "requested").toList();

  List<BookingModel> get _otherBookings =>
      _bookings.where((b) => b.status != "requested").toList();

  /// Groups requests by skillId → Map<skillId, {title, bookings}>
  Map<String, _SkillGroup> get _requestsBySkill {
    final map = <String, _SkillGroup>{};
    for (final b in _requests) {
      map.putIfAbsent(
        b.skillId,
        () => _SkillGroup(skillId: b.skillId, skillTitle: b.skillTitle),
      ).bookings.add(b);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Bookings"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Requests"),
                  if (_requests.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(_requests.length, Colors.orange),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Bookings"),
                  if (_otherBookings.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(_otherBookings.length, Colors.blue),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const SkeletonList()
          : TabBarView(
              controller: _tabController,
              children: [
                _RequestsTab(
                  groups: _requestsBySkill,
                  busy: _busy,
                  onAccept: (id) => _updateStatus(id, "accept"),
                  onReject: (id) => _updateStatus(id, "reject"),
                  onTap: (b) => _showDetailSheet(b),
                ),
                _BookingsTab(
                  bookings: _otherBookings,
                  busy: _busy,
                  onComplete: (id) => _updateStatus(id, "complete"),
                  onNavigate: (b) => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NavigationScreen(
                        jobLat: b.jobGpsLat!,
                        jobLng: b.jobGpsLng!,
                        seekerName: b.seekerName,
                        jobAddress: b.jobAddressFormatted,
                      ),
                    ),
                  ),
                  onTap: (b) => _showDetailSheet(b),
                ),
              ],
            ),
    );
  }

  // ── Full detail bottom sheet ───────────────────────────────────────────────
  void _showDetailSheet(BookingModel b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookingDetailSheet(
        booking: b,
        isBusy: _busy.contains(b.id),
        onAccept: b.status == "requested"
            ? () { Navigator.pop(context); _updateStatus(b.id, "accept"); }
            : null,
        onReject: b.status == "requested"
            ? () { Navigator.pop(context); _updateStatus(b.id, "reject"); }
            : null,
        onComplete: b.status == "accepted"
            ? () { Navigator.pop(context); _updateStatus(b.id, "complete"); }
            : null,
        onNavigate: b.hasGps
            ? () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NavigationScreen(
                      jobLat: b.jobGpsLat!,
                      jobLng: b.jobGpsLng!,
                      seekerName: b.seekerName,
                      jobAddress: b.jobAddressFormatted,
                    ),
                  ),
                );
              }
            : null,
      ),
    );
  }
}

// ── Requests tab — grouped by skill ──────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  final Map<String, _SkillGroup> groups;
  final Set<String> busy;
  final void Function(String id) onAccept;
  final void Function(String id) onReject;
  final void Function(BookingModel) onTap;

  const _RequestsTab({
    required this.groups,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(
          child: Text("No pending requests", style: TextStyle(color: Colors.grey)));
    }

    final groupList = groups.values.toList();

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: groupList.length,
        itemBuilder: (context, gi) {
          final group = groupList[gi];
          // Single skill provider — skip grouping header
          if (groups.length == 1) {
            return Column(
              children: group.bookings
                  .map((b) => _RequestCard(
                        booking: b,
                        isBusy: busy.contains(b.id),
                        onAccept: () => onAccept(b.id),
                        onReject: () => onReject(b.id),
                        onTap: () => onTap(b),
                      ))
                  .toList(),
            );
          }
          // Multiple skills — show expandable group
          return _SkillGroupTile(
            group: group,
            busy: busy,
            onAccept: onAccept,
            onReject: onReject,
            onTap: onTap,
          );
        },
      ),
    );
  }
}

// ── Skill group expandable tile ───────────────────────────────────────────────

class _SkillGroupTile extends StatefulWidget {
  final _SkillGroup group;
  final Set<String> busy;
  final void Function(String) onAccept;
  final void Function(String) onReject;
  final void Function(BookingModel) onTap;

  const _SkillGroupTile({
    required this.group,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onTap,
  });

  @override
  State<_SkillGroupTile> createState() => _SkillGroupTileState();
}

class _SkillGroupTileState extends State<_SkillGroupTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          // Group header
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.group.skillTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  _Badge(widget.group.bookings.length, Colors.orange),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0 : -0.25,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          // Requests list
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: widget.group.bookings
                  .map((b) => _RequestCard(
                        booking: b,
                        isBusy: widget.busy.contains(b.id),
                        onAccept: () => widget.onAccept(b.id),
                        onReject: () => widget.onReject(b.id),
                        onTap: () => widget.onTap(b),
                        nested: true,
                      ))
                  .toList(),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Compact request card ──────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final BookingModel booking;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onTap;
  final bool nested;

  const _RequestCard({
    required this.booking,
    required this.isBusy,
    required this.onAccept,
    required this.onReject,
    required this.onTap,
    this.nested = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(nested ? 0 : 14),
      child: Container(
        margin: nested
            ? const EdgeInsets.symmetric(horizontal: 0)
            : const EdgeInsets.only(bottom: 10),
        decoration: nested
            ? BoxDecoration(
                border: Border(
                    top: BorderSide(color: Colors.grey.shade100)))
            : BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3)),
                ],
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Orange left accent
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seeker name + "tap for details" hint
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 15, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(b.seekerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        const Spacer(),
                        const Icon(Icons.chevron_right,
                            size: 18, color: Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // District
                    Row(children: [
                      const Icon(Icons.location_on,
                          size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(b.jobDistrictLabel,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
                    const SizedBox(height: 3),
                    // Date/time
                    Row(children: [
                      const Icon(Icons.access_time,
                          size: 13, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(b.slotRangeFormatted,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Accept / Reject inline
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isBusy
                    ? const SizedBox(
                        key: ValueKey("busy"),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Column(
                        key: const ValueKey("actions"),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SmallBtn(
                              label: "Accept",
                              color: Colors.blue,
                              onPressed: onAccept),
                          const SizedBox(height: 4),
                          _SmallBtn(
                              label: "Reject",
                              color: Colors.red,
                              outlined: true,
                              onPressed: onReject),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bookings tab (accepted / completed / rejected) ────────────────────────────

class _BookingsTab extends StatelessWidget {
  final List<BookingModel> bookings;
  final Set<String> busy;
  final void Function(String id) onComplete;
  final void Function(BookingModel) onNavigate;
  final void Function(BookingModel) onTap;

  const _BookingsTab({
    required this.bookings,
    required this.busy,
    required this.onComplete,
    required this.onNavigate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const Center(
          child: Text("No bookings yet", style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: bookings.length,
      itemBuilder: (context, i) {
        final b = bookings[i];
        return InkWell(
          onTap: () => onTap(b),
          borderRadius: BorderRadius.circular(14),
          child: _BookingListCard(
            booking: b,
            isBusy: busy.contains(b.id),
            onComplete: () => onComplete(b.id),
            onNavigate: b.hasGps ? () => onNavigate(b) : null,
          ),
        );
      },
    );
  }
}

class _BookingListCard extends StatelessWidget {
  final BookingModel booking;
  final bool isBusy;
  final VoidCallback onComplete;
  final VoidCallback? onNavigate;

  const _BookingListCard({
    required this.booking,
    required this.isBusy,
    required this.onComplete,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    Color statusColor;
    switch (b.status) {
      case "accepted":  statusColor = Colors.blue;   break;
      case "completed": statusColor = Colors.green;  break;
      case "rejected":  statusColor = Colors.red;    break;
      default:          statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 90,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(b.skillTitle,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                            overflow: TextOverflow.ellipsis),
                      ),
                      _StatusChip(b.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.person_outline,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(b.seekerName,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.access_time,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(b.slotRangeFormatted,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ]),
                  const SizedBox(height: 8),
                  // Actions
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isBusy
                        ? const Row(
                            key: ValueKey("busy"),
                            children: [
                              SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text("Updating…",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ],
                          )
                        : Wrap(
                            key: const ValueKey("actions"),
                            spacing: 8,
                            children: [
                              if (b.status == "accepted") ...[
                                if (onNavigate != null)
                                  _SmallBtn(
                                      label: "Navigate",
                                      color: Colors.blue.shade700,
                                      icon: Icons.navigation_rounded,
                                      onPressed: onNavigate!),
                                _SmallBtn(
                                    label: "Complete",
                                    color: Colors.green,
                                    onPressed: onComplete),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ),
        ],
      ),
    );
  }
}

// ── Full detail bottom sheet ───────────────────────────────────────────────────

class _BookingDetailSheet extends StatelessWidget {
  final BookingModel booking;
  final bool isBusy;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onComplete;
  final VoidCallback? onNavigate;

  const _BookingDetailSheet({
    required this.booking,
    required this.isBusy,
    this.onAccept,
    this.onReject,
    this.onComplete,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    Color statusColor;
    switch (b.status) {
      case "requested":  statusColor = Colors.orange; break;
      case "accepted":   statusColor = Colors.blue;   break;
      case "completed":  statusColor = Colors.green;  break;
      default:           statusColor = Colors.red;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status chip + skill title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            b.skillTitle,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            b.status.toUpperCase(),
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Created at — light grey small
                    Text(
                      "Requested on ${b.createdAtFormatted}",
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 12),
                    ),

                    const SizedBox(height: 20),
                    const _SectionLabel("Seeker"),

                    _DetailRow(
                      icon: Icons.person,
                      text: b.seekerName,
                      bold: true,
                    ),

                    const SizedBox(height: 16),
                    const _SectionLabel("When"),

                    _DetailRow(
                      icon: Icons.calendar_today,
                      text: b.slotRangeFormatted,
                    ),

                    const SizedBox(height: 16),
                    const _SectionLabel("Location"),

                    _DetailRow(
                      icon: Icons.location_on,
                      text: b.jobAddressFormatted,
                    ),
                    if (b.distanceKmEstimate != null) ...[
                      const SizedBox(height: 6),
                      _DetailRow(
                        icon: Icons.directions_walk,
                        text: b.distanceLabel,
                        subtle: true,
                      ),
                    ],

                    if (b.jobDescription != null &&
                        b.jobDescription!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SectionLabel("Description"),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          b.jobDescription!,
                          style: const TextStyle(
                              fontSize: 14, height: 1.5),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Action buttons
                    if (isBusy)
                      const Center(child: CircularProgressIndicator())
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (onAccept != null)
                            ElevatedButton(
                              onPressed: onAccept,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  minimumSize:
                                      const Size.fromHeight(48)),
                              child: const Text("Accept Request"),
                            ),
                          if (onReject != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: onReject,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  minimumSize:
                                      const Size.fromHeight(48)),
                              child: const Text("Reject Request"),
                            ),
                          ],
                          if (onNavigate != null) ...[
                            ElevatedButton.icon(
                              onPressed: onNavigate,
                              icon: const Icon(
                                  Icons.navigation_rounded,
                                  size: 18),
                              label: const Text("Navigate to Job"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  minimumSize:
                                      const Size.fromHeight(48)),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (onComplete != null)
                            ElevatedButton(
                              onPressed: onComplete,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  minimumSize:
                                      const Size.fromHeight(48)),
                              child: const Text("Mark as Complete"),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _SkillGroup {
  final String skillId;
  final String skillTitle;
  final List<BookingModel> bookings = [];
  _SkillGroup({required this.skillId, required this.skillTitle});
}

class _Badge extends StatelessWidget {
  final int count;
  final Color color;
  const _Badge(this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(10)),
      child: Text("$count",
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case "requested": color = Colors.orange; break;
      case "accepted":  color = Colors.blue;   break;
      case "completed": color = Colors.green;  break;
      default:          color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool outlined;
  final VoidCallback onPressed;

  const _SmallBtn({
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )
        : ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );

    if (outlined) {
      return OutlinedButton(
          onPressed: onPressed,
          style: style,
          child: Text(label, style: const TextStyle(fontSize: 12)));
    }
    if (icon != null) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 13),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      );
    }
    return ElevatedButton(
        onPressed: onPressed,
        style: style,
        child: Text(label, style: const TextStyle(fontSize: 12)));
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade500,
              letterSpacing: 0.8)),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool bold;
  final bool subtle;

  const _DetailRow({
    required this.icon,
    required this.text,
    this.bold = false,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: bold ? 15 : 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
              color: subtle ? Colors.grey.shade500 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
