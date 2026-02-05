import 'package:flutter/material.dart';

import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';

class AddSkillScreen extends StatefulWidget {
  const AddSkillScreen({super.key});

  @override
  State<AddSkillScreen> createState() => _AddSkillScreenState();
}

class _AddSkillScreenState extends State<AddSkillScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  String _unit = "hour";
  String _level = "beginner";

  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);

    final token = await AuthStorage.getToken();

    if (token == null) return;

    final response = await ApiService.post(
      "/skills",
      {
        "title": _titleCtrl.text,
        "description": _descCtrl.text,
        "category": _categoryCtrl.text,
        "skillLevel": _level,
        "location": _locationCtrl.text,
        "pricing": {
          "amount": int.parse(_priceCtrl.text),
          "unit": _unit,
        },
      },
      token: token,
    );

    setState(() => _loading = false);

    if (response["statusCode"] == 201) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add skill")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Skill"),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: "Title"),
            ),

            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: "Description"),
              maxLines: 3,
            ),

            TextField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(labelText: "Category"),
            ),

            TextField(
              controller: _locationCtrl,
              decoration: const InputDecoration(labelText: "Location"),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField(
              value: _level,
              decoration: const InputDecoration(labelText: "Skill Level"),
              items: const [
                DropdownMenuItem(value: "beginner", child: Text("Beginner")),
                DropdownMenuItem(value: "intermediate", child: Text("Intermediate")),
                DropdownMenuItem(value: "expert", child: Text("Expert")),
              ],
              onChanged: (v) => setState(() => _level = v!),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField(
              value: _unit,
              decoration: const InputDecoration(labelText: "Pricing Unit"),
              items: const [
                DropdownMenuItem(value: "hour", child: Text("Per Hour")),
                DropdownMenuItem(value: "day", child: Text("Per Day")),
                DropdownMenuItem(value: "job", child: Text("Per Job")),
              ],
              onChanged: (v) => setState(() => _unit = v!),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Price"),
            ),

            const SizedBox(height: 24),

            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submit,
                    child: const Text("Add Skill"),
                  ),
          ],
        ),
      ),
    );
  }
}
