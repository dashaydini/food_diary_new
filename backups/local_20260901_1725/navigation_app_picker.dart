import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';

import '../theme/colors.dart';

class NavigationAppPicker {
  NavigationAppPicker._();

  static List<MapApp> get _webNavigationApps {
    final maps = <MapApp>[
      MapApp.google,
      MapApp.waze,
    ];

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      maps.insert(0, MapApp.apple);
    }

    return maps;
  }

  static Future<void> show(
    BuildContext context,
    Map<String, dynamic> place, {
    Map<String, dynamic>? from,
    List<Map<String, dynamic>> waypoints = const [],
    String? title,
  }) async {
    final name = place['name']?.toString().trim() ?? '';
    final address = place['address']?.toString().trim() ?? '';
    final latitude = double.tryParse(place['latitude']?.toString() ?? '');
    final longitude = double.tryParse(place['longitude']?.toString() ?? '');

    final Location destination;
    if (latitude != null && longitude != null) {
      destination = Location.coords(
        latitude,
        longitude,
        title: name.isEmpty ? null : name,
      );
    } else if (address.isNotEmpty) {
      destination = Location.search(address);
    } else {
      _showMessage(context, 'אין מיקום זמין לניווט עבור המקום הזה');
      return;
    }

    final request = MapLauncher.directions(
      destination,
      from: from == null ? null : _locationFromMap(from),
      mode: TravelMode.driving,
      waypoints:
          waypoints.map(_coordsFromMap).whereType<LocationCoords>().toList(),
    );

    try {
      final supportedMaps = await request.getSupportedMaps(
        kIsWeb ? _webNavigationApps : MapApp.all,
      );
      final availableMaps = (kIsWeb
          ? supportedMaps
          : supportedMaps.where((map) => map.isInstalled).toList())
        ..sort((first, second) => first.name.compareTo(second.name));

      if (!context.mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => _NavigationAppsScreen(
            title: title ??
                (name.isEmpty ? 'בחירת אפליקציית ניווט' : 'ניווט אל $name'),
            maps: availableMaps,
            webMode: kIsWeb,
          ),
        ),
      );
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, 'לא ניתן לטעון את אפליקציות הניווט');
      }
    }
  }

  static Location? _locationFromMap(Map<String, dynamic> value) {
    final latitude = double.tryParse(value['latitude']?.toString() ?? '');
    final longitude = double.tryParse(value['longitude']?.toString() ?? '');
    if (latitude == null || longitude == null) return null;
    return Location.coords(latitude, longitude);
  }

  static LocationCoords? _coordsFromMap(Map<String, dynamic> value) {
    final latitude = double.tryParse(value['latitude']?.toString() ?? '');
    final longitude = double.tryParse(value['longitude']?.toString() ?? '');
    if (latitude == null || longitude == null) return null;
    return LocationCoords(latitude, longitude);
  }

  static void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _NavigationAppsScreen extends StatelessWidget {
  final String title;
  final List<SupportedMap> maps;
  final bool webMode;

  const _NavigationAppsScreen({
    required this.title,
    required this.maps,
    required this.webMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('בחירת אפליקציית ניווט'),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 36),
              children: [
                Text(
                  title,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  webMode
                      ? 'בסימנייה ממסך הבית לא ניתן לזהות אילו אפליקציות מותקנות. בחר שירות ניווט לפתיחה.'
                      : 'מוצגות רק אפליקציות הניווט שמותקנות במכשיר.',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                if (maps.isEmpty)
                  _NavigationEmptyState(
                    icon: Icons.location_off_outlined,
                    title: webMode
                        ? 'לא נמצא שירות ניווט מתאים'
                        : 'לא נמצאה אפליקציית ניווט',
                    message: webMode
                        ? 'שירותי הניווט הזמינים בסימנייה אינם תומכים במסלול הזה.'
                        : 'לא נמצאה במכשיר אפליקציית ניווט שתומכת ביעד הזה.',
                  )
                else
                  ...maps.map(
                    (map) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color:
                                  AppColors.champagne.withValues(alpha: 0.16),
                            ),
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.memory(
                              map.iconBytes,
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                          ),
                          title: Text(
                            map.name,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            webMode
                                ? 'ייפתח באפליקציה אם היא מותקנת'
                                : 'מותקנת במכשיר',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11.5,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 15,
                            color: AppColors.textMuted,
                          ),
                          onTap: () => _openMap(context, map),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMap(BuildContext context, SupportedMap map) async {
    try {
      await map.show();
      if (context.mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('לא ניתן לפתוח את ${map.name}')),
      );
    }
  }
}

class _NavigationEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _NavigationEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.champagne, size: 40),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
