import 'package:flutter/material.dart';

class AuthBrandHero extends StatelessWidget {
  final double width;
  final double height;

  const AuthBrandHero({
    super.key,
    this.width = 275,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: width,
        height: height,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            return const RadialGradient(
              center: Alignment(0, -0.03),
              radius: 0.72,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0xFCFFFFFF),
                Color(0xF0FFFFFF),
                Color(0xD8FFFFFF),
                Color(0xA8FFFFFF),
                Color(0x70FFFFFF),
                Color(0x3AFFFFFF),
                Color(0x16FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [
                0.00,
                0.34,
                0.45,
                0.53,
                0.60,
                0.67,
                0.73,
                0.79,
                0.84,
                0.90,
              ],
            ).createShader(bounds);
          },
          child: Image.asset(
            'assets/branding/bite_the_way_logo_master.png',
            width: width,
            height: height,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
