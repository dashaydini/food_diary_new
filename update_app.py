import os
import re

theme_code = '''import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF0D0F14);
  static const Color cardBg = Color(0xFF131722);
  static const Color cardBorder = Color(0xFF2C3242);
  static const Color gold = Color(0xFFFFC107);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF8E99A8);
  static const Color inputBg = Color(0xFF1B202E);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        surface: AppColors.cardBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static ThemeData get lightTheme => darkTheme;
  static ThemeData get light => darkTheme;
  static ThemeData get dark => darkTheme;
}
'''

cat_card_code = '''import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 28),
              const SizedBox(width: 16),
              Container(width: 1, height: 32, color: AppColors.cardBorder),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1.0)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
'''

place_card_code = '''import 'package0package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

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
    final fields = ['imageUrl', 'image_url', 'image', 'photo', 'photoUrl', 'photo_url'];
    for (final field in fields) {
      if (place[field] != null && place[field].toString().isNotEmpty) return place[field].toString();
    }
    if (place['images'] is List && (place['images'] as List).isNotEmpty) return place['images'][0].toString();
    return null;
  }

  static Future<void> showNavigationOptions(BuildContext context, Map<String, dynamic> place) async {
    final title = place['name']?.toString() ?? place['title']?.toString() ?? 'מיקום';
    final address = place['address']?.toString() ?? '';
    final lat = place['latitude'] != null ? double.tryParse(place['latitude'].toString()) : null;
    final lng = place['longitude'] != null ? double.tryParse(place['longitude'].toString()) : null;

    final query = (lat != null && lng != null) ? '$lat,$lng' : Uri.encodeComponent(address);
    final googleMapsApp = Uri.parse('comgooglemaps://?q=$query');
    final googleMapsWeb = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    final wazeApp = (lat != null && lng != null) ? Uri.parse('waze://?ll=$lat,$lng&navigate=yes') : Uri.parse('waze://?q=${Uri.encodeComponent(address)}&navigate=yes');
    final appleMapsApp = Uri.parse('maps://?q=$query');

    final List<Map<String, dynamic>> availableApps = [];
    if (await canLaunchUrl(wazeApp)) availableApps.add({'title': 'Waze', 'icon': Icons.navigation_rounded, 'color': Colors.cyan, 'uri': wazeApp});
    if (await canLaunchUrl(googleMapsApp)) availableApps.add({'title': 'Google Maps', 'icon': Icons.map_rounded, 'color': Colors.blue, 'uri': googleMapsApp});
    else availableApps.add({'title': 'Google Maps (בדפדפן)', 'icon': Icons.language_rounded, 'color': Colors.blue, 'uri': googleMapsWeb});
    if (await canLaunchUrl(appleMapsApp)) availableApps.add({'title': 'Apple Maps', 'icon': Icons.explore_rounded, 'color': Colors.white, 'uri': appleMapsApp});

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                Text('נווט ל-$title', style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                for (var app in availableApps)
                  ListTile(
                    leading: Icon(app['icon'] as IconData, color: app['color'] as Color),
                    title: Text(app['title'] as String, style: const TextStyle(color: AppColors.textPrimary)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final uri = app['uri'] as Uri;
                      if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    final title = place['name']?.toString() ?? place['title']?.toString() ?? '';
    final address = place['address']?.toString() ?? '';
    final description = place['description']?.toString() ?? '';
    final imageUrl = extractImageUrl(place);
    final rating = place['rating'] != null ? double.tryParse(place['rating'].toString()) : null;
    final ratingCount = place['rating_count'] ?? place['reviews_count'] ?? 128;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(imageUrl, width: 120, height: 120, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(width: 120, height: 120, color: AppColors.inputBg, child: const Icon(Icons.restaurant_rounded, color: AppColors.textSecondary, size: 36)))
                        : Container(width: 120, height: 120, color: AppColors.inputBg, child: const Icon(Icons.storefront_rounded, color: AppColors.textSecondary, size: 36)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(title, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (address.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: Text(address, textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 4),
                              const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 15),
                            ],
                          ),
                        ],
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(description, textAlign: TextAlign.right, style: TextStyle(color: AppColors.textPrimary.withValues(alpha: 0.65), fontSize: 12.5, height: 1.35), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: AppColors.cardBorder.withValues(alpha: 0.6)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.gold, size: 20),
                      const SizedBox(width: 4),
                      Text((rating ?? 4.6).toStringAsFixed(1), style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(width: 4),
                      Text('($ratingCount)', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                  InkWell(
                    onTap: onNavigate ?? () => showNavigationOptions(context, place),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Text('ניווט', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                          SizedBox(width: 6),
                          Icon(Icons.near_me_outlined, color: AppColors.textPrimary, size: 18),
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
    );
  }
}
'''

def write_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

write_file('lib/theme/app_theme.dart', theme_code)
write_file('lib/widgets/category_card.dart', cat_card_code)
write_file('lib/widgets/place_card.dart', place_card_code)

print("הקבצים עודכנו בהצלחה במערכת!")
