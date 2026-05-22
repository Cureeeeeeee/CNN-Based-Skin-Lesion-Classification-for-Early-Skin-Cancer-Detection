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

    return MaterialApp(
      title: 'Skin Lesion Classification',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
