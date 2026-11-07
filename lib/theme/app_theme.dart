import 'package:flutter/material.dart';

/// Paleta azul y blanco de la aplicación.
class AppColors {
  static const Color blue900 = Color(0xFF0D47A1);
  static const Color blue700 = Color(0xFF1565C0);
  static const Color blue500 = Color(0xFF1E88E5);
  static const Color blue300 = Color(0xFF64B5F6);
  static const Color blue100 = Color(0xFFD6E6FA);
  static const Color blue50 = Color(0xFFF1F7FE);

  static const Color textDark = Color(0xFF0B2545);
  static const Color textMuted = Color(0xFF5B7691);

  // Solo para avisos: esfuerzo intenso y alertas.
  static const Color warning = Color(0xFFE08A00);
  static const Color danger = Color(0xFFD32F2F);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue700,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.blue700,
      onPrimary: Colors.white,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.blue50,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.blue700,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.textDark,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: AppColors.textDark),
      ),
    );
  }
}
