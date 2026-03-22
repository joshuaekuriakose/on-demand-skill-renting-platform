import 'package:flutter/material.dart';
import '../skill_service.dart';
import '../models/skill_model.dart';
import 'skill_detail_screen.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';

class SkillListScreen extends StatefulWidget {
  const SkillListScreen({super.key});

  @override
  State<SkillListScreen> createState() => _SkillListScreenState();
}

class _SkillListScreenState extends State<SkillListScreen> {
  final TextEditingController _searchController = TextEditingController();
  // Filters
String _searchText = "";
String? _selectedCategory;
double? _minPrice;
double? _maxPrice;
double? _minRating;
  late Future<List<SkillModel>> _skills;

  @override
  void initState() {
    super.initState();
    _skills = SkillService.fetchSkills();
  }

  final Map<String, List<String>> categoryMap = {
  "Plumbing": [
    "Plumbing",
    "Plumber",
    "Pipe Repair",
    "Water Works",
  ],

  "Electrical": [
    "Electrical",
    "Electrician",
    "Wiring",
    "Power Repair",
  ],

  "Appliance Repair": [
    "Appliance Repair",
    "Washing Machine Repair",
    "Fridge Repair",
    "AC Repair",
  ],

  "Cleaning": [
    "Cleaning",
    "House Cleaning",
    "Office Cleaning",
    "Sanitation",
  ],
};

void _searchSkills() {
  setState(() {
    _skills = SkillService.searchSkills(
      query: _searchText,
      category: _selectedCategory,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      minRating: _minRating,
    );
  });
}

void _openFilterSheet() {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Filter Skills",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: "Category",
              ),
              items: const [
                DropdownMenuItem(value: "Plumbing", child: Text("Plumbing")),
                DropdownMenuItem(value: "Electrical", child: Text("Electrical")),
                DropdownMenuItem(value: "Appliance Repair", child: Text("Appliance Repair")),
                DropdownMenuItem(value: "Cleaning", child: Text("Cleaning")),
              ],
              onChanged: (value) {
                _selectedCategory = value;
              },
            ),

            const SizedBox(height: 12),

            // Min Price
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Min Price",
              ),
              onChanged: (v) {
                _minPrice = double.tryParse(v);
              },
            ),

            const SizedBox(height: 12),

            // Max Price
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Max Price",
              ),
              onChanged: (v) {
                _maxPrice = double.tryParse(v);
              },
            ),

            const SizedBox(height: 12),

            // Rating
            DropdownButtonFormField<double>(
              value: _minRating,
              decoration: const InputDecoration(
                labelText: "Minimum Rating",
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text("1+")),
                DropdownMenuItem(value: 2, child: Text("2+")),
                DropdownMenuItem(value: 3, child: Text("3+")),
                DropdownMenuItem(value: 4, child: Text("4+")),
              ],
              onChanged: (value) {
                _minRating = value;
              },
            ),

            const SizedBox(height: 20),

            Row(
  children: [

    // Clear Filters
    Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() {
            _selectedCategory = null;
            _minPrice = null;
            _maxPrice = null;
            _minRating = null;
            _searchText = "";
            _searchController.clear();
            _skills = SkillService.fetchSkills();
          });

          Navigator.pop(context);
        },
        child: const Text("Clear"),
      ),
    ),

    const SizedBox(width: 12),

    // Apply Filters
    Expanded(
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _searchSkills();
        },
        child: const Text("Apply"),
      ),
    ),
  ],
),
          ],
        ),
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      appBar: AppBar(title: const Text("Available Skills")),
      body: Column(
  children: [

    // Search Bar
    Padding(
      padding: const EdgeInsets.all(10),
      child: TextField(
  controller: _searchController,
  decoration: const InputDecoration(
    hintText: "Search skills...",
    prefixIcon: Icon(Icons.search),
  ),
  onChanged: (value) {
    _searchText = value;
    _searchSkills();
  },
),
    ),

    Align(
  alignment: Alignment.centerRight,
  child: TextButton.icon(
    icon: const Icon(Icons.filter_list),
    label: const Text("Filters"),
    onPressed: _openFilterSheet,
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
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  itemCount: skills.length,
  itemBuilder: (context, index) {
    final skill = skills[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surface,
        elevation: 2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SkillDetailScreen(skill: skill)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Title + price row ──────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            skill.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            skill.category,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant.withOpacity(0.7),
                              fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "₹${skill.price.toStringAsFixed(0)}/${skill.pricingUnit}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(skill.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                        ]),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.5)),
                const SizedBox(height: 10),

                // ── Provider info ──────────────────────────────────────
                Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.primaryContainer.withOpacity(0.5),
                    child: Text(
                      skill.providerName.isNotEmpty
                          ? skill.providerName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          skill.providerName.isNotEmpty
                              ? skill.providerName
                              : 'Provider',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        if (skill.providerLocality.isNotEmpty ||
                            skill.providerDistrict.isNotEmpty)
                          Text(
                            [
                              if (skill.providerLocality.isNotEmpty)
                                skill.providerLocality,
                              if (skill.providerDistrict.isNotEmpty)
                                skill.providerDistrict,
                            ].join(', '),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant.withOpacity(0.7)),
                          ),
                      ],
                    ),
                  ),
                  if (skill.providerRating > 0)
                    Row(children: [
                      const Icon(Icons.thumb_up_outlined,
                          size: 12, color: Colors.green),
                      const SizedBox(width: 3),
                      Text(
                        '${skill.providerTotalReviews} reviews',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.green),
                      ),
                    ]),
                ]),
              ],
            ),
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
