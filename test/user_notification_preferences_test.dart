import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/core/services/user_preferences_service.dart';

void main() {
  test('notification preferences default to enabled', () {
    final preferences = UserNotificationPreferences.fromMap(null);

    expect(preferences.enabled, isTrue);
    expect(preferences.coupons, isTrue);
    expect(preferences.tags, isTrue);
    expect(preferences.newFollowers, isTrue);
    expect(preferences.newPlacesAi, isTrue);
    expect(preferences.systemMessages, isTrue);
    expect(preferences.managerNewExperience, isTrue);
  });

  test('notification preferences preserve independent choices', () {
    final preferences = UserNotificationPreferences.fromMap({
      'enabled': true,
      'coupons': false,
      'tags': true,
      'new_followers': false,
      'new_places_ai': true,
      'system_messages': false,
      'manager_new_experience': true,
    });

    expect(preferences.coupons, isFalse);
    expect(preferences.tags, isTrue);
    expect(preferences.newFollowers, isFalse);
    expect(preferences.systemMessages, isFalse);

    final updated = preferences.copyWith(coupons: true);
    expect(updated.coupons, isTrue);
    expect(updated.newFollowers, isFalse);
    expect(updated.systemMessages, isFalse);
  });

  test('all notification types can be disabled with the master switch', () {
    const preferences = UserNotificationPreferences(
      enabled: false,
      coupons: false,
      tags: false,
      newFollowers: false,
      newPlacesAi: false,
      systemMessages: false,
      managerNewExperience: false,
    );

    final row = preferences.toMap('user-1');
    expect(row['enabled'], isFalse);
    expect(row['coupons'], isFalse);
    expect(row['tags'], isFalse);
    expect(row['new_followers'], isFalse);
    expect(row['new_places_ai'], isFalse);
    expect(row['system_messages'], isFalse);
    expect(row['manager_new_experience'], isFalse);
  });
}
