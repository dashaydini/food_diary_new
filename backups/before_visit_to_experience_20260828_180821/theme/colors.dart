import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Main background
  static const Color background = Color(0xFF0B0F15);

  // Layered surfaces
  static const Color surface = Color(0xFF10151D);
  static const Color surfaceRaised = Color(0xFF151B24);
  static const Color card = Color(0xFF121821);
  static const Color cardBg = Color(0xFF121821);
  static const Color inputBg = Color(0xFF171D27);

  // Borders / separators
  static const Color cardBorder = Color(0xFF2A3340);
  static const Color line = Color(0xFF28313D);
  static const Color lineSoft = Color(0xFF202833);

  // Luxury champagne
  static const Color champagne = Color(0xFFE3C995);
  static const Color gold = Color(0xFFE3C995);
  static const Color brass = Color(0xFFE3C995);
  static const Color champagneSoft = Color(0xFFCAB58D);

  // Text
  static const Color textPrimary = Color(0xFFF4F1EB);
  static const Color textSecondary = Color(0xFFB8BBC1);
  static const Color textMuted = Color(0xFF858C96);

  // Backwards-compatible aliases
  static const Color ink = textPrimary;
  static const Color white = textPrimary;
  static const Color muted = textMuted;

  // Functional
  static const Color danger = Color(0xFFD86C6C);
  static const Color error = danger;
  static const Color success = Color(0xFF86B796);

  // Image overlays
  static const Color overlayStrong = Color(0x99000000);
  static const Color overlayMedium = Color(0x73000000);
  static const Color overlaySoft = Color(0x52000000);
}
