import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth_service.dart';
import '../../dashboard/main_dashboard.dart';
import 'login_screen.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ── Shared form widgets (duplicated here; also in login_screen.dart) ──────────

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.8), width: 0.8),
        boxShadow: [
          BoxShadow(color: cs.shadow.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? errorText;
  final void Function(String)? onChanged;

  const _Input({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(color: cs.onSurface, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        prefixIcon: Icon(prefixIcon, size: 18),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _houseCtrl    = TextEditingController();
  final _localityCtrl = TextEditingController();
  final _pinCtrl      = TextEditingController();
  final _districtCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _phoneError;

  String? _validatePhone(String p) {
    if (p.isEmpty) return null;
    if (p.length != 10) return "Must be 10 digits";
    return null;
  }

  Future<void> _register() async {
    final phoneError = _validatePhone(_phoneCtrl.text.trim());
    if (phoneError != null) { setState(() => _phoneError = phoneError); return; }
    setState(() { _loading = true; _error = null; _phoneError = null; });

    final user = await AuthService.register(
      _nameCtrl.text.trim(), _emailCtrl.text.trim(),
      _phoneCtrl.text.trim(), _passwordCtrl.text.trim(),
      address: {
        "houseName": _houseCtrl.text.trim(),
        "locality":  _localityCtrl.text.trim(),
        "pincode":   _pinCtrl.text.trim(),
        "district":  _districtCtrl.text.trim(),
      },
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (user == null) { setState(() => _error = "Registration failed"); return; }
    if (context.mounted) FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Account created successfully")));
    Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()));
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await ApiService.post("/users/save-token", {"token": fcmToken}, token: user.token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text("Create Account"),
        backgroundColor: cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Personal info", style: tt.titleMedium),
            const SizedBox(height: 4),
            Text("Fill in your details to get started",
                style: tt.bodySmall),
            const SizedBox(height: 16),

            _FormCard(children: [
              _Input(controller: _nameCtrl,  label: "Full name",      prefixIcon: Icons.person_outline_rounded),
              const SizedBox(height: 14),
              _Input(controller: _emailCtrl, label: "Email address",  prefixIcon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 14),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                style: TextStyle(color: cs.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "Phone number",
                  errorText: _phoneError,
                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                ),
                onChanged: (v) {
                  final e = _validatePhone(v);
                  if (e != _phoneError) setState(() => _phoneError = e);
                },
              ),
              const SizedBox(height: 14),
              _Input(
                controller: _passwordCtrl, label: "Password",
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20, color: cs.onSurfaceVariant),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ]),

            const SizedBox(height: 20),
            Text("Address", style: tt.titleMedium),
            const SizedBox(height: 4),
            Text("Used to match you with nearby providers",
                style: tt.bodySmall),
            const SizedBox(height: 16),

            _FormCard(children: [
              _Input(controller: _houseCtrl,    label: "House / flat name", prefixIcon: Icons.home_outlined),
              const SizedBox(height: 14),
              _Input(controller: _localityCtrl, label: "Locality / area",   prefixIcon: Icons.location_city_outlined),
              const SizedBox(height: 14),
              _Input(
                controller: _pinCtrl,
                label: "PIN code",
                prefixIcon: Icons.pin_drop_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              _Input(controller: _districtCtrl, label: "District",          prefixIcon: Icons.map_outlined),
            ]),

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
                onPressed: _loading ? null : _register,
                child: _loading
                    ? SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                    : const Text("Create Account"),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
