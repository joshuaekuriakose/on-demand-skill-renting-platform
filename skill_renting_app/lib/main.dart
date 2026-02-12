import 'package:flutter/material.dart';
import 'core/utils/app_entry.dart';
import 'package:skill_renting_app/features/auth/screens/login_screen.dart';
import 'package:skill_renting_app/features/auth/screens/register_screen.dart';


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

  theme: ThemeData(
  useMaterial3: true,

  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.indigo,
  ),

  scaffoldBackgroundColor: Colors.grey.shade50,

  appBarTheme: const AppBarTheme(
    centerTitle: true,
    elevation: 2,
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(double.infinity, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    ),
  ),

  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
  ),
),


  home: LoginScreen(),

routes: {
  "/login": (context) => LoginScreen(),
  "/register": (context) => RegisterScreen(),
},
);

  }
}
