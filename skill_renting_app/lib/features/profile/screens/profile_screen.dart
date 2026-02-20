import 'package:flutter/material.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/auth/screens/login_screen.dart';
import 'package:skill_renting_app/features/profile/profile_service.dart';
import 'package:skill_renting_app/features/profile/models/profile_model.dart';
import 'change_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileModel? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await ProfileService.getProfile();

    setState(() {
      _profile = data;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await AuthStorage.clear();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _showEditDialog() async {
  final nameController =
      TextEditingController(text: _profile?.name ?? "");
  final phoneController =
      TextEditingController(text: _profile?.phone ?? "");

  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Edit Profile"),

        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // Name
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Name",
              ),
            ),

            const SizedBox(height: 12),

            // Phone
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone",
              ),
            ),
          ],
        ),

        actions: [

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),

          ElevatedButton(
            child: const Text("Save"),

            onPressed: () async {
              final success =
                  await ProfileService.updateProfile(
                nameController.text.trim(),
                phoneController.text.trim(),
              );

              if (success) {
                Navigator.pop(context);
                _loadProfile(); // refresh UI

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Profile updated"),
                  ),
                );
              }
            },
          ),
        ],
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text("Failed to load profile"))
              : SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),

                    child: Column(
                      children: [
      // Avatar
      CircleAvatar(
        radius: 45,
        backgroundColor: Colors.indigo,

        child: Text(
          _profile!.name.isNotEmpty
              ? _profile!.name[0].toUpperCase()
              : "U",
          style: const TextStyle(
            fontSize: 32,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

                        const SizedBox(height: 12),

                        // ================= NAME =================
                        Text(
                          _profile!.name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // ================= EMAIL =================
                        Text(
                          _profile!.email,
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Divider(),

                        const SizedBox(height: 20),

                        // ================= INFO CARDS =================

                        _InfoTile(
                          icon: Icons.phone,
                          title: "Phone",
                          value: _profile!.phone,
                        ),

                        _InfoTile(
                          icon: Icons.lock,
                          title: "Password",
                          value: "••••••••",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ChangePasswordScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 30),

                        // ================= ACTION BUTTONS =================

                        SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    icon: const Icon(Icons.edit),
    label: const Text("Edit Profile"),
    onPressed: _showEditDialog,
  ),
),

                        const SizedBox(height: 12),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.logout),
                            label: const Text("Logout"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            onPressed: _logout,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

// =======================================================
// Info Tile Widget
// =======================================================

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),

      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),

        title: Text(title),

        subtitle: Text(value),

        trailing:
            onTap != null ? const Icon(Icons.arrow_forward_ios, size: 16) : null,

        onTap: onTap,
      ),
    );
  }
}