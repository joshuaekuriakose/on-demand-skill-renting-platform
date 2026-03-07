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

  // Reviews State
  List _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  // Load reviews from backend
  Future<void> _loadReviews() async {
    final data =
        await ReviewService.fetchSkillReviews(widget.skill.id);

    setState(() {
      _reviews = data;
      _loading = false;
    });
  }

  bool _isProfileComplete(ProfileModel profile) {
    final addr = profile.address;
    final house = addr?["houseName"]?.toString().trim() ?? "";
    final locality = addr?["locality"]?.toString().trim() ?? "";
    final pin = addr?["pincode"]?.toString().trim() ?? "";
    final district = addr?["district"]?.toString().trim() ?? "";

    return profile.name.trim().isNotEmpty &&
        profile.phone.trim().isNotEmpty &&
        house.isNotEmpty &&
        locality.isNotEmpty &&
        pin.isNotEmpty &&
        district.isNotEmpty;
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
            "Please add your address details in Profile before booking.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Go to Profile"),
            ),
          ],
        ),
      );

      if (go == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        );
      }
      return false;
    }

    return true;
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

            // Title
            Text(
              skill.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text("Category: ${skill.category}"),

            const SizedBox(height: 6),

            Text("Price: ₹${skill.price}/${skill.pricingUnit}"),

            const SizedBox(height: 6),

            Text("Rating: ⭐ ${skill.rating.toStringAsFixed(1)}"),

            const SizedBox(height: 12),

            Text(skill.description),

            const SizedBox(height: 20),

            // Book Button
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
                child: const Text("Book Skill"),
              ),
            ),

            const SizedBox(height: 24),

            // Reviews Section
            const Text(
              "Reviews",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            _loading
  ? const SkeletonList()

                : _reviews.isEmpty
                    ? const Text("No reviews yet")

                    : ListView.builder(
                        shrinkWrap: true,
                        physics:
                            const NeverScrollableScrollPhysics(),

                        itemCount: _reviews.length,

                        itemBuilder: (context, index) {
                          final r = _reviews[index];

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 6,
                            ),

                            child: ListTile(
                              leading:
                                  const Icon(Icons.person),

                              title: Text(
                                r["reviewer"]?["name"] ??
                                    "User",
                              ),

                              subtitle: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,

                                children: [

                                  Text("⭐ ${r["rating"]}"),

                                  if (r["comment"] != null &&
                                      r["comment"]
                                          .toString()
                                          .isNotEmpty)
                                    Text(r["comment"]),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
