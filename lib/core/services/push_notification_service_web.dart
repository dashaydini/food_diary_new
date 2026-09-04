import 'dart:convert';
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';

@JS('btwPush.isSupported')
external JSPromise<JSBoolean> _isSupportedJs();
@JS('btwPush.isSubscribed')
external JSPromise<JSBoolean> _isSubscribedJs();
@JS('btwPush.subscribe')
external JSPromise<JSString> _subscribeJs(JSString publicKey);
@JS('btwPush.unsubscribe')
external JSPromise<JSString> _unsubscribeJs();

class PushNotificationService {
  static const vapidPublicKey =
      'BKSEMdCoF6M2af4dfsiNHrhmld1jNoGmffoKd_m6iTqQ4_CZTEmrq-DPvfhP0BED4E5JsEYTDxtWaL4G4ibRx7c';

  static Future<bool> isSupported() async =>
      (await _isSupportedJs().toDart).toDart;

  static Future<bool> isEnabled() async {
    if (!await isSupported()) return false;
    return (await _isSubscribedJs().toDart).toDart;
  }

  static Future<void> enable() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) throw StateError('login_required');
    final raw = (await _subscribeJs(vapidPublicKey.toJS).toDart).toDart;
    final subscription = Map<String, dynamic>.from(jsonDecode(raw));
    await Supabase.instance.client.from('push_subscriptions').upsert({
      'user_id': user.id,
      'endpoint': subscription['endpoint'],
      'subscription': subscription,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'endpoint');
  }

  static Future<void> disable() async {
    final endpoint = (await _unsubscribeJs().toDart).toDart;
    if (endpoint.isNotEmpty) {
      await Supabase.instance.client
          .from('push_subscriptions')
          .delete()
          .eq('endpoint', endpoint);
    }
  }
}
