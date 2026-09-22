import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';
import 'admin_categories_screen.dart';
import 'admin_coupons_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_place_managers_screen.dart';
import 'admin_users_screen.dart';

class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'admin-users',
        body: {'action': 'statistics'},
      );
      if (response.status < 200 || response.status >= 300) {
        throw StateError('statistics_failed');
      }
      final data = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      setState(() => _statistics = data);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'לא ניתן לטעון כרגע את נתוני המערכת');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _group(String key) {
    final value = _statistics[key];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  String _number(dynamic value) => ((value as num?)?.toInt() ?? 0).toString();

  String _decimal(dynamic value) {
    final number = (value as num?)?.toDouble();
    return number == null ? '—' : number.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final users = _group('users');
    final content = _group('content');
    final engagement = _group('engagement');
    final business = _group('business');
    final moderation = _group('moderation');
    final topCategory = content['top_category'] is Map
        ? Map<String, dynamic>.from(content['top_category'] as Map)
        : <String, dynamic>{};
    final pending = ((moderation['pending_support'] as num?) ?? 0) +
        ((moderation['pending_visit_reports'] as num?) ?? 0) +
        ((moderation['pending_image_reports'] as num?) ?? 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('סטטיסטיקות מערכת'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _load,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: _loading && _statistics.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                      children: [
                        if (_loading) const LinearProgressIndicator(),
                        if (_error != null) _errorCard(),
                        _section('משתמשים', Icons.people_outline_rounded, [
                          _Metric(
                              'משתמשים רשומים', _number(users['registered'])),
                          _Metric(
                              'פעילים ב־30 יום', _number(users['active_30d'])),
                          _Metric('חשבונות Premium', _number(users['premium'])),
                          _Metric('מנהלים', _number(users['admins'])),
                        ]),
                        _section('תוכן ופעילות', Icons.insights_outlined, [
                          _Metric('מקומות', _number(content['places'])),
                          _Metric('מקומות חדשים ב־30 יום',
                              _number(content['new_places_30d'])),
                          _Metric(
                              'כל החוויות', _number(content['experiences'])),
                          _Metric('חוויות ב־30 יום',
                              _number(content['experiences_30d'])),
                          _Metric('חוויות בשבוע',
                              _number(content['experiences_7d'])),
                          _Metric('משתמשים שתרמו חוויה',
                              _number(content['contributors'])),
                          _Metric('דירוג ממוצע',
                              _decimal(content['average_rating'])),
                          _Metric(
                            'קטגוריה מובילה',
                            topCategory.isEmpty
                                ? '—'
                                : '${topCategory['title']} (${_number(topCategory['count'])})',
                          ),
                          _Metric('מקומות עם מיקום במפה',
                              _number(content['geocoded_places'])),
                        ]),
                        _section('מעורבות קהילתית', Icons.groups_outlined, [
                          _Metric('קשרי מעקב', _number(engagement['follows'])),
                          _Metric('שמירות במועדפים',
                              _number(engagement['favorites'])),
                          _Metric('שמירות ברשימת משאלות',
                              _number(engagement['wishlist'])),
                          _Metric('משתמשים עם Push פעיל',
                              _number(engagement['push_users'])),
                        ]),
                        _section('עסקים וקופונים', Icons.storefront_outlined, [
                          _Metric('כל הקופונים', _number(business['coupons'])),
                          _Metric('קופונים פעילים',
                              _number(business['active_coupons'])),
                          _Metric('מנהלי עסקים', _number(business['managers'])),
                          _Metric('שיוכי מקומות פעילים',
                              _number(business['managed_places'])),
                        ]),
                        _section(
                          'טיפול וניהול',
                          Icons.health_and_safety_outlined,
                          [
                            _Metric('פניות פתוחות',
                                _number(moderation['pending_support'])),
                            _Metric('דיווחי חוויות',
                                _number(moderation['pending_visit_reports'])),
                            _Metric('דיווחי תמונות',
                                _number(moderation['pending_image_reports'])),
                          ],
                          alert: pending > 0,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'הנתונים מתעדכנים בעת פתיחת המסך או במשיכה לרענון.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorCard() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(child: Text(_error!)),
            TextButton(onPressed: _load, child: const Text('ניסיון נוסף')),
          ],
        ),
      );

  Widget _section(
    String title,
    IconData icon,
    List<_Metric> metrics, {
    bool alert = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: alert
              ? AppColors.danger.withValues(alpha: 0.42)
              : AppColors.champagne.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: alert ? AppColors.danger : AppColors.champagne),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 820
                  ? 4
                  : constraints.maxWidth >= 520
                      ? 2
                      : 1;
              final width =
                  (constraints.maxWidth - ((columns - 1) * 10)) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final metric in metrics)
                    SizedBox(width: width, child: _metricCard(metric)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metricCard(_Metric metric) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _openMetricDetails(metric),
          child: Container(
            constraints: const BoxConstraints(minHeight: 92),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(15),
              border:
                  Border.all(color: AppColors.champagne.withValues(alpha: 0.1)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  metric.value,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  metric.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11.5),
                ),
                const SizedBox(height: 5),
                const Icon(Icons.info_outline_rounded,
                    size: 14, color: AppColors.champagne),
              ],
            ),
          ),
        ),
      );

  void _openMetricDetails(_Metric metric) {
    final destination = _metricDestination(metric.label);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      showDragHandle: true,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(metric.label,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(metric.value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppColors.champagne,
                        fontSize: 32,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(_metricExplanation(metric.label),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppColors.textSecondary, height: 1.45)),
                if (destination != null) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => destination),
                      );
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('פתיחת מסך הניהול המתאים'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _metricDestination(String label) {
    if ({'משתמשים רשומים', 'פעילים ב־30 יום', 'חשבונות Premium', 'מנהלים'}
        .contains(label)) {
      return const AdminUsersScreen();
    }
    if ({'פניות פתוחות', 'דיווחי חוויות', 'דיווחי תמונות'}.contains(label)) {
      return const AdminNotificationsScreen();
    }
    if ({'כל הקופונים', 'קופונים פעילים'}.contains(label)) {
      return const AdminCouponsScreen();
    }
    if ({'מנהלי עסקים', 'שיוכי מקומות פעילים'}.contains(label)) {
      return const AdminPlaceManagersScreen();
    }
    if (label == 'קטגוריה מובילה') return const AdminCategoriesScreen();
    return null;
  }

  String _metricExplanation(String label) => switch (label) {
        'משתמשים רשומים' =>
          'כל החשבונות הרשומים, ללא משתמשים אנונימיים או אורחים.',
        'פעילים ב־30 יום' =>
          'משתמשים שביצעו כניסה לחשבון במהלך 30 הימים האחרונים.',
        'חשבונות Premium' => 'מנויי Premium פעילים שמועד התוקף שלהם לא חלף.',
        'מנהלים' => 'חשבונות בעלי הרשאת ניהול פעילה.',
        'מקומות' => 'כל המקומות הקיימים כרגע במאגר.',
        'מקומות חדשים ב־30 יום' => 'מקומות שנוצרו במהלך 30 הימים האחרונים.',
        'כל החוויות' => 'כל החוויות והביקורות שנשמרו באפליקציה.',
        'חוויות ב־30 יום' => 'חוויות שנוספו במהלך 30 הימים האחרונים.',
        'חוויות בשבוע' => 'חוויות שנוספו במהלך שבעת הימים האחרונים.',
        'משתמשים שתרמו חוויה' =>
          'מספר המשתמשים הייחודיים שכתבו לפחות חוויה אחת.',
        'דירוג ממוצע' => 'הממוצע של כל דירוגי החוויות בעלי ציון.',
        'קטגוריה מובילה' => 'הקטגוריה שבה נמצא מספר המקומות הגדול ביותר.',
        'מקומות עם מיקום במפה' => 'מקומות שנשמרו עבורם קווי רוחב ואורך תקינים.',
        'קשרי מעקב' => 'מספר קשרי המעקב הפעילים בין משתמשים.',
        'שמירות במועדפים' => 'מספר כל השמירות שסומנו כמועדפים.',
        'שמירות ברשימת משאלות' => 'מספר כל השמירות שסומנו ברשימת המשאלות.',
        'משתמשים עם Push פעיל' =>
          'משתמשים ייחודיים שלפחות מכשיר אחד שלהם רשום להתראות Push.',
        'כל הקופונים' => 'כל הקופונים, כולל טיוטות וקופונים שפג תוקפם.',
        'קופונים פעילים' => 'קופונים שפורסמו ותאריך התוקף שלהם טרם חלף.',
        'מנהלי עסקים' => 'משתמשים ייחודיים שמנהלים לפחות מקום אחד.',
        'שיוכי מקומות פעילים' => 'כל החיבורים הפעילים בין מנהלים למקומות.',
        'פניות פתוחות' => 'פניות הנהלה במצב חדש או בטיפול.',
        'דיווחי חוויות' => 'דיווחים חדשים על חוויות שממתינים לטיפול.',
        'דיווחי תמונות' => 'דיווחים חדשים על תמונות שממתינים לטיפול.',
        _ => 'הנתון מחושב בזמן פתיחת המסך ומתעדכן במשיכה לרענון.',
      };
}

class _Metric {
  final String label;
  final String value;

  const _Metric(this.label, this.value);
}
