import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coupon.dart';

class CouponService {
  CouponService._();
  static final _client = Supabase.instance.client;

  static Future<List<Coupon>> list({bool includeDrafts = false}) async {
    dynamic query = _client.from('coupons').select();
    if (!includeDrafts) query = query.eq('is_published', true);
    final rows = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows).map(Coupon.fromJson).toList();
  }

  static Future<void> save(Map<String, dynamic> values, {String? id}) async {
    if (id == null) {
      await _client.from('coupons').insert({
        ...values,
        'created_by': _client.auth.currentUser!.id,
      });
    } else {
      await _client.from('coupons').update({
        ...values,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
    }
  }

  static Future<void> remove(String id) async {
    await _client.from('coupons').delete().eq('id', id);
  }

  static Future<Map<String, dynamic>> publish(
    String id, {
    bool sendPush = false,
    String? pushTitle,
    String? pushBody,
  }) async {
    final response = await _client.functions.invoke(
      'publish-coupon',
      body: {
        'coupon_id': id,
        'send_push': sendPush,
        if (pushTitle != null) 'push_title': pushTitle,
        if (pushBody != null) 'push_body': pushBody,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
