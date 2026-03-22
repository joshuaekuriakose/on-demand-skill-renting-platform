import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_renting_app/core/services/auth_storage.dart';
import 'package:skill_renting_app/features/auth/screens/login_screen.dart';
import 'package:skill_renting_app/features/auth/auth_service.dart';
import 'package:skill_renting_app/features/profile/profile_service.dart';
import 'package:skill_renting_app/features/profile/models/profile_model.dart';
import 'change_password_screen.dart';
import 'package:skill_renting_app/features/reports/reports_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileModel? _profile;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final d = await ProfileService.getProfile();
    if (mounted) setState(() { _profile = d; _loading = false; });
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  Future<void> _showEdit() async {
    final nameC     = TextEditingController(text: _profile?.name ?? "");
    final phoneC    = TextEditingController(text: _profile?.phone ?? "");
    final houseC    = TextEditingController(text: _profile?.address?["houseName"]?.toString() ?? "");
    final localityC = TextEditingController(text: _profile?.address?["locality"]?.toString() ?? "");
    final pinC      = TextEditingController(text: _profile?.address?["pincode"]?.toString() ?? "");
    final districtC = TextEditingController(text: _profile?.address?["district"]?.toString() ?? "");

    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(
                color: isDark ? const Color(0xFF2A2740) : cs.outlineVariant.withOpacity(0.5), width: 0.6))),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
                Row(children: [
                  Text("Edit Profile", style: Theme.of(ctx).textTheme.titleSmall),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ]),
                const SizedBox(height: 16),
                _EditField(ctrl: nameC,     label: "Full name"),
                const SizedBox(height: 12),
                _EditField(ctrl: phoneC,    label: "Phone number",  type: TextInputType.phone,
                    formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]),
                const SizedBox(height: 12),
                _EditField(ctrl: houseC,    label: "House name"),
                const SizedBox(height: 12),
                _EditField(ctrl: localityC, label: "Locality"),
                const SizedBox(height: 12),
                _EditField(ctrl: pinC,      label: "PIN code", type: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]),
                const SizedBox(height: 12),
                _EditField(ctrl: districtC, label: "District"),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, height: 50,
                  child: FilledButton(
                    onPressed: () async {
                      final ok = await ProfileService.updateProfile(nameC.text.trim(), phoneC.text.trim(),
                        address: {"houseName": houseC.text.trim(), "locality": localityC.text.trim(),
                            "pincode": pinC.text.trim(), "district": districtC.text.trim()});
                      if (ok && mounted) {
                        Navigator.pop(ctx);
                        _load();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Profile updated")));
                      }
                    },
                    child: const Text("Save changes"))),
              ]),
            ),
          ),
        );
      },
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
        title: Text("Profile", style: tt.titleLarge),
        shape: Border(bottom: BorderSide(
          color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.5), width: 0.5)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? Center(child: Text("Failed to load", style: tt.bodySmall))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    // Avatar
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [cs.primary, cs.secondary],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2A2740) : cs.outlineVariant, width: 2)),
                      child: Center(child: Text(
                        _profile!.name.isNotEmpty ? _profile!.name[0].toUpperCase() : "U",
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700))),
                    ),
                    const SizedBox(height: 14),
                    Text(_profile!.name, style: tt.headlineSmall),
                    const SizedBox(height: 4),
                    Text(_profile!.email, style: tt.bodySmall),
                    const SizedBox(height: 24),

                    // Info card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F0E17) : cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.8),
                          width: isDark ? 0.6 : 0.8)),
                      child: Column(children: [
                        _InfoRow(icon: Icons.phone_outlined,    label: "Phone",    value: _profile!.phone, cs: cs, tt: tt, isDark: isDark),
                        Divider(height: 1, color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.5)),
                        _InfoRow(icon: Icons.location_on_outlined, label: "Address",
                            value: [_profile!.address?["locality"], _profile!.address?["district"],
                                _profile!.address?["pincode"]].where((s) => s != null && s.toString().isNotEmpty)
                                .join(", ").isNotEmpty
                                ? [_profile!.address?["locality"], _profile!.address?["district"],
                                    _profile!.address?["pincode"]].where((s) => s != null && s.toString().isNotEmpty).join(", ")
                                : "Not set",
                            cs: cs, tt: tt, isDark: isDark),
                      ]),
                    ),
                    const SizedBox(height: 12),

                    // Action tiles
                    _ActionTile(icon: Icons.lock_outline_rounded, label: "Change password",
                        sub: "Update your account password", cs: cs, tt: tt, isDark: isDark,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
                    const SizedBox(height: 8),
                    _ActionTile(icon: Icons.bar_chart_rounded, label: "My reports",
                        sub: "View and download service reports", cs: cs, tt: tt, isDark: isDark,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
                    const SizedBox(height: 24),

                    // Buttons
                    SizedBox(width: double.infinity, height: 50,
                      child: FilledButton.icon(
                        onPressed: _showEdit,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text("Edit profile"))),
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout_rounded, size: 16),
                        label: const Text("Sign out"),
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFF87171),
                            side: const BorderSide(color: Color(0xFFF87171), width: 0.8)))),
                  ]),
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon; final String label, value;
  final ColorScheme cs; final TextTheme tt; final bool isDark;
  const _InfoRow({required this.icon, required this.label, required this.value,
      required this.cs, required this.tt, required this.isDark});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Icon(icon, size: 16, color: cs.onSurfaceVariant),
      const SizedBox(width: 12),
      Text(label, style: tt.labelSmall),
      const Spacer(),
      Flexible(child: Text(value, style: tt.bodySmall, textAlign: TextAlign.right,
          maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]));
}

class _ActionTile extends StatelessWidget {
  final IconData icon; final String label, sub;
  final ColorScheme cs; final TextTheme tt; final bool isDark;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.label, required this.sub,
      required this.cs, required this.tt, required this.isDark, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0E17) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E1C30) : cs.outlineVariant.withOpacity(0.8),
          width: isDark ? 0.6 : 0.8)),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 17, color: cs.primary)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: tt.labelLarge),
          const SizedBox(height: 2),
          Text(sub, style: tt.labelSmall),
        ])),
        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: cs.onSurfaceVariant),
      ]),
    ));
}

class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType type;
  final List<TextInputFormatter> formatters;
  const _EditField({required this.ctrl, required this.label,
      this.type = TextInputType.text, this.formatters = const []});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: type, inputFormatters: formatters,
    decoration: InputDecoration(labelText: label),
  );
}
