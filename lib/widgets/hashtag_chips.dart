import 'package:flutter/material.dart';
import '../theme/colors.dart';

class HashtagChips extends StatelessWidget {
  final Iterable<String> hashtags;
  final ValueChanged<String>? onSelected;

  const HashtagChips({super.key, required this.hashtags, this.onSelected});

  @override
  Widget build(BuildContext context) => Wrap(
        textDirection: TextDirection.rtl,
        spacing: 8,
        runSpacing: 6,
        children: hashtags.toSet().map((tag) {
          final label = Text('#$tag', textDirection: TextDirection.rtl);
          return onSelected == null
              ? Chip(
                  label: label,
                  labelStyle: const TextStyle(color: AppColors.champagne))
              : ActionChip(
                  label: label,
                  tooltip: 'חיפוש מקומות עם #$tag',
                  labelStyle: const TextStyle(color: AppColors.champagne),
                  onPressed: () => onSelected!(tag),
                );
        }).toList(),
      );
}
