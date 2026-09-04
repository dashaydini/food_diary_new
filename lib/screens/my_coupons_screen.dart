import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../core/models/coupon.dart';
import '../core/services/coupon_service.dart';
import '../widgets/home_button.dart';
import '../widgets/navigation_app_picker.dart';
import '../features/authentication/screens/login_screen.dart';
import '../main.dart' show AuthGate;
import 'place_details_screen.dart';

class MyCouponsScreen extends StatefulWidget {
  const MyCouponsScreen({super.key});

  @override
  State<MyCouponsScreen> createState() => _MyCouponsScreenState();
}

class _MyCouponsScreenState extends State<MyCouponsScreen> {
  bool _loading = true;
  List<Coupon> _coupons = [];

  bool get _isGuest {
    final user = Supabase.instance.client.auth.currentUser;
    return user == null || user.isAnonymous;
  }

  @override
  void initState() {
    super.initState();
    if (_isGuest) {
      Future<void>.delayed(const Duration(seconds: 1), _showLoginRequired);
    } else {
      _loadCoupons();
    }
  }

  Future<void> _loadCoupons() async {
    try {
      final coupons = await CouponService.list();
      if (mounted) setState(() => _coupons = coupons);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא ניתן לטעון את הקופונים')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showLoginRequired() async {
    if (!mounted || !_isGuest) return;
    final login = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(Icons.lock_outline_rounded),
          title: const Text('יש להתחבר כדי להציג קופונים'),
          content: const Text(
            'הקופונים האישיים זמינים למשתמשים רשומים. אפשר להתחבר לחשבון קיים או להירשם.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('לא עכשיו'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('לכניסה ולהרשמה'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (login != true) {
      Navigator.of(context).pop();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onAuthSuccess: () {
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthGate()),
              (route) => false,
            );
          },
        ),
      ),
    );
  }

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
              child: _isGuest || _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                      children: [
                        const _PageIntro(),
                        const SizedBox(height: 20),
                        if (_coupons.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(30),
                              child: Text('אין כרגע קופונים פעילים',
                                  textAlign: TextAlign.center))
                        else
                          for (final coupon in _coupons) ...[
                            _CouponCard(coupon: coupon),
                            const SizedBox(height: 12),
                          ],
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
            Icons.card_giftcard_rounded,
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
  final Coupon coupon;

  const _CouponCard({required this.coupon});

  Future<void> _openCoupon(BuildContext context) async {
    await _CouponAnalytics.record(coupon.id, 'coupon_open');
    await _CouponAnalytics.record(coupon.id, 'code_view');
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CouponPresentationScreen(coupon: coupon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCoupon(context),
        child: SizedBox(
          height: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(coupon.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.champagne,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 7),
                      Text(coupon.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.15)),
                      const SizedBox(height: 6),
                      Text(coupon.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      const Spacer(),
                      Text('בתוקף עד ${coupon.validUntilLabel}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 5),
                      const Row(children: [
                        Icon(Icons.touch_app_outlined,
                            size: 16, color: AppColors.champagne),
                        SizedBox(width: 5),
                        Text('לפתיחת הקופון',
                            style: TextStyle(
                                color: AppColors.champagne, fontSize: 12.5)),
                      ]),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 138,
                child: _couponImage(coupon.imageUrl),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CouponPresentationScreen extends StatelessWidget {
  final Coupon coupon;

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
          .eq('id', coupon.placeId!)
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
                    _CouponGallery(images: coupon.images),
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
                      'בתוקף עד ${coupon.validUntilLabel}  •  ${coupon.isUnlimited ? 'ללא הגבלת מימושים' : ''}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (coupon.latitude != null && coupon.longitude != null)
                      OutlinedButton.icon(
                        onPressed: () => _openNavigation(context),
                        icon: const Icon(Icons.navigation_outlined),
                        label: const Text('ניווט לבית העסק'),
                      ),
                    const SizedBox(height: 10),
                    if (coupon.placeId != null)
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

class _CouponGallery extends StatefulWidget {
  final List<String> images;

  const _CouponGallery({required this.images});

  @override
  State<_CouponGallery> createState() => _CouponGalleryState();
}

class _CouponGalleryState extends State<_CouponGallery> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: _couponImage(''),
        ),
      );
    }

    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: PageView.builder(
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _current = index),
            itemBuilder: (_, index) => _couponImage(widget.images[index]),
          ),
        ),
      ),
      if (widget.images.length > 1) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          children: List.generate(widget.images.length, (index) {
            final selected = index == _current;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.champagne
                    : AppColors.textMuted.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    ]);
  }
}

Widget _couponImage(String source) {
  if (source.startsWith('http://') || source.startsWith('https://')) {
    return Image.network(source,
        fit: BoxFit.cover,
        alignment: const Alignment(0, 0.3),
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.card_giftcard_rounded)));
  }
  return Image.asset(source,
      fit: BoxFit.cover,
      alignment: const Alignment(0, 0.3),
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.card_giftcard_rounded)));
}

class _CouponAnalytics {
  static Future<void> record(String couponId, String eventType) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      await client.from('coupon_events').insert({
        'coupon_id': couponId,
        'event_type': eventType,
        'user_id': user.id,
      });
    } catch (_) {
      // Analytics must never block access to a coupon.
    }
  }
}
