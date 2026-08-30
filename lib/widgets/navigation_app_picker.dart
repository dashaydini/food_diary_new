import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map_launcher/map_launcher.dart';

import '../theme/colors.dart';

class NavigationAppPicker {
  NavigationAppPicker._();

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
      final supportedMaps = await request.getSupportedMaps(MapApp.all);
      final availableMaps = kIsWeb
          ? supportedMaps.where((map) => map.hasUniversalLink).toList()
          : supportedMaps.where((map) => map.isInstalled).toList();

      if (!context.mounted) return;

      if (availableMaps.isEmpty) {
        _showMessage(context, 'לא נמצאה אפליקציית ניווט זמינה במכשיר');
        return;
      }

      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.card,
        showDragHandle: true,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (sheetContext) {
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title ??
                            (name.isEmpty
                                ? 'בחירת אפליקציית ניווט'
                                : 'ניווט אל $name'),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kIsWeb
                            ? 'בחר שירות ניווט שייפתח בדפדפן'
                            : 'מוצגות אפליקציות הניווט המותקנות במכשיר',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),
                      for (final map in availableMaps)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(14),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: AppColors.champagne
                                      .withValues(alpha: 0.12),
                                ),
                              ),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  map.iconBytes,
                                  width: 38,
                                  height: 38,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              ),
                              title: Text(
                                map.name,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: kIsWeb
                                  ? const Text(
                                      'פתיחה בדפדפן',
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    )
                                  : null,
                              trailing: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 15,
                                color: AppColors.textMuted,
                              ),
                              onTap: () async {
                                Navigator.of(sheetContext).pop();
                                try {
                                  await map.show();
                                } catch (_) {
                                  if (context.mounted) {
                                    _showMessage(
                                      context,
                                      'לא ניתן לפתוח את ${map.name}',
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
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
