import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
import '../models/skill_model.dart';
import 'package:skill_renting_app/features/reviews/review_service.dart';
import '../../bookings/screens/booking_schedule_screen.dart';
import 'package:skill_renting_app/features/profile/profile_service.dart';
import 'package:skill_renting_app/features/profile/models/profile_model.dart';
import 'package:skill_renting_app/features/profile/screens/profile_screen.dart';

class SkillDetailScreen extends StatefulWidget {
  final SkillModel skill;

  const SkillDetailScreen({
    super.key,
    required this.skill,
  });

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  List _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final data = await ReviewService.fetchSkillReviews(widget.skill.id);
    setState(() { _reviews = data; _loading = false; });
  }

  bool _isProfileComplete(ProfileModel profile) {
    final addr = profile.address;
    return profile.name.trim().isNotEmpty &&
        profile.phone.trim().isNotEmpty &&
        (addr?["houseName"]?.toString().trim() ?? "").isNotEmpty &&
        (addr?["locality"]?.toString().trim() ?? "").isNotEmpty &&
        (addr?["pincode"]?.toString().trim() ?? "").isNotEmpty &&
        (addr?["district"]?.toString().trim() ?? "").isNotEmpty;
  }

  Future<bool> _ensureProfileComplete() async {
    final profile = await ProfileService.getProfile();
    if (!mounted) return false;

    if (profile == null || !_isProfileComplete(profile)) {
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Complete your profile"),
          content: const Text(
              "Please add your address details in Profile before booking."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel")),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Go to Profile")),
          ],
        ),
      );

      if (go == true && mounted) {
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()));
      }
      return false;
    }
    return true;
  }

  double get _avgRating {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<double>(
        0, (acc, r) => acc + (r["rating"] as num).toDouble());
    return sum / _reviews.length;
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return "";
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return "";
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inDays > 30) return "${(diff.inDays / 30).floor()}mo ago";
    if (diff.inDays > 0) return "${diff.inDays}d ago";
    if (diff.inHours > 0) return "${diff.inHours}h ago";
    return "Just now";
  }

  @override
  Widget build(BuildContext context) {
    final skill = widget.skill;

    return Scaffold(
      appBar: AppBar(title: Text(skill.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info card ──────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Colors.indigo.shade400
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(skill.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(skill.category,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 14),
                  Row(children: [
                    _Chip(
                        icon: Icons.currency_rupee,
                        label:
                            "₹${skill.price.toStringAsFixed(0)} / ${skill.pricingUnit}"),
                    const SizedBox(width: 10),
                    _Chip(
                        icon: Icons.star,
                        label: skill.rating.toStringAsFixed(1)),
                  ]),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Description
            if (skill.description.isNotEmpty) ...[
              Text(skill.description,
                  style:
                      const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 20),
            ],

            // Book button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final ok = await _ensureProfileComplete();
                  if (!ok || !context.mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingScheduleScreen(
                        skillId: skill.id,
                        pricingUnit: skill.pricingUnit,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: const Text("Book Service"),
              ),
            ),

            const SizedBox(height: 24),

            // ── Reviews ────────────────────────────────────────────────
            Row(
              children: [
                const Text("Reviews",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_reviews.isNotEmpty)
                  Text(
                    "⭐ ${_avgRating.toStringAsFixed(1)} · ${_reviews.length}",
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            _loading
                ? const SkeletonList()
                : _reviews.isEmpty
                    ? const Text("No reviews yet",
                        style: TextStyle(color: Colors.grey))
                    : ListView.builder(
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),
                        itemCount: _reviews.length,
                        itemBuilder: (context, index) {
                          final r = _reviews[index];
                          return _PublicReviewCard(
                              review: r, timeAgo: _timeAgo);
                        },
                      ),
          ],
        ),
      ),
    );
  }
}

// ── Public review card (seeker view — read-only, shows reply if present) ──────

class _PublicReviewCard extends StatelessWidget {
  final Map review;
  final String Function(String?) timeAgo;

  const _PublicReviewCard(
      {required this.review, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    final r = review;
    final rating = (r["rating"] as num?)?.toInt() ?? 0;
    final reviewerName = r["reviewer"]?["name"] ?? "User";
    final comment = r["comment"]?.toString() ?? "";
    final replyText = r["providerReply"]?["text"]?.toString();
    final repliedAt = r["providerReply"]?["repliedAt"]?.toString();
    final hasReply = replyText != null && replyText.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.indigo.shade100,
                child: Text(
                  reviewerName.isNotEmpty
                      ? reviewerName[0].toUpperCase()
                      : "U",
                  style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(reviewerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(timeAgo(r["createdAt"]),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    size: 14,
                    color: Colors.amber,
                  ),
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment,
                style: const TextStyle(fontSize: 14, height: 1.4)),
          ],

          // Provider reply — public, read-only
          if (hasReply) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply,
                          size: 14, color: Colors.indigo.shade400),
                      const SizedBox(width: 4),
                      Text("Provider's reply",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo.shade600)),
                      const Spacer(),
                      Text(timeAgo(repliedAt),
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(replyText!,
                      style:
                          const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Chip for header ───────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
