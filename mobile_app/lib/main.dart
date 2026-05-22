import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  runApp(const SkinLesionApp());
}

class SkinLesionApp extends StatelessWidget {
  const SkinLesionApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2563EB);
    const darkBlue = Color(0xFF1D4ED8);

    return MaterialApp(
      title: 'Skin Lesion Classification',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F7FC),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: darkBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: const Color(0x1A0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFEFF6FF),
          selectedColor: const Color(0xFFDBEAFE),
          labelStyle: const TextStyle(color: Color(0xFF1E3A8A)),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8E2F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD8E2F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryBlue, width: 1.4),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: primaryBlue,
            side: const BorderSide(color: Color(0xFF93C5FD)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
