import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class AppTypography {
  static const display = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w400,
    height: 1.08,
    letterSpacing: -0.7,
    color: AppColors.ink,
  );

  static const headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w500,
    height: 1.15,
    letterSpacing: -0.3,
    color: AppColors.ink,
  );

  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.2,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.ink,
  );

  static const secondary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.muted,
  );

  static const overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 3.0,
    color: AppColors.brass,
  );

  static const caption = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 1.2,
    color: AppColors.muted,
  );

  static const button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );
}
