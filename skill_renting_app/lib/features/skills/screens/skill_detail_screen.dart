import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
import '../models/skill_model.dart';
import 'package:skill_renting_app/features/reviews/review_service.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';
import '../../bookings/screens/booking_schedule_screen.dart';
import 'package:skill_renting_app/features/profile/profile_service.dart';
import 'package:skill_renting_app/features/profile/models/profile_model.dart';
import 'package:skill_renting_app/features/profile/screens/profile_screen.dart';
import 'package:skill_renting_app/features/chat/chat_screen.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'dart:math' as _math;

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
  String _myId  = "";
  double? _distanceKm;
  bool _distanceLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _loadMyId();
    _loadDistance();
  }

  Future<void> _loadMyId() async {
    final id = await AuthStorage.getUserId();
    if (mounted) setState(() => _myId = id);
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    double r(double d) => d * _math.pi / 180;
    final dLat = r(lat2 - lat1);
    final dLon = r(lon2 - lon1);
    final a = _math.pow(_math.sin(dLat / 2), 2) +
        _math.cos(r(lat1)) * _math.cos(r(lat2)) *
            _math.pow(_math.sin(dLon / 2), 2);
    return 6371.0 * 2 *
        _math.atan2(_math.sqrt(a.toDouble()), _math.sqrt(1 - a.toDouble()));
  }

  Future<void> _loadDistance() async {
    final provPin = widget.skill.providerPincode;
    if (provPin.isEmpty) return;

    setState(() => _distanceLoading = true);
    try {
      final token = await AuthStorage.getToken();
      final profile = await ProfileService.getProfile();
      final seekerPin = profile?.address?['pincode']?.toString() ?? '';
      if (seekerPin.isEmpty) return;
      if (seekerPin == provPin) {
        if (mounted) setState(() { _distanceKm = 1.5; _distanceLoading = false; });
        return;
      }

      final results = await Future.wait([
        ApiService.get('/utils/pincode/$provPin',   token: token),
        ApiService.get('/utils/pincode/$seekerPin', token: token),
      ]);

      final prov   = results[0];
      final seeker = results[1];
      if (prov['statusCode'] != 200 || seeker['statusCode'] != 200) return;

      final pLat = (prov['data']?['lat']    as num?)?.toDouble();
      final pLon = (prov['data']?['lon']    as num?)?.toDouble();
      final sLat = (seeker['data']?['lat']  as num?)?.toDouble();
      final sLon = (seeker['data']?['lon']  as num?)?.toDouble();
      if (pLat == null || pLon == null || sLat == null || sLon == null) return;

      final km = _haversineKm(pLat, pLon, sLat, sLon);
      if (mounted) setState(() => _distanceKm = (km * 10).roundToDouble() / 10);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _distanceLoading = false);
    }
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
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
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
                      style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(skill.category,
                      style: TextStyle(
                          color: scheme.onPrimary.withOpacity(0.7),
                          fontSize: 14)),
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

            const SizedBox(height: 14),

            // ── Provider card ────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor:
                      scheme.primaryContainer.withOpacity(0.5),
                  child: Text(
                    skill.providerName.isNotEmpty
                        ? skill.providerName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        skill.providerName.isNotEmpty
                            ? skill.providerName
                            : 'Provider',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (skill.providerLocality.isNotEmpty ||
                          skill.providerDistrict.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          Icon(Icons.location_on_outlined,
                              size: 13,
                              color: scheme.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              [
                                if (skill.providerLocality.isNotEmpty)
                                  skill.providerLocality,
                                if (skill.providerDistrict.isNotEmpty)
                                  skill.providerDistrict,
                              ].join(', '),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                      if (skill.providerRating > 0) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < skill.providerRating.round()
                                  ? Icons.star
                                  : Icons.star_border,
                              size: 13,
                              color: Colors.amber,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${skill.providerRating.toStringAsFixed(1)} (${skill.providerTotalReviews} reviews)',
                            style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
                // ── Distance badge ──────────────────────────────────
                const SizedBox(width: 10),
                if (_distanceLoading)
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: scheme.onSurfaceVariant),
                  )
                else if (_distanceKm != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: scheme.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.near_me_outlined,
                            size: 16,
                            color: scheme.primary),
                        const SizedBox(height: 3),
                        Text(
                          _distanceKm! < 1
                              ? '${(_distanceKm! * 1000).round()} m'
                              : '~${_distanceKm!.toStringAsFixed(1)} km',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                        Text(
                          'away',
                          style: TextStyle(
                            fontSize: 9,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ]),
            ),

            const SizedBox(height: 16),

            // Description
            if (skill.description.isNotEmpty) ...[
              Text(skill.description,
                  style:
                      const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 20),
            ],

            // Action buttons — Book and Message
            Row(
              children: [
                // Message button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (_myId.isEmpty) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chatType:        "direct",
                            providerId:      skill.providerId,
                            skillId:         skill.id,
                            otherPersonName: skill.providerName.isNotEmpty
                                ? skill.providerName
                                : "Provider",
                            currentUserId:   _myId,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text("Message"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: BorderSide(color: scheme.primary),
                      foregroundColor: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Book button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final ok = await _ensureProfileComplete();
                      if (!ok || !context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingScheduleScreen(
                            skillId:     skill.id,
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
              ],
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
    final scheme = Theme.of(context).colorScheme;
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
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
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
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  reviewerName.isNotEmpty
                      ? reviewerName[0].toUpperCase()
                      : "U",
                  style: TextStyle(
                      color: scheme.onPrimaryContainer,
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
                            fontSize: 11,
                            color: scheme.onSurfaceVariant.withOpacity(0.85))),
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
                color: scheme.primaryContainer.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.reply,
                          size: 14, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text("Provider's reply",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.primary)),
                      const Spacer(),
                      Text(timeAgo(repliedAt),
                          style: TextStyle(
                              fontSize: 11,
                              color:
                                  scheme.onSurfaceVariant.withOpacity(0.85))),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: scheme.onPrimaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
