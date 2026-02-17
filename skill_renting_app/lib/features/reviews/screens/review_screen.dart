import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
import 'package:skill_renting_app/features/bookings/models/booking_model.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';

class ReviewScreen extends StatefulWidget {
  final BookingModel booking;

  const ReviewScreen({super.key, required this.booking});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final _commentController = TextEditingController();
  bool _loading = false;

  Future<void> _submitReview() async {
    setState(() => _loading = true);

    final token = await AuthStorage.getToken();
    
    if (token == null) return;

    print("📤 Sending review:");
print("Rating: $_rating");
print("Comment: ${_commentController.text}");

final response = await ApiService.post(
  "/reviews",
  {
    "bookingId": widget.booking.id, // ✅ correct
    "rating": _rating,
    "comment": _commentController.text,
  },
  token: token,
);

    
    print("📥 Review Status: ${response["statusCode"]}");
print("📥 Review Response: ${response["data"]}");


    setState(() => _loading = false);

    if (response["statusCode"] == 201) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Review failed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Give Review"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            const Text(
              "Rate this Service",
              style: TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  onPressed: () {
                    setState(() {
                      _rating = i + 1;
                    });
                  },
                  icon: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                );
              }),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: "Comment",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            _loading
  ? const SkeletonList()
                : ElevatedButton(
                    onPressed: _submitReview,
                    child: const Text("Submit Review"),
                  ),
          ],
        ),
      ),
    );
  }
}
