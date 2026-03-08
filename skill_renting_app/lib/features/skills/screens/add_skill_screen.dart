import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
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
  // ===== Availability =====
List<String> _workingDays = [];
TimeOfDay? _startTime;
TimeOfDay? _endTime;
int _slotDuration = 60;

  Future<void> _submit() async {
    setState(() => _loading = true);

    final token = await AuthStorage.getToken();

    if (token == null) return;

    final skillData = {
  "title": _titleCtrl.text,
  "description": _descCtrl.text,
  "category": _categoryCtrl.text,
  "skillLevel": _level,
  "location": _locationCtrl.text,
  "pricing": {
    "amount": int.parse(_priceCtrl.text),
    "unit": _unit,
  },
  "availability": {
    "workingDays": _workingDays,
    "startTime": _unit == "hour" && _startTime != null
        ? "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}"
        : null,
    "endTime": _unit == "hour" && _endTime != null
        ? "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}"
        : null,
    "slotDuration": _unit == "hour" ? _slotDuration : null,
  }
};

if (_workingDays.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Select working days")),
  );
  setState(() => _loading = false);
  return;
}

if (_unit == "hour" &&
    (_startTime == null || _endTime == null)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Select working hours")),
  );
  setState(() => _loading = false);
  return;
}

final response = await ApiService.post(
  "/skills",
  skillData,
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
        title: const Text("Add Service"),
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
                DropdownMenuItem(value: "task", child: Text("Per task")),
              ],
              onChanged: (v) => setState(() => _unit = v!),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Price"),
            ),

            const SizedBox(height: 20),

const Align(
  alignment: Alignment.centerLeft,
  child: Text(
    "Working Days",
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
),

const SizedBox(height: 8),

Wrap(
  spacing: 8,
  children: [
    for (final day in [
      "monday",
      "tuesday",
      "wednesday",
      "thursday",
      "friday",
      "saturday",
      "sunday",
    ])
      FilterChip(
        label: Text(day.substring(0, 3).toUpperCase()),
        selected: _workingDays.contains(day),
        onSelected: (selected) {
          setState(() {
            if (selected) {
              _workingDays.add(day);
            } else {
              _workingDays.remove(day);
            }
          });
        },
      ),
  ],
),

const SizedBox(height: 20),

if (_unit == "hour") ...[
  const SizedBox(height: 20),

  ElevatedButton(
    onPressed: () async {
      final picked = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 9, minute: 0),
      );
      if (picked != null) {
        setState(() => _startTime = picked);
      }
    },
    child: Text(_startTime == null
        ? "Select Start Time"
        : "Start: ${_startTime!.format(context)}"),
  ),

  const SizedBox(height: 10),

  ElevatedButton(
    onPressed: () async {
      final picked = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 18, minute: 0),
      );
      if (picked != null) {
        setState(() => _endTime = picked);
      }
    },
    child: Text(_endTime == null
        ? "Select End Time"
        : "End: ${_endTime!.format(context)}"),
  ),

  const SizedBox(height: 10),

  TextField(
    decoration:
        const InputDecoration(labelText: "Slot Duration (minutes)"),
    keyboardType: TextInputType.number,
    onChanged: (value) {
      _slotDuration = int.tryParse(value) ?? 60;
    },
  ),
],

            const SizedBox(height: 24),

            _loading
  ? const Center(child: CircularProgressIndicator())
  : ElevatedButton(
                    onPressed: _submit,
                    child: const Text("Add Service"),
                  ),
          ],
        ),
      ),
    );
  }
}
