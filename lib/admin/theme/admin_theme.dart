import 'package:flutter/material.dart';

/// Field-ops color palette for the admin dashboard.
/// Kept separate from the tourist-facing app's default theme since the
/// admin dashboard is a distinct, denser, operator-focused surface.
class AdminColors {
  static const chrome = Color(0xFF12181A);
  static const panel = Color(0xFF1B2422);
  static const panel2 = Color(0xFF212B29);
  static const hairline = Color(0xFF2E3936);

  static const brass = Color(0xFFC9A15A);
  static const brassDim = Color(0xFF7A6741);

  static const safe = Color(0xFF3E7D5A);
  static const safeBg = Color(0xFF1E2E26);

  static const caution = Color(0xFFD98A2B);
  static const cautionBg = Color(0xFF2E2519);

  static const danger = Color(0xFFC1443A);
  static const dangerBg = Color(0xFF2E1917);

  static const textPrimary = Color(0xFFEDE7D8);
  static const textMuted = Color(0xFF8B9490);

  static Color statusColor(String status) {
    switch (status) {
      case 'open':
        return danger;
      case 'acknowledged':
        return caution;
      case 'resolved':
        return safe;
      default:
        return textMuted;
    }
  }

  static Color statusBg(String status) {
    switch (status) {
      case 'open':
        return dangerBg;
      case 'acknowledged':
        return cautionBg;
      case 'resolved':
        return safeBg;
      default:
        return panel2;
    }
  }
}

final adminTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AdminColors.chrome,
  colorScheme: const ColorScheme.dark(
    primary: AdminColors.brass,
    surface: AdminColors.panel,
  ),
  cardColor: AdminColors.panel,
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: AdminColors.textPrimary),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AdminColors.panel,
    foregroundColor: AdminColors.textPrimary,
    elevation: 0,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AdminColors.panel,
    selectedItemColor: AdminColors.brass,
    unselectedItemColor: AdminColors.textMuted,
  ),
  dividerColor: AdminColors.hairline,
);
