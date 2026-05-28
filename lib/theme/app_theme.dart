// app_theme.dart
// Defines the dark, security-focused color palette and text styles
// used consistently across all CryptWhisper screens.

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Color palette ──────────────────────────────────────────────────
  static const Color primary       = Color(0xFF00E5FF); // bright cyan
  static const Color primaryDark   = Color(0xFF00838F);
  static const Color background    = Color(0xFF080D1A); // near-black navy
  static const Color surface       = Color(0xFF111827); // dark card bg
  static const Color surfaceLight  = Color(0xFF1C2A3A); // slightly lighter
  static const Color success       = Color(0xFF00E676); // green
  static const Color error         = Color(0xFFFF1744); // red
  static const Color warning       = Color(0xFFFFAB00); // amber
  static const Color textPrimary   = Color(0xFFE8EAF6);
  static const Color textSecondary = Color(0xFF78909C);
  static const Color divider       = Color(0xFF1E2D42);

  // ── Theme ──────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary:   primary,
        secondary: primaryDark,
        surface:   surface,
        error:     error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: primary, fontSize: 18, fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
        iconTheme: IconThemeData(color: primary),
      ),
      cardTheme: const CardThemeData(
        color: surfaceLight,
        elevation: 3,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle:  const TextStyle(color: textSecondary),
        prefixIconColor: primary,
        suffixIconColor: textSecondary,
      ),
      dividerColor: divider,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
