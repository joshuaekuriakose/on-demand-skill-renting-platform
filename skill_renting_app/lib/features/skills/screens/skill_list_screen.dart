import 'package:flutter/material.dart';
import '../skill_service.dart';
import '../models/skill_model.dart';
import 'skill_detail_screen.dart';


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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Available Skills")),
      body: FutureBuilder<List<SkillModel>>(
        future: _skills,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No skills available"));
          }

          final skills = snapshot.data!;

          return ListView.builder(
            itemCount: skills.length,
            itemBuilder: (context, index) {
              final skill = skills[index];

              return ListTile(
  title: Text(skill.title),
  subtitle: Text(
    "${skill.category} • ₹${skill.price}/${skill.pricingUnit}",
  ),
  trailing: Text("⭐ ${skill.rating.toStringAsFixed(1)}"),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SkillDetailScreen(skill: skill),
      ),
    );
  },
);

            },
          );
        },
      ),
    );
  }
}
