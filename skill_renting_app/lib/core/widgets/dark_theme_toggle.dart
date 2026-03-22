import 'package:flutter/material.dart';

import '../theme/theme_toggle_controller.dart';

class DarkThemeToggle extends StatelessWidget {
  const DarkThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeToggleController.themeMode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return SwitchListTile(
          title: const Text("Dark theme"),
          value: isDark,
          onChanged: (v) => ThemeToggleController.setDarkEnabled(v),
        );
      },
    );
  }
}

