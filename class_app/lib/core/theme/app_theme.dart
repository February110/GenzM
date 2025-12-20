import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get light {
    const seed = Color(0xFF2563EB);
    const buttonShape = StadiumBorder();
    final buttonShapeProperty =
        MaterialStateProperty.all<OutlinedBorder>(buttonShape);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      dividerColor: const Color(0xFFE5E7EB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: seed, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(shape: buttonShapeProperty),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(shape: buttonShapeProperty),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(shape: buttonShapeProperty),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: StadiumBorder(),
      ),
    );
  }

  static ThemeData get dark {
    const seed = Color(0xFF2563EB);
    const buttonShape = StadiumBorder();
    final buttonShapeProperty =
        MaterialStateProperty.all<OutlinedBorder>(buttonShape);
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      dividerColor: const Color(0xFF1F2937),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1F2937)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: seed, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seed,
          foregroundColor: Colors.white,
          shape: buttonShape,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(shape: buttonShapeProperty),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(shape: buttonShapeProperty),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(shape: buttonShapeProperty),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: StadiumBorder(),
      ),
    );
  }
}
