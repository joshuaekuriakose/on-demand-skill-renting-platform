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
    return Scaffold(
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
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        elevation: 2,
        borderRadius: BorderRadius.circular(16),

        child: InkWell(
          borderRadius: BorderRadius.circular(16),

          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SkillDetailScreen(skill: skill),
              ),
            );
          },

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Top Image / Banner
              Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  color: Colors.indigo.shade50,
                ),

                child: const Center(
                  child: Icon(
                    Icons.work_outline,
                    size: 48,
                    color: Colors.indigo,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(14),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Title
                    Text(
                      skill.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Category
                    Text(
                      skill.category,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        // Price Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),

                          child: Text(
                            "₹${skill.price}/${skill.pricingUnit}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo,
                              fontSize: 13,
                            ),
                          ),
                        ),

                        // Rating
                        Row(
                          children: [

                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 18,
                            ),

                            const SizedBox(width: 3),

                            Text(
                              skill.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
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
