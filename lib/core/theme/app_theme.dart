import 'package:flutter/material.dart';

class AppTheme {
  // Color Palette
  static const Color primaryColor = Color(0xFF0B1F3A);
  static const Color accentColor = Color(0xFF4A6FA5);
  static const Color semanticColor = Color(0xFFF8E7A1);
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color foregroundColor = Color(0xFF000000);
  static const Color borderColor = Color(0xFF739BD0);

  // Backward compatibility alias
  static const Color cardColor = backgroundColor;
  static const Color textPrimary = foregroundColor;
  static const Color textSecondary = accentColor;

  // Typography (Roboto)
  static const TextStyle robotoBlack = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w700,
    fontSize: 32,
    color: foregroundColor,
  );

  static const TextStyle robotoBold = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 24,
    color: foregroundColor,
  );

  static const TextStyle robotoMedium = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w400,
    fontSize: 18,
    color: foregroundColor,
  );

  static const TextStyle robotoRegular = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w300,
    fontSize: 16,
    color: foregroundColor,
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
        tertiary: semanticColor,
        onTertiary: foregroundColor,
        error: Colors.redAccent,
        onError: backgroundColor,
        surface: backgroundColor,
        onSurface: foregroundColor,
        outline: borderColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      textTheme: const TextTheme(
        displayLarge: robotoBlack,
        displayMedium: robotoBlack,
        headlineLarge: robotoBlack,
        headlineMedium: robotoBold,
        headlineSmall: robotoBold,
        titleLarge: robotoBold,
        titleMedium: robotoMedium,
        titleSmall: robotoMedium,
        bodyLarge: robotoMedium,
        bodyMedium: robotoRegular,
        bodySmall: robotoRegular,
        labelLarge: robotoMedium,
        labelMedium: robotoRegular,
        labelSmall: robotoRegular,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: robotoMedium,
      ),
      cardTheme: CardThemeData(
        color: backgroundColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor),
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
          textStyle: robotoMedium.copyWith(color: backgroundColor),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: robotoRegular.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        labelStyle: robotoRegular.copyWith(color: foregroundColor.withValues(alpha: 0.7)),
        hintStyle: robotoRegular.copyWith(color: foregroundColor.withValues(alpha: 0.5)),
      ),
    );
  }
}
