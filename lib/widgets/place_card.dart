import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class PlaceCard extends StatelessWidget {
  final dynamic place;
  final VoidCallback? onTap;
  final VoidCallback? onChanged;
  final VoidCallback? onSelected;
  final VoidCallback? onNavigate;

  const PlaceCard({
    super.key,
    required this.place,
    this.onTap,
    this.onChanged,
    this.onSelected,
    this.onNavigate,
  });

  dynamic _getVal(List<String> keys) {
    if (place is Map) {
      for (var key in keys) {
        if (place.containsKey(key) && place[key] != null) {
          return place[key];
        }
      }
      return null;
    } else {
      try {
        for (var key in keys) {
          switch (key) {
            case 'name': return place.name;
            case 'address': return place.address;
            case 'description': return place.description;
            case 'imageUrl': case 'image_url': case 'image': return place.imageUrl;
            case 'weighted_rating': case 'rating_weighted': case 'rating': case 'avg_rating': case 'score': 
              try { return place.weighted_rating; } catch(_) { return place.rating; }
            case 'rating_count': case 'reviewCount': case 'reviews_count': case 'total_reviews': case 'visits_count': 
              try { return place.rating_count; } catch(_) { return place.reviewCount; }
          }
        }
      } catch (_) {}
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = onTap ?? onChanged ?? onSelected;
    
    final name = _getVal(['name', 'title']) ?? '';
    final address = _getVal(['address', 'location']) ?? '';
    final description = _getVal(['description', 'notes', 'details']) ?? '';
    
    dynamic imageUrl;
    if (place is Map) {
      imageUrl = place['imageUrl'] ?? place['image_url'] ?? place['image'] ?? place['photo'] ?? place['photo_url'] ?? place['img'];
    } else {
      imageUrl = _getVal(['imageUrl', 'image_url', 'image']);
    }

    final rawRating = _getVal(['weighted_rating', 'rating_weighted', 'rating', 'avg_rating', 'score']) ?? 0.0;
    // final rawReviews = _getVal(['rating_count', 'reviewCount', 'reviews_count', 'total_reviews', 'visits_count']) ?? 0;

    final ratingNum = rawRating is num ? rawRating.toDouble() : double.tryParse(rawRating.toString()) ?? 0.0;
    // // final reviewCountInt = rawReviews is num ? rawReviews.toInt() : int.tryParse(rawReviews.toString()) ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D24),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: effectiveOnTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imageUrl != null && imageUrl.toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 110,
                          height: 110,
                          child: Image.network(
                            imageUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    if (imageUrl != null && imageUrl.toString().isNotEmpty)
                      const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 14, color: Color(0xFFD4AF37)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  address.toString(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Divider(color: Colors.white12, height: 1),
                          ),
                          Text(
                            description.toString(),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Divider(color: Colors.white12, height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFE6C687), size: 18),
                        const SizedBox(width: 6),
                        Text(
                          ratingNum.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '()',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: onNavigate ?? () async {
      final lat = place is Map ? (place['latitude'] != null ? double.tryParse(place['latitude'].toString()) : null) : null;
      final lng = place is Map ? (place['longitude'] != null ? double.tryParse(place['longitude'].toString()) : null) : null;
      final addr = place is Map ? (place['address']?.toString() ?? '') : '';

      if (lat != null && lng != null) {
        final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } else if (addr.isNotEmpty) {
        final encodedAddress = Uri.encodeComponent(addr);
        final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      }
    },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          children: const [
                            Icon(Icons.navigation_outlined,
                                color: Color(0xFFE6C687), size: 16),
                            SizedBox(width: 6),
                            Text(
                              'ניווט',
                              style: TextStyle(
                                color: Color(0xFFE6C687),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
