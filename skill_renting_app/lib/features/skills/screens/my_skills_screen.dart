import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_renting_app/features/skills/skill_service.dart';
import 'package:skill_renting_app/features/skills/screens/add_skill_screen.dart';
import 'package:skill_renting_app/features/bookings/screens/provider_calendar_screen.dart';
import 'package:skill_renting_app/features/reviews/review_service.dart';

const _kDays   = ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"];
const _kLevels = {"beginner":"Beginner","intermediate":"Intermediate","expert":"Expert"};
const _kUnits  = {"hour":"Per hour","day":"Per day","task":"Per task"};

Color _levelColor(String l) {
  switch (l) {
    case "beginner":     return const Color(0xFF10B981);
    case "intermediate": return const Color(0xFFF59E0B);
    case "expert":       return const Color(0xFFEF4444);
    default:             return const Color(0xFF6B7280);
  }
}

class MySkillsScreen extends StatefulWidget {
  const MySkillsScreen({super.key});
  @override
  State<MySkillsScreen> createState() => _MySkillsScreenState();
}

class _MySkillsScreenState extends State<MySkillsScreen> {
  List<Map<String, dynamic>> _skills = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadSkills(); }

  Future<void> _loadSkills() async {
    setState(() => _loading = true);
    final data = await SkillService.fetchMySkills();
    if (mounted) setState(() {
      _skills = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  void _patchSkill(int i, Map<String, dynamic> u) => setState(() => _skills[i] = u);
  void _removeSkill(int i)                        => setState(() => _skills.removeAt(i));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text("My Services"),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.primary.withOpacity(0.3), width: 0.8),
              ),
              child: Icon(Icons.add_rounded, size: 18, color: cs.primary)),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSkillScreen()));
              _loadSkills();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _skills.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 72, height: 72,
                      decoration: BoxDecoration(color: cs.surfaceContainerHigh, shape: BoxShape.circle,
                          border: Border.all(color: cs.outlineVariant, width: 0.8)),
                      child: Icon(Icons.work_outline_rounded, size: 32, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  Text("No services added yet", style: tt.titleMedium),
                  const SizedBox(height: 6),
                  Text("Add your first service to start receiving bookings", style: tt.bodySmall, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddSkillScreen()));
                      _loadSkills();
                    },
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text("Add Service")),
                ]))
              : RefreshIndicator(
                  onRefresh: _loadSkills,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _skills.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _ServiceCard(
                      key: ValueKey(_skills[i]["_id"]),
                      skill: _skills[i],
                      onUpdated: (u) => _patchSkill(i, u),
                      onDeleted: () => _removeSkill(i),
                    ),
                  ),
                ),
    );
  }
}

// ─── Service card ─────────────────────────────────────────────────────────────
class _ServiceCard extends StatefulWidget {
  final Map<String, dynamic> skill;
  final void Function(Map<String, dynamic>) onUpdated;
  final VoidCallback onDeleted;
  const _ServiceCard({super.key, required this.skill, required this.onUpdated, required this.onDeleted});
  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  late Map<String, dynamic> _s;
  bool _togglingActive = false;

  @override
  void initState() { super.initState(); _s = Map.from(widget.skill); }

  Future<void> _toggleActive() async {
    if (_togglingActive) return;
    setState(() => _togglingActive = true);
    final newVal = !(_s["isActive"] == true);
    await SkillService.updateSkill(_s["_id"], {"isActive": newVal});
    if (!mounted) return;
    setState(() { _s["isActive"] = newVal; _togglingActive = false; });
    widget.onUpdated(_s);
  }

  Future<void> _delete() async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text("Delete Service"),
      content: Text('Delete "${_s["title"]}"? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          child: const Text("Delete")),
      ],
    ));
    if (confirmed == true) {
      await SkillService.deleteSkill(_s["_id"]);
      widget.onDeleted();
    }
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _EditSkillSheet(
        skill: _s,
        onSaved: (u) { setState(() => _s = u); widget.onUpdated(u); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs         = Theme.of(context).colorScheme;
    final tt         = Theme.of(context).textTheme;
    final isActive   = _s["isActive"] == true;
    final rating     = (_s["rating"] as num?)?.toDouble() ?? 0.0;
    final reviews    = _s["totalReviews"] ?? 0;
    final unit       = _s["pricing"]?["unit"] ?? "hour";
    final price      = _s["pricing"]?["amount"];
    final levelKey   = _s["skillLevel"]?.toString() ?? "beginner";
    final levelCol   = _levelColor(levelKey);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ServiceDetailScreen(skill: _s))),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
          boxShadow: [BoxShadow(color: cs.shadow.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))],
        ),
        child: Column(children: [
          // Inactive banner
          if (!isActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: const Border(
                    bottom: BorderSide(color: Color(0xFFEF4444), width: 0.5)),
              ),
              child: const Center(child: Text("INACTIVE",
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1.2))),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Top row
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_s["title"] ?? "", style: tt.titleSmall,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: cs.outlineVariant, width: 0.8),
                      ),
                      child: Text(_s["category"] ?? "",
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: levelCol.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: levelCol.withOpacity(0.3), width: 0.8),
                      ),
                      child: Text(_kLevels[levelKey] ?? levelKey,
                          style: TextStyle(fontSize: 11, color: levelCol, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ])),

                // Menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: "edit",     child: _MenuItem(Icons.edit_outlined,    "Edit")),
                    const PopupMenuItem(value: "calendar", child: _MenuItem(Icons.calendar_month_outlined, "Calendar")),
                    const PopupMenuItem(value: "toggle",   child: _MenuItem(Icons.toggle_on_outlined, "Toggle active")),
                    const PopupMenuItem(value: "delete",   child: _MenuItem(Icons.delete_outline_rounded, "Delete", danger: true)),
                  ],
                  onSelected: (v) {
                    switch (v) {
                      case "edit":     _openEditSheet(); break;
                      case "toggle":   _toggleActive(); break;
                      case "delete":   _delete(); break;
                      case "calendar":
                        Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ProviderCalendarScreen(
                                skillId: _s["_id"], pricingUnit: _s["pricing"]["unit"])));
                        break;
                    }
                  },
                ),
              ]),

              const SizedBox(height: 10),
              Divider(height: 1, color: cs.outlineVariant.withOpacity(0.5)),
              const SizedBox(height: 10),

              // Bottom row
              Row(children: [
                // Price chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.primary.withOpacity(0.25), width: 0.8),
                  ),
                  child: Text(price != null ? "₹$price / $unit" : "—",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary)),
                ),
                const SizedBox(width: 8),
                // Rating
                Row(children: [
                  ...List.generate(5, (i) => Icon(
                      i < rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 13, color: const Color(0xFFF59E0B))),
                  const SizedBox(width: 4),
                  Text(rating > 0 ? "${rating.toStringAsFixed(1)} ($reviews)" : "No reviews",
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
                const Spacer(),

                // Active toggle
                GestureDetector(
                  onTap: _toggleActive,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _togglingActive ? cs.surfaceContainerHigh
                          : isActive ? const Color(0xFF10B981).withOpacity(0.1)
                              : const Color(0xFFEF4444).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _togglingActive ? cs.outlineVariant
                            : isActive ? const Color(0xFF10B981).withOpacity(0.4)
                                : const Color(0xFFEF4444).withOpacity(0.4),
                        width: 0.8),
                    ),
                    child: _togglingActive
                        ? SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: cs.onSurfaceVariant))
                        : Text(
                            isActive ? "Active" : "Inactive",
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600,
                              color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  const _MenuItem(this.icon, this.label, {this.danger = false});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = danger ? const Color(0xFFEF4444) : cs.onSurface;
    return Row(children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: color, fontSize: 14)),
    ]);
  }
}

// ─── Edit sheet ───────────────────────────────────────────────────────────────
class _EditSkillSheet extends StatefulWidget {
  final Map<String, dynamic> skill;
  final void Function(Map<String, dynamic>) onSaved;
  const _EditSkillSheet({required this.skill, required this.onSaved});
  @override
  State<_EditSkillSheet> createState() => _EditSkillSheetState();
}

class _EditSkillSheetState extends State<_EditSkillSheet> {
  late final TextEditingController _titleCtrl, _descCtrl, _locationCtrl, _priceCtrl;
  late String _level, _unit;
  late List<String> _workingDays;
  TimeOfDay? _startTime, _endTime;
  late int _slotDuration;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.skill;
    _titleCtrl    = TextEditingController(text: s["title"] ?? "");
    _descCtrl     = TextEditingController(text: s["description"] ?? "");
    _locationCtrl = TextEditingController(text: s["location"] ?? "");
    _priceCtrl    = TextEditingController(text: (s["pricing"]?["amount"] ?? "").toString());
    _level        = s["skillLevel"] ?? "beginner";
    _unit         = s["pricing"]?["unit"] ?? "hour";
    final avail   = s["availability"];
    _workingDays  = avail?["workingDays"] is List ? List<String>.from(avail["workingDays"]) : [];
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
    _titleCtrl.dispose(); _descCtrl.dispose();
    _locationCtrl.dispose(); _priceCtrl.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}";

  Future<void> _save() async {
    if (_workingDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select at least one working day"))); return;
    }
    if (_unit == "hour" && (_startTime == null || _endTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select working hours"))); return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      "title":       _titleCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "location":    _locationCtrl.text.trim(),
      "skillLevel":  _level,
      "pricing":     {"amount": int.tryParse(_priceCtrl.text) ?? 0, "unit": _unit},
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
    final updated = Map<String, dynamic>.from(widget.skill)..addAll(body);
    widget.onSaved(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.93, minChildSize: 0.5, maxChildSize: 0.96,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: cs.outlineVariant.withOpacity(0.5), width: 0.8)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 36, height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(child: Text("Edit Service", style: tt.titleMedium)),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ]),
          ),
          Divider(height: 1, color: cs.outlineVariant.withOpacity(0.5)),
          Expanded(
            child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                _Sec("Service details", tt),
                _EditCard(cs: cs, children: [
                  _EField(ctrl: _titleCtrl,    label: "Title",       icon: Icons.work_outline_rounded),
                  const SizedBox(height: 12),
                  _EField(ctrl: _descCtrl,     label: "Description", icon: Icons.description_outlined, maxLines: 3),
                  const SizedBox(height: 12),
                  _EField(ctrl: _locationCtrl, label: "Service area",icon: Icons.location_on_outlined),
                ]),

                const SizedBox(height: 18),
                _Sec("Skill level", tt),
                _EditCard(cs: cs, children: [
                  Row(children: _kLevels.entries.map((e) {
                    final sel = _level == e.key;
                    final col = _levelColor(e.key);
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _level = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? col.withOpacity(0.1) : cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? col : cs.outlineVariant, width: sel ? 1.5 : 0.8),
                        ),
                        child: Text(e.value, textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: sel ? col : cs.onSurfaceVariant)),
                      ),
                    ));
                  }).toList()),
                ]),

                const SizedBox(height: 18),
                _Sec("Pricing", tt),
                _EditCard(cs: cs, children: [
                  Row(children: _kUnits.entries.map((e) {
                    final sel = _unit == e.key;
                    return Expanded(child: GestureDetector(
                      onTap: () => setState(() => _unit = e.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? cs.primaryContainer : cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: sel ? cs.primary : cs.outlineVariant, width: sel ? 1.5 : 0.8),
                        ),
                        child: Text(e.value, textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: sel ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
                      ),
                    ));
                  }).toList()),
                  const SizedBox(height: 12),
                  _EField(ctrl: _priceCtrl, label: "Price (₹)", icon: Icons.currency_rupee,
                      keyboardType: TextInputType.number),
                ]),

                const SizedBox(height: 18),
                _Sec("Working days", tt),
                _EditCard(cs: cs, children: [
                  Wrap(spacing: 8, runSpacing: 8, children: _kDays.map((d) {
                    final sel = _workingDays.contains(d);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (sel) _workingDays.remove(d); else _workingDays.add(d);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: sel ? cs.primaryContainer : cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: sel ? cs.primary : cs.outlineVariant, width: sel ? 1.5 : 0.8),
                        ),
                        child: Text(d.substring(0,3).toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: sel ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
                      ),
                    );
                  }).toList()),
                ]),

                if (_unit == "hour") ...[
                  const SizedBox(height: 18),
                  _Sec("Working hours", tt),
                  _EditCard(cs: cs, children: [
                    _TimeTile("Start time", _startTime, () async {
                      final t = await showTimePicker(context: context,
                          initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0));
                      if (t != null) setState(() => _startTime = t);
                    }, cs),
                    const SizedBox(height: 10),
                    _TimeTile("End time", _endTime, () async {
                      final t = await showTimePicker(context: context,
                          initialTime: _endTime ?? const TimeOfDay(hour: 18, minute: 0));
                      if (t != null) setState(() => _endTime = t);
                    }, cs),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _slotDuration.toString(),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) => _slotDuration = int.tryParse(v) ?? _slotDuration,
                      decoration: const InputDecoration(
                          labelText: "Slot duration (minutes)", suffixText: "min"),
                    ),
                  ]),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text("Save Changes")),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Service detail screen ────────────────────────────────────────────────────
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
  void initState() { super.initState(); _loadReviews(); }

  Future<void> _loadReviews() async {
    setState(() => _loading = true);
    final data = await ReviewService.fetchSkillReviews(widget.skill["_id"]);
    if (mounted) setState(() { _reviews = data; _loading = false; });
  }

  double get _avgRating => _reviews.isEmpty ? 0
      : _reviews.fold<double>(0, (s, r) => s + (r["rating"] as num).toDouble()) / _reviews.length;

  String _timeAgo(String? iso) {
    if (iso == null) return "";
    final d = DateTime.now().difference(DateTime.tryParse(iso)?.toLocal() ?? DateTime.now());
    if (d.inDays > 30) return "${(d.inDays/30).floor()}mo ago";
    if (d.inDays > 0) return "${d.inDays}d ago";
    if (d.inHours > 0) return "${d.inHours}h ago";
    return "Just now";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s  = widget.skill;
    final unit  = s["pricing"]?["unit"] ?? "hour";
    final price = s["pricing"]?["amount"];
    final levelKey = s["skillLevel"]?.toString() ?? "beginner";
    final levelCol = _levelColor(levelKey);

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: Text(s["title"] ?? "Service")),
      body: RefreshIndicator(
        onRefresh: _loadReviews,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Header card
            Container(
              width: double.infinity, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [cs.primaryContainer, cs.secondaryContainer],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.4), width: 0.8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(s["title"] ?? "", style: tt.headlineSmall?.copyWith(color: cs.onPrimaryContainer))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (s["isActive"] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (s["isActive"] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.4), width: 0.8),
                    ),
                    child: Text(s["isActive"] == true ? "ACTIVE" : "INACTIVE",
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: s["isActive"] == true ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(s["category"] ?? "",
                    style: TextStyle(color: cs.onPrimaryContainer.withOpacity(0.7), fontSize: 13)),
                const SizedBox(height: 14),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _HeaderChip(Icons.currency_rupee, price != null ? "₹$price / $unit" : "—", cs),
                  _HeaderChip(Icons.access_time_rounded, unit, cs),
                  _HeaderChip(Icons.signal_cellular_alt_rounded, _kLevels[levelKey] ?? levelKey, cs,
                      color: levelCol),
                ]),
              ]),
            ),

            if ((s["description"] ?? "").toString().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surface, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
                ),
                child: Text(s["description"], style: tt.bodyMedium?.copyWith(height: 1.6, color: cs.onSurfaceVariant)),
              ),
            ],

            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Text("Reviews", style: tt.titleMedium)),
              if (_reviews.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 0.8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 4),
                    Text("${_avgRating.toStringAsFixed(1)} · ${_reviews.length}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF59E0B))),
                  ]),
                ),
            ]),
            const SizedBox(height: 12),

            _loading
                ? const Center(child: CircularProgressIndicator())
                : _reviews.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(color: cs.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8)),
                        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.rate_review_outlined, size: 36, color: cs.onSurfaceVariant.withOpacity(0.4)),
                          const SizedBox(height: 8),
                          Text("No reviews yet", style: tt.bodySmall),
                        ])))
                    : Column(children: _reviews.map((r) =>
                        Padding(padding: const EdgeInsets.only(bottom: 10),
                          child: _ReviewCard(review: r, timeAgo: _timeAgo, cs: cs, tt: tt,
                              onReplyChanged: _loadReviews))).toList()),
          ]),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final Color? color;
  const _HeaderChip(this.icon, this.label, this.cs, {this.color});
  @override
  Widget build(BuildContext context) {
    final c = color ?? cs.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.25), width: 0.8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
      ]),
    );
  }
}

// ─── Review card with reply ────────────────────────────────────────────────────
class _ReviewCard extends StatefulWidget {
  final Map review;
  final String Function(String?) timeAgo;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback? onReplyChanged;
  const _ReviewCard({required this.review, required this.timeAgo,
      required this.cs, required this.tt, this.onReplyChanged});
  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool _showField = false;
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final ok = await ReviewService.replyToReview(widget.review["_id"], _ctrl.text.trim());
    setState(() => _submitting = false);
    if (ok) { setState(() => _showField = false); widget.onReplyChanged?.call(); }
    else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save reply")));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;
    final cs = widget.cs;
    final tt = widget.tt;
    final rating    = (r["rating"] as num?)?.toInt() ?? 0;
    final name      = r["reviewer"]?["name"] ?? "User";
    final comment   = r["comment"]?.toString() ?? "";
    final replyText = r["providerReply"]?["text"]?.toString();
    final repliedAt = r["providerReply"]?["repliedAt"]?.toString();
    final hasReply  = replyText != null && replyText.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 16, backgroundColor: cs.primaryContainer,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : "U",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: tt.labelLarge),
            Text(widget.timeAgo(r["createdAt"]), style: tt.labelSmall),
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
              color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.6), width: 0.8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.reply_rounded, size: 13, color: cs.primary),
                const SizedBox(width: 4),
                Text("Your reply", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
                const Spacer(),
                Text(widget.timeAgo(repliedAt), style: tt.labelSmall),
              ]),
              const SizedBox(height: 6),
              Text(replyText!, style: tt.bodySmall?.copyWith(color: cs.onSurface, height: 1.4)),
              const SizedBox(height: 8),
              Row(children: [
                TextButton(
                  onPressed: () { _ctrl.text = replyText; setState(() => _showField = true); },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: cs.primary),
                  child: const Text("Edit", style: TextStyle(fontSize: 12))),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () async {
                    final ok = await ReviewService.deleteReply(widget.review["_id"]);
                    if (ok) widget.onReplyChanged?.call();
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFFEF4444)),
                  child: const Text("Delete", style: TextStyle(fontSize: 12))),
              ]),
            ]),
          ),
        ],
        if (!hasReply && !_showField) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _showField = true),
            icon: const Icon(Icons.reply_rounded, size: 14),
            label: const Text("Reply", style: TextStyle(fontSize: 13)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap, foregroundColor: cs.primary)),
        ],
        if (_showField) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant, width: 0.8)),
            child: TextField(controller: _ctrl, maxLines: 3,
              style: TextStyle(color: cs.onSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Write your reply…",
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
                hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.5), fontSize: 13),
              )),
          ),
          const SizedBox(height: 8),
          Row(children: [
            TextButton(onPressed: () => setState(() { _showField = false; _ctrl.clear(); }),
                child: const Text("Cancel")),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Post Reply")),
          ]),
        ],
      ]),
    );
  }
}

// ─── Small edit sheet helpers ─────────────────────────────────────────────────
class _Sec extends StatelessWidget {
  final String text; final TextTheme tt;
  const _Sec(this.text, this.tt);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: tt.titleSmall));
}

class _EditCard extends StatelessWidget {
  final List<Widget> children; final ColorScheme cs;
  const _EditCard({required this.children, required this.cs});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
}

class _EField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label; final IconData icon;
  final int maxLines; final TextInputType keyboardType;
  const _EField({required this.ctrl, required this.label, required this.icon,
      this.maxLines = 1, this.keyboardType = TextInputType.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(controller: ctrl, maxLines: maxLines, keyboardType: keyboardType,
      style: TextStyle(color: cs.onSurface, fontSize: 14),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18)));
  }
}

class _TimeTile extends StatelessWidget {
  final String label; final TimeOfDay? time;
  final VoidCallback onTap; final ColorScheme cs;
  const _TimeTile(this.label, this.time, this.onTap, this.cs);
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: time != null ? cs.primary : cs.outlineVariant,
            width: time != null ? 1.5 : 0.8)),
      child: Row(children: [
        Icon(Icons.access_time_rounded, size: 18, color: time != null ? cs.primary : cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13))),
        Text(time?.format(context) ?? "Tap to set",
            style: TextStyle(fontSize: 14, fontWeight: time != null ? FontWeight.w600 : FontWeight.normal,
                color: time != null ? cs.primary : cs.onSurfaceVariant.withOpacity(0.5))),
      ]),
    ));
}
