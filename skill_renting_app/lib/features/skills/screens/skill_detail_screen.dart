import 'dart:math';
import 'package:flutter/material.dart';
import '../models/skill_model.dart';
import 'package:skill_renting_app/features/reviews/review_service.dart';
import '../../bookings/screens/booking_schedule_screen.dart';
import 'package:skill_renting_app/features/profile/profile_service.dart';
import 'package:skill_renting_app/features/profile/models/profile_model.dart';
import 'package:skill_renting_app/features/profile/screens/profile_screen.dart';
import 'package:skill_renting_app/features/chat/chat_screen.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/core/services/api_service.dart';

class SkillDetailScreen extends StatefulWidget {
  final SkillModel skill;
  const SkillDetailScreen({super.key, required this.skill});
  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  List _reviews = [];
  bool _loading = true;
  String _myId  = "";
  double? _distanceKm;
  bool _distanceLoading = true;

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

  Future<void> _loadReviews() async {
    final data = await ReviewService.fetchSkillReviews(widget.skill.id);
    if (mounted) setState(() { _reviews = data; _loading = false; });
  }

  Future<void> _loadDistance() async {
    try {
      final profile = await ProfileService.getProfile();
      final seekerPin = profile?.address?["pincode"]?.toString();
      final providerPin = widget.skill.providerPincode;
      if (seekerPin == null || providerPin == null || seekerPin.isEmpty || providerPin.isEmpty) {
        if (mounted) setState(() => _distanceLoading = false); return;
      }
      if (seekerPin == providerPin) {
        if (mounted) setState(() { _distanceKm = 1.5; _distanceLoading = false; }); return;
      }
      final token = await AuthStorage.getToken();
      final resA = await ApiService.get("/utils/pincode/$seekerPin", token: token);
      final resB = await ApiService.get("/utils/pincode/$providerPin", token: token);
      if (resA["statusCode"] == 200 && resB["statusCode"] == 200) {
        final latA = (resA["data"]["lat"] as num?)?.toDouble();
        final lonA = (resA["data"]["lon"] as num?)?.toDouble();
        final latB = (resB["data"]["lat"] as num?)?.toDouble();
        final lonB = (resB["data"]["lon"] as num?)?.toDouble();
        if (latA != null && lonA != null && latB != null && lonB != null) {
          final km = _haversine(latA, lonA, latB, lonB);
          if (mounted) setState(() { _distanceKm = (km * 10).round() / 10; _distanceLoading = false; });
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _distanceLoading = false);
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  bool _isProfileComplete(ProfileModel p) {
    final a = p.address;
    return p.name.trim().isNotEmpty && p.phone.trim().isNotEmpty &&
        (a?["houseName"]?.toString().trim() ?? "").isNotEmpty &&
        (a?["locality"]?.toString().trim()  ?? "").isNotEmpty &&
        (a?["pincode"]?.toString().trim()   ?? "").isNotEmpty &&
        (a?["district"]?.toString().trim()  ?? "").isNotEmpty;
  }

  Future<bool> _ensureProfileComplete() async {
    final profile = await ProfileService.getProfile();
    if (!mounted) return false;
    if (profile == null || !_isProfileComplete(profile)) {
      final go = await showDialog<bool>(context: context,
        builder: (_) => AlertDialog(
          title: const Text("Complete your profile"),
          content: const Text("Add your address details before booking."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("Go to Profile")),
          ],
        ));
      if (go == true && mounted)
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      return false;
    }
    return true;
  }

  double get _avgRating {
    if (_reviews.isEmpty) return 0;
    return _reviews.fold<double>(0, (s, r) => s + (r["rating"] as num).toDouble()) / _reviews.length;
  }

  String _timeAgo(String? iso) {
    if (iso == null) return "";
    final d = DateTime.now().difference(DateTime.tryParse(iso)?.toLocal() ?? DateTime.now());
    if (d.inDays > 30) return "${(d.inDays / 30).floor()}mo ago";
    if (d.inDays > 0)  return "${d.inDays}d ago";
    if (d.inHours > 0) return "${d.inHours}h ago";
    return "Just now";
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final tt   = Theme.of(context).textTheme;
    final skill = widget.skill;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          // ── Hero app bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: cs.surface,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primaryContainer, cs.secondaryContainer],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: cs.surface.withOpacity(0.9),
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.outlineVariant, width: 0.8),
                    ),
                    child: Icon(Icons.work_outline_rounded, size: 32, color: cs.primary),
                  ),
                  const SizedBox(height: 8),
                  Text(skill.category,
                      style: TextStyle(color: cs.onPrimaryContainer.withOpacity(0.8), fontSize: 13)),
                ])),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Title + price ─────────────────────────────────────────────
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(skill.title, style: tt.headlineSmall)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cs.primary.withOpacity(0.3), width: 0.8),
                    ),
                    child: Text("₹${skill.price.toStringAsFixed(0)}/${skill.pricingUnit}",
                        style: TextStyle(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer, fontSize: 14)),
                  ),
                ]),
                const SizedBox(height: 10),

                // ── Rating + distance ─────────────────────────────────────────
                Row(children: [
                  ...List.generate(5, (i) => Icon(
                    i < skill.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16, color: const Color(0xFFF59E0B))),
                  const SizedBox(width: 6),
                  Text("${skill.rating.toStringAsFixed(1)} (${_reviews.length} reviews)",
                      style: tt.labelMedium),
                  const Spacer(),
                  if (_distanceLoading)
                    const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5))
                  else if (_distanceKm != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cs.outlineVariant, width: 0.8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.near_me_outlined, size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(_distanceKm! < 1
                            ? "${(_distanceKm! * 1000).round()} m away"
                            : "~${_distanceKm!.toStringAsFixed(1)} km away",
                            style: tt.labelSmall),
                      ]),
                    ),
                ]),

                const SizedBox(height: 16),

                // ── Provider card ─────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        skill.providerName.isNotEmpty ? skill.providerName[0].toUpperCase() : "P",
                        style: TextStyle(fontWeight: FontWeight.bold,
                            fontSize: 16, color: cs.onPrimaryContainer)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(skill.providerName, style: tt.titleSmall),
                      if (skill.providerLocality != null && skill.providerLocality!.isNotEmpty)
                        Text("${skill.providerLocality}"
                            "${skill.providerDistrict != null ? ', ${skill.providerDistrict}' : ''}",
                            style: tt.bodySmall),
                      if ((skill.providerRating ?? 0) > 0) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text("${skill.providerRating!.toStringAsFixed(1)} · ${skill.providerTotalReviews} reviews",
                              style: tt.labelSmall),
                        ]),
                      ],
                    ])),
                  ]),
                ),

                const SizedBox(height: 14),

                // ── Description ───────────────────────────────────────────────
                if (skill.description.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
                    ),
                    child: Text(skill.description,
                        style: tt.bodyMedium?.copyWith(height: 1.6, color: cs.onSurfaceVariant)),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── CTA buttons ───────────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: SizedBox(height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          if (_myId.isEmpty) return;
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                            chatType: "direct",
                            providerId: skill.providerId,
                            skillId: skill.id,
                            otherPersonName: skill.providerName.isNotEmpty ? skill.providerName : "Provider",
                            currentUserId: _myId,
                          )));
                        },
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: const Text("Message"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(height: 48,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final ok = await _ensureProfileComplete();
                          if (!ok || !mounted) return;
                          Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScheduleScreen(
                            skillId: skill.id, pricingUnit: skill.pricingUnit)));
                        },
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: const Text("Book"),
                      ),
                    ),
                  ),
                ]),

                const SizedBox(height: 24),

                // ── Reviews ───────────────────────────────────────────────────
                Row(children: [
                  Expanded(child: Text("Reviews", style: tt.titleMedium)),
                  if (_reviews.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 0.8),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text("${_avgRating.toStringAsFixed(1)} · ${_reviews.length}",
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
                      ]),
                    ),
                ]),
                const SizedBox(height: 12),

                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _reviews.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
                            ),
                            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.rate_review_outlined, size: 36, color: cs.onSurfaceVariant.withOpacity(0.4)),
                              const SizedBox(height: 8),
                              Text("No reviews yet", style: tt.bodySmall),
                            ])),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _reviews.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _ReviewCard(
                                review: _reviews[i], timeAgo: _timeAgo, cs: cs, tt: tt),
                          ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map review;
  final String Function(String?) timeAgo;
  final ColorScheme cs;
  final TextTheme tt;
  const _ReviewCard({required this.review, required this.timeAgo, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    final r = review;
    final rating = (r["rating"] as num?)?.toInt() ?? 0;
    final name   = r["reviewer"]?["name"] ?? "User";
    final comment = r["comment"]?.toString() ?? "";
    final replyText = r["providerReply"]?["text"]?.toString();
    final repliedAt = r["providerReply"]?["repliedAt"]?.toString();
    final hasReply  = replyText != null && replyText.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 16, backgroundColor: cs.primaryContainer,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : "U",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: tt.labelLarge),
            Text(timeAgo(r["createdAt"]), style: tt.labelSmall),
          ])),
          Row(children: List.generate(5, (i) => Icon(
            i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 14, color: const Color(0xFFF59E0B)))),
        ]),
        if (comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(comment, style: tt.bodySmall?.copyWith(color: cs.onSurface, height: 1.5)),
        ],
        if (hasReply) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.6), width: 0.8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.reply_rounded, size: 13, color: cs.primary),
                const SizedBox(width: 4),
                Text("Provider's reply", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
                const Spacer(),
                Text(timeAgo(repliedAt), style: tt.labelSmall),
              ]),
              const SizedBox(height: 6),
              Text(replyText!, style: tt.bodySmall?.copyWith(color: cs.onSurface, height: 1.4)),
            ]),
          ),
        ],
      ]),
    );
  }
}
