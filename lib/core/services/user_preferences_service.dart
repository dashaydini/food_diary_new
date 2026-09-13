import 'package:supabase_flutter/supabase_flutter.dart';

class UserNotificationPreferences {
  final bool enabled;
  final bool coupons;
  final bool tags;
  final bool newFollowers;
  final bool newPlacesAi;
  final bool systemMessages;
  final bool managerNewExperience;

  const UserNotificationPreferences({
    this.enabled = true,
    this.coupons = true,
    this.tags = true,
    this.newFollowers = true,
    this.newPlacesAi = true,
    this.systemMessages = true,
    this.managerNewExperience = true,
  });

  factory UserNotificationPreferences.fromMap(Map<String, dynamic>? row) {
    return UserNotificationPreferences(
      enabled: row?['enabled'] != false,
      coupons: row?['coupons'] != false,
      tags: row?['tags'] != false,
      newFollowers: row?['new_followers'] != false,
      newPlacesAi: row?['new_places_ai'] != false,
      systemMessages: row?['system_messages'] != false,
      managerNewExperience: row?['manager_new_experience'] != false,
    );
  }

  UserNotificationPreferences copyWith({
    bool? enabled,
    bool? coupons,
    bool? tags,
    bool? newFollowers,
    bool? newPlacesAi,
    bool? systemMessages,
    bool? managerNewExperience,
  }) {
    return UserNotificationPreferences(
      enabled: enabled ?? this.enabled,
      coupons: coupons ?? this.coupons,
      tags: tags ?? this.tags,
      newFollowers: newFollowers ?? this.newFollowers,
      newPlacesAi: newPlacesAi ?? this.newPlacesAi,
      systemMessages: systemMessages ?? this.systemMessages,
      managerNewExperience: managerNewExperience ?? this.managerNewExperience,
    );
  }

  Map<String, dynamic> toMap(String userId) => {
        'user_id': userId,
        'enabled': enabled,
        'coupons': coupons,
        'tags': tags,
        'new_followers': newFollowers,
        'new_places_ai': newPlacesAi,
        'system_messages': systemMessages,
        'manager_new_experience': managerNewExperience,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
}

class UserPreferencesService {
  static const privacyPolicyVersion = '2026-09-13';

  final SupabaseClient client;

  const UserPreferencesService(this.client);

  Future<bool> hasAcceptedCurrentPrivacyPolicy(String userId) async {
    final row = await client
        .from('user_legal_consents')
        .select('privacy_policy_version')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['privacy_policy_version'] == privacyPolicyVersion;
  }

  Future<void> acceptCurrentPrivacyPolicy(String userId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await client.from('user_legal_consents').upsert({
      'user_id': userId,
      'privacy_policy_version': privacyPolicyVersion,
      'accepted_at': now,
      'updated_at': now,
    });
  }

  Future<UserNotificationPreferences> notificationPreferences(
    String userId,
  ) async {
    final row = await client
        .from('notification_preferences')
        .select(
          'enabled,coupons,tags,new_followers,new_places_ai,'
          'system_messages,manager_new_experience',
        )
        .eq('user_id', userId)
        .maybeSingle();
    return UserNotificationPreferences.fromMap(row);
  }

  Future<void> saveNotificationPreferences(
    String userId,
    UserNotificationPreferences preferences,
  ) async {
    await client
        .from('notification_preferences')
        .upsert(preferences.toMap(userId));
  }
}
