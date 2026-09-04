class PushNotificationService {
  static Future<bool> isSupported() async => false;
  static Future<bool> isEnabled() async => false;
  static Future<void> enable() async => throw UnsupportedError('Web Push');
  static Future<void> disable() async {}
}
