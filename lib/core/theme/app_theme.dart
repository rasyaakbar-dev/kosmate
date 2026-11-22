import 'package:flutter/material.dart';

class AppTheme {
  // Brand & Accent Colors
  static const Color primaryColor = Color(0xFF0B1F3A);
  static const Color accentColor = Color(0xFF4A6FA5);
  static const Color primaryLight = Color(0xFFEBF3FA);
  static const Color iconBadgeBackground = Color(0xFFEFF6FF);

  // Background & Surface
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFF1F5F9);

  // Text Colors
  static const Color foregroundColor = Color(0xFF000000);
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textSubtle = Color(0xFF94A3B8);

  // Border & Divider Colors
  static const Color borderColor = Color(0xFF739BD0);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderMedium = Color(0xFFCBD5E1);

  // Status & Feedback Colors
  static const Color destructiveColor = Color(0xFFDC2626);
  static const Color destructiveLight = Color(0xFFFEE2E2);
  static const Color successColor = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFE6F4EA);
  static const Color warningColor = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFEF9E7);

  // Typography Styles
  static const TextStyle headingLarge = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w700,
    fontSize: 24,
    color: textDark,
  );

  static const TextStyle headingMedium = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w600,
    fontSize: 18,
    color: textDark,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    color: textDark,
  );

  static const TextStyle bodyMuted = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w400,
    fontSize: 13,
    color: textMuted,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 13,
    color: textMuted,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryColor,
        onPrimary: backgroundColor,
        secondary: accentColor,
        onSecondary: backgroundColor,
        tertiary: accentColor,
        onTertiary: backgroundColor,
        error: destructiveColor,
        onError: backgroundColor,
        surface: backgroundColor,
        onSurface: textDark,
        outline: borderLight,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: const TextTheme(
        headlineLarge: headingLarge,
        headlineMedium: headingLarge,
        titleLarge: headingMedium,
        titleMedium: headingMedium,
        bodyLarge: bodyMedium,
        bodyMedium: bodyMedium,
        bodySmall: bodyMuted,
        labelLarge: labelMedium,
        labelMedium: labelMedium,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: headingMedium,
      ),
      cardTheme: CardThemeData(
        color: backgroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: backgroundColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: backgroundColor,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: borderMedium),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          color: textMuted,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          color: textSubtle,
        ),
      ),
    );
  }
}
