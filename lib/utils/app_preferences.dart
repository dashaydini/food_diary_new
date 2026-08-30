import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  static const routeNotificationsKey = 'route_notifications_enabled';
  static const themeModeKey = 'theme_mode';

  static Future<bool> routeNotificationsEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(routeNotificationsKey) ?? false;
  }

  static Future<void> setRouteNotificationsEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(routeNotificationsKey, enabled);
  }

  static Future<String> themeMode() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(themeModeKey) ?? 'dark';
  }

  static Future<void> setThemeMode(String mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(themeModeKey, mode);
  }
}
