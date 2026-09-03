import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'navigation_app_picker.dart';

class PlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback? onTap;
  final VoidCallback? onNavigate;
  final String actionLabel;
  final IconData actionIcon;
  final bool actionSelected;

  const PlaceCard({
    super.key,
    required this.place,
    this.onTap,
    this.onNavigate,
    this.actionLabel = 'ניווט',
    this.actionIcon = Icons.near_me_outlined,
    this.actionSelected = false,
  });

  static String? extractImageUrl(Map<String, dynamic> place) {
    final fields = [
      'imageUrl',
      'image_url',
      'image',
      'photo',
      'photoUrl',
      'photo_url'
    ];
    for (final field in fields) {
      if (place[field] != null && place[field].toString().isNotEmpty) {
        return place[field].toString();
      }
    }
    if (place['images'] is List && (place['images'] as List).isNotEmpty) {
      return place['images'][0].toString();
    }
    return null;
  }

  static Future<void> showNavigationOptions(
      BuildContext context, Map<String, dynamic> place) async {
    await NavigationAppPicker.show(context, place);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = place['name']?.toString() ?? place['title']?.toString() ?? '';

    final address = place['address']?.toString() ?? '';
    final description = place['description']?.toString() ?? '';
    final recommendationReason =
        place['recommendation_reason']?.toString().trim() ?? '';
    final hashtagReason =
        place['hashtag_recommendation_reason']?.toString() ?? '';
    final imageUrl = extractImageUrl(place);
    final matchedHashtags = (place['matched_hashtags'] as Iterable?)
            ?.whereType<String>()
            .toList() ??
        <String>[];

    final ratingValue = place['weighted_rating'] ?? place['rating'];
    final rating =
        ratingValue == null ? null : double.tryParse(ratingValue.toString());

    final ratingCount = place['rating_count'] ?? place['reviews_count'] ?? 0;
    final averagePriceLevel =
        (place['average_price_level'] as num?)?.toDouble();
    final priceRatingCount =
        (place['price_rating_count'] as num?)?.toInt() ?? 0;
    final distanceMeters = (place['distance_meters'] as num?)?.toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 620;

        final imageSize = mobile ? 90.0 : 104.0;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
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
              borderRadius: BorderRadius.circular(19),
              child: Ink(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: AppColors.champagne.withValues(alpha: 0.17),
                    width: 0.8,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(mobile ? 12 : 14),
                  child: Column(
                    children: [
                      Row(
                        textDirection: TextDirection.ltr,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color:
                                    AppColors.champagne.withValues(alpha: 0.16),
                                width: 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.champagne
                                      .withValues(alpha: 0.04),
                                  blurRadius: 20,
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: imageUrl != null && imageUrl.isNotEmpty
                                  ? Image.network(
                                      imageUrl,
                                      width: imageSize,
                                      height: imageSize,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _placeImageFallback(imageSize),
                                    )
                                  : _placeImageFallback(imageSize),
                            ),
                          ),
                          SizedBox(width: mobile ? 12 : 16),
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: mobile ? 17 : 19,
                                      height: 1.1,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (recommendationReason.isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(
                                      recommendationReason,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.champagneSoft,
                                        fontSize: mobile ? 10.5 : 11.5,
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                  if (matchedHashtags.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'מופיע בחוויה: ${matchedHashtags.map((tag) => '#$tag').join(' · ')}',
                                      textAlign: TextAlign.right,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.champagne,
                                      ),
                                    ),
                                  ],
                                  if (hashtagReason.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      hashtagReason,
                                      textAlign: TextAlign.right,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: AppColors.champagneSoft),
                                    ),
                                  ],
                                  if (address.isNotEmpty) ...[
                                    const SizedBox(height: 7),
                                    Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        const Icon(
                                          Icons.location_on_outlined,
                                          size: 15,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            address,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: AppColors.textSecondary,
                                              fontSize: mobile ? 11 : 12,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (description.isNotEmpty) ...[
                                    const SizedBox(height: 7),
                                    Text(
                                      description,
                                      maxLines: mobile ? 2 : 3,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.textMuted,
                                        fontSize: mobile ? 11 : 12,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 0.7,
                        color: AppColors.champagne.withValues(alpha: 0.10),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          InkWell(
                            onTap: onNavigate ??
                                () => showNavigationOptions(context, place),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    actionIcon,
                                    size: 17,
                                    color: actionSelected
                                        ? AppColors.success
                                        : AppColors.champagne,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    actionLabel,
                                    style: TextStyle(
                                      color: actionSelected
                                          ? AppColors.success
                                          : AppColors.champagne,
                                      fontSize: 13,
                                      fontWeight: actionSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (distanceMeters != null) ...[
                            const SizedBox(width: 14),
                            Row(
                              children: [
                                const Icon(
                                  Icons.near_me_outlined,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  distanceMeters < 1000
                                      ? '${distanceMeters.round()} מ׳ ממך'
                                      : '${(distanceMeters / 1000).toStringAsFixed(1)} ק״מ ממך',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const Spacer(),
                          if (averagePriceLevel != null) ...[
                            Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                Text(
                                  List.filled(
                                    averagePriceLevel.round().clamp(1, 4),
                                    '₪',
                                  ).join(),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.champagne,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '($priceRatingCount)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                          ],
                          if (rating != null)
                            Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: AppColors.champagne,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '($ratingCount)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeImageFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.champagne.withValues(alpha: 0.025),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.10),
          width: 0.7,
        ),
      ),
      child: const Icon(
        Icons.storefront_outlined,
        size: 30,
        color: AppColors.textMuted,
      ),
    );
  }
}
