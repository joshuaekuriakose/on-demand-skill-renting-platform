import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/auth/auth_service.dart';
import 'package:skill_renting_app/features/auth/screens/login_screen.dart';
import 'package:skill_renting_app/features/profile/profile_service.dart';
import 'package:skill_renting_app/features/profile/models/profile_model.dart';
import 'change_password_screen.dart';
import 'package:skill_renting_app/features/reports/reports_screen.dart';
import 'package:skill_renting_app/core/widgets/app_scaffold.dart';

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
    setState(() { _profile = data; _loading = false; });
  }

  Future<void> _logout() async {
    await AuthService.logout();
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
    final houseController = TextEditingController(
        text: _profile?.address?["houseName"]?.toString() ?? "");
    final localityController = TextEditingController(
        text: _profile?.address?["locality"]?.toString() ?? "");
    final pinController = TextEditingController(
        text: _profile?.address?["pincode"]?.toString() ?? "");
    final districtController = TextEditingController(
        text: _profile?.address?["district"]?.toString() ?? "");

    await showDialog(
      context: context,
      builder: (context) {
        String? phoneError;

        return StatefulBuilder(
          builder: (context, setS) {
            String? validatePhone(String v) {
              if (v.isEmpty) return null;
              if (v.length != 10) return "Invalid number";
              return null;
            }

            return AlertDialog(
              title: const Text("Edit Profile"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name
                    TextField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: "Name"),
                    ),
                    const SizedBox(height: 12),

                    // Phone with inline validation
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: "Phone",
                        errorText: phoneError,
                      ),
                      onChanged: (v) {
                        final err = validatePhone(v);
                        if (err != phoneError) {
                          setS(() => phoneError = err);
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: houseController,
                      decoration:
                          const InputDecoration(labelText: "House name"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: localityController,
                      decoration:
                          const InputDecoration(labelText: "Locality"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pinController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      decoration:
                          const InputDecoration(labelText: "PIN code"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: districtController,
                      decoration:
                          const InputDecoration(labelText: "District"),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  // Disable Save if phone error present
                  onPressed: phoneError != null
                      ? null
                      : () async {
                          // Final validation before saving
                          final err = validatePhone(
                              phoneController.text.trim());
                          if (err != null) {
                            setS(() => phoneError = err);
                            return;
                          }
                          final success =
                              await ProfileService.updateProfile(
                            nameController.text.trim(),
                            phoneController.text.trim(),
                            address: {
                              "houseName":
                                  houseController.text.trim(),
                              "locality":
                                  localityController.text.trim(),
                              "pincode": pinController.text.trim(),
                              "district":
                                  districtController.text.trim(),
                            },
                          );
                          if (success && context.mounted) {
                            Navigator.pop(context);
                            _loadProfile();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Profile updated")),
                            );
                          }
                        },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      // Theme-driven colors for consistent light/dark appearance.
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
                        CircleAvatar(
                          radius: 45,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(
                            _profile!.name.isNotEmpty
                                ? _profile!.name[0].toUpperCase()
                                : "U",
                            style: TextStyle(
                              fontSize: 32,
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(_profile!.name,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(_profile!.email,
                            style:
                                TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),
                        _InfoTile(
                          icon: Icons.phone,
                          title: "Phone",
                          value: _profile!.phone,
                        ),
                        _InfoTile(
                          icon: Icons.lock,
                          title: "Password",
                          value: "Change your password",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ChangePasswordScreen()),
                          ),
                        ),
                        _InfoTile(
                          icon: Icons.bar_chart,
                          title: "My Reports",
                          value: "View and download reports",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ReportsScreen()),
                          ),
                        ),
                        const SizedBox(height: 30),
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
                                foregroundColor: Colors.red),
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: scheme.primary),
        title: Text(title),
        subtitle: Text(value),
        trailing: onTap != null
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
        onTap: onTap,
      ),
    );
  }
}
