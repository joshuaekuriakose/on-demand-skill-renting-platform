import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';
import 'package:skill_renting_app/features/common/widgets/skeleton_list.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  String? _error;

  Future<void> _changePassword() async {
    final current = _currentController.text.trim();
    final newPass = _newController.text.trim();
    final confirm = _confirmController.text.trim();

    if (newPass != confirm) {
      setState(() {
        _error = "Passwords do not match";
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final success = await AuthService.changePassword(
      current,
      newPass,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (!success) {
      setState(() {
        _error = "Current password is incorrect";
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Password changed successfully"),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            TextField(
              controller: _currentController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Current Password",
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _newController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "New Password",
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: "Confirm Password",
              ),
            ),

            const SizedBox(height: 20),

            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _loading ? null : _changePassword,
              child: _loading
  ? const SkeletonList()
                  : const Text("Update Password"),
            ),
          ],
        ),
      ),
    );
  }
}
