import 'package:flutter/material.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/bookings/booking_service.dart';
import '../models/booking_model.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';

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
  ? const SkeletonList()

        : _bookings.isEmpty
            ? const Center(child: Text("No bookings yet"))

            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _bookings.length,
                itemBuilder: (context, index) {
                  final b = _bookings[index];

                  return Container(
  margin: const EdgeInsets.only(bottom: 12),

  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ],
  ),

  child: Row(
    children: [

      // Status Color Bar
      Container(
        width: 5,
        height: 130,
        decoration: BoxDecoration(
          color: _getStatusColor(b.status),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            bottomLeft: Radius.circular(14),
          ),
        ),
      ),

      Expanded(
        child: Padding(
          padding: const EdgeInsets.all(14),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Title + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  Expanded(
                    child: Text(
                      b.skillTitle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  _StatusChip(b.status),
                ],
              ),

              const SizedBox(height: 8),

              // Seeker
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    b.seekerName,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              const SizedBox(height: 10),

              // Actions
              Wrap(
                spacing: 8,

                children: [

                  if (b.status == "requested")
                    OutlinedButton(
                      onPressed: () =>
                          _updateStatus(b.id, "accept"),

                      child: const Text("Accept"),
                    ),

                  if (b.status == "requested")
                    OutlinedButton(
                      onPressed: () =>
                          _updateStatus(b.id, "reject"),

                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
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
      ),
    ],
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

class _StatusChip extends StatelessWidget {
  final String status;

  _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {

    Color color;

    switch (status) {
      case "requested":
        color = Colors.orange;
        break;

      case "accepted":
        color = Colors.blue;
        break;

      case "completed":
        color = Colors.green;
        break;

      case "rejected":
        color = Colors.red;
        break;

      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),

      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        status.toUpperCase(),

        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
