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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
              ? const Center(child: Text("No bookings yet"))
              : ListView.builder(
                  itemCount: _bookings.length,
                  itemBuilder: (context, index) {
                    final b = _bookings[index];

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.skillTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 4),

                            Text("By: ${b.seekerName}"),

                            const SizedBox(height: 6),

                            Text("Status: ${b.status}"),

                            const SizedBox(height: 10),

                            Row(
                              children: [

                                // Accept
                                if (b.status == "requested")
                                  ElevatedButton(
                                    onPressed: () =>
                                        _updateStatus(b.id, "accept"),
                                    child: const Text("Accept"),
                                  ),

                                const SizedBox(width: 8),

                                // Reject
                                if (b.status == "requested")
                                  ElevatedButton(
                                    onPressed: () =>
                                        _updateStatus(b.id, "reject"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    child: const Text("Reject"),
                                  ),

                                // Complete
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
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
