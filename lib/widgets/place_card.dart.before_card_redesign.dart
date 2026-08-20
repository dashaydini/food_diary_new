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
  Future<void> _openPlaceDetails() async {
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
  }

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
        await _showNavigationOptions(latitude, longitude);
      }
    } catch (_) {
      if (!mounted) return;
      await _showNavigationOptions(latitude, longitude);
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
                    color: Color(0xFFF5EEE6),
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
                    style: TextStyle(
                      color: Color(0xFFF5EEE6),
                    ),
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
                    style: TextStyle(
                      color: Color(0xFFF5EEE6),
                    ),
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
                    style: TextStyle(
                      color: Color(0xFFF5EEE6),
                    ),
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

    final hasLocation =
        widget.place['latitude'] != null && widget.place['longitude'] != null;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.line,
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openPlaceDetails,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                14,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // תמונה בצד שמאל
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: 145,
                      height: 145,
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return const SizedBox.shrink();
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  const SizedBox(width: 18),

                  // פרטי המקום בצד ימין
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          name,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF5EEE6),
                          ),
                        ),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  address,
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.location_on_outlined,
                                size: 20,
                                color: AppColors.muted,
                              ),
                            ],
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Container(
                            height: 1,
                            color: AppColors.line,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            description,
                            textAlign: TextAlign.right,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // קו מפריד
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 1,
                color: AppColors.line,
              ),
            ),

            // שורת תחתית
            SizedBox(
              height: 62,
              child: Row(
                children: [
                  // דירוג בצד שמאל
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 18),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: weightedRating != null
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 27,
                                    color: Color(0xFFF5EEE6),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    weightedRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFF5EEE6),
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 34,
                    color: AppColors.line,
                  ),

                  // ניווט בצד ימין
                  Expanded(
                    child: hasLocation
                        ? TextButton.icon(
                            onPressed: _openNavigation,
                            icon: const Icon(
                              Icons.navigation_outlined,
                              size: 25,
                              color: Color(0xFFF5EEE6),
                            ),
                            label: const Text(
                              'ניווט',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF5EEE6),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
