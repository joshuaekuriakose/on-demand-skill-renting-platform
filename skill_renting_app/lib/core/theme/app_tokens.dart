import 'package:flutter/material.dart';

class AppTokens {
  // ── Radii ────────────────────────────────────────────────────────────────
  static const double radiusSm   =  8.0;
  static const double radiusMd   = 12.0;
  static const double radiusLg   = 16.0;
  static const double radiusXl   = 24.0;
  static const double radiusFull = 999.0;

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double sp4  =  4.0;
  static const double sp8  =  8.0;
  static const double sp12 = 12.0;
  static const double sp16 = 16.0;
  static const double sp20 = 20.0;
  static const double sp24 = 24.0;
  static const double sp32 = 32.0;

  // Legacy aliases
  static const double radius12 = radiusMd;
  static const double radius16 = radiusLg;
  static const double radius20 = radiusXl;
  static const double space4   = sp4;
  static const double space8   = sp8;
  static const double space12  = sp12;
  static const double space16  = sp16;
  static const double space20  = sp20;
  static const double space24  = sp24;
  static const int    elevation2 = 2;
  static const int    elevation4 = 4;

  // ── Brand ────────────────────────────────────────────────────────────────
  static const Color primarySeed   = Color(0xFF7C3AED); // Violet-600
  static const Color secondarySeed = Color(0xFF0D9488); // Teal-600

  // ── Dark editorial palette ────────────────────────────────────────────────
  // Surfaces — near-black with subtle violet undertone
  static const Color darkBase      = Color(0xFF07070D); // deepest
  static const Color darkSurface   = Color(0xFF0F0E17); // cards
  static const Color darkElevated  = Color(0xFF161427); // elevated cards
  static const Color darkHighest   = Color(0xFF1E1B31); // inputs, chips

  // Accent violet
  static const Color violet400 = Color(0xFFA78BFA);
  static const Color violet500 = Color(0xFF8B5CF6);
  static const Color violet600 = Color(0xFF7C3AED);
  static const Color violetGlow = Color(0x338B5CF6); // 20% violet

  // Accent teal
  static const Color teal400 = Color(0xFF2DD4BF);
  static const Color teal500 = Color(0xFF14B8A6);

  // Text
  static const Color textPrimary   = Color(0xFFEDE9FF); // slightly violet-tinted white
  static const Color textSecondary = Color(0x80EDE9FF); // 50%
  static const Color textTertiary  = Color(0x40EDE9FF); // 25%

  // ── Status colours ────────────────────────────────────────────────────────
  static const Color statusPending    = Color(0xFFF59E0B);
  static const Color statusAccepted   = Color(0xFF60A5FA);
  static const Color statusInProgress = Color(0xFFA78BFA);
  static const Color statusCompleted  = Color(0xFF34D399);
  static const Color statusRejected   = Color(0xFFF87171);
  static const Color statusCancelled  = Color(0xFF9CA3AF);

  // ── Card decoration ───────────────────────────────────────────────────────
  static BoxDecoration cardDecoration(BuildContext ctx, {
    Color? color,
    double radius = radiusMd,
    bool elevated = true,
    Color? borderColor,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return BoxDecoration(
      color: color ?? cs.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? (isDark
            ? const Color(0x10FFFFFF)  // rgba(255,255,255,0.06)
            : cs.outlineVariant.withOpacity(0.8)),
        width: isDark ? 0.6 : 0.8,
      ),
    );
  }

  // ── Glow border (accent cards in dark mode) ───────────────────────────────
  static BoxDecoration glowCard(BuildContext ctx, Color accentColor, {
    double radius = radiusMd,
  }) {
    final cs = Theme.of(ctx).colorScheme;
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Color.alphaBlend(accentColor.withOpacity(0.07), const Color(0xFF0F0E17))
          : cs.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accentColor.withOpacity(isDark ? 0.25 : 0.2),
        width: isDark ? 0.8 : 0.8,
      ),
    );
  }
}
