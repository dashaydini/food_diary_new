import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'privacy_consent_platform_stub.dart'
    if (dart.library.js_interop) 'privacy_consent_platform_web.dart';

enum PrivacyConsentChoice { undecided, accepted, rejected }

class PrivacyConsentService {
  static const _preferenceKey = 'privacy_advertising_consent_v1';

  static final ValueNotifier<PrivacyConsentChoice> choice =
      ValueNotifier(PrivacyConsentChoice.undecided);

  static bool get shouldRequestConsent =>
      PrivacyConsentPlatform.shouldRequestConsent;

  static bool get advertisingAllowed =>
      choice.value == PrivacyConsentChoice.accepted;

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString(_preferenceKey);
    choice.value = switch (stored) {
      'accepted' => PrivacyConsentChoice.accepted,
      'rejected' => PrivacyConsentChoice.rejected,
      _ => PrivacyConsentChoice.undecided,
    };
    PrivacyConsentPlatform.applyAdvertisingConsent(advertisingAllowed);
  }

  static Future<void> setAdvertisingAllowed(bool allowed) async {
    final next =
        allowed ? PrivacyConsentChoice.accepted : PrivacyConsentChoice.rejected;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, next.name);
    choice.value = next;
    PrivacyConsentPlatform.applyAdvertisingConsent(allowed);
  }
}
