import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:skill_renting_app/features/reviews/screens/review_screen.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import 'package:skill_renting_app/features/bookings/models/booking_model.dart';
import 'package:skill_renting_app/features/common/widgets/empty_state.dart';
import 'package:skill_renting_app/features/skills/screens/skill_list_screen.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
import 'package:skill_renting_app/features/bookings/screens/booking_schedule_screen.dart';
import 'package:skill_renting_app/features/bookings/screens/gps_location_screen.dart';
import 'package:skill_renting_app/features/chat/chat_screen.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart' as _authSt;

// ── Status helpers ──────────────────────────────────────────────────────────
Color _statusColor(String s) {
  switch (s) {
    case "requested":   return const Color(0xFFF59E0B);
    case "accepted":    return const Color(0xFF3B82F6);
    case "in_progress": return const Color(0xFF8B5CF6);
    case "completed":   return const Color(0xFF10B981);
    case "rejected":    return const Color(0xFFEF4444);
    default:            return const Color(0xFF6B7280);
  }
}

String _statusLabel(String s) => s.replaceAll("_", " ").toUpperCase();

// ── Status chip ──────────────────────────────────────────────────────────────
class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);
  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.35), width: 0.8),
      ),
      child: Text(_statusLabel(status),
          style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class SeekerBookingsScreen extends StatefulWidget {
  const SeekerBookingsScreen({super.key});
  @override
  State<SeekerBookingsScreen> createState() => _SeekerBookingsScreenState();
}

class _SeekerBookingsScreenState extends State<SeekerBookingsScreen>
    with SingleTickerProviderStateMixin {
  List<BookingModel> _bookings = [];
  bool _loading = true;
  final Set<String> _busy      = {};
  final Set<String> _shownOtps = {};
  final Set<String> _shownAutoCancelAlerts = {};
  late TabController _tabCtrl;

  static bool _hasPenalty(BookingModel b) {
    final diff = b.startDate.difference(DateTime.now());
    if (b.pricingUnit == "hour") return diff.inMinutes < 30 && diff.inSeconds > 0;
    if (b.pricingUnit == "day")  return diff.inMinutes < 360 && diff.inSeconds > 0;
    return false;
  }

  static String _penaltyNote(BookingModel b) {
    final amount = (b.price * 0.5).toStringAsFixed(0);
    return b.pricingUnit == "hour"
        ? "Cancelling within 30 minutes of your slot incurs a 50% penalty (₹$amount).\n\nContinue?"
        : "Cancelling within 6 hours of your slot incurs a 50% penalty (₹$amount).\n\nContinue?";
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    final data = await BookingService.fetchMyBookings();
    data.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() { _bookings = data; _loading = false; });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOtps();
      _checkAutoCancelledBookings();
    });
  }

  // ── OTP check ───────────────────────────────────────────────────────────────
  void _checkOtps() {
    for (final b in _bookings) {
      if (b.beginOtp != null) {
        final key = "${b.id}_begin_${b.beginOtp}";
        if (!_shownOtps.contains(key)) { _shownOtps.add(key); _showOtpPopup(b, isBegin: true); return; }
      }
      if (b.completeOtp != null) {
        final key = "${b.id}_complete_${b.completeOtp}";
        if (!_shownOtps.contains(key)) { _shownOtps.add(key); _showOtpPopup(b, isBegin: false); return; }
      }
    }
  }

  void _showOtpPopup(BookingModel b, {required bool isBegin}) {
    final otp   = isBegin ? b.beginOtp! : b.completeOtp!;
    final cs    = Theme.of(context).colorScheme;
    final color = isBegin ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(isBegin ? Icons.play_circle_outline_rounded : Icons.check_circle_outline_rounded,
              color: color, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(isBegin ? "Provider has arrived!" : "Verify Completion",
              style: const TextStyle(fontSize: 16))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(isBegin ? "Read this OTP to your provider to begin service." :
              "Read this OTP to confirm the job is done.",
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Text(otp,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold,
                    letterSpacing: 12, color: color)),
          ),
          const SizedBox(height: 12),
          Text(b.skillTitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ]),
        actions: [FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it"))],
      ),
    );
  }

  // ── Auto-cancel alert ───────────────────────────────────────────────────────
  void _checkAutoCancelledBookings() {
    for (final b in _bookings) {
      if (b.autoCancelledForNoResponse && !b.isReviewed && !_shownAutoCancelAlerts.contains(b.id)) {
        _shownAutoCancelAlerts.add(b.id);
        _showAutoCancelPopup(b); return;
      }
    }
  }

  void _showAutoCancelPopup(BookingModel b) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context, barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: const Color(0xFFF59E0B), size: 24),
          const SizedBox(width: 8),
          const Expanded(child: Text("Provider Didn't Respond", style: TextStyle(fontSize: 16))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(b.skillTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 4),
          Text("with ${b.providerName}", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 0.8),
            ),
            child: const Text(
              "This booking was auto-cancelled because the provider did not respond before your scheduled slot.",
              style: TextStyle(fontSize: 13, height: 1.4)),
          ),
        ]),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Later")),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ReviewScreen(booking: b, isForNoResponse: true)));
              if (mounted) _loadBookings();
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            icon: const Icon(Icons.star_half_outlined, size: 16),
            label: const Text("Rate & Report"),
          ),
        ],
      ),
    );
  }

  // ── Cancel ──────────────────────────────────────────────────────────────────
  Future<void> _cancelBooking(String bookingId) async {
    if (_busy.contains(bookingId)) return;
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    final booking = idx != -1 ? _bookings[idx] : null;
    if (booking != null && _hasPenalty(booking)) {
      final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: const Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          const Text("Cancellation Penalty"),
        ]),
        content: Text(_penaltyNote(booking), style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Keep Booking")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text("Cancel Anyway")),
        ],
      ));
      if (confirmed != true) return;
    } else {
      final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: const Text("Cancel Booking"),
        content: const Text("Are you sure you want to cancel this booking?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("No")),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text("Cancel")),
        ],
      ));
      if (confirmed != true) return;
    }
    setState(() => _busy.add(bookingId));
    try {
      final ok = await BookingService.updateBookingStatus(bookingId, "cancel");
      if (!ok || !mounted) return;
      setState(() {
        final i = _bookings.indexWhere((b) => b.id == bookingId);
        if (i != -1) _bookings[i] = _bookings[i].copyWith(status: "cancelled");
      });
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
  }

  Future<void> _requestCancellation(String bookingId) async {
    if (_busy.contains(bookingId)) return;
    setState(() => _busy.add(bookingId));
    try {
      final ok = await BookingService.requestCancellation(bookingId);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Cancellation request sent to provider")));
        _loadBookings();
      }
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
  }

  Future<void> _markPaid(String bookingId) async {
    final ok = await BookingService.markPaymentDone(bookingId);
    if (ok && mounted) setState(() {
      final i = _bookings.indexWhere((b) => b.id == bookingId);
      if (i != -1) _bookings[i] = _bookings[i].copyWith(paymentStatus: "paid");
    });
  }

  void _showDetailSheet(BookingModel b) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        booking: b,
        isBusy: _busy.contains(b.id),
        onCancel: (b.status == "requested" || b.status == "accepted")
            ? () { Navigator.pop(context); _cancelBooking(b.id); } : null,
        onRequestCancellation: (b.status == "in_progress" && !b.cancellationRequested)
            ? () { Navigator.pop(context); _requestCancellation(b.id); } : null,
        onReview: ((b.status == "completed" && !b.isReviewed) ||
                   (b.autoCancelledForNoResponse && !b.isReviewed))
            ? () async {
                Navigator.pop(context);
                await Navigator.push(context, MaterialPageRoute(builder: (_) => ReviewScreen(
                    booking: b, isForNoResponse: b.autoCancelledForNoResponse)));
                _loadBookings();
              } : null,
        onShareGps: (b.status == "accepted" && b.gpsLocationStatus == "pending")
            ? () async {
                Navigator.pop(context);
                final res = await Navigator.push<bool>(context, MaterialPageRoute(
                    builder: (_) => GpsLocationScreen(bookingId: b.id, seekerName: "Job Location")));
                if (res == true && mounted) _loadBookings();
              } : null,
        onPay: (b.status == "completed" && b.paymentStatus == "pending")
            ? () => _markPaid(b.id) : null,
        onMessage: (b.status == "accepted" || b.status == "in_progress")
            ? () async {
                Navigator.pop(context);
                final myId = await _authSt.AuthStorage.getUserId();
                if (!mounted) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                    chatType: "booking", bookingId: b.id,
                    otherPersonName: b.providerName, currentUserId: myId)));
              } : null,
      ),
    );
  }

  List<BookingModel> get _active   => _bookings.where((b) => ["requested","accepted","in_progress"].contains(b.status)).toList();
  List<BookingModel> get _history  => _bookings.where((b) => ["completed","cancelled","rejected"].contains(b.status)).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text("My Bookings"),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text("Active"),
              if (!_loading && _active.isNotEmpty) ...[
                const SizedBox(width: 6),
                _TabBadge(_active.length, cs),
              ],
            ])),
            Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text("History"),
              if (!_loading && _history.isNotEmpty) ...[
                const SizedBox(width: 6),
                _TabBadge(_history.length, cs),
              ],
            ])),
          ],
        ),
      ),
      body: _loading
          ? const SkeletonList()
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _BookingList(
                  bookings: _active,
                  emptyIcon: Icons.calendar_today_outlined,
                  emptyTitle: "No active bookings",
                  emptyMessage: "Book a service to get started",
                  emptyAction: "Browse Services",
                  onEmptyTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SkillListScreen())),
                  busy: _busy,
                  onTap: _showDetailSheet,
                  onRefresh: _loadBookings,
                ),
                _BookingList(
                  bookings: _history,
                  emptyIcon: Icons.history_rounded,
                  emptyTitle: "No history yet",
                  emptyMessage: "Completed and cancelled bookings will appear here",
                  emptyAction: "Browse Services",
                  onEmptyTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SkillListScreen())),
                  busy: _busy,
                  onTap: _showDetailSheet,
                  onRefresh: _loadBookings,
                ),
              ],
            ),
    );
  }
}

// ─── Booking list ─────────────────────────────────────────────────────────────
class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final IconData emptyIcon;
  final String emptyTitle, emptyMessage, emptyAction;
  final VoidCallback onEmptyTap;
  final Set<String> busy;
  final void Function(BookingModel) onTap;
  final Future<void> Function() onRefresh;
  const _BookingList({
    required this.bookings, required this.emptyIcon, required this.emptyTitle,
    required this.emptyMessage, required this.emptyAction, required this.onEmptyTap,
    required this.busy, required this.onTap, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (bookings.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 72, height: 72,
          decoration: BoxDecoration(color: cs.surfaceContainerHigh, shape: BoxShape.circle,
              border: Border.all(color: cs.outlineVariant, width: 0.8)),
          child: Icon(emptyIcon, size: 32, color: cs.onSurfaceVariant)),
      const SizedBox(height: 16),
      Text(emptyTitle, style: tt.titleMedium),
      const SizedBox(height: 6),
      Text(emptyMessage, style: tt.bodySmall, textAlign: TextAlign.center),
      const SizedBox(height: 20),
      FilledButton(onPressed: onEmptyTap, child: Text(emptyAction)),
    ]));
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _BookingCard(
          booking: bookings[i],
          isBusy: busy.contains(bookings[i].id),
          onTap: () => onTap(bookings[i]),
        ),
      ),
    );
  }
}

// ─── Booking card ─────────────────────────────────────────────────────────────
class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool isBusy;
  final VoidCallback onTap;
  const _BookingCard({required this.booking, required this.isBusy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final b  = booking;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final statusCol  = _statusColor(b.status);
    final needsGps   = b.status == "accepted" && b.gpsLocationStatus == "pending";
    final hasOtp     = b.beginOtp != null || b.completeOtp != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
          boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))],
        ),
        child: Column(children: [
          // OTP banner
          if (hasOtp)
            _OtpBanner(
              isBegin: b.beginOtp != null,
              otp: b.beginOtp ?? b.completeOtp!,
              cs: cs,
            ),
          // GPS banner
          if (needsGps)
            _Banner(
              icon: Icons.location_on_outlined,
              text: "Provider needs your job location",
              color: const Color(0xFFF59E0B), cs: cs,
              isTop: !hasOtp,
            ),
          if (b.status == "accepted" && b.gpsLocationStatus == "provided")
            _Banner(
              icon: Icons.check_circle_outline_rounded,
              text: "Location shared with provider",
              color: const Color(0xFF10B981), cs: cs,
              isTop: !hasOtp,
            ),
          // Cancellation requested
          if (b.cancellationRequested)
            _Banner(
              icon: Icons.hourglass_top_rounded,
              text: "Cancellation request sent — awaiting provider",
              color: const Color(0xFFF59E0B), cs: cs,
              isTop: !hasOtp && !needsGps,
            ),
          // Auto-cancelled
          if (b.autoCancelledForNoResponse)
            _Banner(
              icon: Icons.block_outlined,
              text: "Auto-cancelled — provider did not respond",
              color: const Color(0xFFEF4444), cs: cs,
              isTop: !hasOtp && !needsGps,
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Title row
              Row(children: [
                // Status accent bar
                Container(width: 4, height: 42,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(color: statusCol, borderRadius: BorderRadius.circular(2))),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(b.skillTitle, style: tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(b.createdAtFormatted, style: tt.labelSmall),
                ])),
                _StatusChip(b.status),
              ]),
              const SizedBox(height: 10),
              _InfoRow(Icons.person_outline_rounded, b.providerName, cs),
              const SizedBox(height: 4),
              _InfoRow(Icons.access_time_rounded, b.slotRangeFormatted, cs),
              const SizedBox(height: 4),
              _InfoRow(Icons.location_on_outlined, b.jobDistrictLabel, cs),
              const SizedBox(height: 10),
              Divider(height: 1, color: cs.outlineVariant.withOpacity(0.5)),
              const SizedBox(height: 10),
              Row(children: [
                Text("₹${b.price.toStringAsFixed(0)}/${b.pricingUnit}",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary)),
                const Spacer(),
                isBusy
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                    : Text("Tap for details →",
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Detail bottom sheet ──────────────────────────────────────────────────────
class _DetailSheet extends StatefulWidget {
  final BookingModel booking;
  final bool isBusy;
  final VoidCallback? onCancel, onRequestCancellation, onReview, onShareGps, onMessage;
  final Future<void> Function()? onPay;
  const _DetailSheet({
    required this.booking, required this.isBusy,
    this.onCancel, this.onRequestCancellation, this.onReview,
    this.onShareGps, this.onPay, this.onMessage,
  });
  @override
  State<_DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<_DetailSheet> {
  late String _paymentStatus;
  @override
  void initState() { super.initState(); _paymentStatus = widget.booking.paymentStatus; }

  @override
  Widget build(BuildContext context) {
    final b  = widget.booking;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final statusCol = _statusColor(b.status);

    return DraggableScrollableSheet(
      initialChildSize: 0.78, minChildSize: 0.4, maxChildSize: 0.96,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.5), width: 0.8)),
        ),
        child: Column(children: [
          // Handle
          Container(margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(b.skillTitle, style: tt.headlineSmall)),
                  _StatusChip(b.status),
                ]),
                const SizedBox(height: 4),
                Text("Booked on ${b.createdAtFormatted}", style: tt.labelSmall),

                // OTP
                if (b.beginOtp != null) ...[
                  const SizedBox(height: 16),
                  _OtpCard(otp: b.beginOtp!, title: "Share to begin service",
                      subtitle: "Tell this OTP to your provider", color: const Color(0xFF3B82F6), cs: cs),
                ],
                if (b.completeOtp != null) ...[
                  const SizedBox(height: 16),
                  _OtpCard(otp: b.completeOtp!, title: "Share to confirm completion",
                      subtitle: "Tell this OTP to confirm the job is done", color: const Color(0xFF10B981), cs: cs),
                ],

                const SizedBox(height: 20),
                _SectionLabel("Provider", cs),
                _DetailCard(cs: cs, children: [
                  _DRow(Icons.person_outline_rounded, b.providerName, cs, bold: true),
                  const SizedBox(height: 6),
                  Row(children: [
                    ...List.generate(5, (i) => Icon(
                        i < b.providerRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 14, color: const Color(0xFFF59E0B))),
                    const SizedBox(width: 6),
                    Text(b.providerRating > 0
                        ? "${b.providerRating.toStringAsFixed(1)} (${b.providerTotalReviews})"
                        : "No ratings yet",
                        style: tt.labelSmall),
                  ]),
                  if (b.providerAddressFormatted != "Not available") ...[
                    const SizedBox(height: 6),
                    _DRow(Icons.location_city_outlined, b.providerAddressFormatted, cs, subtle: true),
                  ],
                ]),

                const SizedBox(height: 14),
                _SectionLabel("Booking details", cs),
                _DetailCard(cs: cs, children: [
                  _DRow(Icons.calendar_today_rounded, b.slotRangeFormatted, cs),
                  const SizedBox(height: 8),
                  _DRow(Icons.location_on_outlined, b.jobAddressFormatted, cs),
                  if (b.distanceKmEstimate != null) ...[
                    const SizedBox(height: 8),
                    _DRow(Icons.near_me_outlined, b.distanceLabel, cs, subtle: true),
                  ],
                  if (b.jobDescription != null && b.jobDescription!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _DRow(Icons.description_outlined, b.jobDescription!, cs, subtle: true),
                  ],
                ]),

                const SizedBox(height: 14),
                _SectionLabel("Payment", cs),
                _DetailCard(cs: cs, children: [
                  _DRow(Icons.currency_rupee, "₹${b.price.toStringAsFixed(0)} / ${b.pricingUnit}", cs),
                  if (b.extraCharges > 0) ...[
                    const SizedBox(height: 8),
                    _DRow(Icons.more_time_rounded, "Extra: ₹${b.extraCharges.toStringAsFixed(0)}", cs, subtle: true),
                  ],
                  if (b.totalAmount != null || b.status == "completed") ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.25), width: 0.8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.receipt_outlined, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text("Total: ₹${b.amountDue.toStringAsFixed(0)}",
                            style: const TextStyle(fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981), fontSize: 15)),
                      ]),
                    ),
                  ],
                ]),

                const SizedBox(height: 24),

                // ── Actions ─────────────────────────────────────────────────
                if (widget.isBusy)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Provider phone warning
                    if (b.showProviderPhone) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 0.8),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 16),
                            const SizedBox(width: 6),
                            Text("Provider hasn't responded (${b.minsUntilSlot} min left)",
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                          ]),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final uri = Uri(scheme: 'tel', path: b.providerPhone);
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                            child: Row(children: [
                              Container(width: 36, height: 36,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.phone_rounded, color: Color(0xFFF59E0B), size: 18)),
                              const SizedBox(width: 10),
                              Text(b.providerPhone, style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B),
                                  decoration: TextDecoration.underline)),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],

                    if (widget.onShareGps != null) ...[
                      SizedBox(height: 50, child: FilledButton.icon(
                        onPressed: widget.onShareGps,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                        icon: const Icon(Icons.location_on_rounded, size: 18),
                        label: const Text("Share GPS Location"))),
                      const SizedBox(height: 10),
                    ],
                    if (widget.onMessage != null) ...[
                      SizedBox(height: 50, child: FilledButton.icon(
                        onPressed: widget.onMessage,
                        style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D9488)),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        label: const Text("Message Provider"))),
                      const SizedBox(height: 10),
                    ],
                    if (b.status == "completed" && _paymentStatus == "pending") ...[
                      SizedBox(height: 50, child: FilledButton.icon(
                        onPressed: () => _UpiSheet.show(context: context, booking: b,
                            onPaid: () { setState(() => _paymentStatus = "paid"); widget.onPay?.call(); }),
                        icon: const Icon(Icons.payment_rounded, size: 18),
                        label: Text("Pay ₹${b.amountDue.toStringAsFixed(0)}"))),
                      const SizedBox(height: 10),
                    ],
                    if (b.status == "completed" && _paymentStatus == "paid") ...[
                      Container(
                        height: 50, alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3), width: 0.8),
                        ),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                          SizedBox(width: 8),
                          Text("Payment Complete", style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (widget.onReview != null && !b.isReviewed) ...[
                      SizedBox(height: 50, child: FilledButton.icon(
                        onPressed: widget.onReview,
                        style: b.autoCancelledForNoResponse
                            ? FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444))
                            : null,
                        icon: const Icon(Icons.star_outline_rounded, size: 18),
                        label: Text(b.autoCancelledForNoResponse
                            ? "Rate Provider's Responsiveness" : "Leave a Review"))),
                      const SizedBox(height: 10),
                    ],
                    if (b.isReviewed) ...[
                      Container(height: 50, alignment: Alignment.center,
                        decoration: BoxDecoration(color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.outlineVariant, width: 0.8)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.check_rounded, color: cs.onSurfaceVariant, size: 16),
                          const SizedBox(width: 6),
                          Text("Already Reviewed", style: TextStyle(color: cs.onSurfaceVariant)),
                        ])),
                      const SizedBox(height: 10),
                    ],
                    if (widget.onCancel != null) ...[
                      SizedBox(height: 50, child: OutlinedButton(
                        onPressed: widget.onCancel,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444), width: 0.8)),
                        child: const Text("Cancel Booking"))),
                    ],
                    if (widget.onRequestCancellation != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(height: 50, child: OutlinedButton(
                        onPressed: widget.onRequestCancellation,
                        style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFF59E0B),
                            side: const BorderSide(color: Color(0xFFF59E0B), width: 0.8)),
                        child: const Text("Request Cancellation"))),
                    ],
                  ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── UPI sheet (unchanged logic, new style) ───────────────────────────────────
class _UpiSheet {
  static Future<void> show({required BuildContext context, required BookingModel booking, required VoidCallback onPaid}) {
    return showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _UpiSheetWidget(booking: booking, onPaid: onPaid));
  }
}

const _kUpiApps = [
  ["Google Pay",  "g_pay"],
  ["PhonePe",     "phonepe"],
  ["Paytm",       "paytm"],
  ["BHIM",        "bhim"],
  ["Amazon Pay",  "amazon"],
  ["Other UPI",   "upi"],
];

const _kUpiColors = [
  Color(0xFF4285F4), Color(0xFF5F259F), Color(0xFF00BAF2),
  Color(0xFF138808), Color(0xFFFF9900), Color(0xFF607D8B),
];

const _kUpiIcons = [
  Icons.g_mobiledata_rounded, Icons.phone_android_rounded, Icons.account_balance_wallet_rounded,
  Icons.account_balance_rounded, Icons.shopping_bag_outlined, Icons.payment_rounded,
];

class _UpiSheetWidget extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback onPaid;
  const _UpiSheetWidget({required this.booking, required this.onPaid});
  @override
  State<_UpiSheetWidget> createState() => _UpiSheetWidgetState();
}

class _UpiSheetWidgetState extends State<_UpiSheetWidget> {
  String? _selected;
  bool _processing = false;

  Future<void> _onTap(int i) async {
    if (_processing) return;
    setState(() { _selected = _kUpiApps[i][0]; _processing = true; });
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.pop(context);
    _showBillDialog(_kUpiApps[i][0]);
  }

  void _showBillDialog(String appName) {
    final b  = widget.booking;
    final cs = Theme.of(context).colorScheme;
    showDialog(context: context, barrierDismissible: false,
      builder: (dCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 60, height: 60,
                decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 36)),
            const SizedBox(height: 12),
            const Text("Payment Successful!", style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text("Paid via $appName", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 20),
            _BillRow("Provider",  b.providerName,           cs),
            _BillRow("Service",   b.skillTitle,             cs),
            _BillRow("Slot",      b.slotRangeFormatted,     cs),
            _BillRow("Base rate", "₹${b.price.toStringAsFixed(0)}/${b.pricingUnit}", cs),
            if (b.extraCharges > 0)
              _BillRow("Extra",   "+ ₹${b.extraCharges.toStringAsFixed(0)}", cs),
            const Divider(height: 20),
            Row(children: [
              const Expanded(child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
              Text("₹${b.amountDue.toStringAsFixed(0)}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: cs.primary)),
            ]),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, height: 48,
              child: FilledButton(
                onPressed: () { Navigator.pop(dCtx); widget.onPaid(); },
                child: const Text("Done"))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.5), width: 0.8)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
        Row(children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Pay via UPI", style: tt.titleSmall),
            Text("₹${widget.booking.amountDue.toStringAsFixed(0)}", style: tt.bodySmall),
          ])),
        ]),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.1,
          children: List.generate(_kUpiApps.length, (i) {
            final isLoading = _selected == _kUpiApps[i][0] && _processing;
            return GestureDetector(
              onTap: _processing ? null : () => _onTap(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isLoading ? _kUpiColors[i].withOpacity(0.08) : cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isLoading ? _kUpiColors[i] : cs.outlineVariant,
                    width: isLoading ? 1.5 : 0.8),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  isLoading
                      ? SizedBox(width: 26, height: 26,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _kUpiColors[i]))
                      : Icon(_kUpiIcons[i], size: 30, color: _kUpiColors[i]),
                  const SizedBox(height: 6),
                  Text(_kUpiApps[i][0],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurface),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.security_rounded, size: 13, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text("Secured by UPI", style: tt.labelSmall),
        ]),
      ]),
    );
  }
}

// ─── Shared small widgets ─────────────────────────────────────────────────────
class _TabBadge extends StatelessWidget {
  final int count;
  final ColorScheme cs;
  const _TabBadge(this.count, this.cs);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
    child: Text("$count", style: TextStyle(color: cs.onPrimary, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}

class _OtpBanner extends StatelessWidget {
  final bool isBegin;
  final String otp;
  final ColorScheme cs;
  const _OtpBanner({required this.isBegin, required this.otp, required this.cs});
  @override
  Widget build(BuildContext context) {
    final color = isBegin ? const Color(0xFF3B82F6) : const Color(0xFF10B981);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.2), width: 0.8)),
      ),
      child: Row(children: [
        Icon(Icons.lock_open_rounded, color: color, size: 14),
        const SizedBox(width: 8),
        Text(isBegin ? "OTP to begin: " : "OTP to confirm: ",
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        Text(otp, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.bold, letterSpacing: 4)),
        const Spacer(),
        Text("Tap to view", style: TextStyle(fontSize: 11, color: color.withOpacity(0.6))),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final ColorScheme cs;
  final bool isTop;
  const _Banner({required this.icon, required this.text, required this.color,
      required this.cs, required this.isTop});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: isTop ? const BorderRadius.vertical(top: Radius.circular(16)) : null,
      border: Border(bottom: BorderSide(color: color.withOpacity(0.2), width: 0.8)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500))),
    ]),
  );
}

class _OtpCard extends StatelessWidget {
  final String otp, title, subtitle;
  final Color color;
  final ColorScheme cs;
  const _OtpCard({required this.otp, required this.title, required this.subtitle,
      required this.color, required this.cs});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.3), width: 1),
    ),
    child: Column(children: [
      Row(children: [
        Icon(Icons.lock_open_rounded, color: color, size: 16),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
      const SizedBox(height: 10),
      Text(otp, style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, letterSpacing: 12, color: color)),
      const SizedBox(height: 8),
      Text(subtitle, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
    ]),
  );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final ColorScheme cs;
  const _SectionLabel(this.text, this.cs);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant, letterSpacing: 0.8)),
  );
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  final ColorScheme cs;
  const _DetailCard({required this.children, required this.cs});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _DRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme cs;
  final bool bold, subtle;
  const _DRow(this.icon, this.text, this.cs, {this.bold = false, this.subtle = false});
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 15, color: cs.onSurfaceVariant),
    const SizedBox(width: 8),
    Expanded(child: Text(text, style: TextStyle(
        fontSize: bold ? 15 : 13,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        color: subtle ? cs.onSurfaceVariant : cs.onSurface))),
  ]);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final ColorScheme cs;
  const _InfoRow(this.icon, this.text, this.cs);
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, size: 13, color: cs.onSurfaceVariant),
    const SizedBox(width: 6),
    Expanded(child: Text(text,
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        maxLines: 2, overflow: TextOverflow.ellipsis)),
  ]);
}

class _BillRow extends StatelessWidget {
  final String label, value;
  final ColorScheme cs;
  const _BillRow(this.label, this.value, this.cs);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
      const SizedBox(width: 12),
      Flexible(child: Text(value, textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]),
  );
}
