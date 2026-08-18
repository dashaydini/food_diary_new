import 'package:flutter/material.dart';

import 'colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,

      brightness: Brightness.dark,

      scaffoldBackgroundColor: AppColors.background,

      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.black,
        secondary: AppColors.secondary,
        onSecondary: Colors.black,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.error,
        onError: Colors.white,
      ),

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.champagne,
        titleTextStyle: TextStyle(
          color: AppColors.champagne,
          fontSize: 21,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
        ),
        iconTheme: IconThemeData(
          color: AppColors.primaryLight,
        ),
      ),

      // ==========================================================
      // CARDS
      // ==========================================================

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(
            color: AppColors.border,
            width: 0.7,
          ),
        ),
      ),

      // ==========================================================
      // INPUTS
      // ==========================================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        labelStyle: const TextStyle(
          color: AppColors.champagneSoft,
        ),
        hintStyle: const TextStyle(
          color: AppColors.muted,
        ),
        prefixIconColor: AppColors.primaryLight,
        suffixIconColor: AppColors.primaryLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.border,
            width: 0.8,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.border,
            width: 0.8,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: AppColors.primaryLight,
            width: 1.1,
          ),
        ),
      ),

      // ==========================================================
      // BUTTONS
      // ==========================================================

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          backgroundColor: AppColors.surfaceTop,
          foregroundColor: AppColors.champagne,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(
              color: AppColors.border,
              width: 0.8,
            ),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.champagne,
          side: const BorderSide(
            color: AppColors.border,
            width: 0.8,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      // ==========================================================
      // FLOATING ACTION BUTTON
      // ==========================================================

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.surfaceTop,
        foregroundColor: AppColors.champagne,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(14),
          ),
          side: BorderSide(
            color: AppColors.border,
            width: 0.8,
          ),
        ),
      ),

      // ==========================================================
      // CHIPS
      // ==========================================================

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSoft,
        selectedColor: AppColors.primaryDark,
        disabledColor: AppColors.surface,
        secondarySelectedColor: AppColors.primaryDark,
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        labelStyle: const TextStyle(
          color: AppColors.champagneSoft,
          fontSize: 13,
        ),
        side: const BorderSide(
          color: AppColors.border,
          width: 0.6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
        ),
      ),

      // ==========================================================
      // DIVIDERS
      // ==========================================================

      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.6,
        space: 1,
      ),

      // ==========================================================
      // ICONS
      // ==========================================================

      iconTheme: const IconThemeData(
        color: AppColors.primaryLight,
      ),

      // ==========================================================
      // PROGRESS
      // ==========================================================

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primaryLight,
      ),

      // ==========================================================
      // DIALOGS
      // ==========================================================

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(
            color: AppColors.border,
            width: 0.8,
          ),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.champagne,
          fontSize: 20,
          fontWeight: FontWeight.w400,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.text,
          fontSize: 15,
        ),
      ),

      // ==========================================================
      // BOTTOM SHEETS
      // ==========================================================

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.primaryDark,
      ),

      // ==========================================================
      // SNACKBARS
      // ==========================================================

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceTop,
        contentTextStyle: const TextStyle(
          color: AppColors.champagne,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(
            color: AppColors.border,
            width: 0.6,
          ),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ==========================================================
      // SWITCH
      // ==========================================================

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.champagne;
            }

            return AppColors.muted;
          },
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryDark;
            }

            return AppColors.surfaceSoft;
          },
        ),
      ),
    );
  }
}
