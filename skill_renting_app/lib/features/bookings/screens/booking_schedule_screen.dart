import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../skills/skill_service.dart';

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

class _BookingScheduleScreenState
    extends State<BookingScheduleScreen> {

  DateTime? selectedDate;
  List<dynamic> slots = [];
  dynamic selectedSlot;
  bool isLoading = false;

 Future<void> _loadAvailability() async {
  print("Availability button clicked");
  print("Pricing unit: ${widget.pricingUnit}");

  if (widget.pricingUnit == "hour") {

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 30),
      ),
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
      selectedSlot = null;
      isLoading = true;
    });

    final formattedDate =
        DateFormat('yyyy-MM-dd').format(picked);

    final result = await SkillService.fetchAvailableSlots(
      widget.skillId,
      formattedDate,
    );

    print("Slots received: $result");

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
      "", // backend ignores date for daily
    );

    print("Daily slots received: $result");

    setState(() {
      slots = result;
      isLoading = false;
    });
  }
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

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedSlot = slot;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedSlot == slot
                        ? Colors.indigo
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      widget.pricingUnit == "hour"
                          ? slot
                          : DateFormat('dd MMM')
                              .format(DateTime.parse(slot)),
                      style: TextStyle(
                        color: selectedSlot == slot
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
            onPressed: () {},
            child: const Text("Confirm Booking"),
          ),
        ),
    ],
  ),
),
    );
  }
}