import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_filter.dart';
import '../screens/place_details_screen.dart';
import '../theme/colors.dart';

class PlaceCard extends StatefulWidget {
  final Map<String, dynamic> place;
  final ContentFilter filter;
  final VoidCallback? onChanged;

  const PlaceCard({
    super.key,
    required this.place,
    this.filter = ContentFilter.all,
    this.onChanged,
  });

  @override
  State<PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends State<PlaceCard> {
  Future<void> _openNavigation() async {
    final latitude = (widget.place['latitude'] as num?)?.toDouble();
    final longitude = (widget.place['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אין מיקום זמין לניווט עבור המקום הזה'),
        ),
      );
      return;
    }

    if (kIsWeb) {
      await _showNavigationOptions(latitude, longitude);
      return;
    }

    final uri = Uri.parse(
      'geo:$latitude,$longitude?q=$latitude,$longitude',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('לא נמצאה אפליקציית מפות במכשיר'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן לפתוח אפליקציית ניווט'),
        ),
      );
    }
  }

  Future<void> _showNavigationOptions(
    double latitude,
    double longitude,
  ) async {
    if (!mounted) return;

    final googleMaps = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    final waze = Uri.parse(
      'https://www.waze.com/ul?ll=$latitude%2C$longitude&navigate=yes',
    );
    final appleMaps = Uri.parse(
      'https://maps.apple.com/?daddr=$latitude,$longitude',
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.muted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'בחר אפליקציית ניווט',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: AppColors.card,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.map_outlined,
                    color: AppColors.muted,
                  ),
                  title: const Text(
                    'Google Maps',
                    style: TextStyle(color: AppColors.card),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await launchUrl(
                      googleMaps,
                      mode: LaunchMode.platformDefault,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.navigation_outlined,
                    color: AppColors.muted,
                  ),
                  title: const Text(
                    'Waze',
                    style: TextStyle(color: AppColors.card),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await launchUrl(
                      waze,
                      mode: LaunchMode.platformDefault,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.muted,
                  ),
                  title: const Text(
                    'Apple Maps',
                    style: TextStyle(color: AppColors.card),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await launchUrl(
                      appleMaps,
                      mode: LaunchMode.platformDefault,
                    );
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
    final name = widget.place['name']?.toString() ?? '';
    final description = widget.place['description']?.toString() ?? '';
    final address = widget.place['address']?.toString() ?? '';
    final imageUrl = widget.place['image_url']?.toString() ?? '';
    final weightedRating =
        (widget.place['weighted_rating'] as num?)?.toDouble();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => PlaceDetailsScreen(
              place: widget.place,
              filter: widget.filter,
            ),
          ),
        );

        if (changed == true) {
          widget.onChanged?.call();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.line,
            width: 0.7,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.card,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.place['latitude'] != null &&
                          widget.place['longitude'] != null) ...[
                        const SizedBox(width: 14),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'ניווט למקום',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              icon: const Icon(
                                Icons.navigation_outlined,
                                size: 22,
                                color: AppColors.muted,
                              ),
                              onPressed: _openNavigation,
                            ),
                            const Text(
                              'ניווט למקום',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      if (weightedRating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              size: 17,
                              color: AppColors.card,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              weightedRating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.card,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (imageUrl.isNotEmpty) ...[
              const SizedBox(width: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 105,
                  height: 105,
                  child: Image.network(
                    imageUrl,
                    width: 105,
                    height: 105,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
