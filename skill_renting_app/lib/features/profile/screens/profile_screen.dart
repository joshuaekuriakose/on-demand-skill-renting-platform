import 'package:flutter/material.dart';
import '../profile_service.dart';
import 'change_password_screen.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await ProfileService.getProfile();

    if (data != null) {
      _nameController.text = data["name"] ?? "";
      _phoneController.text = data["phone"] ?? "";
    }

    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final success = await ProfileService.updateProfile(
      _nameController.text.trim(),
      _phoneController.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? "Profile updated" : "Update failed",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Profile"),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),

              child: Column(
                children: [

                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Name",
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: "Phone",
                    ),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _save,
                    child: const Text("Save Changes"),
                  ),
                  ListTile(
  leading: const Icon(Icons.lock),
  title: const Text("Change Password"),
  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChangePasswordScreen(),
      ),
    );
  },
),

                ],
              ),
            ),
    );
  }
}
