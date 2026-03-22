import 'package:flutter/material.dart';
import '../skill_service.dart';
import '../models/skill_model.dart';
import 'skill_detail_screen.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';

class SkillListScreen extends StatefulWidget {
  const SkillListScreen({super.key});
  @override
  State<SkillListScreen> createState() => _SkillListScreenState();
}

class _SkillListScreenState extends State<SkillListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchText = "";
  String? _selectedCategory;
  double? _minPrice, _maxPrice, _minRating;
  late Future<List<SkillModel>> _skills;

  @override
  void initState() { super.initState(); _skills = SkillService.fetchSkills(); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  void _search() => setState(() {
    _skills = SkillService.searchSkills(
      query: _searchText, category: _selectedCategory,
      minPrice: _minPrice, maxPrice: _maxPrice, minRating: _minRating);
  });

  bool get _hasFilters => _selectedCategory != null || _minPrice != null ||
      _maxPrice != null || _minRating != null;

  void _showFilters() {
    String? cat = _selectedCategory;
    double? mn = _minPrice, mx = _maxPrice, mr = _minRating;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(
              color: isDark ? const Color(0xFF2A2740) : cs.outlineVariant.withOpacity(0.5),
              width: 0.6))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
              Row(children: [
                Text("Filters", style: Theme.of(ctx).textTheme.titleSmall),
                const Spacer(),
                if (cat != null || mn != null || mx != null || mr != null)
                  TextButton(onPressed: () => setSt(() { cat = null; mn = null; mx = null; mr = null; }),
                      child: const Text("Clear all")),
              ]),
              const SizedBox(height: 16),
              Text("Category", style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: ["Plumbing","Electrical","Appliance Repair","Cleaning"]
                .map((c) => GestureDetector(
                  onTap: () => setSt(() => cat = cat == c ? null : c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: cat == c ? cs.primary.withOpacity(isDark ? 0.2 : 0.1) : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: cat == c ? cs.primary.withOpacity(0.5) : cs.outlineVariant.withOpacity(0.6),
                        width: 0.8)),
                    child: Text(c, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: cat == c ? cs.primary : cs.onSurfaceVariant))))).toList()),
              const SizedBox(height: 16),
              Text("Min rating", style: Theme.of(ctx).textTheme.labelMedium),
              const SizedBox(height: 8),
              Row(children: [null, 3.0, 4.0, 4.5].map((r) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setSt(() => mr = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: mr == r ? cs.primary.withOpacity(isDark ? 0.2 : 0.1) : cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: mr == r ? cs.primary.withOpacity(0.5) : cs.outlineVariant.withOpacity(0.6),
                        width: 0.8)),
                    child: Text(r == null ? "Any" : "★ $r+",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                            color: mr == r ? cs.primary : cs.onSurfaceVariant)))))).toList()),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() { _selectedCategory = cat; _minPrice = mn; _maxPrice = mx; _minRating = mr; });
                    _search();
                  },
                  child: const Text("Apply filters"))),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        title: Text("Explore", style: tt.titleLarge),
        shape: Border(bottom: BorderSide(
          color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.5), width: 0.5)),
      ),
      body: Column(children: [
        // Search + filter bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            Expanded(child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A2740) : cs.outlineVariant, width: 0.8)),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search services…",
                  hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: cs.onSurfaceVariant),
                  suffixIcon: _searchText.isNotEmpty ? IconButton(
                    icon: Icon(Icons.clear_rounded, size: 16, color: cs.onSurfaceVariant),
                    onPressed: () { _searchCtrl.clear(); setState(() => _searchText = ""); _search(); })
                    : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onChanged: (v) { setState(() => _searchText = v); _search(); },
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showFilters,
              child: Container(
                height: 42, width: 42,
                decoration: BoxDecoration(
                  color: _hasFilters ? cs.primary.withOpacity(isDark ? 0.2 : 0.1) : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasFilters ? cs.primary.withOpacity(0.5)
                        : (isDark ? const Color(0xFF2A2740) : cs.outlineVariant),
                    width: 0.8)),
                child: Icon(Icons.tune_rounded, size: 18,
                    color: _hasFilters ? cs.primary : cs.onSurfaceVariant),
              ),
            ),
          ]),
        ),

        // Active filter chips
        if (_hasFilters)
          SizedBox(height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (_selectedCategory != null) _FilterChip(label: _selectedCategory!, cs: cs, isDark: isDark,
                    onRemove: () { setState(() => _selectedCategory = null); _search(); }),
                if (_minRating != null) _FilterChip(label: "★ $_minRating+", cs: cs, isDark: isDark,
                    onRemove: () { setState(() => _minRating = null); _search(); }),
              ],
            )),

        // List
        Expanded(
          child: FutureBuilder<List<SkillModel>>(
            future: _skills,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done)
                return _SkeletonList(cs: cs);
              if (!snap.hasData || snap.data!.isEmpty)
                return Center(child: Text("No services found", style: tt.bodySmall));
              final skills = snap.data!;
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                itemCount: skills.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _SkillCard(skill: skills[i], cs: cs, tt: tt, isDark: isDark,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => SkillDetailScreen(skill: skills[i])))),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.cs, required this.isDark, required this.onRemove});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: cs.primary.withOpacity(isDark ? 0.15 : 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: cs.primary.withOpacity(0.3), width: 0.8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w500)),
      const SizedBox(width: 4),
      GestureDetector(onTap: onRemove,
          child: Icon(Icons.close_rounded, size: 13, color: cs.primary)),
    ]),
  );
}

class _SkillCard extends StatelessWidget {
  final SkillModel skill;
  final ColorScheme cs;
  final TextTheme tt;
  final bool isDark;
  final VoidCallback onTap;
  const _SkillCard({required this.skill, required this.cs, required this.tt,
      required this.isDark, required this.onTap});

  Color get _accentColor {
    switch (skill.category.toLowerCase()) {
      case 'plumbing':         return const Color(0xFF60A5FA);
      case 'electrical':       return const Color(0xFFFBBF24);
      case 'appliance repair': return const Color(0xFFA78BFA);
      case 'cleaning':         return const Color(0xFF34D399);
      default:                 return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0E17) : cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.8),
          width: isDark ? 0.6 : 0.8)),
      child: Row(children: [
        // Category icon box
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: _accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accentColor.withOpacity(isDark ? 0.25 : 0.2), width: 0.8)),
          child: Icon(Icons.build_outlined, size: 22, color: _accentColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(skill.title, style: tt.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(skill.providerName.isNotEmpty ? skill.providerName : skill.category,
              style: tt.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFBBF24)),
            const SizedBox(width: 3),
            Text(skill.rating.toStringAsFixed(1), style: tt.labelSmall),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
              child: Text(skill.category,
                  style: TextStyle(fontSize: 10, color: _accentColor, fontWeight: FontWeight.w500))),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text("₹${skill.price.toStringAsFixed(0)}",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: cs.primary)),
          Text("/${skill.pricingUnit}", style: tt.labelSmall),
          const SizedBox(height: 8),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: cs.onSurfaceVariant),
        ]),
      ]),
    ),
  );
}

class _SkeletonList extends StatelessWidget {
  final ColorScheme cs;
  const _SkeletonList({required this.cs});
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
    itemCount: 6,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (_, __) => Container(
      height: 78,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4), width: 0.6))));
}
