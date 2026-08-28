import 'package:flutter/material.dart';

class AuthBrandHero extends StatelessWidget {
  final double width;

  const AuthBrandHero({
    super.key,
    this.width = 430,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/branding/bite_the_way_logo_master.png',
        width: width,
        fit: BoxFit.contain,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
