import 'package:flutter/material.dart';
import '../models/skill_model.dart';

class SkillDetailScreen extends StatelessWidget {
  final SkillModel skill;

  const SkillDetailScreen({super.key, required this.skill});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(skill.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              skill.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text("Category: ${skill.category}"),
            const SizedBox(height: 8),
            Text("Price: ₹${skill.price}/${skill.pricingUnit}"),
            const SizedBox(height: 8),
            Text("Rating: ⭐ ${skill.rating.toStringAsFixed(1)}"),
            const SizedBox(height: 16),
            Text(skill.description),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Booking UI coming next"),
                  ),
                );
              },
              child: const Text("Book Skill"),
            ),
          ],
        ),
      ),
    );
  }
}
