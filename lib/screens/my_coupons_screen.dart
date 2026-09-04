import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';
import '../widgets/navigation_app_picker.dart';
import 'place_details_screen.dart';

class MyCouponsScreen extends StatelessWidget {
  const MyCouponsScreen({super.key});

  static const _coupon = _Coupon(
    title: 'קפה לבחירה במתנה',
    subtitle: 'בקניית מארז לראש השנה',
    description: 'על כל קניית מארז לחג, קפה לבחירה במתנה.',
    code: 'BTW-CAFE-1109',
    validUntil: '11.09.2026',
    businessName: 'פטפוט במוזיאון',
    address: 'העצמאות 60, העיר העתיקה, באר שבע',
    latitude: 31.2410286761093,
    longitude: 34.7888643763947,
    placeId: 'ca43cd9b-a450-47fd-8a7d-b51d0dd174b4',
    imageAsset: 'assets/coupons/rosh_hashanah_gift_basket.jpeg',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('הקופונים שלי'),
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                children: [
                  const _PageIntro(),
                  const SizedBox(height: 20),
                  _CouponCard(coupon: _coupon),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.champagne.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: AppColors.champagne.withValues(alpha: 0.35),
            ),
          ),
          child: const Icon(
            Icons.confirmation_number_outlined,
            color: AppColors.champagne,
          ),
        ),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ההטבות שמחכות לך',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'מציגים את הקופון בבית העסק ונהנים.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CouponCard extends StatelessWidget {
  final _Coupon coupon;

  const _CouponCard({required this.coupon});

  Future<void> _openNavigation(BuildContext context) =>
      NavigationAppPicker.show(
        context,
        coupon.navigationPlace,
        title: 'ניווט אל ${coupon.businessName}',
      );

  Future<void> _openBusiness(BuildContext context) async {
    try {
      final place = await Supabase.instance.client
          .from('places')
          .select()
          .eq('id', coupon.placeId)
          .single();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן לפתוח כרגע את כרטיס העסק')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.cardBorder),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 3.2,
                  child: Image.asset(
                    coupon.imageAsset,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, 0.28),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.background.withValues(alpha: 0.78),
                        ],
                        stops: const [0.5, 1],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.background.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: AppColors.champagne.withValues(alpha: 0.55),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.all_inclusive,
                            size: 17, color: AppColors.champagne),
                        SizedBox(width: 6),
                        Text(
                          'ללא הגבלת מימושים',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 20,
                        color: AppColors.champagne,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          coupon.businessName,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    coupon.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    coupon.subtitle,
                    style: const TextStyle(
                      color: AppColors.champagne,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.event_available_outlined,
                    text: 'בתוקף עד ${coupon.validUntil}',
                  ),
                  const SizedBox(height: 8),
                  const _InfoRow(
                    icon: Icons.storefront_outlined,
                    text: 'למימוש בהצגת הקופון בבית העסק',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    text: coupon.address,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              _CouponPresentationScreen(coupon: coupon),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: const Text('הצגת הקופון למימוש'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _openNavigation(context),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('ניווט לבית העסק'),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _openBusiness(context),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('לכרטיס העסק באפליקציה'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: AppColors.champagneSoft),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _CouponPresentationScreen extends StatelessWidget {
  final _Coupon coupon;

  const _CouponPresentationScreen({required this.coupon});

  Future<void> _openNavigation(BuildContext context) =>
      NavigationAppPicker.show(
        context,
        coupon.navigationPlace,
        title: 'ניווט אל ${coupon.businessName}',
      );

  Future<void> _openBusiness(BuildContext context) async {
    try {
      final place = await Supabase.instance.client
          .from('places')
          .select()
          .eq('id', coupon.placeId)
          .single();
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן לפתוח כרגע את כרטיס העסק')),
      );
    }
  }

  Future<void> _copyCode(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: coupon.code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('קוד הקופון הועתק')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('הצגת קופון'),
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Image.asset(
                          coupon.imageAsset,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, 0.28),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: AppColors.champagne.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.champagne.withValues(alpha: 0.42),
                        ),
                      ),
                      child: const Icon(
                        Icons.coffee_outlined,
                        size: 38,
                        color: AppColors.champagne,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      coupon.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      coupon.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.champagne,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      coupon.businessName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      coupon.address,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.champagne.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'קוד הקופון',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            coupon.code,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.2,
                            ),
                          ),
                          const SizedBox(height: 13),
                          TextButton.icon(
                            onPressed: () => _copyCode(context),
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('העתקת הקוד'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'יש להציג את המסך לצוות בית העסק לפני התשלום.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'בתוקף עד ${coupon.validUntil}  •  ללא הגבלת מימושים',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),
                    OutlinedButton.icon(
                      onPressed: () => _openNavigation(context),
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('ניווט לבית העסק'),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: () => _openBusiness(context),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('לכרטיס העסק באפליקציה'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Coupon {
  final String title;
  final String subtitle;
  final String description;
  final String code;
  final String validUntil;
  final String businessName;
  final String address;
  final double latitude;
  final double longitude;
  final String placeId;
  final String imageAsset;

  const _Coupon({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.code,
    required this.validUntil,
    required this.businessName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.placeId,
    required this.imageAsset,
  });

  Map<String, dynamic> get navigationPlace => {
        'name': businessName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
      };
}
