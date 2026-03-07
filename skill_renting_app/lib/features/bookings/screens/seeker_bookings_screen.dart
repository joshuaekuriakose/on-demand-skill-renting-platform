import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/reviews/screens/review_screen.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import 'package:skill_renting_app/features/bookings/models/booking_model.dart';
import 'package:skill_renting_app/features/common/widgets/empty_state.dart';
import 'package:skill_renting_app/features/skills/screens/skill_list_screen.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
import 'package:skill_renting_app/features/bookings/screens/booking_schedule_screen.dart';
import 'package:skill_renting_app/features/bookings/screens/gps_location_screen.dart';

class SeekerBookingsScreen extends StatefulWidget {
  const SeekerBookingsScreen({super.key});

  @override
  State<SeekerBookingsScreen> createState() => _SeekerBookingsScreenState();
}

class _SeekerBookingsScreenState extends State<SeekerBookingsScreen> {
  List<BookingModel> _bookings = [];
  bool _loading = true;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    final data = await BookingService.fetchMyBookings();
    // Sort latest first
    data.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) setState(() { _bookings = data; _loading = false; });
  }

  Future<void> _cancelBooking(String bookingId) async {
    if (_busy.contains(bookingId)) return;
    setState(() => _busy.add(bookingId));
    try {
      final ok =
          await BookingService.updateBookingStatus(bookingId, "cancel");
      if (!ok || !mounted) return;
      setState(() {
        final i = _bookings.indexWhere((b) => b.id == bookingId);
        if (i != -1) {
          _bookings[i] = _bookings[i].copyWith(status: "cancelled");
        }
      });
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
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
                  message: "You haven't booked any skills yet.",
                  buttonText: "Browse Skills",
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SkillListScreen()),
                  ),
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
                        onCancel: () => _cancelBooking(b.id),
                        onReschedule: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingScheduleScreen(
                                skillId: b.skillId,
                                pricingUnit: b.pricingUnit,
                              ),
                            ),
                          );
                          if (mounted) _loadBookings();
                        },
                        onReview: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ReviewScreen(booking: b)),
                          );
                          _loadBookings();
                        },
                        onShareGps: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GpsLocationScreen(
                                bookingId: b.id,
                                seekerName: "Job Location",
                              ),
                            ),
                          );
                          if (result == true && mounted) _loadBookings();
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────────

class _SeekerBookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool isBusy;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;
  final VoidCallback onReview;
  final VoidCallback onShareGps;

  const _SeekerBookingCard({
    required this.booking,
    required this.isBusy,
    required this.onCancel,
    required this.onReschedule,
    required this.onReview,
    required this.onShareGps,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final needsGps =
        b.status == "accepted" && b.gpsLocationStatus == "pending";

    return AnimatedContainer(
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
          // GPS banners
          if (needsGps) _GpsBanner(onShareGps: onShareGps, provided: false),
          if (b.status == "accepted" && b.gpsLocationStatus == "provided")
            _GpsBanner(onShareGps: onShareGps, provided: true),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + created at
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.skillTitle,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(b.createdAtFormatted,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                    _StatusBadge(b.status),
                  ],
                ),
                const SizedBox(height: 8),

                // Provider
                Row(children: [
                  const Icon(Icons.person, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(b.providerName,
                      style: const TextStyle(fontSize: 13)),
                ]),
                const SizedBox(height: 4),

                // Slot
                Row(children: [
                  const Icon(Icons.access_time,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(b.slotRangeFormatted,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87)),
                  ),
                ]),

                const SizedBox(height: 12),

                // Actions
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isBusy
                      ? const Padding(
                          key: ValueKey("busy"),
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text("Updating…",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                          ]),
                        )
                      : Column(
                          key: const ValueKey("actions"),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (needsGps) ...[
                              ElevatedButton.icon(
                                onPressed: onShareGps,
                                icon: const Icon(Icons.location_on),
                                label: const Text("Share GPS Location"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (b.status == "completed")
                              ElevatedButton(
                                onPressed: b.isReviewed
                                    ? () =>
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "Already reviewed")))
                                    : onReview,
                                child: Text(b.isReviewed
                                    ? "Reviewed"
                                    : "Give Review"),
                              ),
                            if (b.status == "requested")
                              OutlinedButton(
                                onPressed: onCancel,
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red),
                                child: const Text("Cancel Request"),
                              ),
                            if (b.status == "rejected")
                              ElevatedButton(
                                onPressed: onReschedule,
                                child: const Text("Reschedule"),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
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
      case "requested": color = Colors.orange; break;
      case "accepted":  color = Colors.blue;   break;
      case "completed": color = Colors.green;  break;
      case "rejected":  color = Colors.red;    break;
      default:          color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
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
    final icon = provided ? Icons.check_circle : Icons.location_on;
    final text = provided
        ? "Location shared with provider"
        : "Provider needs your job location";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500))),
        if (!provided)
          TextButton(
            onPressed: onShareGps,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text("Share Now",
                style:
                    TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
      ]),
    );
  }
}
