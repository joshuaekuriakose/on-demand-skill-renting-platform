import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../skills/skill_service.dart';
import '../booking_service.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';

class ProviderCalendarScreen extends StatefulWidget {
  final String skillId;
  final String pricingUnit;

  const ProviderCalendarScreen({
    super.key,
    required this.skillId,
    required this.pricingUnit,
  });

  @override
  State<ProviderCalendarScreen> createState() => _ProviderCalendarScreenState();
}

class _ProviderCalendarScreenState extends State<ProviderCalendarScreen> {
  DateTime? selectedDate;
  List<dynamic> slots = [];
  dynamic selectedSlot;
  bool isLoading = false;
  List<Map<String, dynamic>> occupiedItems = [];

  Future<void> _fetchOccupiedSlots(String formattedDate) async {
    final result =
        await BookingService.fetchOccupiedSlots(widget.skillId, formattedDate);

    final parsed = <Map<String, dynamic>>[];
    if (result is List) {
      for (final item in result) {
        if (item is Map) {
          final start =
              DateTime.tryParse(item["startDate"]?.toString() ?? "");
          final end = DateTime.tryParse(item["endDate"]?.toString() ?? "");
          if (start != null && end != null) {
            parsed.add({
              "start": start.toLocal(),
              "end": end.toLocal(),
              "type": item["type"] ?? "booking",
            });
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      occupiedItems = parsed;
    });
  }

  Future<void> _fetchAllOccupiedSlots() async {
    try {
      final result =
          await BookingService.fetchAllOccupiedSlots(widget.skillId);

      final parsed = <Map<String, dynamic>>[];
      if (result is List) {
        for (final item in result) {
          if (item is Map) {
            final start =
                DateTime.tryParse(item["startDate"]?.toString() ?? "");
            final end =
                DateTime.tryParse(item["endDate"]?.toString() ?? "");
            if (start != null && end != null) {
              parsed.add({
                "start": start.toLocal(),
                "end": end.toLocal(),
                "type": item["type"] ?? "booking",
              });
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        occupiedItems = parsed;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        occupiedItems = [];
      });
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
        selectedSlot = null;
        isLoading = true;
      });

      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);

      final result = await SkillService.fetchAvailableSlots(
        widget.skillId,
        formattedDate,
      );

      await _fetchOccupiedSlots(formattedDate);

      setState(() {
        slots = result;
        isLoading = false;
      });
    } else if (widget.pricingUnit == "day") {
      setState(() {
        selectedSlot = null;
        isLoading = true;
      });

      final result = await SkillService.fetchAvailableSlots(
        widget.skillId,
        "",
      );
      await _fetchAllOccupiedSlots();

      setState(() {
        slots = result;
        isLoading = false;
      });
    }
  }

  bool _isBooking(DateTime slotStart, DateTime slotEnd) {
    for (final item in occupiedItems) {
      final start = item["start"] as DateTime;
      final end = item["end"] as DateTime;
      if (start.isBefore(slotEnd) && end.isAfter(slotStart)) {
        if (item["type"] == "booking") return true;
      }
    }
    return false;
  }

  bool _isBlocked(DateTime slotStart, DateTime slotEnd) {
    for (final item in occupiedItems) {
      final start = item["start"] as DateTime;
      final end = item["end"] as DateTime;
      if (start.isBefore(slotEnd) && end.isAfter(slotStart)) {
        if (item["type"] == "blocked") return true;
      }
    }
    return false;
  }

  Future<void> _toggleSlot(DateTime slotStart) async {
    final end = _buildSlotEnd(slotStart);
    try {
      await BookingService.toggleBlockedSlot(
        skillId: widget.skillId,
        start: slotStart,
        end: end,
      );

      if (widget.pricingUnit == "hour" && selectedDate != null) {
        final formattedDate =
            DateFormat('yyyy-MM-dd').format(selectedDate!);
        await _fetchOccupiedSlots(formattedDate);
      } else {
        await _fetchAllOccupiedSlots();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text("Manage Calendar"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _loadAvailability,
              child: const Text("Load Availability"),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator()),
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
                    if (slotStart == null) {
                      return const SizedBox.shrink();
                    }
                    final slotEnd = _buildSlotEnd(slotStart);

                    final isBooked = _isBooking(slotStart, slotEnd);
                    final isBlocked = _isBlocked(slotStart, slotEnd);

                    Color bgColor;
                    if (isBooked) {
                      bgColor = Colors.red.shade300;
                    } else if (isBlocked) {
                      bgColor = Colors.orange.shade300;
                    } else {
                      bgColor = Colors.green.shade200;
                    }

                    return GestureDetector(
                      onTap: isBooked
                          ? null
                          : () => _toggleSlot(slotStart),
                      child: Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.pricingUnit == "hour"
                                    ? slotStr
                                    : DateFormat('dd MMM')
                                        .format(slotStart),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isBooked
                                    ? "Booked"
                                    : isBlocked
                                        ? "Rest"
                                        : "Free",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

