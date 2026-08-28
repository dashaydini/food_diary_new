import 'package:flutter/material.dart';

class AppBrandMark extends StatelessWidget {
  final double size;

  const AppBrandMark({
    super.key,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/branding/bite_the_way_logo_master.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}
