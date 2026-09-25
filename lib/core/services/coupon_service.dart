import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/coupon.dart';

class CouponService {
  CouponService._();
  static final _client = Supabase.instance.client;

  static Future<List<Coupon>> list({
    bool includeDrafts = false,
    bool includeExpired = false,
    String? placeId,
  }) async {
    dynamic query = _client.from('coupons').select(
          'id,title,subtitle,description,valid_until,business_name,address,'
          'latitude,longitude,place_id,image_url,gallery_images,category_ids,'
          'notification_region,is_unlimited,is_published,is_premium_only,'
          'published_at,notification_sent_at,created_by,created_at,updated_at',
        );
    if (!includeDrafts) query = query.eq('is_published', true);
    if (!includeExpired) {
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      query = query.gte('valid_until', today);
    }
    if (placeId != null) query = query.eq('place_id', placeId);
    final rows = await query.order('created_at', ascending: false);
    var coupons =
        List<Map<String, dynamic>>.from(rows).map(Coupon.fromJson).toList();
    if (includeDrafts) {
      coupons = await Future.wait([
        for (final coupon in coupons)
          getCode(coupon.id).then(coupon.copyWithCode),
      ]);
    }
    return coupons;
  }

  static Future<String> getCode(String couponId) async {
    final value = await _client.rpc(
      'get_coupon_redemption_code',
      params: {'target_coupon_id': couponId},
    );
    return value?.toString() ?? '';
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

  static Future<void> restore(String id, DateTime validUntil) async {
    final date =
        '${validUntil.year.toString().padLeft(4, '0')}-${validUntil.month.toString().padLeft(2, '0')}-${validUntil.day.toString().padLeft(2, '0')}';
    await save({'valid_until': date}, id: id);
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
