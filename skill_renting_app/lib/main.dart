import 'package:flutter/material.dart';
import 'features/auth/screens/login_screen.dart';

void main() {
  runApp(const SkillRentingApp());
}

class SkillRentingApp extends StatelessWidget {
  const SkillRentingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Skill Renting App',
      theme: ThemeData(useMaterial3: true),
      home: const LoginScreen(),
    );
  }
}
