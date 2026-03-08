import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../auth_service.dart';
import '../../dashboard/main_dashboard.dart';
import 'login_screen.dart';
import 'package:skill_renting_app/core/services/api_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _houseController = TextEditingController();
  final _localityController = TextEditingController();
  final _pinController = TextEditingController();
  final _districtController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  String? _phoneError; // inline phone error

  String? _validatePhone(String phone) {
    if (phone.isEmpty) return null; // let server validate required
    if (phone.length != 10) return "Invalid number";
    return null;
  }

  Future<void> _register() async {
    // Validate phone before submitting
    final phoneError = _validatePhone(_phoneController.text.trim());
    if (phoneError != null) {
      setState(() => _phoneError = phoneError);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _phoneError = null;
    });

    final user = await AuthService.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _phoneController.text.trim(),
      _passwordController.text.trim(),
      address: {
        "houseName": _houseController.text.trim(),
        "locality": _localityController.text.trim(),
        "pincode": _pinController.text.trim(),
        "district": _districtController.text.trim(),
      },
    );

    if (!mounted) return;

    if (user == null) {
      setState(() {
        _error = "Registration failed";
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Registration successful")),
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      await ApiService.post(
        "/users/save-token",
        {"token": fcmToken},
        token: user.token,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),

              // Phone with inline validation
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  labelText: "Phone",
                  errorText: _phoneError,
                ),
                onChanged: (v) {
                  final err = _validatePhone(v);
                  if (err != _phoneError) {
                    setState(() => _phoneError = err);
                  }
                },
              ),

              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _houseController,
                decoration:
                    const InputDecoration(labelText: "House name"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _localityController,
                decoration: const InputDecoration(labelText: "Locality"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(labelText: "PIN code"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _districtController,
                decoration: const InputDecoration(labelText: "District"),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Register"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
