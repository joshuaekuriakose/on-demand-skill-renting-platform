import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/bookings/models/booking_model.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';

class ReviewScreen extends StatefulWidget {
  final BookingModel booking;
  final bool isForNoResponse;
  const ReviewScreen({super.key, required this.booking, this.isForNoResponse = false});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late int _rating;
  final _commentCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.isForNoResponse ? 1 : 5;
  }

  @override
  void dispose() { _commentCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() => _loading = true);
    final token = await AuthStorage.getToken();
    if (token == null) { setState(() => _loading = false); return; }
    final response = await ApiService.post("/reviews", {
      "bookingId": widget.booking.id,
      "rating":    _rating,
      "comment":   _commentCtrl.text.trim(),
    }, token: token);
    setState(() => _loading = false);
    if (response["statusCode"] == 201) {
      if (mounted) Navigator.pop(context, true);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response["message"] ?? "Failed to submit review")));
    }
  }

  String get _ratingLabel {
    switch (_rating) {
      case 1: return "Very poor";
      case 2: return "Poor";
      case 3: return "Average";
      case 4: return "Good";
      case 5: return "Excellent";
      default: return "";
    }
  }

  Color get _ratingColor {
    switch (_rating) {
      case 1: return const Color(0xFFEF4444);
      case 2: return const Color(0xFFF97316);
      case 3: return const Color(0xFFF59E0B);
      case 4: return const Color(0xFF10B981);
      case 5: return const Color(0xFF059669);
      default: return Colors.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs  = Theme.of(context).colorScheme;
    final tt  = Theme.of(context).textTheme;
    final isNR = widget.isForNoResponse;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(isNR ? "Rate Experience" : "Leave a Review")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Context banner for no-response ────────────────────────────────
          if (isNR) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.errorContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.error.withOpacity(0.2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline_rounded, size: 18, color: cs.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(child: Text(
                  "This booking was cancelled because the provider did not respond before your scheduled slot. Your review is optional.",
                  style: tt.bodySmall?.copyWith(color: cs.onErrorContainer, height: 1.5),
                )),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          // ── Service info ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.work_outline_rounded, color: cs.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.booking.skillTitle, style: tt.titleSmall),
                const SizedBox(height: 2),
                Text("with ${widget.booking.providerName}", style: tt.bodySmall),
              ])),
            ]),
          ),

          const SizedBox(height: 28),

          // ── Star rating ───────────────────────────────────────────────────
          Center(child: Column(children: [
            Text(isNR ? "Rate their responsiveness" : "How was your experience?",
                style: tt.titleSmall),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i < _rating ? _ratingColor : cs.outlineVariant,
                    size: 44,
                  ),
                ),
              )),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(_rating),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: _ratingColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _ratingColor.withOpacity(0.3)),
                ),
                child: Text(_ratingLabel,
                    style: TextStyle(
                        color: _ratingColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ])),

          const SizedBox(height: 28),

          // ── Comment ───────────────────────────────────────────────────────
          Text("Add a comment", style: tt.titleSmall),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
            ),
            child: TextField(
              controller: _commentCtrl,
              maxLines: 4,
              style: TextStyle(color: cs.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: isNR
                    ? "Describe what happened (optional)…"
                    : "Share your experience (optional)…",
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),

          const SizedBox(height: 28),

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: isNR ? const Color(0xFFEF4444) : null),
                  child: const Text("Submit Review"),
                ),
              ),
              if (isNR) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text("Skip"),
                  ),
                ),
              ],
            ]),
        ]),
      ),
    );
  }
}
