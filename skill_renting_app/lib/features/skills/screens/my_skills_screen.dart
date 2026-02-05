import 'package:flutter/material.dart';
import 'package:skill_renting_app/features/skills/skill_service.dart';
import 'package:skill_renting_app/features/skills/screens/add_skill_screen.dart';

class MySkillsScreen extends StatefulWidget {
  const MySkillsScreen({super.key});

  @override
  State<MySkillsScreen> createState() => _MySkillsScreenState();
}

class _MySkillsScreenState extends State<MySkillsScreen> {
  List _skills = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSkills();
  }

  Future<void> _loadSkills() async {
    final data = await SkillService.fetchMySkills();

    setState(() {
      _skills = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text("My Skills"),

  actions: [
    IconButton(
      icon: const Icon(Icons.add),
      tooltip: "Add Skill",
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddSkillScreen(),
          ),
        );

        _loadSkills(); // Refresh after adding
      },
    ),
  ],
),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _skills.isEmpty
              ? const Center(child: Text("No skills added yet"))
              : ListView.builder(
                  itemCount: _skills.length,
                  itemBuilder: (context, index) {
                    final s = _skills[index];

                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text(s["title"]),
                        subtitle: Text(s["category"]),
                        trailing: PopupMenuButton(
  itemBuilder: (context) => [

    const PopupMenuItem(
      value: "edit",
      child: Text("Edit"),
    ),

    PopupMenuItem(
      value: "toggle",
      child: Text(
        s["isActive"] ? "Deactivate" : "Activate",
      ),
    ),

    const PopupMenuItem(
      value: "delete",
      child: Text("Delete"),
    ),
  ],

  onSelected: (value) async {

    // DELETE
    if (value == "delete") {
      await SkillService.deleteSkill(s["_id"]);
      _loadSkills();
    }

    // TOGGLE
    if (value == "toggle") {
      await SkillService.updateSkill(
        s["_id"],
        {"isActive": !s["isActive"]},
      );
      _loadSkills();
    }

    // EDIT
    if (value == "edit") {
      _openEditDialog(s);
    }
  },
),

                      ),
                    );
                  },
                ),
    );
  }
  void _openEditDialog(Map skill) {
  final titleCtrl = TextEditingController(text: skill["title"]);
  final priceCtrl = TextEditingController(
    text: skill["pricing"]["amount"].toString(),
  );

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Edit Skill"),

      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: "Title"),
          ),

          TextField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Price"),
          ),
        ],
      ),

      actions: [

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),

        ElevatedButton(
          onPressed: () async {

           await SkillService.updateSkill(
  skill["_id"],
  {
    "title": titleCtrl.text,
    "pricing": {
      "amount": int.parse(priceCtrl.text),
      "unit": skill["pricing"]["unit"],
    },
  },
);


            Navigator.pop(context);
            _loadSkills();
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );
}



}
