import 'package:flutter/material.dart';
import 'core/utils/app_entry.dart';

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
      home: const AppEntry(),
    );
  }
}
