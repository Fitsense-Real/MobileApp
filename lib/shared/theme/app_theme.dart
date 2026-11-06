import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_radius.dart';

class AppTheme {
  AppTheme._();

  // ============================================================
  // MODO CLARO
  // ============================================================

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.black,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      outline: AppColors.lightBorder,
      error: AppColors.error,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      background: AppColors.lightBackground,
      surface: AppColors.lightSurface,
      text: AppColors.lightText,
      secondaryText: AppColors.lightTextSecondary,
      border: AppColors.lightBorder,
      isDark: false,
    );
  }

  // ============================================================
  // MODO OSCURO
  // ============================================================

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.black,
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkText,
      outline: AppColors.darkBorder,
      error: AppColors.error,
    );

    return _buildTheme(
      colorScheme: colorScheme,
      background: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      text: AppColors.darkText,
      secondaryText: AppColors.darkTextSecondary,
      border: AppColors.darkBorder,
      isDark: true,
    );
  }

  // ============================================================
  // CONSTRUCTOR BASE
  // ============================================================

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color background,
    required Color surface,
    required Color text,
    required Color secondaryText,
    required Color border,
    required bool isDark,
  }) {
    final radius = BorderRadius.circular(AppRadius.lg);

    return ThemeData(
      useMaterial3: true,

      brightness: isDark
          ? Brightness.dark
          : Brightness.light,

      colorScheme: colorScheme,

      scaffoldBackgroundColor: background,

      fontFamily: 'Poppins',

      splashFactory: NoSplash.splashFactory,

      // ========================================================
      // APP BAR
      // ========================================================

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: background,
        foregroundColor: text,
      ),

      // ========================================================
      // CARDS
      // ========================================================

      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
        ),
      ),

      // ========================================================
      // INPUTS
      // ========================================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,

        fillColor: isDark
            ? AppColors.darkSurfaceElevated
            : Colors.white,

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),

        hintStyle: TextStyle(
          color: secondaryText,
          fontSize: 14,
        ),

        labelStyle: TextStyle(
          color: secondaryText,
        ),

        prefixIconColor: secondaryText,

        suffixIconColor: secondaryText,

        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: border,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: border,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(
            color: AppColors.error,
          ),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.5,
          ),
        ),
      ),

      // ========================================================
      // BOTONES PRINCIPALES
      // ========================================================

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(
            double.infinity,
            56,
          ),

          backgroundColor: AppColors.primary,

          foregroundColor: Colors.black,

          elevation: 0,

          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: radius,
          ),
        ),
      ),

      // ========================================================
      // BOTONES OUTLINED
      // ========================================================

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,

          side: BorderSide(
            color: border,
          ),

          minimumSize: const Size(
            double.infinity,
            54,
          ),

          shape: RoundedRectangleBorder(
            borderRadius: radius,
          ),
        ),
      ),

      // ========================================================
      // TEXT BUTTON
      // ========================================================

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryDark,
        ),
      ),

      // ========================================================
      // DIVISORES
      // ========================================================

      dividerTheme: DividerThemeData(
        color: border,
        thickness: .8,
      ),

      // ========================================================
      // SNACKBAR
      // ========================================================

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,

        backgroundColor: isDark
            ? AppColors.darkSurfaceElevated
            : AppColors.lightText,

        contentTextStyle: TextStyle(
          color: isDark
              ? AppColors.darkText
              : Colors.white,
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppRadius.md,
          ),
        ),
      ),

      // ========================================================
      // TIPOGRAFÍA
      // ========================================================

      textTheme: const TextTheme().copyWith(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: text,
        ),

        headlineMedium: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          color: text,
        ),

        headlineSmall: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          color: text,
        ),

        titleLarge: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: text,
        ),

        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: text,
        ),

        bodyLarge: TextStyle(
          fontSize: 15,
          color: text,
          height: 1.45,
        ),

        bodyMedium: TextStyle(
          fontSize: 13,
          color: text,
          height: 1.45,
        ),

        bodySmall: TextStyle(
          fontSize: 11.5,
          color: secondaryText,
          height: 1.4,
        ),
      ),
    );
  }
}
