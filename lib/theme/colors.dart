import 'package:flutter/material.dart';

/// צבעי המותג המרכזיים של Food Diary.
/// כל האפליקציה אמורה להשתמש בצבעים מכאן במקום בצבעים ישירים.
class AppColors {
  // ─────────────────────────────────────────────
  // BACKGROUNDS
  // ─────────────────────────────────────────────

  /// הרקע הראשי של האפליקציה.
  static const Color background = Color(0xFF0F1015);

  /// משטח פנימי / אזורים מעט מורמים מהרקע.
  static const Color surface = Color(0xFF14171F);

  /// רקע כרטיס.
  static const Color card = Color(0xFF14171F);

  /// alias לכרטיסים.
  static const Color cardBg = Color(0xFF14171F);

  /// רקע שדות קלט.
  static const Color inputBg = Color(0xFF14171F);

  // ─────────────────────────────────────────────
  // BORDERS / DIVIDERS
  // ─────────────────────────────────────────────

  /// מסגרת דקה של כרטיסים.
  static const Color cardBorder = Color(0xFF3A3C43);

  /// קווים מפרידים.
  static const Color line = Color(0xFF3A3C43);

  // ─────────────────────────────────────────────
  // TEXT
  // ─────────────────────────────────────────────

  /// טקסט ראשי — כמעט לבן.
  static const Color textPrimary = Color(0xFFF0F0F0);

  /// alias היסטורי.
  static const Color ink = Color(0xFFF0F0F0);

  /// לבן של המערכת.
  static const Color white = Color(0xFFF0F0F0);

  /// טקסט משני.
  static const Color textSecondary = Color(0xFFB8B8BC);

  /// טקסט חלש.
  static const Color textMuted = Color(0xFF777980);

  /// alias היסטורי.
  static const Color muted = Color(0xFF777980);

  // ─────────────────────────────────────────────
  // BRAND / CHAMPAGNE
  // ─────────────────────────────────────────────

  /// צבע המותג — שמפניה עדין.
  static const Color champagne = Color(0xFFE6D5B8);

  /// alias.
  static const Color gold = Color(0xFFE6D5B8);

  /// alias.
  static const Color brass = Color(0xFFE6D5B8);

  // ─────────────────────────────────────────────
  // FUNCTIONAL
  // ─────────────────────────────────────────────

  static const Color error = Color(0xFFD95C5C);

  static const Color success = Color(0xFF9FBF9A);

  static const Color warning = Color(0xFFD8B36A);
}
