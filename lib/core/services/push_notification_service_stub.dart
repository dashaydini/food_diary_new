class PushNotificationService {
  static Future<void> initialize() async {}
  static Future<Uri?> initialLink() async => null;
  static Stream<Uri> get openedLinks => const Stream.empty();
  static Future<bool> isSupported() async => false;
  static Future<bool> isEnabled() async => false;
  static Future<void> enable() async => throw UnsupportedError('Web Push');
  static Future<void> disable() async {}
}
