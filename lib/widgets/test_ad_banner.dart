import 'package:flutter/material.dart';

import '../theme/colors.dart';

class TestAdBanner extends StatelessWidget {
  const TestAdBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'פרסומת בתצוגת בדיקה',
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: AppColors.champagne.withValues(alpha: 0.22),
            width: 0.8,
          ),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.champagne.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'פרסומת · תצוגת בדיקה',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.champagne,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'המקום הבא שלכם מתחיל כאן',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'באנר לדוגמה לבדיקת מיקום, גודל ונראות באפליקציה',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: AppColors.champagne.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.champagne.withValues(alpha: 0.18),
                ),
              ),
              child: const Icon(
                Icons.storefront_outlined,
                color: AppColors.champagne,
                size: 25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
