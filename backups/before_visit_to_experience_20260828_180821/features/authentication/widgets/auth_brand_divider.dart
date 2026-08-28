import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/colors.dart';

class AuthBrandDivider extends StatelessWidget {
  const AuthBrandDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 260,
        height: 30,
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 0.7,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0x002A3340),
                      Color(0xFF2A3340),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            const SizedBox(
              width: 25,
              height: 25,
              child: CustomPaint(
                painter: _BiteRosettePainter(),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Container(
                height: 0.7,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFF2A3340),
                      Color(0x002A3340),
                    ],
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

class _BiteRosettePainter extends CustomPainter {
  const _BiteRosettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final gold = Paint()
      ..color = AppColors.champagne
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = AppColors.champagne.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    // Five-petal fine-dining rosette.
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate((math.pi * 2 / 5) * i);

      final petal = Rect.fromCenter(
        center: const Offset(0, -6.0),
        width: 7.2,
        height: 12.5,
      );

      canvas.drawOval(petal, fill);
      canvas.drawOval(petal, gold);
      canvas.restore();
    }

    // Tiny central point.
    canvas.drawCircle(
      center,
      1.7,
      Paint()
        ..color = AppColors.champagne
        ..style = PaintingStyle.fill,
    );

    // "Bite": two small cut-outs from upper-right edge.
    final cut = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.80, size.height * 0.27),
      2.6,
      cut,
    );

    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.40),
      2.1,
      cut,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
