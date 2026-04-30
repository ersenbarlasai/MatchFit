import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;
  
  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
class MatchFitTheme {
  static const Color primaryBlue = Color(0xFF0052FF);
  static const Color accentGreen = Color(0xFFCCFF00); // Neon Green
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF121212); // Deep Charcoal

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: accentGreen,
        surface: Colors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGreen, // Primary button is Neon Green
          foregroundColor: const Color(0xFF121212), // Black text
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // 24px radius
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: accentGreen, width: 2),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: accentGreen,
        surface: Color(0xFF1E2020),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentGreen, // Primary button is Neon Green
          foregroundColor: const Color(0xFF121212), // Black text
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // 24px radius
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1C1C), // 5% lighter than background
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: accentGreen, width: 2),
        ),
      ),
    );
  }
}
