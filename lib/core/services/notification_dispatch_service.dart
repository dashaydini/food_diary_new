import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationDispatchService {
  const NotificationDispatchService._();

  static Future<void> send({
    required String eventType,
    required String resourceId,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-event-notification',
        body: {'event_type': eventType, 'resource_id': resourceId},
      );
    } catch (error) {
      // Saving content must never fail only because a push could not be sent.
      debugPrint('PUSH DISPATCH ERROR ($eventType/$resourceId): $error');
    }
  }
}
