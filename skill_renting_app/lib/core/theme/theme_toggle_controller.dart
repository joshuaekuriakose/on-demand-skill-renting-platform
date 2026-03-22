import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeToggleController {
  static const _key = "ui_dark_theme_enabled";

  // Default to DARK — premium editorial is the default experience
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  static ThemeMode get currentMode => themeMode.value;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to dark (true) if never set before
    final enabled = prefs.getBool(_key) ?? true;
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setDarkEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
  }

  static bool get isDark => themeMode.value == ThemeMode.dark;
}
