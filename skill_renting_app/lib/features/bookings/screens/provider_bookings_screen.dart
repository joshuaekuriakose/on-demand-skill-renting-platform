import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import '../models/booking_model.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
import 'package:skill_renting_app/features/bookings/screens/navigation_screen.dart';
import 'package:skill_renting_app/features/chat/chat_screen.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart' as _authSt;
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';
import 'package:skill_renting_app/features/skills/skill_service.dart';
import 'dart:math' as _math;
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:skill_renting_app/features/profile/profile_service.dart';

// ─── Route-optimisation helpers ─────────────────────────────────────────────

class _LatLng {
  final double lat, lng;
  const _LatLng(this.lat, this.lng);
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  double r(double d) => d * _math.pi / 180;
  final dLat = r(lat2 - lat1);
  final dLon = r(lon2 - lon1);
  final a = _math.pow(_math.sin(dLat / 2), 2) +
      _math.cos(r(lat1)) * _math.cos(r(lat2)) *
      _math.pow(_math.sin(dLon / 2), 2);
  return 6371.0 * 2 *
      _math.atan2(_math.sqrt(a.toDouble()), _math.sqrt(1 - a.toDouble()));
}

String _ordinal(int n) {
  if (n == 1) return '1st';
  if (n == 2) return '2nd';
  if (n == 3) return '3rd';
  return '${n}th';
}

// ────────────────────────────────────────────────────────────────────────────

class ProviderBookingsScreen extends StatefulWidget {
  const ProviderBookingsScreen({super.key});

  // Public static — shared with MainDashboard so both screens read/write
  // the same seen-bookings state without needing a state management package.
  static final Set<String> seenBookingIds = {};

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

  // Day-wise filter for the "Requests" tab.
  String _selectedRequestDayKey = "";

  // Cached available slots for hourly skills on the selected day.
  bool _slotsLoading = false;
  String _slotsLoadedForDayKey = "";
  Map<String, List<dynamic>> _availableSlotsBySkill = {};

  // Route-optimised ranking (bookingId → rank and label)
  Map<String, int>    _routeRanks  = {};
  Map<String, String> _routeLabels = {};

  // Badge count = active bookings whose IDs are NOT in this set.
  // Defined as static on ProviderBookingsScreen (widget class) for cross-screen access.

  static const _badgeStatuses = {"accepted", "in_progress", "completed"};

  String _dayKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }

  DateTime _dayFromKey(String dayKey) {
    // Expected format: yyyy-MM-dd
    final parts = dayKey.split("-");
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return DateTime(y, m, d);
  }

  String _dayLabel(DateTime dt) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    final mm = months[dt.month - 1];
    return "$mm ${dt.day}";
  }

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

  // Call this when the Bookings tab is opened — marks all current active IDs as seen.
  void _markBookingsSeen() {
    final activeIds = _bookings
        .where((b) => _badgeStatuses.contains(b.status))
        .map((b) => b.id)
        .toSet();
    setState(() => ProviderBookingsScreen.seenBookingIds.addAll(activeIds));
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);
    final data = await BookingService.fetchProviderBookings();
    data.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (mounted) {
      setState(() {
        _bookings = data;
        _loading = false;

        // Initialize the selected day for day-wise request filtering.
        final requested = data.where((b) => b.status == "requested").toList()
          ..sort((a, b) => a.startDate.compareTo(b.startDate));
        if (requested.isNotEmpty) {
          _selectedRequestDayKey = _dayKey(requested.first.startDate);
        } else {
          _selectedRequestDayKey = "";
        }

        // Reset slot cache because the selected day may change.
        _slotsLoading = false;
        _slotsLoadedForDayKey = "";
        _availableSlotsBySkill = {};
      });
      _computeRouteRanks(_selectedRequestDayKey);
    }
  }

  // Geocodes pincodes, groups by slot-hour, builds greedy route chain.
  // Hourly → full chain (rank 1 = closest to provider, rank 2+ = next stop).
  // Daily  → single "Closest to you" label only (no chain).
  Future<void> _computeRouteRanks(String dayKey) async {
    // Only requests on the SELECTED day
    final dayRequests = _bookings.where((b) =>
        b.status == 'requested' && _dayKey(b.startDate) == dayKey).toList();
    if (dayRequests.isEmpty) {
      if (mounted) setState(() { _routeRanks = {}; _routeLabels = {}; });
      return;
    }

    final token  = await _authSt.AuthStorage.getToken();
    final profile = await ProfileService.getProfile();
    final provPin = profile?.address?['pincode']?.toString();

    final allPins = <String>{};
    if (provPin != null && provPin.isNotEmpty) allPins.add(provPin);
    for (final b in dayRequests) {
      final pin = b.jobAddress?['pincode']?.toString();
      if (pin != null && pin.isNotEmpty) allPins.add(pin);
    }

    final coords = <String, _LatLng>{};
    for (final pin in allPins) {
      try {
        final res = await ApiService.get('/utils/pincode/$pin', token: token);
        if (res['statusCode'] == 200) {
          final lat = (res['data']?['lat'] as num?)?.toDouble();
          final lon = (res['data']?['lon'] as num?)?.toDouble();
          if (lat != null && lon != null) coords[pin] = _LatLng(lat, lon);
        }
      } catch (_) {}
    }

    _LatLng? currentPos = provPin != null ? coords[provPin] : null;

    // ── Separate hourly vs daily ──────────────────────────────────────────
    final hourlyRequests = dayRequests.where((b) => b.pricingUnit == 'hour').toList();
    final dailyRequests  = dayRequests.where((b) => b.pricingUnit != 'hour').toList();

    final ranks  = <String, int>{};
    final labels = <String, String>{};

    // Helper: distance from currentPos to a booking's pincode (or fallback)
    double _distTo(_LatLng? pos, BookingModel b) {
      final pin = b.jobAddress?['pincode']?.toString();
      if (pos != null && pin != null && coords[pin] != null) {
        return _haversineKm(pos.lat, pos.lng, coords[pin]!.lat, coords[pin]!.lng);
      }
      return b.distanceKmEstimate ?? double.infinity;
    }

    // ── Special case: exactly 1 hourly AND daily bookings present ────────
    // Compare both pools together — only the true closest gets "Closest to you"
    if (hourlyRequests.length == 1 && dailyRequests.isNotEmpty) {
      final combined = [...hourlyRequests, ...dailyRequests];
      BookingModel? best;
      double bestDist = double.infinity;
      for (final b in combined) {
        final d = _distTo(currentPos, b);
        if (d < bestDist) { bestDist = d; best = b; }
      }
      if (best != null) {
        ranks[best.id]  = 1;
        labels[best.id] = 'Closest to you';
      }
    } else {
      // ── Normal path: hourly chain + daily closest (independent) ─────────

      // Hourly: group by slot-hour, build greedy route chain
      if (hourlyRequests.isNotEmpty) {
        final slotGroups = <String, List<BookingModel>>{};
        for (final b in hourlyRequests) {
          final d = b.startDate;
          final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-'
              '${d.day.toString().padLeft(2,'0')}-'
              '${d.hour.toString().padLeft(2,'0')}';
          slotGroups.putIfAbsent(key, () => []).add(b);
        }
        int idx = 1;
        for (final key in slotGroups.keys.toList()..sort()) {
          BookingModel? best;
          double bestDist = double.infinity;
          for (final b in slotGroups[key]!) {
            final d = _distTo(currentPos, b);
            if (d < bestDist) { bestDist = d; best = b; }
          }
          if (best != null) {
            ranks[best.id]  = idx;
            labels[best.id] = idx == 1 ? 'Closest to you'
                : '${_ordinal(idx)} stop on your route';
            final pin = best.jobAddress?['pincode']?.toString();
            if (pin != null && coords[pin] != null) currentPos = coords[pin];
            idx++;
          }
        }
      }

      // Daily: just find the single closest — no chain
      if (dailyRequests.isNotEmpty) {
        BookingModel? best;
        double bestDist = double.infinity;
        for (final b in dailyRequests) {
          final d = _distTo(currentPos, b);
          if (d < bestDist) { bestDist = d; best = b; }
        }
        if (best != null) {
          ranks[best.id]  = 1;
          labels[best.id] = 'Closest to you';
        }
      }
    }

    if (mounted) setState(() { _routeRanks = ranks; _routeLabels = labels; });
  }

  Future<void> _loadHourlySlotsForDay(String dayKey) async {
    if (dayKey.isEmpty) return;
    if (_slotsLoadedForDayKey == dayKey && _availableSlotsBySkill.isNotEmpty) {
      return;
    }

    setState(() {
      _slotsLoading = true;
      _slotsLoadedForDayKey = dayKey;
    });

    try {
      final dayRequests = _requests
          .where((b) => _dayKey(b.startDate) == dayKey && b.pricingUnit == "hour")
          .toList();
      final skillIds = dayRequests.map((b) => b.skillId).toSet().toList();

      final results = await Future.wait(
        skillIds.map((skillId) async {
          final slots = await SkillService.fetchAvailableSlots(skillId, dayKey);
          return MapEntry(skillId, slots);
        }),
      );

      setState(() {
        _availableSlotsBySkill = Map<String, List<dynamic>>.fromEntries(results);
      });
    } finally {
      if (mounted) {
        setState(() => _slotsLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String id, String action) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final ok = await BookingService.updateBookingStatus(id, action);
      if (!ok || !mounted) return;
      final newStatus = action == "accept" ? "accepted" : "rejected";
      setState(() {
        final i = _bookings.indexWhere((b) => b.id == id);
        if (i != -1) _bookings[i] = _bookings[i].copyWith(status: newStatus);
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

  // ── OTP actions ──────────────────────────────────────────────────────────────

  Future<void> _triggerBegin(String bookingId) async {
    if (_busy.contains(bookingId)) return;
    setState(() => _busy.add(bookingId));
    try {
      final ok = await BookingService.beginBooking(bookingId);
      if (!ok || !mounted) return;
      // After triggering, open OTP entry dialog
      _showOtpEntryDialog(bookingId, isBegin: true);
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
  }

  void _showOtpEntryDialog(String bookingId, {required bool isBegin}) {
    final ctrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(isBegin ? Icons.play_circle : Icons.check_circle,
                color: isBegin ? Colors.blue : Colors.green),
            const SizedBox(width: 10),
            Text(isBegin ? "Enter Begin OTP" : "Enter Completion OTP",
                style: const TextStyle(fontSize: 17)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Ask the seeker for the OTP shown on their screen.",
                style: TextStyle(fontSize: 13,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 32, letterSpacing: 12, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: "• • • •",
                  hintStyle: const TextStyle(letterSpacing: 12, fontSize: 28),
                  errorText: error,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) {
                  if (error != null) setS(() => error = null);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (ctrl.text.length != 4) {
                  setS(() => error = "Enter 4-digit OTP");
                  return;
                }
                Navigator.pop(ctx);
                if (isBegin) {
                  await _verifyBeginOtp(bookingId, ctrl.text);
                } else {
                  await _verifyCompleteOtp(bookingId, ctrl.text);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: isBegin ? Colors.blue : Colors.green,
                  foregroundColor: Colors.white),
              child: const Text("Verify"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _verifyBeginOtp(String bookingId, String otp) async {
    if (_busy.contains(bookingId)) return;
    setState(() => _busy.add(bookingId));
    try {
      final err = await BookingService.verifyBeginOtp(bookingId, otp);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
        // Re-open OTP entry
        _showOtpEntryDialog(bookingId, isBegin: true);
        return;
      }
      // Success
      setState(() {
        final i = _bookings.indexWhere((b) => b.id == bookingId);
        if (i != -1) _bookings[i] = _bookings[i].copyWith(status: "in_progress");
      });
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
  }

  void _showExtraChargesDialog(BookingModel b) {
    final now = DateTime.now();
    final bookedMs = b.endDate.difference(b.startDate).inMilliseconds;
    final elapsedMs = now.difference(b.startDate).inMilliseconds;
    final extraMs = elapsedMs - bookedMs;

    double extraAmount = 0;
    String extraLabel = "";

    if (extraMs > 0) {
      if (b.pricingUnit == "hour") {
        final extraHours = extraMs / (1000 * 60 * 60);
        extraAmount = double.parse((extraHours * b.price).toStringAsFixed(2));
        extraLabel =
            "${extraHours.toStringAsFixed(1)} extra hrs × ₹${b.price.toStringAsFixed(0)}/hr";
      } else if (b.pricingUnit == "day") {
        final extraDays = (extraMs / (1000 * 60 * 60 * 24)).ceil();
        extraAmount = extraDays * b.price;
        extraLabel = "$extraDays extra day(s) × ₹${b.price.toStringAsFixed(0)}/day";
      }
    }

    bool addExtra = extraAmount > 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final dScheme = Theme.of(ctx).colorScheme;
          return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Complete Job"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Base amount
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: dScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: dScheme.outlineVariant)),
                child: Row(children: [
                  Icon(Icons.currency_rupee, color: dScheme.onSurfaceVariant, size: 18),
                  const SizedBox(width: 8),
                  Text("Base rate: ₹${b.price.toStringAsFixed(0)} / ${b.pricingUnit}",
                      style: const TextStyle(fontSize: 14)),
                ]),
              ),

              // Extra charges (only if time overrun)
              if (extraAmount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.more_time,
                            color: Colors.orange.shade700, size: 18),
                        const SizedBox(width: 6),
                        Text("Extra time detected",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                                fontSize: 13)),
                      ]),
                      const SizedBox(height: 6),
                      Text(extraLabel,
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade700)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Checkbox(
                          value: addExtra,
                          activeColor: Colors.orange,
                          onChanged: (v) => setS(() => addExtra = v ?? false),
                        ),
                        Expanded(
                          child: Text(
                              "Add ₹${extraAmount.toStringAsFixed(0)} extra",
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ]),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Total
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.35))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total",
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text(
                      "₹${(b.price + (addExtra ? extraAmount : 0)).toStringAsFixed(0)}",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.green.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel")),
            ElevatedButton.icon(
              onPressed: () async {
                final charges = addExtra ? extraAmount : 0.0;
                Navigator.pop(ctx);
                await _doRequestComplete(b.id, charges);
              },
              icon: const Icon(Icons.send, size: 16),
              label: const Text("Send OTP to Seeker"),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white),
            ),
          ],
        );
        },
      ),
    );
  }

  Future<void> _doRequestComplete(String bookingId, double extraCharges) async {
    if (_busy.contains(bookingId)) return;
    setState(() => _busy.add(bookingId));
    try {
      final ok = await BookingService.requestComplete(bookingId,
          extraCharges: extraCharges);
      if (!ok || !mounted) return;
      // OTP sent to seeker; show OTP entry for provider
      _showOtpEntryDialog(bookingId, isBegin: false);
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
  }

  Future<void> _verifyCompleteOtp(String bookingId, String otp) async {
    if (_busy.contains(bookingId)) return;
    setState(() => _busy.add(bookingId));
    try {
      final err = await BookingService.verifyCompleteOtp(bookingId, otp);
      if (!mounted) return;
      if (err != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err)));
        _showOtpEntryDialog(bookingId, isBegin: false);
        return;
      }
      // Success — refresh to get totalAmount
      final fresh = await BookingService.fetchProviderBookings();
      fresh.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _bookings = fresh);
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
  }

  // ── Derived lists ────────────────────────────────────────────────────────────

  List<BookingModel> get _requests =>
      _bookings.where((b) => b.status == "requested").toList();

  List<BookingModel> get _otherBookings =>
      _bookings.where((b) => b.status != "requested").toList();

  // Only these statuses count toward the Bookings badge
  List<BookingModel> get _activeBookings => _bookings
      .where((b) => _badgeStatuses.contains(b.status))
      .toList();

  // Badge count = active bookings the user hasn't seen yet
  int get _unseenBookingsCount => _bookings
      .where((b) => _badgeStatuses.contains(b.status) && !ProviderBookingsScreen.seenBookingIds.contains(b.id))
      .length;

  Map<String, _SkillGroup> get _requestsBySkill {
    final map = <String, _SkillGroup>{};
    for (final b in _requests) {
      map.putIfAbsent(b.skillId,
              () => _SkillGroup(skillId: b.skillId, skillTitle: b.skillTitle))
          .bookings
          .add(b);
    }
    return map;
  }

  Map<String, _SkillGroup> _requestsBySkillFor(List<BookingModel> requests) {
    final map = <String, _SkillGroup>{};
    for (final b in requests) {
      map.putIfAbsent(
        b.skillId,
        () => _SkillGroup(skillId: b.skillId, skillTitle: b.skillTitle),
      ).bookings.add(b);
    }
    return map;
  }

  // ── Navigate helper ──────────────────────────────────────────────────────────

  void _navigate(BookingModel b) {
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text("Job Queue"),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            if (index == 1) _markBookingsSeen();
          },
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
                  if (_unseenBookingsCount > 0) ...[
                    const SizedBox(width: 6),
                    _Badge(_unseenBookingsCount, Colors.blue),
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
                // ── Requests tab ──────────────────────────────────────────
                Builder(
                  builder: (ctx) {
                    final scheme = Theme.of(ctx).colorScheme;
                    final dayKeys = _requests
                        .map((b) => _dayKey(b.startDate))
                        .toSet()
                        .toList()
                      ..sort();

                    final selectedKey = (_selectedRequestDayKey.isNotEmpty &&
                            dayKeys.contains(_selectedRequestDayKey))
                        ? _selectedRequestDayKey
                        : (dayKeys.isNotEmpty ? dayKeys.first : "");

                    final dayRequests = _requests
                        .where((b) => _dayKey(b.startDate) == selectedKey)
                        .toList();
                    final dayGroups = _requestsBySkillFor(dayRequests);

                    final hourSkillsPresent =
                        dayRequests.any((b) => b.pricingUnit == "hour");

                    if (selectedKey.isNotEmpty &&
                        hourSkillsPresent &&
                        _slotsLoadedForDayKey != selectedKey &&
                        !_slotsLoading) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _loadHourlySlotsForDay(selectedKey);
                      });
                    }

                    return Column(
                      children: [
                        if (dayKeys.isNotEmpty)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: dayKeys.map((k) {
                                final label = _dayLabel(_dayFromKey(k));
                                final selected = k == selectedKey;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(label),
                                    selected: selected,
                                    backgroundColor: scheme.surfaceVariant,
                                    selectedColor: scheme.primaryContainer,
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurfaceVariant,
                                    ),
                                    onSelected: (v) {
                                      if (!v) return;
                                      setState(() => _selectedRequestDayKey = k);
                                      _loadHourlySlotsForDay(k);
                                      _computeRouteRanks(k);
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        if (hourSkillsPresent) ...[
                          if (selectedKey.isNotEmpty && _slotsLoading && _slotsLoadedForDayKey == selectedKey)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else ...[
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Available slots (${_dayLabel(_dayFromKey(selectedKey))})",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            ListView(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 0),
                              children: [
                                  for (final skillGroup in dayGroups.values)
                                    _HourlySlotsForSkill(
                                      skillId: skillGroup.skillId,
                                      bookings: skillGroup.bookings,
                                      occupiedBookings: _bookings.where((b) =>
                                          b.skillId == skillGroup.skillId &&
                                          (b.status == "accepted" || b.status == "in_progress") &&
                                          _dayKey(b.startDate) == selectedKey).toList(),
                                      dayKey: selectedKey,
                                      availableSlots: _availableSlotsBySkill[skillGroup.skillId] ?? [],
                                      isLoading: _slotsLoading,
                                      onTapSlotRequests: (list) => _showSlotRequestsSheet(list),
                                      onTapOccupied: (b) => _showDetailSheet(b),
                                    ),
                              ],
                            ),
                          ],
                        ],

                        // Requests list for selected day (accept/reject)
                        Expanded(
                          child: _RequestsTab(
                            groups: dayGroups,
                            busy: _busy,
                            onAccept: (id) => _updateStatus(id, "accept"),
                            onReject: (id) => _updateStatus(id, "reject"),
                            onTap: (b) => _showDetailSheet(b),
                            onRefresh: _loadBookings,
                            routeRanks:  _routeRanks,
                            routeLabels: _routeLabels,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                // ── Bookings tab ──────────────────────────────────────────
                _BookingsTab(
                  bookings: _otherBookings,
                  busy: _busy,
                  onBegin: (b) => _triggerBegin(b.id),
                  onComplete: (b) => _showExtraChargesDialog(b),
                  onNavigate: (b) => _navigate(b),
                  onTap: (b) => _showDetailSheet(b),
                  onRefresh: _loadBookings,
                ),
              ],
            ),
    );
  }

  // ── Detail sheet ─────────────────────────────────────────────────────────────

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
        onBegin: b.status == "accepted"
            ? () { Navigator.pop(context); _triggerBegin(b.id); }
            : null,
        onComplete: b.status == "in_progress"
            ? () { Navigator.pop(context); _showExtraChargesDialog(b); }
            : null,
        onNavigate: b.hasGps
            ? () { Navigator.pop(context); _navigate(b); }
            : null,
        onMessage: (b.status == "accepted" || b.status == "in_progress")
            ? () async {
                Navigator.pop(context);
                final myId = await _authSt.AuthStorage.getUserId();
                if (!mounted) return;
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    chatType:        "booking",
                    bookingId:       b.id,
                    otherPersonName: b.seekerName,
                    currentUserId:   myId,
                  ),
                ));
              }
            : null,
        onApproveCancellation: (b.status == "in_progress" && b.cancellationRequested)
            ? () { Navigator.pop(context); _approveCancellation(b.id); }
            : null,
        onDenyCancellation: (b.status == "in_progress" && b.cancellationRequested)
            ? () { Navigator.pop(context); _denyCancellation(b.id); }
            : null,
      ),
    );
  }

  // Shows a bottom sheet listing all pending requests for a tapped slot.
  // If there is only one request, goes directly to its detail sheet.
  void _showSlotRequestsSheet(List<BookingModel> requests) {
    if (requests.isEmpty) return;
    if (requests.length == 1) {
      _showDetailSheet(requests.first);
      return;
    }

    final timeLabel = () {
      final s = requests.first.startDate;
      final e = requests.first.endDate;
      final hh = s.hour.toString().padLeft(2, '0');
      final mm = s.minute.toString().padLeft(2, '0');
      final eh = e.hour.toString().padLeft(2, '0');
      final em = e.minute.toString().padLeft(2, '0');
      return '$hh:$mm – $eh:$em';
    }();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final scheme = Theme.of(context).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          builder: (_, ctrl) => Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: scheme.outlineVariant.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(children: [
                    Icon(Icons.access_time_rounded,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Requests for $timeLabel',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: scheme.onSurface),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: Text('${requests.length}',
                          style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final b = requests[i];
                      final rank  = _routeRanks[b.id];
                      final label = _routeLabels[b.id];
                      final isFirst   = rank == 1;
                      final isOnRoute = (rank ?? 0) > 1;
                      final barColor  = isFirst
                          ? Colors.green
                          : isOnRoute
                              ? Colors.blue.shade400
                              : Colors.orange;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _showDetailSheet(b);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: scheme.outlineVariant.withOpacity(0.6)),
                          ),
                          child: Row(children: [
                            Container(
                              width: 4, height: 52,
                              decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(2)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(Icons.person_outline,
                                        size: 14,
                                        color: scheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(b.seekerName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                    ),
                                    if (label != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isFirst
                                                  ? Colors.green.shade700
                                                  : Colors.blue.shade700)
                                              .withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(label,
                                            style: TextStyle(
                                                color: isFirst
                                                    ? Colors.green.shade700
                                                    : Colors.blue.shade700,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ]),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    Icon(Icons.location_on,
                                        size: 13,
                                        color: scheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(b.jobDistrictLabel,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: scheme.onSurfaceVariant),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    if (b.distanceKmEstimate != null)
                                      Text(
                                        '~${b.distanceKmEstimate!.toStringAsFixed(1)} km',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: barColor,
                                            fontWeight: FontWeight.w600),
                                      ),
                                  ]),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _SmallBtn(
                                    label: "Accept",
                                    color: Colors.blue,
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _updateStatus(b.id, "accept");
                                    }),
                                const SizedBox(height: 4),
                                _SmallBtn(
                                    label: "Reject",
                                    color: Colors.red,
                                    outlined: true,
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _updateStatus(b.id, "reject");
                                    }),
                              ],
                            ),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _approveCancellation(String bookingId) async {
    if (_busy.contains(bookingId)) return;
    setState(() => _busy.add(bookingId));
    try {
      final ok = await BookingService.approveCancellation(bookingId);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cancellation approved.")));
        _loadBookings();
      }
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
  }

  Future<void> _denyCancellation(String bookingId) async {
    if (_busy.contains(bookingId)) return;
    setState(() => _busy.add(bookingId));
    try {
      final ok = await BookingService.denyCancellation(bookingId);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cancellation request denied.")));
        _loadBookings();
      }
    } finally {
      if (mounted) setState(() => _busy.remove(bookingId));
    }
  }
}

// ── Hourly slots for a single skill (selected day) ──────────────────────────
class _HourlySlotsForSkill extends StatefulWidget {
  final String skillId;
  final List<BookingModel> bookings;          // requested bookings this day
  final List<BookingModel> occupiedBookings;  // accepted/in_progress this day
  final String dayKey; // yyyy-MM-dd
  final List<dynamic> availableSlots;
  final bool isLoading;
  // Called with ALL pending requests that overlap a slot (may be >1)
  final void Function(List<BookingModel>)? onTapSlotRequests;
  // Called when tapping an occupied (accepted/in_progress) slot chip
  final void Function(BookingModel)? onTapOccupied;

  const _HourlySlotsForSkill({
    required this.skillId,
    required this.bookings,
    required this.dayKey,
    required this.availableSlots,
    required this.isLoading,
    this.occupiedBookings = const [],
    this.onTapSlotRequests,
    this.onTapOccupied,
  });

  @override
  State<_HourlySlotsForSkill> createState() => _HourlySlotsForSkillState();
}

class _HourlySlotsForSkillState extends State<_HourlySlotsForSkill> {
  bool _expanded = false; // collapsed by default

  DateTime _dayFromKey(String key) {
    final parts = key.split("-");
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return DateTime(y, m, d);
  }

  DateTime? _slotStartFromTimeStr(DateTime day, String timeStr) {
    final parts = timeStr.split(":");
    if (parts.length != 2) return null;
    final hh = int.tryParse(parts[0]);
    final mm = int.tryParse(parts[1]);
    if (hh == null || mm == null) return null;
    return DateTime(day.year, day.month, day.day, hh, mm);
  }

  @override
  Widget build(BuildContext context) {
    final scheme     = Theme.of(context).colorScheme;
    final day        = _dayFromKey(widget.dayKey);
    final bookings   = widget.bookings;
    final skillTitle = bookings.isNotEmpty ? bookings.first.skillTitle : "Skill";

    // Slot counts for the header pill
    final bookedCount   = bookings.length + widget.occupiedBookings.length;
    final totalSlots    = widget.availableSlots.length + widget.occupiedBookings.length;

    if (widget.isLoading && widget.availableSlots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: scheme.surfaceVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Collapsible header ───────────────────────────────────────
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Text(skillTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        )),
                  ),
                  if (totalSlots > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text("$bookedCount/$totalSlots booked",
                          style: TextStyle(fontSize: 10, color: scheme.onPrimaryContainer)),
                    ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: scheme.onSurfaceVariant),
                  ),
                ]),
              ),
            ),

            // ── Expandable slots grid ────────────────────────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Divider(height: 8),
                  const SizedBox(height: 4),
              if (widget.availableSlots.isEmpty)
                Text(
                  "No available slots",
                  style: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.7)),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.availableSlots.map((slot) {
                    final timeStr = slot?.toString() ?? "";
                    final slotStart = _slotStartFromTimeStr(day, timeStr);
                    if (slotStart == null) return const SizedBox.shrink();

                    // Collect ALL pending requests that overlap this slot
                    final matches = widget.bookings.where((b) {
                      return (slotStart.isAtSameMomentAs(b.startDate) ||
                              slotStart.isAfter(b.startDate)) &&
                          slotStart.isBefore(b.endDate);
                    }).toList();

                    final hasRequests = matches.isNotEmpty;
                    final chipBg = hasRequests
                        ? scheme.primaryContainer.withOpacity(0.35)
                        : scheme.surface;
                    final chipFg = hasRequests
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant;

                    if (hasRequests && widget.onTapSlotRequests != null) {
                      return ActionChip(
                        backgroundColor: chipBg,
                        avatar: Icon(Icons.assignment_outlined, size: 13, color: chipFg),
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(timeStr,
                                style: TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w700, color: chipFg)),
                            Text(
                              matches.length == 1
                                  ? "Request"
                                  : "${matches.length} Requests",
                              style: TextStyle(fontSize: 10, color: chipFg.withOpacity(0.8)),
                            ),
                          ],
                        ),
                        onPressed: () => widget.onTapSlotRequests!(matches),
                      );
                    }
                    return Chip(
                      backgroundColor: chipBg,
                      label: Text(timeStr, style: TextStyle(color: chipFg, fontSize: 12)),
                    );
                  }).toList(),
                ),
            // Occupied chips — tappable to view booking detail
            if (widget.occupiedBookings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: widget.occupiedBookings.map((ob) {
                  final ts = "${ob.startDate.hour.toString().padLeft(2,'0')}:"
                      "${ob.startDate.minute.toString().padLeft(2,'0')}";
                  return ActionChip(
                    avatar: Icon(Icons.lock_outline, size: 13, color: Colors.red.shade300),
                    backgroundColor: Colors.red.withOpacity(0.08),
                    side: BorderSide(color: Colors.red.withOpacity(0.25), width: 0.8),
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ts, style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.w700, color: Colors.red.shade300)),
                        Text("Occupied", style: TextStyle(fontSize: 10,
                            color: Colors.red.shade300)),
                      ],
                    ),
                    onPressed: widget.onTapOccupied != null
                        ? () => widget.onTapOccupied!(ob)
                        : null,
                  );
                }).toList(),
              ),
            ],
          ]),    // firstChild column children end
        ),       // Padding (firstChild) end
        secondChild: const SizedBox.shrink(),
      ),      // AnimatedCrossFade end
    ],        // Column children end
  ),          // Column end
  ),          // Card end
);            // Padding end
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Requests tab
// ═════════════════════════════════════════════════════════════════════════════

class _RequestsTab extends StatelessWidget {
  final Map<String, _SkillGroup> groups;
  final Set<String> busy;
  final void Function(String) onAccept;
  final void Function(String) onReject;
  final void Function(BookingModel) onTap;
  final Future<void> Function() onRefresh;
  final Map<String, int>    routeRanks;
  final Map<String, String> routeLabels;

  const _RequestsTab({
    required this.groups,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onTap,
    required this.onRefresh,
    this.routeRanks  = const {},
    this.routeLabels = const {},
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Center(
          child: Text("No pending requests", style: TextStyle(color: Colors.grey)));
    }
    final groupList = groups.values.toList();
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: groupList.length,
        itemBuilder: (context, gi) {
          final group = groupList[gi];
          if (groups.length == 1) {
            return Column(
              children: group.bookings
                  .map((b) => _RequestCard(
                        booking: b,
                        isBusy:     busy.contains(b.id),
                        routeRank:  routeRanks[b.id],
                        routeLabel: routeLabels[b.id],
                        onAccept: () => onAccept(b.id),
                        onReject: () => onReject(b.id),
                        onTap:    () => onTap(b),
                      ))
                  .toList(),
            );
          }
          return _SkillGroupTile(
            group:       group,
            busy:        busy,
            routeRanks:  routeRanks,
            routeLabels: routeLabels,
            onAccept: onAccept,
            onReject: onReject,
            onTap:    onTap,
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Skill group tile (expandable)
// ═════════════════════════════════════════════════════════════════════════════

class _SkillGroupTile extends StatefulWidget {
  final _SkillGroup group;
  final Set<String> busy;
  final Map<String, int>    routeRanks;
  final Map<String, String> routeLabels;
  final void Function(String) onAccept;
  final void Function(String) onReject;
  final void Function(BookingModel) onTap;

  const _SkillGroupTile({
    required this.group,
    required this.busy,
    required this.onAccept,
    required this.onReject,
    required this.onTap,
    this.routeRanks  = const {},
    this.routeLabels = const {},
  });

  @override
  State<_SkillGroupTile> createState() => _SkillGroupTileState();
}

class _SkillGroupTileState extends State<_SkillGroupTile> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Expanded(
                  child: Text(widget.group.skillTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                _Badge(widget.group.bookings.length, Colors.orange),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down,
                      color: scheme.onSurfaceVariant),
                ),
              ]),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState:
                _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              children: widget.group.bookings
                  .map((b) => _RequestCard(
                        booking:    b,
                        isBusy:     widget.busy.contains(b.id),
                        routeRank:  widget.routeRanks[b.id],
                        routeLabel: widget.routeLabels[b.id],
                        onAccept: () => widget.onAccept(b.id),
                        onReject: () => widget.onReject(b.id),
                        onTap:    () => widget.onTap(b),
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

// ═════════════════════════════════════════════════════════════════════════════
// Request card
// ═════════════════════════════════════════════════════════════════════════════

class _RequestCard extends StatelessWidget {
  final BookingModel booking;
  final bool isBusy;
  final int?    routeRank;   // 1 = closest to provider, 2+ = on-route stops
  final String? routeLabel;  // "Closest to you" / "2nd stop on your route"
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
    this.routeRank,
    this.routeLabel,
    this.nested = false,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final hasDistance = b.distanceKmEstimate != null;
    final scheme = Theme.of(context).colorScheme;

    final isFirst   = routeRank == 1;
    final isOnRoute = (routeRank ?? 0) > 1;
    final isRouted  = isFirst || isOnRoute;

    final barColor   = isFirst ? Colors.green : isOnRoute ? Colors.blue.shade400 : Colors.orange;
    final badgeColor = isFirst ? Colors.green.shade700 : Colors.blue.shade700;
    final badgeIcon  = isFirst ? Icons.near_me : Icons.route;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(nested ? 0 : 14),
      child: Container(
        margin: nested ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
        decoration: nested
            ? BoxDecoration(
                border: Border(
                  top: BorderSide(color: scheme.outlineVariant.withOpacity(0.8)),
                ),
                color: isRouted
                    ? barColor.withOpacity(isFirst ? 0.07 : 0.05)
                    : null,
              )
            : BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: isRouted
                    ? Border.all(color: barColor.withOpacity(0.35), width: 1.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3))
                ],
              ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Left accent bar
              Container(
                width: 4,
                height: 80,
                decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Name + Route badge ──────────────────────────────────
                    Row(children: [
                      Icon(Icons.person_outline,
                          size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(b.seekerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      if (isRouted && routeLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: badgeColor.withOpacity(0.3), width: 0.8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, size: 11, color: badgeColor),
                              const SizedBox(width: 3),
                              Text(routeLabel!,
                                  style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Icon(Icons.chevron_right,
                          size: 18, color: scheme.onSurfaceVariant),
                    ]),

                    const SizedBox(height: 4),

                    // ── Locality  •  ~X.X km ───────────────────────────────
                    Row(children: [
                      Icon(Icons.location_on,
                          size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          () {
                            final loc = b.jobAddress?["locality"]
                                    ?.toString()
                                    .trim() ??
                                "";
                            final dist = hasDistance
                                ? "~${b.distanceKmEstimate!.toStringAsFixed(1)} km"
                                : "";
                            if (loc.isNotEmpty && dist.isNotEmpty) {
                              return "$loc  •  $dist";
                            } else if (loc.isNotEmpty) {
                              return loc;
                            } else if (dist.isNotEmpty) {
                              return dist;
                            }
                            return "Location not set";
                          }(),
                          style: TextStyle(
                            fontSize: 12,
                            color: isRouted && hasDistance
                                ? barColor
                                : scheme.onSurfaceVariant.withOpacity(0.85),
                            fontWeight: isRouted && hasDistance
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),

                    const SizedBox(height: 3),

                    // ── District ───────────────────────────────────────────
                    Row(children: [
                      Icon(Icons.map_outlined,
                          size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          b.jobDistrictLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),

                    const SizedBox(height: 3),

                    // ── Date • Slot ────────────────────────────────────────
                    Row(children: [
                      Icon(Icons.access_time,
                          size: 13, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          b.slotRangeFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Accept / Reject buttons
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isBusy
                    ? const SizedBox(
                        key: ValueKey("busy"),
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
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

// ═════════════════════════════════════════════════════════════════════════════
// Bookings tab
// ═════════════════════════════════════════════════════════════════════════════

class _BookingsTab extends StatelessWidget {
  final List<BookingModel> bookings;
  final Set<String> busy;
  final void Function(BookingModel) onBegin;
  final void Function(BookingModel) onComplete;
  final void Function(BookingModel) onNavigate;
  final void Function(BookingModel) onTap;
  final Future<void> Function() onRefresh;

  const _BookingsTab({
    required this.bookings,
    required this.busy,
    required this.onBegin,
    required this.onComplete,
    required this.onNavigate,
    required this.onTap,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return const Center(
          child: Text("No bookings yet", style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
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
              onBegin: b.status == "accepted" ? () => onBegin(b) : null,
              onComplete: b.status == "in_progress" ? () => onComplete(b) : null,
              onNavigate: b.hasGps &&
                      (b.status == "accepted" || b.status == "in_progress")
                  ? () => onNavigate(b)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _BookingListCard extends StatelessWidget {
  final BookingModel booking;
  final bool isBusy;
  final VoidCallback? onBegin;
  final VoidCallback? onComplete;
  final VoidCallback? onNavigate;

  const _BookingListCard({
    required this.booking,
    required this.isBusy,
    this.onBegin,
    this.onComplete,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final scheme = Theme.of(context).colorScheme;
    Color statusColor;
    switch (b.status) {
      case "accepted":    statusColor = Colors.blue;   break;
      case "in_progress": statusColor = Colors.purple; break;
      case "completed":   statusColor = Colors.green;  break;
      case "rejected":    statusColor = Colors.red;    break;
      default:            statusColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surface,
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
          // Status bar
          Container(
            width: 5, height: 90,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(b.skillTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                    ),
                    _StatusChip(b.status),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.person_outline,
                        size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(b.seekerName,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant.withOpacity(0.85),
                        )),
                  ]),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.access_time,
                        size: 13, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(b.slotRangeFormatted,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant.withOpacity(0.85),
                        )),
                  ]),
                  const SizedBox(height: 8),

                  // Action buttons
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isBusy
                        ? const Row(
                            key: ValueKey("busy"),
                            children: [
                              SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                              SizedBox(width: 8),
                              Text("Updating…",
                                  style: TextStyle(fontSize: 12)),
                            ],
                          )
                        : Wrap(
                            key: const ValueKey("actions"),
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (onNavigate != null)
                                _SmallBtn(
                                    label: "Navigate",
                                    icon: Icons.navigation_rounded,
                                    color: Colors.blue.shade700,
                                    onPressed: onNavigate!),
                              if (onBegin != null)
                                _SmallBtn(
                                    label: "Begin",
                                    icon: Icons.play_arrow_rounded,
                                    color: Colors.blue,
                                    onPressed: onBegin!),
                              if (onComplete != null)
                                _SmallBtn(
                                    label: "Complete",
                                    icon: Icons.check_circle_outline,
                                    color: Colors.green,
                                    onPressed: onComplete!),
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

// ═════════════════════════════════════════════════════════════════════════════
// Full detail bottom sheet (provider view)
// ═════════════════════════════════════════════════════════════════════════════

class _BookingDetailSheet extends StatelessWidget {
  final BookingModel booking;
  final bool isBusy;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onBegin;
  final VoidCallback? onComplete;
  final VoidCallback? onNavigate;
  final VoidCallback? onMessage;
  final VoidCallback? onApproveCancellation;
  final VoidCallback? onDenyCancellation;

  const _BookingDetailSheet({
    required this.booking,
    required this.isBusy,
    this.onAccept,
    this.onReject,
    this.onBegin,
    this.onComplete,
    this.onNavigate,
    this.onMessage,
    this.onApproveCancellation,
    this.onDenyCancellation,
  });

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final scheme = Theme.of(context).colorScheme;
    Color statusColor;
    switch (b.status) {
      case "requested":   statusColor = Colors.orange; break;
      case "accepted":    statusColor = Colors.blue;   break;
      case "in_progress": statusColor = Colors.purple; break;
      case "completed":   statusColor = Colors.green;  break;
      default:            statusColor = Colors.red;
    }

    final statusLabel = b.status.replaceAll("_", " ").toUpperCase();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.96,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withOpacity(0.7),
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
                    Text("Requested on ${b.createdAtFormatted}",
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withOpacity(0.85),
                            fontSize: 12)),

                    const SizedBox(height: 20),
                    const _SectionLabel("Seeker"),
                    _DetailRow(icon: Icons.person, text: b.seekerName, bold: true),

                    const SizedBox(height: 16),
                    const _SectionLabel("When"),
                    _DetailRow(icon: Icons.calendar_today, text: b.slotRangeFormatted),

                    const SizedBox(height: 16),
                    const _SectionLabel("Location"),
                    _DetailRow(icon: Icons.location_on, text: b.jobAddressFormatted),
                    if (b.distanceKmEstimate != null) ...[
                      const SizedBox(height: 6),
                      _DetailRow(
                          icon: Icons.directions_walk,
                          text: b.distanceLabel,
                          subtle: true),
                    ],

                    const SizedBox(height: 16),
                    const _SectionLabel("Pricing"),
                    _DetailRow(
                        icon: Icons.currency_rupee,
                        text: "₹${b.price.toStringAsFixed(0)} / ${b.pricingUnit}"),
                    if (b.extraCharges > 0) ...[
                      const SizedBox(height: 4),
                      _DetailRow(
                          icon: Icons.more_time,
                          text: "Extra: ₹${b.extraCharges.toStringAsFixed(0)}",
                          subtle: true),
                      const SizedBox(height: 4),
                      _DetailRow(
                          icon: Icons.receipt,
                          text: "Total: ₹${b.amountDue.toStringAsFixed(0)}",
                          bold: true),
                    ],

                    if (b.jobDescription != null && b.jobDescription!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SectionLabel("Description"),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Text(b.jobDescription!,
                            style: TextStyle(fontSize: 14, height: 1.5,
                                color: scheme.onSurfaceVariant)),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Actions
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
                                  minimumSize: const Size.fromHeight(48)),
                              child: const Text("Accept Request"),
                            ),
                          if (onReject != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: onReject,
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  minimumSize: const Size.fromHeight(48)),
                              child: const Text("Reject Request"),
                            ),
                          ],
                          if (onNavigate != null) ...[
                            ElevatedButton.icon(
                              onPressed: onNavigate,
                              icon: const Icon(Icons.navigation_rounded, size: 18),
                              label: const Text("Navigate to Job"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48)),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (onBegin != null)
                            ElevatedButton.icon(
                              onPressed: onBegin,
                              icon: const Icon(Icons.play_arrow_rounded, size: 20),
                              label: const Text("Begin Job (Send OTP)"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48)),
                            ),
                          if (onComplete != null) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: onComplete,
                              icon: const Icon(Icons.check_circle_outline, size: 20),
                              label: const Text("Mark Complete"),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48)),
                            ),
                          ],
                          if (onMessage != null) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: onMessage,
                              icon: const Icon(Icons.chat_bubble_outline, size: 18),
                              label: const Text("Message Customer"),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.teal,
                                  side: const BorderSide(color: Colors.teal),
                                  minimumSize: const Size.fromHeight(46)),
                            ),
                          ],

                          // Cancellation request: banner + approve/deny buttons
                          if (booking.cancellationRequested) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                border: Border.all(color: Colors.orange.withOpacity(0.4)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(Icons.warning_amber_rounded,
                                        size: 18, color: Colors.orange.shade700),
                                    const SizedBox(width: 6),
                                    Text("Customer Requested Cancellation",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade700,
                                            fontSize: 13)),
                                  ]),
                                  const SizedBox(height: 6),
                                  Text(
                                    "The customer wants to cancel this ongoing booking. "
                                    "You can approve or deny the request.",
                                    style: TextStyle(
                                        color: Colors.orange.shade700,
                                        fontSize: 12,
                                        height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: onApproveCancellation,
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(44)),
                                  child: const Text("Approve"),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: onDenyCancellation,
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.green.shade700,
                                      side: BorderSide(color: Colors.green.shade600),
                                      minimumSize: const Size.fromHeight(44)),
                                  child: const Text("Deny"),
                                ),
                              ),
                            ]),
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
// Small helpers
// ═════════════════════════════════════════════════════════════════════════════

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
    final onColor = color.computeLuminance() > 0.6 ? Colors.black : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text("$count",
          style: TextStyle(
              color: onColor, fontSize: 11, fontWeight: FontWeight.bold)),
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
      case "requested":   color = Colors.orange; break;
      case "accepted":    color = Colors.blue;   break;
      case "in_progress": color = Colors.purple; break;
      case "completed":   color = Colors.green;  break;
      default:            color = Colors.red;
    }
    final label = status.replaceAll("_", " ").toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label,
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
    final scheme = Theme.of(context).colorScheme;
    final onColor =
        color.computeLuminance() > 0.6 ? Colors.black : Colors.white;
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap)
        : ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: onColor,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap);

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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant.withOpacity(0.85),
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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                fontSize: bold ? 15 : 14,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
                color: subtle
                    ? scheme.onSurfaceVariant.withOpacity(0.85)
                    : scheme.onSurface,
              )),
        ),
      ],
    );
  }
}
