import 'package:flutter/material.dart';

/// Central place for the app's Sci-Fi dark theme and the accent colors that
/// distinguish the three radar modes (green = BLE, blue = Wi-Fi, red = EMF).
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF05070A);
  static const Color surface = Color(0xFF0C1118);
  static const Color surfaceHigh = Color(0xFF141C26);

  // Mode accents
  static const Color bleGreen = Color(0xFF39FF7A);
  static const Color wifiBlue = Color(0xFF35B6FF);
  static const Color emfRed = Color(0xFFFF3B4E);

  static const Color textPrimary = Color(0xFFE6F1FF);
  static const Color textMuted = Color(0xFF7C8CA0);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        surface: AppColors.surface,
        primary: AppColors.bleGreen,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
        fontFamily: 'monospace',
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          letterSpacing: 3,
          fontWeight: FontWeight.w600,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
