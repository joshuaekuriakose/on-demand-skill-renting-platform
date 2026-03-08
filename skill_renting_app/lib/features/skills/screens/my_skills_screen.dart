import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/skills/skill_service.dart';
import 'package:skill_renting_app/features/skills/screens/add_skill_screen.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
import 'package:skill_renting_app/features/bookings/screens/provider_calendar_screen.dart';
import 'package:skill_renting_app/features/reviews/review_service.dart';

class MySkillsScreen extends StatefulWidget {
  const MySkillsScreen({super.key});

  @override
  State<MySkillsScreen> createState() => _MySkillsScreenState();
}

class _MySkillsScreenState extends State<MySkillsScreen> {
  List _skills = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    setState(() => _loading = true);
    final data = await SkillService.fetchMySkills();
    if (mounted) setState(() { _skills = data; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Services"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: "Add Service",
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddSkillScreen()),
              );
              _loadSkills();
            },
          ),
        ],
      ),
      body: _loading
          ? const SkeletonList()
          : _skills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.work_outline,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text("No services added yet",
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddSkillScreen()),
                          );
                          _loadSkills();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text("Add Service"),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSkills,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _skills.length,
                    itemBuilder: (context, index) {
                      final s = _skills[index];
                      return _ServiceCard(
                        skill: s,
                        onRefresh: _loadSkills,
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Service card ──────────────────────────────────────────────────────────────

class _ServiceCard extends StatelessWidget {
  final Map skill;
  final VoidCallback onRefresh;

  const _ServiceCard({required this.skill, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final s = skill;
    final isActive = s["isActive"] == true;
    final rating = (s["rating"] as num?)?.toDouble() ?? 0.0;
    final totalReviews = s["totalReviews"] ?? 0;
    final pricingUnit = s["pricing"]?["unit"] ?? "hour";
    final price = s["pricing"]?["amount"];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceDetailScreen(skill: s),
        ),
      ).then((_) => onRefresh()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(
          children: [
            // Active / inactive banner
            if (!isActive)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: const Center(
                  child: Text("INACTIVE",
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: title + category
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s["title"] ?? "",
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.indigo.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(s["category"] ?? "",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.indigo.shade700)),
                            ),
                          ],
                        ),
                      ),

                      // Right: overflow menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: "edit", child: Text("Edit")),
                          const PopupMenuItem(
                              value: "calendar",
                              child: Text("Manage Calendar")),
                          PopupMenuItem(
                            value: "toggle",
                            child: Text(isActive ? "Deactivate" : "Activate"),
                          ),
                          const PopupMenuItem(
                              value: "delete",
                              child: Text("Delete",
                                  style: TextStyle(color: Colors.red))),
                        ],
                        onSelected: (value) =>
                            _onMenuSelected(context, value, s),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Rate + type row
                  Row(
                    children: [
                      _InfoChip(
                        icon: Icons.currency_rupee,
                        label: price != null
                            ? "₹$price / $pricingUnit"
                            : "—",
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      _InfoChip(
                        icon: Icons.access_time,
                        label: pricingUnit,
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Rating row
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        final filled = i < rating.round();
                        return Icon(
                          filled ? Icons.star : Icons.star_border,
                          size: 16,
                          color: Colors.amber,
                        );
                      }),
                      const SizedBox(width: 6),
                      Text(
                        rating > 0
                            ? "${rating.toStringAsFixed(1)} ($totalReviews review${totalReviews != 1 ? 's' : ''})"
                            : "No reviews yet",
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMenuSelected(BuildContext context, String value, Map s) async {
    if (value == "delete") {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Delete Service"),
          content: Text(
              "Are you sure you want to delete \"${s['title']}\"?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white),
              child: const Text("Delete"),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await SkillService.deleteSkill(s["_id"]);
        onRefresh();
      }
    } else if (value == "toggle") {
      await SkillService.updateSkill(
          s["_id"], {"isActive": !(s["isActive"] == true)});
      onRefresh();
    } else if (value == "calendar") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderCalendarScreen(
            skillId: s["_id"],
            pricingUnit: s["pricing"]["unit"],
          ),
        ),
      );
    } else if (value == "edit") {
      _openEditDialog(context, s);
    }
  }

  void _openEditDialog(BuildContext context, Map s) {
    final titleCtrl = TextEditingController(text: s["title"]);
    final priceCtrl =
        TextEditingController(text: s["pricing"]["amount"].toString());
    final descCtrl =
        TextEditingController(text: s["description"] ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Service"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: "Title")),
              const SizedBox(height: 10),
              TextField(
                  controller: descCtrl,
                  decoration:
                      const InputDecoration(labelText: "Description"),
                  maxLines: 3),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: "Price per ${s['pricing']['unit']}",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await SkillService.updateSkill(s["_id"], {
                "title": titleCtrl.text.trim(),
                "description": descCtrl.text.trim(),
                "pricing": {
                  "amount": int.tryParse(priceCtrl.text) ??
                      s["pricing"]["amount"],
                  "unit": s["pricing"]["unit"],
                },
              });
              Navigator.pop(context);
              onRefresh();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

// ── Info chip ─────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Service Detail Screen
// ═════════════════════════════════════════════════════════════════════════════

class ServiceDetailScreen extends StatefulWidget {
  final Map skill;
  const ServiceDetailScreen({super.key, required this.skill});

  @override
  State<ServiceDetailScreen> createState() => _ServiceDetailScreenState();
}

class _ServiceDetailScreenState extends State<ServiceDetailScreen> {
  List _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _loading = true);
    final data =
        await ReviewService.fetchSkillReviews(widget.skill["_id"]);
    if (mounted) setState(() { _reviews = data; _loading = false; });
  }

  double get _avgRating {
    if (_reviews.isEmpty) return 0;
    final sum = _reviews.fold<double>(
        0, (acc, r) => acc + (r["rating"] as num).toDouble());
    return sum / _reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.skill;
    final pricingUnit = s["pricing"]?["unit"] ?? "hour";
    final price = s["pricing"]?["amount"];
    final isActive = s["isActive"] == true;

    return Scaffold(
      appBar: AppBar(title: Text(s["title"] ?? "Service")),
      body: RefreshIndicator(
        onRefresh: _loadReviews,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header card ─────────────────────────────────────────────
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(s["title"] ?? "",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.shade400
                                : Colors.red.shade400,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isActive ? "ACTIVE" : "INACTIVE",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(s["category"] ?? "",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _WhiteChip(
                            icon: Icons.currency_rupee,
                            label: price != null
                                ? "₹$price / $pricingUnit"
                                : "—"),
                        const SizedBox(width: 10),
                        _WhiteChip(
                            icon: Icons.access_time,
                            label: pricingUnit),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Description ─────────────────────────────────────────────
              if (s["description"] != null &&
                  s["description"].toString().isNotEmpty) ...[
                const Text("About this service",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(s["description"],
                    style: const TextStyle(
                        fontSize: 14, height: 1.5, color: Colors.black87)),
                const SizedBox(height: 20),
              ],

              // ── Rating summary ───────────────────────────────────────────
              Row(
                children: [
                  const Text("Reviews",
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_reviews.isNotEmpty) ...[
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      "${_avgRating.toStringAsFixed(1)} · ${_reviews.length} review${_reviews.length != 1 ? 's' : ''}",
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              // ── Review list ──────────────────────────────────────────────
              _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ))
                  : _reviews.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.rate_review_outlined,
                                  size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text("No reviews yet",
                                  style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : Column(
                          children: _reviews
                              .map((r) => _ReviewCard(
                                    review: r,
                                    isProvider: true,
                                    onReplyChanged: _loadReviews,
                                  ))
                              .toList(),
                        ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── White chip (for gradient header) ─────────────────────────────────────────

class _WhiteChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _WhiteChip({required this.icon, required this.label});

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

// ═════════════════════════════════════════════════════════════════════════════
// Review Card — used both here (provider view) and in skill_detail (seeker view)
// Pass isProvider=true to show reply controls; false for read-only
// ═════════════════════════════════════════════════════════════════════════════

class _ReviewCard extends StatefulWidget {
  final Map review;
  final bool isProvider;
  final VoidCallback? onReplyChanged;

  const _ReviewCard({
    required this.review,
    this.isProvider = false,
    this.onReplyChanged,
  });

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _showReplyField = false;
  final _replyCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
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

  Future<void> _submitReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    final ok = await ReviewService.replyToReview(
        widget.review["_id"], text);
    setState(() => _submitting = false);
    if (ok) {
      setState(() => _showReplyField = false);
      widget.onReplyChanged?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save reply")));
    }
  }

  Future<void> _deleteReply() async {
    final ok = await ReviewService.deleteReply(widget.review["_id"]);
    if (ok) widget.onReplyChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
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
          // Reviewer name + time
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
                    Text(_timeAgo(r["createdAt"]),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400)),
                  ],
                ),
              ),
              // Stars
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

          // Comment
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment,
                style: const TextStyle(fontSize: 14, height: 1.4)),
          ],

          // ── Provider reply ───────────────────────────────────────────
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
                      Text("Your reply",
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo.shade600)),
                      const Spacer(),
                      Text(_timeAgo(repliedAt),
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(replyText!,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                  if (widget.isProvider) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            _replyCtrl.text = replyText;
                            setState(() => _showReplyField = true);
                          },
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: Colors.indigo),
                          child: const Text("Edit",
                              style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _deleteReply,
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: Colors.red),
                          child: const Text("Delete",
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Reply input (provider only) ──────────────────────────────
          if (widget.isProvider && !hasReply && !_showReplyField) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _showReplyField = true),
              icon: const Icon(Icons.reply, size: 16),
              label: const Text("Reply",
                  style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Colors.indigo),
            ),
          ],

          if (_showReplyField) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _replyCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Write your reply…",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      setState(() => _showReplyField = false),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitting ? null : _submitReply,
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Text("Post Reply"),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
