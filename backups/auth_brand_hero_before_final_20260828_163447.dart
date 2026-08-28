import 'package:flutter/material.dart';

class AuthBrandHero extends StatelessWidget {
  final double width;
  final double height;

  const AuthBrandHero({
    super.key,
    this.width = 390,
    this.height = 205,
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
              center: Alignment.center,
              radius: 1.08,
              colors: [
                Colors.white,
                Colors.white,
                Color(0xF2FFFFFF),
                Color(0xBFFFFFFF),
                Color(0x66FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [
                0.00,
                0.48,
                0.62,
                0.76,
                0.90,
                1.00,
              ],
            ).createShader(bounds);
          },
          child: Image.asset(
            'assets/branding/bite_the_way_logo.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) {
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}
