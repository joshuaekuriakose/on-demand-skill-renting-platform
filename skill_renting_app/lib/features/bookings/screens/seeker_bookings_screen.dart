import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/reviews/screens/review_screen.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import 'package:skill_renting_app/features/bookings/models/booking_model.dart';

class SeekerBookingsScreen extends StatefulWidget {
  const SeekerBookingsScreen({super.key});

  @override
  State<SeekerBookingsScreen> createState() =>
      _SeekerBookingsScreenState();
}

class _SeekerBookingsScreenState extends State<SeekerBookingsScreen> {
  List<BookingModel> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _loading = true);

    final data = await BookingService.fetchMyBookings();

    setState(() {
      _bookings = data;
      _loading = false;
    });
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

                            Text("Provider: ${b.providerName}"),
                            if (b.status == "completed")
 Padding(
  padding: const EdgeInsets.only(top: 8),
  child: ElevatedButton(
    onPressed: b.isReviewed
        ? () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Already reviewed"),
              ),
            );
          }
        : () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewScreen(booking: b),
              ),
            );

            _loadBookings(); // Refresh after review
          },

    child: Text(
      b.isReviewed ? "Reviewed" : "Give Review",
    ),
  ),
),



                            const SizedBox(height: 6),

                            Text("Status: ${b.status}"),

                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
