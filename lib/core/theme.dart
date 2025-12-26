import 'package:flutter/material.dart';

class AppTheme {
  // Colors inspired by your UI screenshots
  static const Color background = Color(0xFFF4F5F7);
  static const Color card = Colors.white;
  static const Color textDark = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color border = Color(0xFFDADDE3);

  static const Color purple1 = Color(0xFF4F46E5);
  static const Color purple2 = Color(0xFF6D28D9);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      fontFamily: null, // set to "Inter" if you add the font
      colorScheme: ColorScheme.fromSeed(seedColor: purple1),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.4,
          color: textMuted,
        ),
      ),
    );
  }

  static LinearGradient primaryGradient = const LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [purple1, purple2],
  );

  static BoxDecoration cardDecoration({double radius = 26}) {
    return BoxDecoration(
      color: card,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 30,
          offset: const Offset(0, 18),
        ),
      ],
    );
  }
}
