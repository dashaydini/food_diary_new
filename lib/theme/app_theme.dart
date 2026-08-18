import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';
import 'radii.dart';

abstract final class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.brass,
        onPrimary: AppColors.white,
        secondary: AppColors.champagne,
        onSecondary: AppColors.ink,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        outline: AppColors.line,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.ink),
        bodyMedium: TextStyle(color: AppColors.ink),
        bodySmall: TextStyle(color: AppColors.muted),
        titleLarge: TextStyle(color: AppColors.ink),
        titleMedium: TextStyle(color: AppColors.ink),
        titleSmall: TextStyle(color: AppColors.ink),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppTypography.title,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppRadii.medium),
          ),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppRadii.medium),
          ),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppRadii.medium),
          ),
          borderSide: BorderSide(
            color: AppColors.brass,
            width: 1,
          ),
        ),
        labelStyle: TextStyle(color: AppColors.muted),
        hintStyle: TextStyle(color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.champagne,
          foregroundColor: AppColors.background,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          textStyle: AppTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(
            color: AppColors.line,
            width: 0.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 0.7,
        space: 1,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.ink,
        size: 23,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.champagne,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.champagne,
        onPrimary: AppColors.background,
        secondary: AppColors.brass,
        onSecondary: AppColors.background,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        outline: AppColors.line,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.ink),
        bodyMedium: TextStyle(color: AppColors.ink),
        bodySmall: TextStyle(color: AppColors.muted),
        titleLarge: TextStyle(color: AppColors.ink),
        titleMedium: TextStyle(color: AppColors.ink),
        titleSmall: TextStyle(color: AppColors.ink),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AppTypography.title,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppRadii.medium),
          ),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppRadii.medium),
          ),
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(AppRadii.medium),
          ),
          borderSide: BorderSide(
            color: AppColors.brass,
            width: 1,
          ),
        ),
        labelStyle: TextStyle(color: AppColors.muted),
        hintStyle: TextStyle(color: AppColors.muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.champagne,
          foregroundColor: AppColors.background,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          textStyle: AppTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(
            color: AppColors.line,
            width: 0.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 0.7,
        space: 1,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.ink,
        size: 23,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.champagne,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.small),
        ),
      ),
    );
  }
}
