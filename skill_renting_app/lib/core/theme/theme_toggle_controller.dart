import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global theme mode controller (light/dark) with persistence.
///
/// This is intentionally lightweight (no Provider) so it works everywhere.
class ThemeToggleController {
  static const _key = "ui_dark_theme_enabled";

  /// Listenable so `MaterialApp` + UI can rebuild immediately on toggle.
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  static ThemeMode get currentMode => themeMode.value;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_key) ?? false;
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> setDarkEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
    themeMode.value = enabled ? ThemeMode.dark : ThemeMode.light;
  }

  static bool get isDark => themeMode.value == ThemeMode.dark;
}

