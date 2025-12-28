// lib/themes/app_theme.dart

import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    final baseTextTheme = ThemeData(brightness: Brightness.dark).textTheme;
    // Use bundled BarlowCondensed (light) as the primary face.
    final barlowTextTheme = baseTextTheme
        .apply(
          fontFamily: 'BarlowCondensed',
          bodyColor: Colors.white,
          displayColor: Colors.white,
        )
        .copyWith(
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w300,
            letterSpacing: 0.2,
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.25,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: 0.35,
          ),
        );

    const primaryAccent = Color(0xFFFF2800); // matches website header/pill
    const secondaryAccent = Color(0xFF24B6FF); // matches website hover/glow

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      fontFamily: 'BarlowCondensed',
      fontFamilyFallback: const ['SF Pro Text', 'Roboto', 'sans-serif'],
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: secondaryAccent,
        background: Colors.black,
        surface: Color(0xFF111111),
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onBackground: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: barlowTextTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white10,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryAccent, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white24),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: secondaryAccent.withOpacity(0.3),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryAccent,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: secondaryAccent,
        linearTrackColor: Colors.white24,
      ),
      dividerColor: Colors.white12,
      cardColor: const Color(0xFF111111),
    );
  }
}
