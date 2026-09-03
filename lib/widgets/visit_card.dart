import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/add_visit_screen.dart';
import '../screens/public_profile_screen.dart';
import '../theme/colors.dart';
import '../utils/experience_hashtags.dart';
import '../screens/hashtag_search_screen.dart';
import 'hashtag_chips.dart';

class VisitCard extends StatelessWidget {
  final Map<String, dynamic> visit;
  final Map<String, dynamic> place;
  final VoidCallback? onChanged;

  const VisitCard({
    super.key,
    required this.visit,
    required this.place,
    this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddVisitScreen(
          place: place,
          visit: visit,
          viewOnly: true,
        ),
      ),
    );

    if (changed == true) {
      onChanged?.call();
    }
  }

  Future<void> _openProfile(
    BuildContext context,
    String userId,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = visit['rating'];

    final profile = visit['profiles'] as Map<String, dynamic>?;
    final displayName = profile?['display_name'] as String?;
    final email = profile?['email'] as String?;
    final avatarUrl = profile?['avatar_url']?.toString();

    final ownerId = visit['user_id']?.toString();

    final author = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : (email?.trim().isNotEmpty ?? false)
            ? email!.trim().split('@').first
            : 'משתמש';

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final visitDate = DateTime.tryParse(
      visit['visit_date']?.toString() ?? '',
    );

    final dateText = visitDate != null
        ? '${visitDate.day.toString().padLeft(2, '0')}.'
            '${visitDate.month.toString().padLeft(2, '0')}.'
            '${visitDate.year}'
        : '';

    final isOwnVisit =
        ownerId != null && currentUserId != null && ownerId == currentUserId;

    final visitTitle = isOwnVisit ? 'החוויה שלך' : 'חוויה של $author';
    final hashtags = ExperienceHashtags.extract(visit['notes'] as String?);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.05),
            blurRadius: 32,
            spreadRadius: -5,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.022),
            blurRadius: 52,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(17),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.16),
                width: 0.75,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: ownerId == null
                              ? null
                              : () => _openProfile(
                                    context,
                                    ownerId,
                                  ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            textDirection: TextDirection.rtl,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.champagne
                                      .withValues(alpha: 0.028),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.champagne
                                        .withValues(alpha: 0.16),
                                    width: 0.7,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: avatarUrl != null &&
                                        avatarUrl.trim().isNotEmpty
                                    ? Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                          Icons.person_outline_rounded,
                                          size: 19,
                                          color: AppColors.champagne,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person_outline_rounded,
                                        size: 19,
                                        color: AppColors.champagne,
                                      ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                visitTitle,
                                textAlign: TextAlign.right,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (dateText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  dateText,
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (rating != null) ...[
                          const SizedBox(width: 14),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 17,
                                color: AppColors.champagne,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (rating as num).toStringAsFixed(1),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    if (hashtags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      HashtagChips(
                        hashtags: hashtags,
                        onSelected: (tag) =>
                            HashtagSearchScreen.open(context, tag),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
