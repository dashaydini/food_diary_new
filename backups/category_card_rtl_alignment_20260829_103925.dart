import 'package:flutter/material.dart';

import '../theme/colors.dart';

class CategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.055),
            blurRadius: 34,
            spreadRadius: -5,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.025),
            blurRadius: 58,
            spreadRadius: 1,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.18),
                width: 0.75,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 17,
                vertical: 13,
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.champagne.withValues(alpha: 0.025),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: AppColors.champagne.withValues(alpha: 0.17),
                        width: 0.75,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: AppColors.champagne,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Flexible(
                    fit: FlexFit.loose,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.ltr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 9,
                            height: 1.1,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.75,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
