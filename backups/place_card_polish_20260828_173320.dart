import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';

class PlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback? onTap;
  final VoidCallback? onNavigate;

  const PlaceCard({
    super.key,
    required this.place,
    this.onTap,
    this.onNavigate,
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
    final title =
        place['name']?.toString() ?? place['title']?.toString() ?? 'מיקום';
    final address = place['address']?.toString() ?? '';
    final lat = place['latitude'] != null
        ? double.tryParse(place['latitude'].toString())
        : null;
    final lng = place['longitude'] != null
        ? double.tryParse(place['longitude'].toString())
        : null;

    final query = (lat != null && lng != null)
        ? '$lat,$lng'
        : Uri.encodeComponent(address);
    final googleMapsApp = Uri.parse('comgooglemaps://?q=$query');
    final googleMapsWeb =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    final wazeApp = (lat != null && lng != null)
        ? Uri.parse('waze://?ll=$lat,$lng&navigate=yes')
        : Uri.parse('waze://?q=${Uri.encodeComponent(address)}&navigate=yes');
    final appleMapsApp = Uri.parse('maps://?q=$query');

    final List<Map<String, dynamic>> availableApps = [];
    if (await canLaunchUrl(wazeApp)) {
      availableApps.add({
        'title': 'Waze',
        'icon': Icons.navigation_rounded,
        'color': Colors.cyan,
        'uri': wazeApp
      });
    }
    if (await canLaunchUrl(googleMapsApp)) {
      availableApps.add({
        'title': 'Google Maps',
        'icon': Icons.map_rounded,
        'color': Colors.blue,
        'uri': googleMapsApp
      });
    } else {
      availableApps.add({
        'title': 'Google Maps (בדפדפן)',
        'icon': Icons.language_rounded,
        'color': Colors.blue,
        'uri': googleMapsWeb
      });
    }
    if (await canLaunchUrl(appleMapsApp)) {
      availableApps.add({
        'title': 'Apple Maps',
        'icon': Icons.explore_rounded,
        'color': Colors.white,
        'uri': appleMapsApp
      });
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: AppColors.cardBorder,
                        borderRadius: BorderRadius.circular(2))),
                Text('נווט ל-$title',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                for (var app in availableApps)
                  ListTile(
                    leading: Icon(app['icon'] as IconData,
                        color: app['color'] as Color),
                    title: Text(app['title'] as String,
                        style: const TextStyle(color: AppColors.textPrimary)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final uri = app['uri'] as Uri;
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = place['name']?.toString() ?? place['title']?.toString() ?? '';

    final address = place['address']?.toString() ?? '';
    final description = place['description']?.toString() ?? '';
    final imageUrl = extractImageUrl(place);

    final rating = place['rating'] != null
        ? double.tryParse(place['rating'].toString())
        : null;

    final ratingCount = place['rating_count'] ?? place['reviews_count'] ?? 128;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 620;

        final imageSize = mobile ? 92.0 : 108.0;

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
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
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
                                    const SizedBox(height: 9),
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
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.near_me_outlined,
                                    size: 17,
                                    color: AppColors.champagne,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'ניווט',
                                    style: TextStyle(
                                      color: AppColors.champagne,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
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
                                (rating ?? 4.6).toStringAsFixed(1),
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
