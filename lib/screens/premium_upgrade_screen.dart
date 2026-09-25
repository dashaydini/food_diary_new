import 'package:flutter/material.dart';

import '../core/services/premium_service.dart';
import '../theme/colors.dart';
import '../widgets/home_button.dart';

class PremiumUpgradeScreen extends StatefulWidget {
  final String? sourceFeature;

  const PremiumUpgradeScreen({
    super.key,
    this.sourceFeature,
  });

  @override
  State<PremiumUpgradeScreen> createState() => _PremiumUpgradeScreenState();
}

class _PremiumUpgradeScreenState extends State<PremiumUpgradeScreen> {
  bool _refreshing = false;

  Future<void> _refreshStatus() async {
    setState(() => _refreshing = true);
    final premium = await PremiumService.refresh();
    if (!mounted) return;
    setState(() => _refreshing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          premium
              ? 'חשבון Premium פעיל. כל האפשרויות פתוחות עבורך.'
              : 'עדיין לא נמצא מנוי Premium פעיל בחשבון.',
        ),
      ),
    );
    if (premium) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('BITE THE WAY Premium'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 26, 18, 40),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        AppColors.champagne.withValues(alpha: 0.18),
                        AppColors.surfaceRaised,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.champagne.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.champagne.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: AppColors.champagne,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'יותר חופש למצוא ולשמור\n+את המקומות שבאמת מתאימים לך',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 25,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.sourceFeature != null) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'רוצה להמשיך להשתמש באפשרות הזו? עם Premium כל האפשרויות המתקדמות פתוחות עבורך.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _benefit(
                  Icons.tune_rounded,
                  'סינון מתקדם',
                  'שילוב של קטגוריה, מרחק, אווירה, דירוג ומחיר בחיפוש אחד.',
                ),
                _benefit(
                  Icons.favorite_rounded,
                  'שמירה ללא הגבלה',
                  'כמה מועדפים וכמה מקומות ברשימת המשאלות שרוצים.',
                ),
                _benefit(
                  Icons.auto_awesome_rounded,
                  'AI והפתעות אישיות',
                  'המלצות לפי הטעם שלך ובחירת מקום מפתיע על המפה.',
                ),
                _benefit(
                  Icons.collections_bookmark_outlined,
                  'יומן ואוספים מורחבים',
                  'אוספים ללא הגבלה ועד 10 תמונות בכל חוויה.',
                ),
                _benefit(
                  Icons.route_outlined,
                  'כלי גילוי מתקדמים',
                  'מסננים למציאת מקומות בדרך וסידור קטגוריות אישי.',
                ),
                _benefit(
                  Icons.local_activity_outlined,
                  'קופונים בלעדיים',
                  'גישה להטבות ולקופונים שמיועדים לחברי Premium.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Text(
                    'מסלולי הרכישה נמצאים בהכנה. נציג כאן רכישה מאובטחת ברגע שמנגנון התשלום יהיה מוכן.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_clock_rounded),
                  label: const Text('רכישת מנוי — בקרוב'),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _refreshing ? null : _refreshStatus,
                  icon: _refreshing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('כבר הצטרפתי — בדיקת המנוי'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.champagne.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.champagne),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
