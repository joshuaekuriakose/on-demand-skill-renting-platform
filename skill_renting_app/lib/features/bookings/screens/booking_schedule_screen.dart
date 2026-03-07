import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../skills/skill_service.dart';
import '../booking_service.dart';
import 'package:skill_renting_app/features/profile/profile_service.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';

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
  dynamic selectedSlot;
  bool isLoading = false;
  List<Map<String, DateTime>> occupiedRanges = [];

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
    } catch (_) {
      // Network error — don't block the user
      setState(() { _pinError = null; });
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
    } catch (_) {
      if (!mounted) return;
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
      setState(() { selectedDate = picked; selectedSlot = null; isLoading = true; });
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      final result =
          await SkillService.fetchAvailableSlots(widget.skillId, formattedDate);
      await _fetchOccupiedSlots(formattedDate);
      setState(() { slots = result; isLoading = false; });
    } else if (widget.pricingUnit == "day") {
      setState(() { selectedSlot = null; isLoading = true; });
      final result =
          await SkillService.fetchAvailableSlots(widget.skillId, "");
      await _fetchAllOccupiedSlots();
      setState(() { slots = result; isLoading = false; });
    }
  }

  bool _isSlotLocked(DateTime slotStart, DateTime slotEnd) {
    for (var range in occupiedRanges) {
      if (range["start"]!.isBefore(slotEnd) &&
          range["end"]!.isAfter(slotStart)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Schedule")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _loadAvailability,
              child: const Text("Availability"),
            ),
            const SizedBox(height: 20),
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
                    return GestureDetector(
                      onTap: isLocked
                          ? null
                          : () => setState(() => selectedSlot = slot),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isLocked
                              ? Colors.grey[400]
                              : selectedSlot == slot
                                  ? Colors.indigo
                                  : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            widget.pricingUnit == "hour"
                                ? slotStr
                                : slotStart != null
                                    ? DateFormat('dd MMM').format(slotStart)
                                    : slotStr,
                            style: TextStyle(
                              color: isLocked
                                  ? Colors.black38
                                  : selectedSlot == slot
                                      ? Colors.white
                                      : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (selectedSlot != null)
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
    final start = _buildSlotStart(selectedSlot);
    if (start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid slot selected")),
      );
      return;
    }
    final end = _buildSlotEnd(start);

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
      } catch (_) {
        setS(() { pinError = null; });
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
      await BookingService.createBooking(
        skillId: widget.skillId,
        startDate: start,
        endDate: end,
        duration: 1,
        description: description,
        jobAddress: jobAddress,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Booking Requested")),
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
