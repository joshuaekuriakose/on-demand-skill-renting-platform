import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/reviews/screens/review_screen.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import 'package:skill_renting_app/features/bookings/models/booking_model.dart';
import 'package:skill_renting_app/features/common/widgets/empty_state.dart';
import 'package:skill_renting_app/features/skills/screens/skill_list_screen.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';


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
  ? const SkeletonList()
          : _bookings.isEmpty
  ? EmptyState(
      icon: Icons.calendar_today,
      title: "No Bookings",
      message: "You haven’t booked any skills yet.",
      buttonText: "Browse Skills",
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SkillListScreen(),
          ),
        );
      },
    )
              : ListView.builder(
    padding: const EdgeInsets.all(12),

    itemCount: _bookings.length,

    itemBuilder: (context, index) {
      final b = _bookings[index];

      return Card(
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 6),

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

              // Provider
              Row(
                children: [
                  const Icon(Icons.person, size: 16),
                  const SizedBox(width: 4),
                  Text(b.providerName),
                ],
              ),

              const SizedBox(height: 8),

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

              // Review Button (only if completed)
              if (b.status == "completed")
                SizedBox(
                  width: double.infinity,

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
                                builder: (_) =>
                                    ReviewScreen(booking: b),
                              ),
                            );

                            _loadBookings();
                          },

                    child: Text(
                      b.isReviewed
                          ? "Reviewed"
                          : "Give Review",
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
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
