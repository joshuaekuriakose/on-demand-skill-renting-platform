import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';

class AddSkillScreen extends StatefulWidget {
  const AddSkillScreen({super.key});
  @override
  State<AddSkillScreen> createState() => _AddSkillScreenState();
}

class _AddSkillScreenState extends State<AddSkillScreen> {
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _priceCtrl    = TextEditingController();

  String _unit  = "hour";
  String _level = "beginner";
  bool _loading = false;

  List<String> _workingDays = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _slotDuration = 60;

  static const _days = ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"];
  static const _levels = {"beginner": "Beginner", "intermediate": "Intermediate", "expert": "Expert"};
  static const _units  = {"hour": "Per hour", "day": "Per day", "task": "Per task"};

  Future<void> _submit() async {
    if (_workingDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select at least one working day"))); return;
    }
    if (_unit == "hour" && (_startTime == null || _endTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select working hours for hourly pricing"))); return;
    }
    setState(() => _loading = true);
    final token = await AuthStorage.getToken();
    if (token == null) { setState(() => _loading = false); return; }
    final response = await ApiService.post("/skills", {
      "title": _titleCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "category": _categoryCtrl.text.trim(),
      "skillLevel": _level,
      "location": _locationCtrl.text.trim(),
      "pricing": {"amount": int.tryParse(_priceCtrl.text) ?? 0, "unit": _unit},
      "availability": {
        "workingDays": _workingDays,
        "startTime": _unit == "hour" && _startTime != null
            ? "${_startTime!.hour.toString().padLeft(2,'0')}:${_startTime!.minute.toString().padLeft(2,'0')}" : null,
        "endTime":   _unit == "hour" && _endTime != null
            ? "${_endTime!.hour.toString().padLeft(2,'0')}:${_endTime!.minute.toString().padLeft(2,'0')}" : null,
        "slotDuration": _unit == "hour" ? _slotDuration : null,
      },
    }, token: token);
    setState(() => _loading = false);
    if (response["statusCode"] == 201) {
      if (mounted) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to add service")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: const Text("Add Service")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Basic info ──────────────────────────────────────────────────
          _Section("Service details", cs, tt),
          _Card(cs: cs, children: [
            _Field(ctrl: _titleCtrl,    label: "Title",       icon: Icons.work_outline_rounded),
            const SizedBox(height: 14),
            _Field(ctrl: _descCtrl,     label: "Description", icon: Icons.description_outlined, maxLines: 3),
            const SizedBox(height: 14),
            _Field(ctrl: _categoryCtrl, label: "Category",    icon: Icons.category_outlined),
            const SizedBox(height: 14),
            _Field(ctrl: _locationCtrl, label: "Service area",icon: Icons.location_on_outlined),
          ]),

          const SizedBox(height: 20),
          _Section("Skill level", cs, tt),
          _Card(cs: cs, children: [
            Row(children: _levels.entries.map((e) {
              final sel = _level == e.key;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() => _level = e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? cs.primaryContainer : cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? cs.primary : cs.outlineVariant, width: sel ? 1.5 : 0.8),
                  ),
                  child: Text(e.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
                ),
              ));
            }).toList()),
          ]),

          const SizedBox(height: 20),
          _Section("Pricing", cs, tt),
          _Card(cs: cs, children: [
            Row(children: _units.entries.map((e) {
              final sel = _unit == e.key;
              return Expanded(child: GestureDetector(
                onTap: () => setState(() { _unit = e.key; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? cs.primaryContainer : cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel ? cs.primary : cs.outlineVariant, width: sel ? 1.5 : 0.8),
                  ),
                  child: Text(e.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
                ),
              ));
            }).toList()),
            const SizedBox(height: 14),
            _Field(ctrl: _priceCtrl, label: "Price (₹)", icon: Icons.currency_rupee,
                keyboardType: TextInputType.number),
          ]),

          const SizedBox(height: 20),
          _Section("Working days", cs, tt),
          _Card(cs: cs, children: [
            Wrap(spacing: 8, runSpacing: 8, children: _days.map((d) {
              final sel = _workingDays.contains(d);
              return FilterChip(
                label: Text(d.substring(0,3).toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                        color: sel ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
                selected: sel,
                selectedColor: cs.primaryContainer,
                side: BorderSide(color: sel ? cs.primary : cs.outlineVariant, width: sel ? 1.5 : 0.8),
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  if (sel) _workingDays.remove(d); else _workingDays.add(d);
                }),
              );
            }).toList()),
          ]),

          if (_unit == "hour") ...[
            const SizedBox(height: 20),
            _Section("Working hours", cs, tt),
            _Card(cs: cs, children: [
              _TimeTile("Start time", _startTime, () async {
                final t = await showTimePicker(context: context,
                    initialTime: const TimeOfDay(hour: 9, minute: 0));
                if (t != null) setState(() => _startTime = t);
              }, cs, tt),
              const SizedBox(height: 10),
              _TimeTile("End time",   _endTime,   () async {
                final t = await showTimePicker(context: context,
                    initialTime: const TimeOfDay(hour: 18, minute: 0));
                if (t != null) setState(() => _endTime = t);
              }, cs, tt),
              const SizedBox(height: 14),
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: "Slot duration (minutes)", suffixText: "min"),
                onChanged: (v) => _slotDuration = int.tryParse(v) ?? 60,
              ),
            ]),
          ],

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity, height: 52,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                  : const Text("Add Service"),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final ColorScheme cs;
  final TextTheme tt;
  const _Section(this.title, this.cs, this.tt);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(title, style: tt.titleSmall),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  final ColorScheme cs;
  const _Card({required this.children, required this.cs});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cs.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final int maxLines;
  final TextInputType keyboardType;
  const _Field({required this.ctrl, required this.label, required this.icon,
      this.maxLines = 1, this.keyboardType = TextInputType.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(color: cs.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;
  final ColorScheme cs;
  final TextTheme tt;
  const _TimeTile(this.label, this.time, this.onTap, this.cs, this.tt);
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: time != null ? cs.primary : cs.outlineVariant,
          width: time != null ? 1.5 : 0.8),
      ),
      child: Row(children: [
        Icon(Icons.access_time_rounded, size: 18,
            color: time != null ? cs.primary : cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
        Text(
          time?.format(context) ?? "Tap to set",
          style: TextStyle(
            fontSize: 14,
            fontWeight: time != null ? FontWeight.w600 : FontWeight.normal,
            color: time != null ? cs.primary : cs.onSurfaceVariant.withOpacity(0.5)),
        ),
      ]),
    ),
  );
}
