import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  static const _endpointPrefix = 'fcm:';
  static const _channel = AndroidNotificationChannel(
    'bite_the_way_updates',
    'עדכונים מ־BITE THE WAY',
    description: 'קופונים, תיוגים ופעילות שחשובה לך באפליקציה',
    importance: Importance.high,
  );
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static final _openedLinks = StreamController<Uri>.broadcast();
  static bool _initialized = false;
  static bool _localNotificationsReady = false;

  static Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;
    _initialized = true;

    try {
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('btw_notification'),
        ),
        onDidReceiveNotificationResponse: (response) {
          _dispatchLink(response.payload);
        },
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
      _localNotificationsReady = true;
    } catch (_) {
      // Push registration must not prevent the app from starting if a device
      // cannot initialize foreground notification rendering.
      _localNotificationsReady = false;
    }

    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null || !_localNotificationsReady) return;

      // Android 13+ can deliver an FCM callback while notification display
      // permission is disabled. Avoid calling the native notification API in
      // that state, and keep a plugin/device-specific failure from surfacing
      // as an unhandled asynchronous exception.
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      try {
        await _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: 'btw_notification',
            ),
          ),
          payload: message.data['url'] as String?,
        );
      } catch (_) {
        // A notification rendering failure must not interrupt the active app.
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _dispatchLink(message.data['url'] as String?);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      try {
        await _saveToken(token);
      } catch (_) {
        // A later app launch or settings refresh will retry registration.
      }
    });
  }

  static Future<Uri?> initialLink() async {
    if (!Platform.isAndroid) return null;
    final message = await FirebaseMessaging.instance.getInitialMessage();
    return _parseLink(message?.data['url'] as String?);
  }

  static Stream<Uri> get openedLinks => _openedLinks.stream;

  static Future<bool> isSupported() async => Platform.isAndroid;

  static Future<bool> isEnabled() async {
    if (!Platform.isAndroid) return false;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<void> enable() async {
    if (!Platform.isAndroid) throw UnsupportedError('Android Push');
    await initialize();
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) throw StateError('login_required');

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      throw StateError('permission_denied');
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) throw StateError('token_unavailable');
    await _saveToken(token);
  }

  static Future<void> disable() async {
    if (!Platform.isAndroid) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && !user.isAnonymous) {
      await Supabase.instance.client
          .from('push_subscriptions')
          .delete()
          .eq('user_id', user.id)
          .like('endpoint', '$_endpointPrefix%');
    }
    await FirebaseMessaging.instance.deleteToken();
  }

  static Future<void> _saveToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    final endpoint = '$_endpointPrefix$token';

    // A refreshed FCM token replaces older Android tokens for this user.
    await Supabase.instance.client
        .from('push_subscriptions')
        .delete()
        .eq('user_id', user.id)
        .like('endpoint', '$_endpointPrefix%')
        .neq('endpoint', endpoint);
    await Supabase.instance.client.from('push_subscriptions').upsert({
      'user_id': user.id,
      'endpoint': endpoint,
      'subscription': {
        'provider': 'fcm',
        'token': token,
        'platform': 'android',
      },
      'user_agent': 'BITE THE WAY Android',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'endpoint');
  }

  static void _dispatchLink(String? raw) {
    final link = _parseLink(raw);
    if (link != null) _openedLinks.add(link);
  }

  static Uri? _parseLink(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }
}
