import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// A five-star input that supports half-star increments.
class HalfStarRating extends StatelessWidget {
  const HalfStarRating({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 27,
    this.spacing = 2,
    this.keyPrefix,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double size;
  final double spacing;
  final String? keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'דירוג ${value.toStringAsFixed(1)} מתוך 5',
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < 5; index++) ...[
              if (index > 0) SizedBox(width: spacing),
              _star(index),
            ],
          ],
        ),
      ),
    );
  }

  Widget _star(int index) {
    final fullValue = index + 1.0;
    final halfValue = index + 0.5;
    final icon = value >= fullValue
        ? Icons.star_rounded
        : value >= halfValue
            ? Icons.star_half_rounded
            : Icons.star_border_rounded;

    return Tooltip(
      key: keyPrefix == null ? null : ValueKey('$keyPrefix-${index + 1}'),
      message: '${halfValue.toStringAsFixed(1)} או ${fullValue.toInt()} כוכבים',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: onChanged == null
            ? null
            : (details) {
                final selected =
                    details.localPosition.dx < size / 2 ? halfValue : fullValue;
                onChanged!(selected);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Icon(
            icon,
            size: size,
            color: value >= halfValue
                ? AppColors.champagne
                : AppColors.textMuted.withValues(alpha: 0.52),
          ),
        ),
      ),
    );
  }
}
