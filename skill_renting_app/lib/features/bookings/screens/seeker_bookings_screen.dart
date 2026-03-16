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

class SeekerBookingsScreen extends StatefulWidget {
  const SeekerBookingsScreen({super.key});

  @override
  State<SeekerBookingsScreen> createState() => _SeekerBookingsScreenState();
}

class _SeekerBookingsScreenState extends State<SeekerBookingsScreen> {
  List<BookingModel> _bookings = [];
  bool _loading = true;
  final Set<String> _busy = {};

  /// Tracks OTP keys already shown this session to avoid re-popups
  final Set<String> _shownOtps = {};

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    final data = await BookingService.fetchMyBookings();
    data.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() {
      _bookings = data;
      _loading = false;
    });
    // Check for new OTPs after load
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOtps());
  }

  void _checkOtps() {
    for (final b in _bookings) {
      if (b.beginOtp != null) {
        final key = "${b.id}_begin_${b.beginOtp}";
        if (!_shownOtps.contains(key)) {
          _shownOtps.add(key);
          _showOtpPopup(b, isBegin: true);
          return; // show one at a time
        }
      }
      if (b.completeOtp != null) {
        final key = "${b.id}_complete_${b.completeOtp}";
        if (!_shownOtps.contains(key)) {
          _shownOtps.add(key);
          _showOtpPopup(b, isBegin: false);
          return;
        }
      }
    }
  }

  void _showOtpPopup(BookingModel b, {required bool isBegin}) {
    final otp = isBegin ? b.beginOtp! : b.completeOtp!;
    final title = isBegin ? "Provider has arrived!" : "Verify Job Completion";
    final subtitle = isBegin
        ? "Your provider is at your location. Read this OTP to them to begin service."
        : "Your provider says the job is done. Read this OTP to confirm.";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(isBegin ? Icons.directions_run : Icons.check_circle,
              color: isBegin ? Colors.blue : Colors.green),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17))),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.indigo.shade200, width: 1.5),
              ),
              child: Text(
                otp,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 12,
                  color: Colors.indigo.shade700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(b.skillTitle,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44)),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  // ── Cancellation penalty rules ─────────────────────────────────────────────
  // Hourly: penalty if cancelling within 30 min of slot start
  // Daily:  penalty if cancelling within 6 hrs of slot start (day starts 7 AM)
  static bool _hasPenalty(BookingModel b) {
    final now   = DateTime.now();
    final start = b.startDate;
    final diff  = start.difference(now);
    if (b.pricingUnit == "hour") {
      return diff.inMinutes < 30 && diff.inSeconds > 0;
    } else if (b.pricingUnit == "day") {
      return diff.inMinutes < 360 && diff.inSeconds > 0;
    }
    return false;
  }

  static String _penaltyNote(BookingModel b) {
    final amount = (b.price * 0.5).toStringAsFixed(0);
    if (b.pricingUnit == "hour") {
      return "You are cancelling within 30 minutes of your booked slot.\n\n"
          "A cancellation penalty of \u20b9$amount (50% of \u20b9${b.price.toStringAsFixed(0)}) applies.\n\n"
          "Do you still want to cancel?";
    } else {
      return "You are cancelling within 6 hours of your booked slot.\n\n"
          "A cancellation penalty of \u20b9$amount (50% of \u20b9${b.price.toStringAsFixed(0)}) applies.\n\n"
          "Do you still want to cancel?";
    }
  }

  Future<void> _cancelBooking(String bookingId) async {
    if (_busy.contains(bookingId)) return;

    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    final booking = idx != -1 ? _bookings[idx] : null;

    // Show penalty warning if applicable
    if (booking != null && _hasPenalty(booking)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text("Cancellation Penalty"),
          ]),
          content: Text(_penaltyNote(booking),
              style: const TextStyle(fontSize: 14, height: 1.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Keep Booking"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("Cancel Anyway"),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else if (booking != null) {
      // Standard confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Cancel Booking"),
          content: const Text("Are you sure you want to cancel this booking?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("Yes, Cancel"),
            ),
          ],
        ),
      );
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

  Future<void> _markPaid(String bookingId) async {
    final ok = await BookingService.markPaymentDone(bookingId);
    if (ok && mounted) {
      setState(() {
        final i = _bookings.indexWhere((b) => b.id == bookingId);
        if (i != -1) {
          _bookings[i] = _bookings[i].copyWith(paymentStatus: "paid");
        }
      });
    }
  }

  void _showDetailSheet(BookingModel b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeekerBookingDetailSheet(
        booking: b,
        isBusy: _busy.contains(b.id),
        onCancel: b.status == "requested" || b.status == "accepted"
            ? () { Navigator.pop(context); _cancelBooking(b.id); }
            : null,
        onReview: b.status == "completed" && !b.isReviewed
            ? () async {
                Navigator.pop(context);
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ReviewScreen(booking: b)));
                _loadBookings();
              }
            : null,
        onShareGps: b.status == "accepted" && b.gpsLocationStatus == "pending"
            ? () async {
                Navigator.pop(context);
                final result = await Navigator.push<bool>(context,
                    MaterialPageRoute(
                        builder: (_) => GpsLocationScreen(
                            bookingId: b.id, seekerName: "Job Location")));
                if (result == true && mounted) _loadBookings();
              }
            : null,
        onPay: b.status == "completed" && b.paymentStatus == "pending"
            ? () => _markPaid(b.id)
            : null,
        onMessage: (b.status == "accepted" || b.status == "in_progress")
            ? () async {
                Navigator.pop(context);
                final myId = await _authSt.AuthStorage.getUserId();
                if (!mounted) return;
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    bookingId:       b.id,
                    otherPersonName: b.providerName,
                    currentUserId:   myId,
                  ),
                ));
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings")),
      body: _loading
          ? const SkeletonList()
          : _bookings.isEmpty
              ? EmptyState(
                  icon: Icons.calendar_today,
                  title: "No Bookings",
                  message: "You haven't booked any services yet.",
                  buttonText: "Browse Services",
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SkillListScreen())),
                )
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) {
                      final b = _bookings[index];
                      return _SeekerBookingCard(
                        booking: b,
                        isBusy: _busy.contains(b.id),
                        onTap: () => _showDetailSheet(b),
                        onCancel: () => _cancelBooking(b.id),
                        onReschedule: () async {
                          await Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => BookingScheduleScreen(
                                      skillId: b.skillId,
                                      pricingUnit: b.pricingUnit)));
                          if (mounted) _loadBookings();
                        },
                        onReview: () async {
                          await Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => ReviewScreen(booking: b)));
                          _loadBookings();
                        },
                        onShareGps: () async {
                          final result = await Navigator.push<bool>(context,
                              MaterialPageRoute(
                                  builder: (_) => GpsLocationScreen(
                                      bookingId: b.id,
                                      seekerName: "Job Location")));
                          if (result == true && mounted) _loadBookings();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Booking card (list item)
// ═════════════════════════════════════════════════════════════════════════════

class _SeekerBookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;
  final VoidCallback onReview;
  final VoidCallback onShareGps;

  const _SeekerBookingCard({
    required this.booking,
    required this.isBusy,
    required this.onTap,
    required this.onCancel,
    required this.onReschedule,
    required this.onReview,
    required this.onShareGps,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final needsGps = b.status == "accepted" && b.gpsLocationStatus == "pending";
    final hasBeginOtp    = b.beginOtp != null;
    final hasCompleteOtp = b.completeOtp != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            // GPS banner
            if (needsGps) _GpsBanner(onShareGps: onShareGps, provided: false),
            if (b.status == "accepted" && b.gpsLocationStatus == "provided")
              _GpsBanner(onShareGps: onShareGps, provided: true),

            // OTP banner
            if (hasBeginOtp || hasCompleteOtp)
              _OtpBanner(
                  isBegin: hasBeginOtp,
                  otp: hasBeginOtp ? b.beginOtp! : b.completeOtp!,
                  onTap: onTap),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.skillTitle,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(b.createdAtFormatted,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade400)),
                          ],
                        ),
                      ),
                      _StatusBadge(b.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.person, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(b.providerName,
                        style: const TextStyle(fontSize: 13)),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(b.slotRangeFormatted,
                          style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // Inline actions
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isBusy
                        ? const Padding(
                            key: ValueKey("busy"),
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 10),
                              Text("Updating…",
                                  style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ]),
                          )
                        : Wrap(
                            key: const ValueKey("actions"),
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              if (needsGps)
                                _ActionBtn(
                                    label: "Share GPS",
                                    icon: Icons.location_on,
                                    color: Colors.orange,
                                    onPressed: onShareGps),
                              if (b.status == "requested")
                                _ActionBtn(
                                    label: "Cancel",
                                    icon: Icons.cancel_outlined,
                                    color: Colors.red,
                                    outlined: true,
                                    onPressed: onCancel),
                              if (b.status == "rejected")
                                _ActionBtn(
                                    label: "Reschedule",
                                    icon: Icons.schedule,
                                    color: Colors.indigo,
                                    onPressed: onReschedule),
                              if (b.status == "completed")
                                _ActionBtn(
                                    label: b.isReviewed ? "Reviewed" : "Give Review",
                                    icon: Icons.star_outline,
                                    color: Colors.amber.shade700,
                                    onPressed: b.isReviewed ? () {} : onReview),
                              // Tap to view full details hint
                              const _TapHint(),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Full detail bottom sheet (seeker view)
// ═════════════════════════════════════════════════════════════════════════════

class _SeekerBookingDetailSheet extends StatefulWidget {
  final BookingModel booking;
  final bool isBusy;
  final VoidCallback? onCancel;
  final VoidCallback? onReview;
  final VoidCallback? onShareGps;
  final Future<void> Function()? onPay;
  final VoidCallback? onMessage;

  const _SeekerBookingDetailSheet({
    required this.booking,
    required this.isBusy,
    this.onCancel,
    this.onReview,
    this.onShareGps,
    this.onPay,
    this.onMessage,
  });

  @override
  State<_SeekerBookingDetailSheet> createState() => _SeekerBookingDetailSheetState();
}

class _SeekerBookingDetailSheetState extends State<_SeekerBookingDetailSheet> {
  // Local state so payment UI updates without closing/reopening the sheet
  late String _paymentStatus;

  @override
  void initState() {
    super.initState();
    _paymentStatus = widget.booking.paymentStatus;
  }

  void _onPaymentDone() {
    setState(() => _paymentStatus = "paid");
    widget.onPay?.call(); // notify parent to persist in list
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    Color statusColor;
    switch (b.status) {
      case "requested":   statusColor = Colors.orange;       break;
      case "accepted":    statusColor = Colors.blue;         break;
      case "in_progress": statusColor = Colors.purple;       break;
      case "completed":   statusColor = Colors.green;        break;
      default:            statusColor = Colors.red;
    }

    String statusLabel = b.status.replaceAll("_", " ").toUpperCase();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.96,
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + status
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(b.skillTitle,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(statusLabel,
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("Booked on ${b.createdAtFormatted}",
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12)),

                    // OTP display (if pending)
                    if (b.beginOtp != null) ...[
                      const SizedBox(height: 16),
                      _OtpCard(
                          otp: b.beginOtp!,
                          title: "Share to Begin",
                          subtitle: "Tell this OTP to your provider to start the service",
                          color: Colors.blue),
                    ],
                    if (b.completeOtp != null) ...[
                      const SizedBox(height: 16),
                      _OtpCard(
                          otp: b.completeOtp!,
                          title: "Share to Confirm Completion",
                          subtitle: "Tell this OTP to your provider to confirm the job is done",
                          color: Colors.green),
                    ],

                    const SizedBox(height: 20),

                    // ── Provider ───────────────────────────────────────────
                    const _SectionLabel("Provider"),
                    _DetailRow(icon: Icons.person, text: b.providerName, bold: true),
                    const SizedBox(height: 6),
                    Row(children: [
                      ...List.generate(5, (i) => Icon(
                        i < b.providerRating.round() ? Icons.star : Icons.star_border,
                        size: 16, color: Colors.amber,
                      )),
                      const SizedBox(width: 6),
                      Text(
                        b.providerRating > 0
                            ? "${b.providerRating.toStringAsFixed(1)} (${b.providerTotalReviews})"
                            : "No ratings yet",
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    _DetailRow(
                        icon: Icons.location_city,
                        text: b.providerAddressFormatted,
                        subtle: true),

                    const SizedBox(height: 16),

                    // ── Slot ───────────────────────────────────────────────
                    const _SectionLabel("Scheduled Slot"),
                    _DetailRow(icon: Icons.calendar_today, text: b.slotRangeFormatted),

                    const SizedBox(height: 16),

                    // ── Pricing ────────────────────────────────────────────
                    const _SectionLabel("Pricing"),
                    _DetailRow(
                        icon: Icons.currency_rupee,
                        text: "₹${b.price.toStringAsFixed(0)} / ${b.pricingUnit}"),
                    if (b.extraCharges > 0) ...[
                      const SizedBox(height: 4),
                      _DetailRow(
                          icon: Icons.more_time,
                          text: "Extra charges: ₹${b.extraCharges.toStringAsFixed(0)}",
                          subtle: true),
                    ],
                    if (b.status == "completed" || b.totalAmount != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(children: [
                          Icon(Icons.receipt, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text("Total: ₹${b.amountDue.toStringAsFixed(0)}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                  fontSize: 15)),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ── Job location ───────────────────────────────────────
                    const _SectionLabel("Job Location"),
                    _DetailRow(icon: Icons.location_on, text: b.jobAddressFormatted),
                    if (b.distanceKmEstimate != null) ...[
                      const SizedBox(height: 4),
                      _DetailRow(
                          icon: Icons.directions_walk,
                          text: b.distanceLabel,
                          subtle: true),
                    ],

                    if (b.jobDescription != null && b.jobDescription!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SectionLabel("Description"),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(b.jobDescription!,
                            style: const TextStyle(fontSize: 14, height: 1.5)),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ── Actions ────────────────────────────────────────────
                    if (widget.isBusy)
                      const Center(child: CircularProgressIndicator())
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // GPS share
                          if (widget.onShareGps != null) ...[
                            ElevatedButton.icon(
                              onPressed: widget.onShareGps,
                              icon: const Icon(Icons.location_on),
                              label: const Text("Share GPS Location"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48)),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // ── Message ──────────────────────────────────────
                          if (widget.onMessage != null) ...[
                            ElevatedButton.icon(
                              onPressed: widget.onMessage,
                              icon: const Icon(Icons.chat_bubble_outline),
                              label: const Text("Message Provider"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48)),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // ── Payment ──────────────────────────────────────
                          if (b.status == "completed" &&
                              _paymentStatus == "pending") ...[
                            ElevatedButton.icon(
                              onPressed: () => _UpiChooser.show(
                                context: context,
                                booking: b,
                                onPaid: _onPaymentDone,
                              ),
                              icon: const Icon(Icons.payment),
                              label: Text(
                                  "Pay ₹${b.amountDue.toStringAsFixed(0)}"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(50)),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (b.status == "completed" &&
                              _paymentStatus == "paid") ...[
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(12)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.green.shade600),
                                  const SizedBox(width: 8),
                                  Text("Payment Complete",
                                      style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          // Review
                          if (widget.onReview != null)
                            ElevatedButton.icon(
                              onPressed: widget.onReview,
                              icon: const Icon(Icons.star_outline),
                              label: const Text("Leave a Review"),
                              style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48)),
                            ),
                          if (b.status == "completed" && b.isReviewed)
                            OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.check, color: Colors.grey),
                              label: const Text("Already Reviewed",
                                  style: TextStyle(color: Colors.grey)),
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(44)),
                            ),

                          // Cancel
                          if (widget.onCancel != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: widget.onCancel,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  minimumSize: const Size.fromHeight(46)),
                              child: const Text("Cancel Booking"),
                            ),
                          ],
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

// ═════════════════════════════════════════════════════════════════════════════
// Widgets
// ═════════════════════════════════════════════════════════════════════════════

/// Large OTP card shown inside detail sheet
class _OtpCard extends StatelessWidget {
  final String otp;
  final String title;
  final String subtitle;
  final Color color;
  const _OtpCard(
      {required this.otp,
      required this.title,
      required this.subtitle,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(children: [
        Row(children: [
          Icon(Icons.lock_open, color: color, size: 18),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 8),
        Text(otp,
            style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                letterSpacing: 12,
                color: color)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center),
      ]),
    );
  }
}

/// Small OTP banner on the card (tap to view)
class _OtpBanner extends StatelessWidget {
  final bool isBegin;
  final String otp;
  final VoidCallback onTap;
  const _OtpBanner(
      {required this.isBegin, required this.otp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isBegin ? Colors.blue : Colors.green;
    final label = isBegin ? "OTP to begin: " : "OTP to confirm: ";
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(children: [
          Icon(Icons.lock_open, color: color, size: 16),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          Text(otp,
              style: TextStyle(
                  fontSize: 14, color: color, fontWeight: FontWeight.bold,
                  letterSpacing: 4)),
          const Spacer(),
          Text("Tap to view",
              style: TextStyle(fontSize: 11, color: color.withOpacity(0.6))),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case "requested":   color = Colors.orange;  break;
      case "accepted":    color = Colors.blue;    break;
      case "in_progress": color = Colors.purple;  break;
      case "completed":   color = Colors.green;   break;
      case "rejected":    color = Colors.red;     break;
      default:            color = Colors.grey;
    }
    final label = status.replaceAll("_", " ").toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 10)),
    );
  }
}

class _GpsBanner extends StatelessWidget {
  final VoidCallback onShareGps;
  final bool provided;
  const _GpsBanner({required this.onShareGps, required this.provided});

  @override
  Widget build(BuildContext context) {
    final color = provided ? Colors.green : Colors.orange;
    final text = provided
        ? "Location shared with provider"
        : "Provider needs your job location";
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(children: [
        Icon(provided ? Icons.check_circle : Icons.location_on,
            color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12, color: color, fontWeight: FontWeight.w500))),
        if (!provided)
          TextButton(
            onPressed: onShareGps,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text("Share Now",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onPressed;
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap)
        : ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap);
    if (outlined) {
      return OutlinedButton.icon(
          onPressed: onPressed,
          style: style,
          icon: Icon(icon, size: 14),
          label: Text(label, style: const TextStyle(fontSize: 12)));
    }
    return ElevatedButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)));
  }
}

class _TapHint extends StatelessWidget {
  const _TapHint();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(Icons.info_outline, size: 13, color: Colors.grey.shade400),
      const SizedBox(width: 4),
      Text("Tap card for full details",
          style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
    ]);
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
  const _DetailRow(
      {required this.icon,
      required this.text,
      this.bold = false,
      this.subtle = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                fontSize: bold ? 15 : 14,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: subtle ? Colors.grey.shade500 : Colors.black87,
              )),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// UPI App Chooser — dummy payment flow
//
// Shows a bottom sheet listing UPI apps installed on the device.
// Tapping any app immediately shows a success dialog WITHOUT launching the
// UPI app or processing any real transaction.
//
// ── Real payment integration (future) ────────────────────────────────────────
// To implement real UPI payments, replace the `_onAppTapped` method with:
//
//   final upiUri = Uri.parse(
//     "upi://pay"
//     "?pa=MERCHANT_VPA@upi"          // merchant VPA
//     "&pn=SkillRenting"
//     "&am=${amount.toStringAsFixed(2)}"
//     "&cu=INR"
//     "&tn=Booking+Payment"
//     "&tr=UNIQUE_TRANSACTION_REF",   // store this for verification
//   );
//   await launchUrl(upiUri);
//   // Then poll your backend with the transaction ref to verify payment
//   // via the UPI status API before marking paid.
//
// Packages to consider:
//   - upi_india: ^3.0.1  (wraps Android UPI intent, gives success/failure callback)
//   - razorpay_flutter    (full payment gateway — not free)
//   - paytm_allinonesdk  (Paytm SDK)
// ─────────────────────────────────────────────────────────────────────────────

// ═════════════════════════════════════════════════════════════════════════════
// UPI dummy payment — chooser + full bill receipt
// ═════════════════════════════════════════════════════════════════════════════
//
// REAL PAYMENT INTEGRATION (future):
// Replace _onAppTapped body with:
//
//   final upiUri = Uri.parse(
//     "upi://pay?pa=MERCHANT_VPA@upi&pn=SkillRenting"
//     "&am=${booking.amountDue.toStringAsFixed(2)}&cu=INR"
//     "&tn=Booking+Payment&tr=TXN_${booking.id}",
//   );
//   // Use package: upi_india ^3.0.1 for Android intent + callback
//   // Verify transaction on backend with booking.id before marking paid
//
// ─────────────────────────────────────────────────────────────────────────────

class _UpiApp {
  final String name;
  final IconData icon;
  final Color color;
  const _UpiApp(this.name, this.icon, this.color);
}

const _kUpiApps = [
  _UpiApp("Google Pay",  Icons.g_mobiledata_rounded,   Color(0xFF4285F4)),
  _UpiApp("PhonePe",     Icons.phone_android,           Color(0xFF5F259F)),
  _UpiApp("Paytm",       Icons.account_balance_wallet,  Color(0xFF00BAF2)),
  _UpiApp("BHIM",        Icons.account_balance,         Color(0xFF138808)),
  _UpiApp("Amazon Pay",  Icons.shopping_bag_outlined,   Color(0xFFFF9900)),
  _UpiApp("Other UPI",   Icons.payment,                 Color(0xFF607D8B)),
];

// Static helper — call from anywhere
class _UpiChooser {
  static Future<void> show({
    required BuildContext context,
    required BookingModel booking,
    required VoidCallback onPaid,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UpiChooserSheet(booking: booking, onPaid: onPaid),
    );
  }
}

class _UpiChooserSheet extends StatefulWidget {
  final BookingModel booking;
  final VoidCallback onPaid;
  const _UpiChooserSheet({required this.booking, required this.onPaid});

  @override
  State<_UpiChooserSheet> createState() => _UpiChooserSheetState();
}

class _UpiChooserSheetState extends State<_UpiChooserSheet> {
  String? _selected;
  bool _processing = false;

  Future<void> _onAppTapped(_UpiApp app) async {
    if (_processing) return;
    setState(() { _selected = app.name; _processing = true; });

    // Dummy: simulate UPI response delay
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    Navigator.pop(context); // close chooser
    _showBillDialog(app.name);
  }

  void _showBillDialog(String appName) {
    final b = widget.booking;
    final txnId = "TXN${DateTime.now().millisecondsSinceEpoch}";
    final baseAmount = b.price;
    final extra = b.extraCharges;
    final total = b.amountDue;
    final hasExtra = extra > 0;

    // Duration string
    String duration;
    final diff = b.endDate.difference(b.startDate);
    if (b.pricingUnit == "hour") {
      final hrs = diff.inMinutes / 60.0;
      duration = "${hrs.toStringAsFixed(1)} hr${hrs == 1 ? '' : 's'}";
    } else {
      final days = diff.inDays + 1;
      duration = "$days day${days == 1 ? '' : 's'}";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────────────────
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle,
                      color: Color(0xFF2E7D32), size: 40),
                ),
                const SizedBox(height: 12),
                const Text("Payment Successful!",
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Paid via $appName",
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade500)),

                const SizedBox(height: 20),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 12),

                // ── Bill title ───────────────────────────────────────────
                Row(children: [
                  Icon(Icons.receipt_long,
                      size: 16, color: Colors.indigo.shade400),
                  const SizedBox(width: 6),
                  const Text("Bill Receipt",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ]),
                const SizedBox(height: 14),

                // ── Provider ─────────────────────────────────────────────
                _BillRow(label: "Provider", value: b.providerName),
                const SizedBox(height: 6),

                // ── Service ──────────────────────────────────────────────
                _BillRow(label: "Service", value: b.skillTitle),
                const SizedBox(height: 6),

                // ── Duration ─────────────────────────────────────────────
                _BillRow(label: "Duration", value: duration),
                const SizedBox(height: 6),

                // ── Slot ─────────────────────────────────────────────────
                _BillRow(label: "Slot", value: b.slotRangeFormatted),
                const SizedBox(height: 12),

                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 10),

                // ── Base amount ──────────────────────────────────────────
                _BillRow(
                  label: "Base rate (${b.pricingUnit})",
                  value: "₹${baseAmount.toStringAsFixed(0)}",
                ),

                // ── Extra charges ────────────────────────────────────────
                if (hasExtra) ...[
                  const SizedBox(height: 6),
                  _BillRow(
                    label: "Extra time charges",
                    value: "+ ₹${extra.toStringAsFixed(0)}",
                    valueColor: Colors.orange.shade700,
                  ),
                ],

                const SizedBox(height: 10),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 10),

                // ── Total ────────────────────────────────────────────────
                Row(children: [
                  const Text("Total Paid",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const Spacer(),
                  Text("₹${total.toStringAsFixed(0)}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF2E7D32))),
                ]),

                const SizedBox(height: 14),
                Divider(color: Colors.grey.shade200),
                const SizedBox(height: 8),

                // ── Transaction ID ───────────────────────────────────────
                Row(children: [
                  Icon(Icons.tag, size: 13, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(txnId,
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                            fontFamily: 'monospace')),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Done button ──────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dCtx); // close bill dialog
                      widget.onPaid();     // update local state in detail sheet
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text("Done",
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.booking.amountDue;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Row(children: [
            const Icon(Icons.lock_outline, size: 18, color: Colors.green),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Pay via UPI",
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text("Amount: ₹${amount.toStringAsFixed(0)}",
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade600)),
            ]),
          ]),
          const SizedBox(height: 4),
          Text("Choose your UPI app",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 16),

          // App grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: _kUpiApps.map((app) {
              final isLoading = _selected == app.name && _processing;
              return InkWell(
                onTap: _processing ? null : () => _onAppTapped(app),
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isLoading
                        ? app.color.withOpacity(0.08)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isLoading
                            ? app.color
                            : Colors.grey.shade200,
                        width: isLoading ? 1.5 : 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      isLoading
                          ? SizedBox(
                              width: 28, height: 28,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: app.color))
                          : Icon(app.icon, size: 32, color: app.color),
                      const SizedBox(height: 6),
                      Text(app.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.security, size: 13, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text("Secured by UPI",
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade400)),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bill row widget
// ─────────────────────────────────────────────────────────────────────────────

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _BillRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade600)),
        const Spacer(),
        const SizedBox(width: 12),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? Colors.black87)),
        ),
      ],
    );
  }
}
