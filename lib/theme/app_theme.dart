import 'package:flutter/material.dart';

/// Central font family used across the app.
///
/// On Windows we prefer "Microsoft YaHei" because it has full CJK + Latin
/// coverage with consistent weight rendering — this is the primary fix for
/// Chinese/English weight mismatch.  If you bundle a custom font (see
/// pubspec.yaml comment), switch this to that family name.
const _fontFamily = 'Microsoft YaHei';

/// Fallback chain for characters not covered by the primary family.
const _fontFamilyFallback = ['Segoe UI', 'Arial'];

class AppTheme {
  static ThemeData light(Color accentColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData dark(Color accentColor) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
    );

    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    // ── Base text style inherited by everything ──────────────
    final base = TextStyle(
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      color: colorScheme.onSurface,
      // Leading is 1.4 × fontSize so CJK lines don't collide.
      height: 1.4,
    );

    // ── Typography scale ─────────────────────────────────────
    // Every TextStyle used in the app should reference one of these.
    // Widgets must NOT define inline font sizes / families.
    final textTheme = TextTheme(
      // App title: "WeNote" in sidebar header
      headlineMedium: base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      // Session name in chat header
      headlineSmall: base.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      // Session name in the list
      titleLarge: base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      // Dialog titles, section headers
      titleMedium: base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      // Message content
      bodyLarge: base.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.normal,
      ),
      // Session preview / subtitle text
      bodyMedium: base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.normal,
      ),
      // Timestamps, hint text, captions
      bodySmall: base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.normal,
      ),
      // Settings section labels
      labelMedium: base.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      // File-size text, small labels
      labelSmall: base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.normal,
      ),
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      textTheme: textTheme,
      scaffoldBackgroundColor: isDark ? colorScheme.surface : Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      dividerTheme: DividerThemeData(
        space: 0,
        thickness: 0.5,
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
      ),
    );
  }
}
