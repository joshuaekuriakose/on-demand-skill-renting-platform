import 'package:flutter/material.dart';
import '../skill_service.dart';
import '../models/skill_model.dart';
import 'skill_detail_screen.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';

class SkillListScreen extends StatefulWidget {
  const SkillListScreen({super.key});

  @override
  State<SkillListScreen> createState() => _SkillListScreenState();
}

class _SkillListScreenState extends State<SkillListScreen> {
  late Future<List<SkillModel>> _skills;

  @override
  void initState() {
    super.initState();
    _skills = SkillService.fetchSkills();
  }
Future<void> _searchSkills(String value) async {
  if (value.isEmpty) {
    _skills = SkillService.fetchSkills();
  } else {
    _skills = SkillService.searchSkills(value);
  }

  setState(() {});
}




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Available Skills")),
      body: Column(
  children: [

    // Search Bar
    Padding(
      padding: const EdgeInsets.all(10),
      child: TextField(
        decoration: const InputDecoration(
          hintText: "Search skills...",
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          _searchSkills(value);
        },
      ),
    ),

    // Skill List
    Expanded(
  child: FutureBuilder<List<SkillModel>>(
    future: _skills,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const SkeletonList();
      }

      if (!snapshot.hasData || snapshot.data!.isEmpty) {
        return const Center(child: Text("No skills available"));
      }

      final skills = snapshot.data!;

      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: skills.length,
        itemBuilder: (context, index) {
          final skill = skills[index];

          return Card(
            elevation: 3,
            margin: const EdgeInsets.symmetric(vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SkillDetailScreen(skill: skill),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      skill.category,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Text(
                            "₹${skill.price}/${skill.pricingUnit}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              skill.rating
                                  .toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  ),
),

  ],
),

    );
  }
}
