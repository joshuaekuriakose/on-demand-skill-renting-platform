import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_tokens.dart';

class AppTheme {
  // ── Dark editorial (default / hero theme) ────────────────────────────────
  static ThemeData dark() => _buildDark(_darkScheme());

  // ── Light clean (secondary / toggle) ─────────────────────────────────────
  static ThemeData light() => _buildLight(_lightScheme());

  // ─────────────────────────────────────────────────────────────────────────
  // Colour schemes
  // ─────────────────────────────────────────────────────────────────────────

  static ColorScheme _darkScheme() => const ColorScheme(
    brightness: Brightness.dark,

    // Violet primary
    primary:            Color(0xFF8B5CF6),
    onPrimary:          Color(0xFFFFFFFF),
    primaryContainer:   Color(0xFF2D1B69),
    onPrimaryContainer: Color(0xFFDDD6FE),

    // Teal secondary
    secondary:            Color(0xFF14B8A6),
    onSecondary:          Color(0xFFFFFFFF),
    secondaryContainer:   Color(0xFF0D2E2B),
    onSecondaryContainer: Color(0xFF5EEAD4),

    // Tertiary — rose accent
    tertiary:            Color(0xFFF472B6),
    onTertiary:          Color(0xFFFFFFFF),
    tertiaryContainer:   Color(0xFF3D0A26),
    onTertiaryContainer: Color(0xFFFCE7F3),

    // Error
    error:            Color(0xFFF87171),
    onError:          Color(0xFF1C0505),
    errorContainer:   Color(0xFF450A0A),
    onErrorContainer: Color(0xFFFCA5A5),

    // Surfaces — near-black with subtle violet undertone
    surface:                    Color(0xFF0F0E17),
    onSurface:                  Color(0xFFEDE9FF),
    surfaceContainerLowest:     Color(0xFF07070D),
    surfaceContainerLow:        Color(0xFF12101E),
    surfaceContainer:           Color(0xFF161427),
    surfaceContainerHigh:       Color(0xFF1B1930),
    surfaceContainerHighest:    Color(0xFF201D38),
    surfaceVariant:             Color(0xFF1E1B31),
    onSurfaceVariant:           Color(0xFF9D98B8),

    // Outline
    outline:        Color(0xFF3A3652),
    outlineVariant: Color(0xFF1E1C30),

    // Other
    shadow:           Color(0xFF000000),
    scrim:            Color(0xFF000000),
    inverseSurface:   Color(0xFFEDE9FF),
    onInverseSurface: Color(0xFF07070D),
    inversePrimary:   Color(0xFF6D28D9),
  );

  static ColorScheme _lightScheme() => ColorScheme.fromSeed(
    seedColor: AppTokens.primarySeed,
    brightness: Brightness.light,
    surface: const Color(0xFFFFFFFF),
    surfaceContainerLowest: const Color(0xFFF9F8FF),
    surfaceContainerLow:    const Color(0xFFF2F1FA),
    surfaceContainer:       const Color(0xFFECEBF4),
    surfaceContainerHigh:   const Color(0xFFE6E4EE),
    surfaceContainerHighest:const Color(0xFFE0DEEA),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Build dark theme
  // ─────────────────────────────────────────────────────────────────────────

  static ThemeData _buildDark(ColorScheme cs) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surfaceContainerLowest,

      // ── System UI ────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surfaceContainerLowest,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: cs.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: cs.onSurfaceVariant, size: 22),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
          statusBarIconBrightness: Brightness.light,
        ),
        shape: Border(
          bottom: BorderSide(
            color: const Color(0xFF1E1C30),
            width: 0.5,
          ),
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(
            color: Color(0xFF1E1C30),
            width: 0.6,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Input fields ──────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: Color(0xFF2A2740), width: 0.8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: const BorderSide(color: Color(0xFF2A2740), width: 0.8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: cs.primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: cs.error, width: 0.8),
        ),
        labelStyle: const TextStyle(color: Color(0xFF9D98B8), fontSize: 14),
        hintStyle: const TextStyle(color: Color(0x509D98B8), fontSize: 14),
        prefixIconColor: const Color(0xFF9D98B8),
        suffixIconColor: const Color(0xFF9D98B8),
      ),

      // ── Elevated button ───────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ),
      ),

      // ── Filled button ─────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ),
      ),

      // ── Outlined button ───────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: Color(0xFF3A3652), width: 0.8),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.1),
        ),
      ),

      // ── Tabs ──────────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: const Color(0xFF1E1C30),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1B1930),
        selectedColor: cs.primaryContainer,
        side: const BorderSide(color: Color(0xFF2A2740), width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // ── Bottom sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF12101E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: Color(0xFF3A3652),
        dragHandleSize: Size(40, 4),
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF12101E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: const BorderSide(color: Color(0xFF2A2740), width: 0.8),
        ),
        titleTextStyle: const TextStyle(
            color: Color(0xFFEDE9FF), fontSize: 17, fontWeight: FontWeight.w700),
        contentTextStyle: const TextStyle(
            color: Color(0xFF9D98B8), fontSize: 14, height: 1.5),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1E1C30),
        thickness: 0.6,
        space: 0,
      ),

      // ── Snackbar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1B31),
        contentTextStyle: const TextStyle(color: Color(0xFFEDE9FF), fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          side: const BorderSide(color: Color(0xFF2A2740), width: 0.8),
        ),
      ),

      // ── FAB ───────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      // ── Progress ─────────────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        circularTrackColor: const Color(0xFF1E1B31),
      ),

      // ── PopupMenu ────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF161427),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: const BorderSide(color: Color(0xFF2A2740), width: 0.6),
        ),
        textStyle: const TextStyle(color: Color(0xFFEDE9FF), fontSize: 14),
      ),

      // ── ListTile ─────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: Color(0xFF9D98B8),
        titleTextStyle: TextStyle(color: Color(0xFFEDE9FF), fontSize: 14, fontWeight: FontWeight.w500),
        subtitleTextStyle: TextStyle(color: Color(0xFF9D98B8), fontSize: 12),
      ),

      textTheme: _darkTextTheme(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build light theme
  // ─────────────────────────────────────────────────────────────────────────

  static ThemeData _buildLight(ColorScheme cs) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.surfaceContainerLowest,

      appBarTheme: AppBarTheme(
        backgroundColor: cs.surfaceContainerLowest,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.3),
        iconTheme: IconThemeData(color: cs.onSurface, size: 22),
        shape: Border(
          bottom: BorderSide(color: cs.outlineVariant.withOpacity(0.5), width: 0.5)),
      ),

      cardTheme: CardThemeData(
        color: cs.surface, elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.8), width: 0.8)),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: cs.outlineVariant, width: 1)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: cs.outlineVariant, width: 1)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: cs.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: cs.error, width: 1)),
        labelStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
        hintStyle: TextStyle(color: cs.onSurfaceVariant.withOpacity(0.6), fontSize: 14),
        prefixIconColor: cs.onSurfaceVariant,
        suffixIconColor: cs.onSurfaceVariant,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
          elevation: 0, shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          side: BorderSide(color: cs.outline, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusMd)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHigh,
        selectedColor: cs.primaryContainer,
        side: BorderSide(color: cs.outlineVariant, width: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary, unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary, indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: cs.outlineVariant.withOpacity(0.5),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface, surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        dragHandleColor: cs.outlineVariant,
        dragHandleSize: const Size(40, 4),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.5), width: 0.8)),
        titleTextStyle: TextStyle(
            color: cs.onSurface, fontSize: 17, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(
            color: cs.onSurfaceVariant, fontSize: 14, height: 1.5),
      ),

      dividerTheme: DividerThemeData(
        color: cs.outlineVariant.withOpacity(0.6), thickness: 0.8, space: 0),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A1924),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary, circularTrackColor: cs.surfaceContainerHigh),

      popupMenuTheme: PopupMenuThemeData(
        color: cs.surface, surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          side: BorderSide(color: cs.outlineVariant.withOpacity(0.5), width: 0.6)),
        textStyle: TextStyle(color: cs.onSurface, fontSize: 14),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: cs.onSurfaceVariant,
        titleTextStyle: TextStyle(color: cs.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
        subtitleTextStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
      ),

      textTheme: _lightTextTheme(cs),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Text themes
  // ─────────────────────────────────────────────────────────────────────────

  static TextTheme _darkTextTheme() {
    const primary   = Color(0xFFEDE9FF);
    const secondary = Color(0xFF9D98B8);
    return TextTheme(
      displayLarge:  TextStyle(fontSize: 56, fontWeight: FontWeight.w700, color: primary, letterSpacing: -1.5),
      displayMedium: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: primary, letterSpacing: -1.0),
      displaySmall:  TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5),
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.5),
      headlineMedium:TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: primary, letterSpacing: -0.3),
      headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.2),
      titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary, letterSpacing: -0.2),
      titleMedium:   TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primary),
      titleSmall:    TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary),
      bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: primary, height: 1.6),
      bodyMedium:    TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: primary, height: 1.5),
      bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: secondary, height: 1.4),
      labelLarge:    TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary, letterSpacing: 0.1),
      labelMedium:   TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: secondary, letterSpacing: 0.2),
      labelSmall:    TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: secondary, letterSpacing: 0.3),
    );
  }

  static TextTheme _lightTextTheme(ColorScheme cs) => TextTheme(
    displayLarge:  TextStyle(fontSize: 56, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -1.5),
    displayMedium: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -1.0),
    displaySmall:  TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.5),
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.5),
    headlineMedium:TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: -0.3),
    headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: cs.onSurface, letterSpacing: -0.2),
    titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface, letterSpacing: -0.2),
    titleMedium:   TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: cs.onSurface),
    titleSmall:    TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface),
    bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: cs.onSurface, height: 1.6),
    bodyMedium:    TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: cs.onSurface, height: 1.5),
    bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: cs.onSurfaceVariant, height: 1.4),
    labelLarge:    TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface, letterSpacing: 0.1),
    labelMedium:   TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant, letterSpacing: 0.2),
    labelSmall:    TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant, letterSpacing: 0.3),
  );
}
