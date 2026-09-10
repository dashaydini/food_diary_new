import 'dart:js_interop';

@JS('btwPrivacy.setConsent')
external void _setConsent(bool allowed);

class PrivacyConsentPlatform {
  static bool get shouldRequestConsent => true;

  static void applyAdvertisingConsent(bool allowed) => _setConsent(allowed);
}
