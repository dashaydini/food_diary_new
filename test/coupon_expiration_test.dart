import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/core/models/coupon.dart';

Coupon couponWithExpiry(DateTime validUntil) => Coupon(
      id: 'coupon-1',
      title: 'קופון בדיקה',
      subtitle: '',
      description: '',
      code: 'TEST',
      validUntil: validUntil,
      businessName: 'עסק',
      address: '',
      latitude: null,
      longitude: null,
      placeId: null,
      imageUrl: '',
      isUnlimited: true,
      isPublished: true,
    );

void main() {
  final now = DateTime(2026, 9, 13, 16, 30);

  test('coupon remains valid throughout its expiry date', () {
    expect(couponWithExpiry(DateTime(2026, 9, 13)).isExpiredOn(now), isFalse);
  });

  test('coupon is expired starting the following calendar day', () {
    expect(couponWithExpiry(DateTime(2026, 9, 12)).isExpiredOn(now), isTrue);
  });
}
