import 'package:flutter/material.dart';

/// Guardian Go design tokens. Moved here from main_menu_screen.dart so every
/// screen can import the same palette.
class GuardianColors {
  static const bg = Color(0xFF0A0E27);
  static const bgCard = Color(0xFF141A38);
  static const bgCardAlt = Color(0xFF1B2247);
  static const accentBlue = Color(0xFF4C6FFF);
  static const accentPurple = Color(0xFF8B5CF6);
  static const safeGreen = Color(0xFF16C784);
  static const dangerRed = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const textPrimary = Color(0xFFF5F6FA);
  static const textSecondary = Color(0xFF9AA3C7);
  static const border = Color(0x1AFFFFFF); // white @ 10%

  static const LinearGradient brandGradient = LinearGradient(
    colors: [accentBlue, accentPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safeZoneGradient = LinearGradient(
    colors: [Color(0xFF0E8F5E), Color(0xFF16C784)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class GuardianTheme {
  static OutlineInputBorder _border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: GuardianColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: GuardianColors.accentBlue,
        secondary: GuardianColors.accentPurple,
        surface: GuardianColors.bgCard,
        error: GuardianColors.dangerRed,
        onSurface: GuardianColors.textPrimary,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: GuardianColors.textPrimary,
        displayColor: GuardianColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: GuardianColors.textPrimary),
        titleTextStyle: TextStyle(
          color: GuardianColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GuardianColors.bgCard,
        labelStyle: const TextStyle(color: GuardianColors.textSecondary),
        hintStyle: const TextStyle(color: GuardianColors.textSecondary),
        prefixIconColor: GuardianColors.textSecondary,
        suffixIconColor: GuardianColors.textSecondary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(GuardianColors.border),
        enabledBorder: _border(GuardianColors.border),
        focusedBorder: _border(GuardianColors.accentBlue, 1.6),
        errorBorder: _border(GuardianColors.dangerRed),
        focusedErrorBorder: _border(GuardianColors.dangerRed, 1.6),
        errorStyle: const TextStyle(color: GuardianColors.dangerRed),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: GuardianColors.bgCardAlt,
        contentTextStyle: const TextStyle(color: GuardianColors.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: GuardianColors.accentBlue,
        linearTrackColor: GuardianColors.bgCardAlt,
      ),
      dividerColor: GuardianColors.border,
    );
  }
}