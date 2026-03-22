import 'package:flutter/material.dart';
import '../../auth/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl  = TextEditingController();
  final _newCtrl      = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscCurrent = true, _obscNew = true, _obscConfirm = true;
  String? _error;

  Future<void> _change() async {
    final newPass    = _newCtrl.text.trim();
    final confirm    = _confirmCtrl.text.trim();
    final current    = _currentCtrl.text.trim();
    if (newPass != confirm) { setState(() => _error = "Passwords do not match"); return; }
    setState(() { _loading = true; _error = null; });
    final ok = await AuthService.changePassword(current, newPass);
    if (!mounted) return;
    setState(() => _loading = false);
    if (!ok) { setState(() => _error = "Current password is incorrect"); return; }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Password updated")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(title: const Text("Change Password")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Update your password", style: tt.titleMedium),
            const SizedBox(height: 4),
            Text("Choose a strong password for your account",
                style: tt.bodySmall),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
              ),
              child: Column(children: [
                _PwField(ctrl: _currentCtrl, label: "Current password",
                    obscure: _obscCurrent, onToggle: () => setState(() => _obscCurrent = !_obscCurrent)),
                const SizedBox(height: 14),
                _PwField(ctrl: _newCtrl,     label: "New password",
                    obscure: _obscNew,     onToggle: () => setState(() => _obscNew = !_obscNew)),
                const SizedBox(height: 14),
                _PwField(ctrl: _confirmCtrl, label: "Confirm new password",
                    obscure: _obscConfirm, onToggle: () => setState(() => _obscConfirm = !_obscConfirm)),
              ]),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cs.error.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Icon(Icons.error_outline, size: 16, color: cs.onErrorContainer),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: TextStyle(color: cs.onErrorContainer, fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: FilledButton(
                onPressed: _loading ? null : _change,
                child: _loading
                    ? SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                    : const Text("Update Password"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PwField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  const _PwField({required this.ctrl, required this.label, required this.obscure, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(color: cs.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 20, color: cs.onSurfaceVariant),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
