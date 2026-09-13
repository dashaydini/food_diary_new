import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const routeNotificationsKey = 'route_notifications_enabled';
  static const themeModeKey = 'theme_mode';
  static const maximumRouteDetourKmKey = 'maximum_route_detour_km';
  static const routeCategoryIdsKey = 'route_category_ids';
  static const pushPermissionPromptedKey = 'push_permission_prompted';
  static const locationFeaturesEnabledKey = 'location_features_enabled';

  static const defaultMaximumRouteDetourKm = 20.0;

  static Future<bool> routeNotificationsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(routeNotificationsKey) ?? false;
  }

  static Future<void> setRouteNotificationsEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(routeNotificationsKey, enabled);
  }

  static Future<double> maximumRouteDetourKm() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getDouble(maximumRouteDetourKmKey) ??
        defaultMaximumRouteDetourKm;
  }

  static Future<void> setMaximumRouteDetourKm(double distanceKm) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(maximumRouteDetourKmKey, distanceKm);
  }

  static Future<Set<String>> routeCategoryIds() async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(routeCategoryIdsKey) ?? const <String>[])
        .toSet();
  }

  static Future<void> setRouteCategoryIds(Set<String> categoryIds) async {
    final preferences = await SharedPreferences.getInstance();
    final sortedIds = categoryIds.toList()..sort();
    await preferences.setStringList(routeCategoryIdsKey, sortedIds);
  }

  static Future<void> resetRoutePreferences() async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.remove(routeNotificationsKey),
      preferences.remove(maximumRouteDetourKmKey),
      preferences.remove(routeCategoryIdsKey),
    ]);
  }

  static Future<String> themeMode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(themeModeKey) ?? 'dark';
  }

  static Future<void> setThemeMode(String mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(themeModeKey, mode);
  }

  static Future<bool> pushPermissionPrompted(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool('${pushPermissionPromptedKey}_$userId') ?? false;
  }

  static Future<void> setPushPermissionPrompted(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('${pushPermissionPromptedKey}_$userId', true);
  }

  static Future<bool> locationFeaturesEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(locationFeaturesEnabledKey) ?? true;
  }

  static Future<void> setLocationFeaturesEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(locationFeaturesEnabledKey, enabled);
  }
}
