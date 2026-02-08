import 'package:flutter/material.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import '../models/booking_model.dart';

class ProviderBookingsScreen extends StatefulWidget {
  const ProviderBookingsScreen({super.key});

  @override
  State<ProviderBookingsScreen> createState() =>
      _ProviderBookingsScreenState();
}


class _ProviderBookingsScreenState extends State<ProviderBookingsScreen> {
  List<BookingModel> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);

    final data = await BookingService.fetchProviderBookings();

    setState(() {
      _bookings = data;
      _loading = false;
    });
  }

  Future<void> _updateStatus(String id, String action) async {
    final token = await AuthStorage.getToken();

    if (token == null) return;

    await BookingService.updateBookingStatus(id, action);

    await _loadBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Bookings"),
      ),
      body: SafeArea(
  child: RefreshIndicator(
    onRefresh: _loadBookings,

    child: _loading
        ? const Center(child: CircularProgressIndicator())

        : _bookings.isEmpty
            ? const Center(child: Text("No bookings yet"))

            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _bookings.length,
                itemBuilder: (context, index) {
                  final b = _bookings[index];

                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),

                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          // Skill Title
                          Text(
                            b.skillTitle,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          // Seeker
                          Row(
                            children: [
                              const Icon(Icons.person, size: 16),
                              const SizedBox(width: 4),
                              Text(b.seekerName),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(b.status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              b.status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Actions
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [

    if (b.status == "requested")
      ElevatedButton(
        onPressed: () =>
            _updateStatus(b.id, "accept"),
        child: const Text("Accept"),
      ),

    if (b.status == "requested")
      ElevatedButton(
        onPressed: () =>
            _updateStatus(b.id, "reject"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
        ),
        child: const Text("Reject"),
      ),

    if (b.status == "accepted")
      ElevatedButton(
        onPressed: () =>
            _updateStatus(b.id, "complete"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
        ),
        child: const Text("Complete"),
      ),
  ],
),

                        ],
                      ),
                    ),
                  );
                },
              ),
  ),
),

    );
  }

Color _getStatusColor(String status) {
  switch (status) {
    case "requested":
      return Colors.orange;

    case "accepted":
      return Colors.blue;

    case "completed":
      return Colors.green;

    case "rejected":
      return Colors.red;

    default:
      return Colors.grey;
  }
}


}
