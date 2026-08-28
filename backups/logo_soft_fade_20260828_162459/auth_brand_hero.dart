import 'package:flutter/material.dart';

import '../../../theme/colors.dart';

class AuthBrandHero extends StatelessWidget {
  final double width;
  final double height;

  const AuthBrandHero({
    super.key,
    this.width = 380,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;

    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: Image.asset(
                'assets/branding/bite_the_way_logo.jpg',
                fit: BoxFit.contain,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) {
                  return const Center(
                    child: Text(
                      'BITE THE WAY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 2.2,
                        color: AppColors.champagne,
                      ),
                    ),
                  );
                },
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.02,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      AppColors.background.withValues(alpha: 0.16),
                      AppColors.background.withValues(alpha: 0.45),
                      AppColors.background.withValues(alpha: 0.86),
                      AppColors.background,
                    ],
                    stops: [
                      0.0,
                      0.52,
                      0.68,
                      0.80,
                      0.92,
                      1.0,
                    ],
                  ),
                ),
              ),
            ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background.withValues(alpha: 0.10),
                      Colors.transparent,
                      Colors.transparent,
                      AppColors.background.withValues(alpha: 0.18),
                    ],
                    stops: const [0.0, 0.18, 0.72, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
