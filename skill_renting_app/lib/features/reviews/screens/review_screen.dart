import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/bookings/models/booking_model.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';

class ReviewScreen extends StatefulWidget {
  final BookingModel booking;

  /// When true the screen is opened because the booking was auto-cancelled
  /// for non-response — copy and default rating are adjusted accordingly.
  final bool isForNoResponse;

  const ReviewScreen({
    super.key,
    required this.booking,
    this.isForNoResponse = false,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late int _rating;
  final _commentController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Default to 1 star for non-response reviews, 5 for normal completion
    _rating = widget.isForNoResponse ? 1 : 5;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() => _loading = true);

    final token = await AuthStorage.getToken();
    if (token == null) {
      setState(() => _loading = false);
      return;
    }

    final response = await ApiService.post(
      "/reviews",
      {
        "bookingId": widget.booking.id,
        "rating":    _rating,
        "comment":   _commentController.text.trim(),
      },
      token: token,
    );

    setState(() => _loading = false);

    if (response["statusCode"] == 201) {
      if (mounted) Navigator.pop(context, true);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response["message"] ?? "Failed to submit review"),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNR = widget.isForNoResponse;

    final headline = isNR
        ? "Rate Provider's Responsiveness"
        : "Rate this Service";

    final subtext = isNR
        ? "Your booking was auto-cancelled because the provider didn't respond. "
          "You're not obligated to leave a review, but your feedback helps "
          "other seekers make informed decisions."
        : "How was your experience with ${widget.booking.providerName}?";

    final hintText = isNR
        ? "Describe what happened (optional)…"
        : "Share your experience (optional)…";

    return AppScaffold(
      appBar: AppBar(
        title: Text(isNR ? "Review Experience" : "Give Review"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Context banner for no-response flow ───────────────────────
            if (isNR) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepOrange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.deepOrange.shade600, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "This booking was cancelled because the provider "
                        "did not accept or reject your request before the "
                        "scheduled slot. Your review is optional.",
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.deepOrange.shade700,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Headline ──────────────────────────────────────────────────
            Text(
              headline,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              subtext,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 24),

            // ── Star rating ───────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return IconButton(
                        onPressed: () => setState(() => _rating = i + 1),
                        icon: Icon(
                          i < _rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 36,
                        ),
                      );
                    }),
                  ),
                  Text(
                    _ratingLabel(_rating),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Comment ───────────────────────────────────────────────────
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: hintText,
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 28),

            // ── Buttons ───────────────────────────────────────────────────
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _submitReview,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor:
                          isNR ? Colors.deepOrange : null,
                      foregroundColor: isNR ? Colors.white : null,
                    ),
                    child: const Text("Submit Review"),
                  ),
                  if (isNR) ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(46)),
                      child: const Text("Skip — No Review"),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1: return "Very Poor";
      case 2: return "Poor";
      case 3: return "Average";
      case 4: return "Good";
      case 5: return "Excellent";
      default: return "";
    }
  }
}
