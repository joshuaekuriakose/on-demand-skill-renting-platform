import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_renting_app/features/skills/skill_service.dart';
import 'package:skill_renting_app/features/skills/screens/add_skill_screen.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
import 'package:skill_renting_app/features/bookings/screens/provider_calendar_screen.dart';
import 'package:skill_renting_app/features/reviews/review_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const _kDays = [
  "monday", "tuesday", "wednesday", "thursday",
  "friday", "saturday", "sunday",
];

const _kLevels = ["beginner", "intermediate", "expert"];
const _kUnits  = ["hour", "day", "task"];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class MySkillsScreen extends StatefulWidget {
  const MySkillsScreen({super.key});

  @override
  State<MySkillsScreen> createState() => _MySkillsScreenState();
}

class _MySkillsScreenState extends State<MySkillsScreen> {
  List<Map<String, dynamic>> _skills = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    setState(() => _loading = true);
    final data = await SkillService.fetchMySkills();
    if (mounted) {
      setState(() {
        _skills = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    }
  }

  /// Updates only the single card at [index] — no full-list reload.
  void _patchSkill(int index, Map<String, dynamic> updated) {
    setState(() => _skills[index] = updated);
  }

  /// Removes only the single card at [index].
  void _removeSkill(int index) {
    setState(() => _skills.removeAt(index));
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
                      return _ServiceCard(
                        key: ValueKey(_skills[index]["_id"]),
                        skill: _skills[index],
                        onUpdated: (updated) => _patchSkill(index, updated),
                        onDeleted: () => _removeSkill(index),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service card — owns its own toggling state (active/inactive chip)
// ─────────────────────────────────────────────────────────────────────────────

class _ServiceCard extends StatefulWidget {
  final Map<String, dynamic> skill;
  final void Function(Map<String, dynamic> updated) onUpdated;
  final VoidCallback onDeleted;

  const _ServiceCard({
    super.key,
    required this.skill,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  late Map<String, dynamic> _s;
  bool _togglingActive = false;

  @override
  void initState() {
    super.initState();
    _s = Map.from(widget.skill);
  }

  @override
  void didUpdateWidget(_ServiceCard old) {
    super.didUpdateWidget(old);
    if (old.skill != widget.skill) _s = Map.from(widget.skill);
  }

  // ── Toggle active/inactive — updates only THIS card ─────────────────────────
  Future<void> _toggleActive() async {
    if (_togglingActive) return;
    setState(() => _togglingActive = true);
    final newVal = !(_s["isActive"] == true);
    await SkillService.updateSkill(_s["_id"], {"isActive": newVal});
    if (!mounted) return;
    setState(() {
      _s["isActive"] = newVal;
      _togglingActive = false;
    });
    widget.onUpdated(_s);
  }

  // ── Delete — removes only THIS card ─────────────────────────────────────────
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Service"),
        content: Text('Are you sure you want to delete "${_s["title"]}"?'),
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
      await SkillService.deleteSkill(_s["_id"]);
      widget.onDeleted();
    }
  }

  // ── Open full edit sheet ─────────────────────────────────────────────────────
  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSkillSheet(
        skill: _s,
        onSaved: (updated) {
          setState(() => _s = updated);
          widget.onUpdated(updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _s["isActive"] == true;
    final rating = (_s["rating"] as num?)?.toDouble() ?? 0.0;
    final totalReviews = _s["totalReviews"] ?? 0;
    final pricingUnit = _s["pricing"]?["unit"] ?? "hour";
    final price = _s["pricing"]?["amount"];

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ServiceDetailScreen(skill: _s),
        ),
      ).then((_) {}),
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
            // Inactive banner
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_s["title"] ?? "",
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
                              child: Text(_s["category"] ?? "",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.indigo.shade700)),
                            ),
                          ],
                        ),
                      ),

                      // Menu
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
                        onSelected: (v) {
                          switch (v) {
                            case "edit":     _openEditSheet(); break;
                            case "toggle":   _toggleActive(); break;
                            case "delete":   _delete(); break;
                            case "calendar":
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProviderCalendarScreen(
                                    skillId: _s["_id"],
                                    pricingUnit: _s["pricing"]["unit"],
                                  ),
                                ),
                              );
                              break;
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Rate + type chips
                  Wrap(
                    spacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.currency_rupee,
                        label: price != null
                            ? "₹$price / $pricingUnit"
                            : "—",
                        color: Colors.green.shade700,
                      ),
                      _InfoChip(
                        icon: Icons.access_time,
                        label: pricingUnit,
                        color: Colors.blue.shade700,
                      ),
                      if (_s["location"] != null &&
                          _s["location"].toString().isNotEmpty)
                        _InfoChip(
                          icon: Icons.location_on,
                          label: _s["location"],
                          color: Colors.orange.shade700,
                        ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Active toggle chip — only THIS card rebuilds on tap
                  Row(
                    children: [
                      // Rating stars
                      ...List.generate(5, (i) => Icon(
                        i < rating.round() ? Icons.star : Icons.star_border,
                        size: 15, color: Colors.amber,
                      )),
                      const SizedBox(width: 6),
                      Text(
                        rating > 0
                            ? "${rating.toStringAsFixed(1)} ($totalReviews)"
                            : "No reviews",
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const Spacer(),
                      // Active toggle — inline, no full reload
                      GestureDetector(
                        onTap: _toggleActive,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _togglingActive
                                ? Colors.grey.shade200
                                : isActive
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _togglingActive
                                  ? Colors.grey.shade300
                                  : isActive
                                      ? Colors.green.shade300
                                      : Colors.red.shade300,
                            ),
                          ),
                          child: _togglingActive
                              ? SizedBox(
                                  width: 12, height: 12,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.grey.shade600))
                              : Text(
                                  isActive ? "Active" : "Inactive",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isActive
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                  ),
                                ),
                        ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Full edit bottom sheet — each section uses its own local state key
// so only that section rebuilds on interaction
// ─────────────────────────────────────────────────────────────────────────────

class _EditSkillSheet extends StatefulWidget {
  final Map<String, dynamic> skill;
  final void Function(Map<String, dynamic> updated) onSaved;

  const _EditSkillSheet({required this.skill, required this.onSaved});

  @override
  State<_EditSkillSheet> createState() => _EditSkillSheetState();
}

class _EditSkillSheetState extends State<_EditSkillSheet> {
  // Text controllers
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _priceCtrl;

  // Local state — each section uses its own _SectionState widget
  late String _level;
  late String _unit;
  late List<String> _workingDays;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late int _slotDuration;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.skill;
    _titleCtrl    = TextEditingController(text: s["title"] ?? "");
    _descCtrl     = TextEditingController(text: s["description"] ?? "");
    _locationCtrl = TextEditingController(text: s["location"] ?? "");
    _priceCtrl    = TextEditingController(
        text: (s["pricing"]?["amount"] ?? "").toString());

    _level = s["skillLevel"] ?? "beginner";
    _unit  = s["pricing"]?["unit"] ?? "hour";

    final avail = s["availability"];
    _workingDays = avail?["workingDays"] is List
        ? List<String>.from(avail["workingDays"])
        : [];

    final st = avail?["startTime"]?.toString();
    final et = avail?["endTime"]?.toString();
    if (st != null && st.contains(":")) {
      final p = st.split(":");
      _startTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    if (et != null && et.contains(":")) {
      final p = et.split(":");
      _endTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    _slotDuration = avail?["slotDuration"] ?? 60;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  Future<void> _save() async {
    if (_workingDays.isEmpty) {
      _snack("Select at least one working day");
      return;
    }
    if (_unit == "hour" && (_startTime == null || _endTime == null)) {
      _snack("Select working hours for hourly pricing");
      return;
    }

    setState(() => _saving = true);

    final body = <String, dynamic>{
      "title":       _titleCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "location":    _locationCtrl.text.trim(),
      "skillLevel":  _level,
      "pricing": {
        "amount": int.tryParse(_priceCtrl.text) ??
            widget.skill["pricing"]?["amount"] ?? 0,
        "unit": _unit,
      },
      "availability": {
        "workingDays":  _workingDays,
        "startTime":    _unit == "hour" && _startTime != null ? _fmt(_startTime!) : null,
        "endTime":      _unit == "hour" && _endTime   != null ? _fmt(_endTime!)   : null,
        "slotDuration": _unit == "hour" ? _slotDuration : null,
      },
    };

    await SkillService.updateSkill(widget.skill["_id"], body);

    if (!mounted) return;
    setState(() => _saving = false);

    // Build updated local map — no server re-fetch needed
    final updated = Map<String, dynamic>.from(widget.skill)..addAll(body);
    widget.onSaved(updated);
    Navigator.pop(context);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text("Edit Service",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Basic info ───────────────────────────────────────
                    _SectionHeader("Basic Info"),
                    _Field(controller: _titleCtrl,    label: "Title"),
                    const SizedBox(height: 12),
                    _Field(controller: _descCtrl,     label: "Description", maxLines: 3),
                    const SizedBox(height: 12),
                    _Field(controller: _locationCtrl, label: "Location",
                        prefix: const Icon(Icons.location_on_outlined, size: 18)),

                    const SizedBox(height: 20),

                    // ── Skill level — only level chip row rebuilds ────────
                    _SectionHeader("Skill Level"),
                    _LevelSelector(
                      value: _level,
                      onChanged: (v) => setState(() => _level = v),
                    ),

                    const SizedBox(height: 20),

                    // ── Pricing — unit + price ────────────────────────────
                    _SectionHeader("Pricing"),
                    _UnitSelector(
                      value: _unit,
                      onChanged: (v) => setState(() => _unit = v),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      controller: _priceCtrl,
                      label: "Price (₹)",
                      keyboardType: TextInputType.number,
                      prefix: const Text("₹ ",
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),

                    const SizedBox(height: 20),

                    // ── Working days — each chip rebuilds independently ───
                    _SectionHeader("Working Days"),
                    _WorkingDaysSelector(
                      selected: _workingDays,
                      onToggle: (day) {
                        // Only the chip row needs to rebuild
                        setState(() {
                          if (_workingDays.contains(day)) {
                            _workingDays.remove(day);
                          } else {
                            _workingDays.add(day);
                          }
                        });
                      },
                    ),

                    // ── Hourly time config — only shown when unit = hour ──
                    if (_unit == "hour") ...[
                      const SizedBox(height: 20),
                      _SectionHeader("Working Hours"),
                      _TimeRow(
                        label: "Start time",
                        time: _startTime,
                        onPick: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _startTime ??
                                const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (t != null) setState(() => _startTime = t);
                        },
                      ),
                      const SizedBox(height: 10),
                      _TimeRow(
                        label: "End time",
                        time: _endTime,
                        onPick: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: _endTime ??
                                const TimeOfDay(hour: 18, minute: 0),
                          );
                          if (t != null) setState(() => _endTime = t);
                        },
                      ),
                      const SizedBox(height: 12),
                      _SlotDurationField(
                        value: _slotDuration,
                        onChanged: (v) => _slotDuration = v,
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: _saving
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Text("Save Changes",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Granular sub-widgets — each only rebuilds its own section
// ─────────────────────────────────────────────────────────────────────────────

class _LevelSelector extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _LevelSelector({required this.value, required this.onChanged});

  Color _color(String l) {
    switch (l) {
      case "beginner":     return Colors.green;
      case "intermediate": return Colors.orange;
      case "expert":       return Colors.red;
      default:             return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _kLevels.map((l) {
        final selected = l == value;
        final color = _color(l);
        return ChoiceChip(
          label: Text(l[0].toUpperCase() + l.substring(1)),
          selected: selected,
          selectedColor: color.withOpacity(0.15),
          labelStyle: TextStyle(
              color: selected ? color : Colors.grey.shade600,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal),
          side: BorderSide(color: selected ? color : Colors.grey.shade300),
          onSelected: (_) => onChanged(l),
        );
      }).toList(),
    );
  }
}

class _UnitSelector extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  const _UnitSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {"hour": "Per Hour", "day": "Per Day", "task": "Per Task"};
    return Row(
      children: _kUnits.map((u) {
        final selected = u == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(u),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade200,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                labels[u] ?? u,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? Theme.of(context).primaryColor
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _WorkingDaysSelector extends StatelessWidget {
  final List<String> selected;
  final void Function(String day) onToggle;
  const _WorkingDaysSelector(
      {required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _kDays.map((day) {
        final isSelected = selected.contains(day);
        return FilterChip(
          label: Text(day.substring(0, 3).toUpperCase(),
              style: const TextStyle(fontSize: 12)),
          selected: isSelected,
          selectedColor: Colors.indigo.withOpacity(0.12),
          checkmarkColor: Colors.indigo,
          labelStyle: TextStyle(
              color: isSelected ? Colors.indigo : Colors.grey.shade600,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal),
          side: BorderSide(
              color:
                  isSelected ? Colors.indigo : Colors.grey.shade300),
          onSelected: (_) => onToggle(day),
        );
      }).toList(),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onPick;
  const _TimeRow(
      {required this.label, required this.time, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: time != null
                  ? Colors.indigo.shade200
                  : Colors.grey.shade200),
        ),
        child: Row(children: [
          Icon(Icons.access_time,
              size: 18,
              color: time != null ? Colors.indigo : Colors.grey),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const Spacer(),
          Text(
            time != null
                ? time!.format(context)
                : "Tap to set",
            style: TextStyle(
                fontWeight:
                    time != null ? FontWeight.bold : FontWeight.normal,
                color: time != null
                    ? Colors.indigo.shade700
                    : Colors.grey.shade400,
                fontSize: 14),
          ),
        ]),
      ),
    );
  }
}

class _SlotDurationField extends StatelessWidget {
  final int value;
  final void Function(int) onChanged;
  const _SlotDurationField(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value.toString(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: "Slot duration (minutes)",
        suffixText: "min",
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      onChanged: (v) => onChanged(int.tryParse(v) ?? value),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14)),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType keyboardType;
  final Widget? prefix;

  const _Field({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefix != null
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: prefix)
            : null,
        prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    );
  }
}

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
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Service detail screen (provider view — reviews with reply)
// ─────────────────────────────────────────────────────────────────────────────

class ServiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> skill;
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
    final data = await ReviewService.fetchSkillReviews(widget.skill["_id"]);
    if (mounted) setState(() { _reviews = data; _loading = false; });
  }

  double get _avgRating {
    if (_reviews.isEmpty) return 0;
    return _reviews.fold<double>(
            0, (acc, r) => acc + (r["rating"] as num).toDouble()) /
        _reviews.length;
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
              // Header card
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
                    Row(children: [
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
                    ]),
                    const SizedBox(height: 4),
                    Text(s["category"] ?? "",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 14),
                    Wrap(spacing: 8, children: [
                      _WhiteChip(
                          icon: Icons.currency_rupee,
                          label: price != null
                              ? "₹$price / $pricingUnit"
                              : "—"),
                      _WhiteChip(
                          icon: Icons.access_time, label: pricingUnit),
                      if (s["skillLevel"] != null)
                        _WhiteChip(
                            icon: Icons.star_half,
                            label: s["skillLevel"]),
                    ]),
                  ],
                ),
              ),

              if (s["description"] != null &&
                  s["description"].toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text("About this service",
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(s["description"],
                    style:
                        const TextStyle(fontSize: 14, height: 1.5)),
              ],

              const SizedBox(height: 20),

              Row(children: [
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
              ]),

              const SizedBox(height: 12),

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
                          child: const Column(children: [
                            Icon(Icons.rate_review_outlined,
                                size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text("No reviews yet",
                                style: TextStyle(color: Colors.grey)),
                          ]),
                        )
                      : Column(
                          children: _reviews
                              .map((r) => _ReviewCard(
                                    review: r,
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

// ─────────────────────────────────────────────────────────────────────────────
// Review card with inline reply — only the reply section rebuilds
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewCard extends StatefulWidget {
  final Map review;
  final VoidCallback? onReplyChanged;
  const _ReviewCard({required this.review, this.onReplyChanged});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _showField = false;
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  String _timeAgo(String? iso) {
    if (iso == null) return "";
    final dt = DateTime.tryParse(iso);
    if (dt == null) return "";
    final d = DateTime.now().difference(dt.toLocal());
    if (d.inDays > 30) return "${(d.inDays / 30).floor()}mo ago";
    if (d.inDays > 0)  return "${d.inDays}d ago";
    if (d.inHours > 0) return "${d.inHours}h ago";
    return "Just now";
  }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final ok = await ReviewService.replyToReview(
        widget.review["_id"], _ctrl.text.trim());
    setState(() => _submitting = false);
    if (ok) {
      setState(() => _showField = false);
      widget.onReplyChanged?.call();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Failed to save reply")));
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
    final name = r["reviewer"]?["name"] ?? "User";
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
          // Reviewer row
          Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.indigo.shade100,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : "U",
                  style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(_timeAgo(r["createdAt"]),
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            ),
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    size: 14, color: Colors.amber),
              ),
            ),
          ]),

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(comment,
                style: const TextStyle(fontSize: 14, height: 1.4)),
          ],

          // Reply section — only this rebuilds
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
                  Row(children: [
                    Icon(Icons.reply, size: 14, color: Colors.indigo.shade400),
                    const SizedBox(width: 4),
                    Text("Your reply",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.indigo.shade600)),
                    const Spacer(),
                    Text(_timeAgo(repliedAt),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade400)),
                  ]),
                  const SizedBox(height: 6),
                  Text(replyText!,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                  const SizedBox(height: 8),
                  Row(children: [
                    TextButton(
                      onPressed: () {
                        _ctrl.text = replyText;
                        setState(() => _showField = true);
                      },
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: Colors.red),
                      child: const Text("Delete",
                          style: TextStyle(fontSize: 12)),
                    ),
                  ]),
                ],
              ),
            ),
          ],

          if (!hasReply && !_showField) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => setState(() => _showField = true),
              icon: const Icon(Icons.reply, size: 16),
              label: const Text("Reply", style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: Colors.indigo),
            ),
          ],

          if (_showField) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _ctrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Write your reply…",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              TextButton(
                onPressed: () => setState(() { _showField = false; _ctrl.clear(); }),
                child: const Text("Cancel"),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Post Reply"),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// White chip for gradient header
// ─────────────────────────────────────────────────────────────────────────────

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
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: Colors.white),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
