import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../skills/skill_service.dart';
import '../booking_service.dart';
import 'package:skill_renting_app/features/profile/profile_service.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';

class BookingScheduleScreen extends StatefulWidget {
  final String skillId;
  final String pricingUnit;

  const BookingScheduleScreen({
    super.key,
    required this.skillId,
    required this.pricingUnit,
  });

  @override
  State<BookingScheduleScreen> createState() =>
      _BookingScheduleScreenState();
}

class _BookingScheduleScreenState extends State<BookingScheduleScreen> {
  DateTime? selectedDate;
  List<dynamic> slots = [];
  List<dynamic> selectedSlots = [];
  bool isLoading = false;
  List<Map<String, DateTime>> occupiedRanges = [];

  @override
  void initState() {
    super.initState();
    // Auto-load availability as soon as the screen opens —
    // for hourly this shows the date picker immediately,
    // for daily it loads all available days right away.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAvailability());
  }

  // ── PIN validation ─────────────────────────────────────────────────────────
  String? _pinError;
  bool _pinValidating = false;
  String? _pinLookedUpDistrict; // what the server says the district is

  Future<void> _validatePin(String pin, String district) async {
    if (pin.length < 6) {
      if (_pinError != null || _pinLookedUpDistrict != null) {
        setState(() { _pinError = null; _pinLookedUpDistrict = null; });
      }
      return;
    }
    if (pin.length > 6) {
      setState(() { _pinError = "Invalid PIN code"; _pinLookedUpDistrict = null; });
      return;
    }

    // Exactly 6 digits — look up district
    setState(() { _pinValidating = true; _pinError = null; });
    try {
      final token = await AuthStorage.getToken();
      final res = await ApiService.get("/utils/pincode/$pin", token: token);
      if (res["statusCode"] == 200) {
        final serverDistrict = (res["data"]["district"] ?? "").toString().trim();
        setState(() { _pinLookedUpDistrict = serverDistrict; });

        // If district field is already filled, cross-check now
        if (district.trim().isNotEmpty) {
          if (district.trim().toLowerCase() != serverDistrict.toLowerCase()) {
            setState(() {
              _pinError =
                  "PIN code doesn't match the district (expected: $serverDistrict)";
            });
          } else {
            setState(() { _pinError = null; });
          }
        }
      } else {
        setState(() { _pinError = "PIN code not found"; _pinLookedUpDistrict = null; });
      }
    } catch (e) {
      // Network error — don't block the user, but let the user know
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to validate PIN: ${e.toString()}")),
        );
        setState(() { _pinError = null; });
      }
    } finally {
      setState(() { _pinValidating = false; });
    }
  }

  void _checkDistrictAgainstPin(String district) {
    if (_pinLookedUpDistrict == null) return;
    if (district.trim().isEmpty) {
      setState(() { _pinError = null; });
      return;
    }
    if (district.trim().toLowerCase() !=
        _pinLookedUpDistrict!.toLowerCase()) {
      setState(() {
        _pinError =
            "PIN code doesn't match the district (expected: $_pinLookedUpDistrict)";
      });
    } else {
      setState(() { _pinError = null; });
    }
  }
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _fetchOccupiedSlots(String formattedDate) async {
    final result = await BookingService.fetchOccupiedSlots(
        widget.skillId, formattedDate);
    final parsed = <Map<String, DateTime>>[];
    if (result is List) {
      for (final item in result) {
        if (item is Map) {
          final start =
              DateTime.tryParse(item["startDate"]?.toString() ?? "");
          final end =
              DateTime.tryParse(item["endDate"]?.toString() ?? "");
          if (start != null && end != null) {
            parsed.add({"start": start.toLocal(), "end": end.toLocal()});
          }
        }
      }
    }
    if (!mounted) return;
    setState(() { occupiedRanges = parsed; });
  }

  Future<void> _fetchAllOccupiedSlots() async {
    try {
      final result =
          await BookingService.fetchAllOccupiedSlots(widget.skillId);
      final parsed = <Map<String, DateTime>>[];
      if (result is List) {
        for (final item in result) {
          if (item is Map) {
            final start =
                DateTime.tryParse(item["startDate"]?.toString() ?? "");
            final end =
                DateTime.tryParse(item["endDate"]?.toString() ?? "");
            if (start != null && end != null) {
              parsed.add({"start": start.toLocal(), "end": end.toLocal()});
            }
          }
        }
      }
      if (!mounted) return;
      setState(() { occupiedRanges = parsed; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load occupied slots: ${e.toString()}")),
      );
      setState(() { occupiedRanges = []; });
    }
  }

  DateTime? _buildSlotStart(dynamic slot) {
    final slotStr = slot?.toString() ?? "";
    if (slotStr.trim().isEmpty) return null;
    if (widget.pricingUnit == "hour") {
      final base = selectedDate;
      if (base == null) return null;
      final parts = slotStr.split(":");
      if (parts.length != 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      return DateTime(base.year, base.month, base.day, hour, minute);
    }
    final parts = slotStr.split("-");
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  DateTime _buildSlotEnd(DateTime start) {
    return widget.pricingUnit == "hour"
        ? start.add(const Duration(hours: 1))
        : start.add(const Duration(days: 1));
  }

  Future<void> _loadAvailability() async {
    if (widget.pricingUnit == "hour") {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 30)),
      );
      if (picked == null) return;
      setState(() {
        selectedDate = picked;
        selectedSlots = [];
        isLoading = true;
      });
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      final result =
          await SkillService.fetchAvailableSlots(widget.skillId, formattedDate);
      await _fetchOccupiedSlots(formattedDate);
      setState(() { slots = result; isLoading = false; });
    } else if (widget.pricingUnit == "day") {
      setState(() {
        selectedSlots = [];
        isLoading = true;
      });
      final result =
          await SkillService.fetchAvailableSlots(widget.skillId, "");
      await _fetchAllOccupiedSlots();
      setState(() { slots = result; isLoading = false; });
    }
  }

  bool _isSlotLocked(DateTime slotStart, DateTime slotEnd) {
    // Lock any slot whose start time is in the past
    if (slotStart.isBefore(DateTime.now())) return true;

    // Lock slots that overlap with already-booked ranges
    for (var range in occupiedRanges) {
      if (range["start"]!.isBefore(slotEnd) &&
          range["end"]!.isAfter(slotStart)) {
        return true;
      }
    }
    return false;
  }

  /// Returns true if booking THIS slot right now would put the seeker
  /// inside the cancellation-penalty window at the time of booking.
  /// Hourly: booked within 30 min of slot start.
  /// Daily:  booked within 6 hrs of slot start (slots start at 07:00).
  bool _isInPenaltyWindow(DateTime slotStart) {
    final diff = slotStart.difference(DateTime.now());
    if (widget.pricingUnit == "hour") return diff.inMinutes < 30 && diff.inSeconds > 0;
    if (widget.pricingUnit == "day")  return diff.inMinutes < 360 && diff.inSeconds > 0;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text("Schedule")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show selected date header with change option (hourly only)
            if (!isLoading && selectedDate != null && widget.pricingUnit == "hour")
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('EEEE, d MMM yyyy').format(selectedDate!),
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _loadAvailability,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text("Change date"),
                    ),
                  ],
                ),
              ),
            if (isLoading) const Center(child: CircularProgressIndicator()),
            if (!isLoading && slots.isNotEmpty)
              Expanded(
                child: GridView.builder(
                  itemCount: slots.length,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    final slotStart = _buildSlotStart(slot);
                    final slotStr = slot?.toString() ?? "";
                    final slotEnd = slotStart == null
                        ? null
                        : _buildSlotEnd(slotStart);
                    final isLocked =
                        (slotStart == null || slotEnd == null)
                            ? true
                            : _isSlotLocked(slotStart, slotEnd);
                    final inPenalty = !isLocked && slotStart != null
                        && _isInPenaltyWindow(slotStart);
                    return GestureDetector(
                      onTap: isLocked
                          ? null
                          : () => setState(() {
                                if (selectedSlots.contains(slot)) {
                                  selectedSlots.remove(slot);
                                } else {
                                  selectedSlots.add(slot);
                                }
                              }),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isLocked
                              ? Colors.grey[400]
                              : selectedSlots.contains(slot)
                                  ? Colors.indigo
                                  : inPenalty
                                      ? Colors.orange.shade100
                                      : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          border: inPenalty && !selectedSlots.contains(slot)
                              ? Border.all(color: Colors.orange.shade400, width: 1.5)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.pricingUnit == "hour"
                                  ? slotStr
                                  : slotStart != null
                                      ? DateFormat('dd MMM').format(slotStart)
                                      : slotStr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isLocked
                                    ? Colors.black38
                                    : selectedSlots.contains(slot)
                                        ? Colors.white
                                        : Colors.black87,
                              ),
                            ),
                            if (inPenalty) ...[
                              const SizedBox(height: 2),
                              Text("50% penalty",
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: selectedSlots.contains(slot)
                                          ? Colors.white70
                                          : Colors.orange.shade800,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (selectedSlots.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _openBookingDialog(),
                  child: const Text("Confirm Booking"),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Booking dialog ─────────────────────────────────────────────────────────

  Future<void> _openBookingDialog() async {
    if (selectedSlots.isEmpty) return;

    // Convert selected slot tokens into concrete start times.
    final selectedStarts = selectedSlots
        .map(_buildSlotStart)
        .whereType<DateTime>()
        .toList()
      ..sort();

    if (selectedStarts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid slot selected")),
      );
      return;
    }

    final step = widget.pricingUnit == "hour"
        ? const Duration(hours: 1)
        : const Duration(days: 1);

    // Group consecutive slots into "runs"; each run becomes one booking.
    // Example (hour): 10:00, 11:00, 12:00 => one booking from 10:00..13:00.
    final segments = <Map<String, DateTime>>[];
    DateTime runStart = selectedStarts.first;
    DateTime prev = selectedStarts.first;

    for (final s in selectedStarts.skip(1)) {
      final expected = prev.add(step);
      final isConsecutive = s.difference(expected).abs() <= const Duration(seconds: 1);
      if (isConsecutive) {
        prev = s;
      } else {
        segments.add({
          "start": runStart,
          "end": _buildSlotEnd(prev),
        });
        runStart = s;
        prev = s;
      }
    }

    segments.add({
      "start": runStart,
      "end": _buildSlotEnd(prev),
    });

    final earliestStart = segments.first["start"]!;

    final profile = await ProfileService.getProfile();
    final profileAddress = profile?.address ?? {};
    final homeHouse = profileAddress["houseName"]?.toString().trim() ?? "";
    final homeLocality =
        profileAddress["locality"]?.toString().trim() ?? "";
    final homePin = profileAddress["pincode"]?.toString().trim() ?? "";
    final homeDistrict =
        profileAddress["district"]?.toString().trim() ?? "";

    final descCtrl = TextEditingController();
    final houseCtrl = TextEditingController();
    final localityCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final districtCtrl = TextEditingController();

    // Local state for dialog
    bool useHomeAddress = false;
    String? pinError;
    bool pinValidating = false;
    String? pinLookedUpDistrict;

    // PIN debounce timer
    void Function()? pinDebounce;

    Future<void> lookupPin(String pin, String district,
        void Function(void Function()) setS) async {
      if (pin.length < 6) {
        setS(() { pinError = null; pinLookedUpDistrict = null; });
        return;
      }
      if (pin.length > 6) {
        setS(() { pinError = "Invalid PIN code"; pinLookedUpDistrict = null; });
        return;
      }
      setS(() { pinValidating = true; pinError = null; });
      try {
        final token = await AuthStorage.getToken();
        final res =
            await ApiService.get("/utils/pincode/$pin", token: token);
        if (res["statusCode"] == 200) {
          final serverDistrict =
              (res["data"]["district"] ?? "").toString().trim();
          setS(() { pinLookedUpDistrict = serverDistrict; });
          if (district.trim().isNotEmpty &&
              district.trim().toLowerCase() !=
                  serverDistrict.toLowerCase()) {
            setS(() {
              pinError =
                  "PIN code doesn't match the district (expected: $serverDistrict)";
            });
          } else {
            // Auto-fill district if empty
            if (district.trim().isEmpty) {
              districtCtrl.text = serverDistrict;
            }
            setS(() { pinError = null; });
          }
        } else {
          setS(() {
            pinError = "PIN code not found";
            pinLookedUpDistrict = null;
          });
        }
      } catch (e) {
        setS(() {
          pinError = "PIN lookup failed. Please try again.";
          pinLookedUpDistrict = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("PIN lookup failed: ${e.toString()}")),
          );
        }
      } finally {
        setS(() { pinValidating = false; });
      }
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setS) {
          void applyHome() {
            houseCtrl.text = homeHouse;
            localityCtrl.text = homeLocality;
            pinCtrl.text = homePin;
            districtCtrl.text = homeDistrict;
            pinError = null;
            pinLookedUpDistrict = homeDistrict.isNotEmpty ? homeDistrict : null;
          }

          return AlertDialog(
            title: const Text("Booking details"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Penalty warning note ────────────────────────────
                  if (_isInPenaltyWindow(earliestStart)) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Cancellation Penalty Applies",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.orange.shade800)),
                                const SizedBox(height: 4),
                                Text(
                                  widget.pricingUnit == "hour"
                                      ? "You are booking within 30 minutes of the slot start. "
                                        "If you cancel, a 50% penalty will apply."
                                      : "You are booking within 6 hours of the slot start. "
                                        "If you cancel, a 50% penalty will apply.",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.orange.shade900,
                                      height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── Cancellation policy note (always shown) ──────────────
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Note: Cancellation Policy",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.blue.shade800)),
                        const SizedBox(height: 4),
                        if (widget.pricingUnit == "hour")
                          Text(
                            "• Cancelling within 30 minutes of the slot start will incur a 50% penalty of the booking rate.",
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700, height: 1.4),
                          ),
                        if (widget.pricingUnit == "day") ...[
                          Text(
                            "• Cancelling within 6 hours of the slot start will incur a 50% penalty of the daily rate.",
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700, height: 1.4),
                          ),
                          Text(
                            "• Daily job slots run from 7:00 AM to 7:00 AM (next day).",
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade700, height: 1.4),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Description
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                        labelText: "What do you need?"),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 10),

                  // Use home address toggle
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Use home address"),
                    subtitle: Text(homePin.isNotEmpty
                        ? "PIN: $homePin"
                        : "Add address in Profile to use this"),
                    value: useHomeAddress,
                    onChanged: homePin.isEmpty
                        ? null
                        : (v) {
                            setS(() => useHomeAddress = v);
                            if (v) applyHome();
                          },
                  ),

                  // House name
                  TextField(
                    controller: houseCtrl,
                    decoration:
                        const InputDecoration(labelText: "House name"),
                  ),

                  // Locality
                  TextField(
                    controller: localityCtrl,
                    decoration:
                        const InputDecoration(labelText: "Locality"),
                  ),

                  // PIN code with inline validation
                  const SizedBox(height: 8),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: "PIN code",
                      suffixIcon: pinValidating
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                            )
                          : null,
                    ),
                    onChanged: (v) {
                      if (useHomeAddress) setS(() => useHomeAddress = false);
                      // Immediate >6 check
                      if (v.length > 6) {
                        setS(() { pinError = "Invalid PIN code"; });
                        return;
                      }
                      // Lookup when exactly 6
                      lookupPin(v, districtCtrl.text, setS);
                    },
                  ),

                  // PIN error shown inline in red
                  if (pinError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        pinError!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12),
                      ),
                    ),

                  // District
                  TextField(
                    controller: districtCtrl,
                    decoration:
                        const InputDecoration(labelText: "District"),
                    onChanged: (v) {
                      if (useHomeAddress) setS(() => useHomeAddress = false);
                      // Re-check district vs known PIN
                      if (pinLookedUpDistrict != null) {
                        if (v.trim().isNotEmpty &&
                            v.trim().toLowerCase() !=
                                pinLookedUpDistrict!.toLowerCase()) {
                          setS(() {
                            pinError =
                                "PIN code doesn't match the district (expected: $pinLookedUpDistrict)";
                          });
                        } else {
                          setS(() { pinError = null; });
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                // Block Continue if PIN error exists
                onPressed: pinError != null || pinValidating
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text("Continue"),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return;

    // Validate description client-side before hitting server
    final description = descCtrl.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Description is required")),
      );
      return;
    }

    final jobAddress = {
      "houseName": houseCtrl.text.trim(),
      "locality": localityCtrl.text.trim(),
      "pincode": pinCtrl.text.trim(),
      "district": districtCtrl.text.trim(),
    };

    try {
      int createdCount = 0;
      for (final seg in segments) {
        await BookingService.createBooking(
          skillId: widget.skillId,
          startDate: seg["start"]!,
          endDate: seg["end"]!,
          duration: 1,
          description: description,
          jobAddress: jobAddress,
        );
        createdCount++;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Booking Requested (${createdCount})")),
      );
      Navigator.pop(context);
    } catch (e) {
      // Server errors shown as snackbar (not exception crash)
      if (!mounted) return;
      String message = e.toString();
      // Strip "Exception:" prefix if present
      message = message.replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}
