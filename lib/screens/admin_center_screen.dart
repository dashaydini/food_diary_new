import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';
import '../widgets/admin_notification_button.dart';
import 'admin_categories_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_statistics_screen.dart';
import 'admin_users_screen.dart';
import 'admin_coupons_screen.dart';
import 'admin_place_managers_screen.dart';
import 'admin_place_category_screen.dart';
import 'user_tutorial_screen.dart';
import 'admin_system_notifications_screen.dart';

class AdminCenterScreen extends StatefulWidget {
  const AdminCenterScreen({super.key});

  @override
  State<AdminCenterScreen> createState() => _AdminCenterScreenState();
}

class _AdminCenterScreenState extends State<AdminCenterScreen> {
  int _reports = 0;
  int _categories = 0;
  int _users = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    if (!Permissions.isAdmin) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final results = await Future.wait<dynamic>([
        Permissions.canManageContent
            ? Supabase.instance.client
                .from('visit_image_reports')
                .select('id')
                .eq('status', 'new')
            : Future<List<dynamic>>.value(const []),
        Supabase.instance.client.from('categories').select('id'),
        Permissions.canManageUsers
            ? Supabase.instance.client.functions
                .invoke('admin-users', body: {'action': 'list'})
            : Future<FunctionResponse?>.value(),
        Permissions.canManageSupport
            ? Supabase.instance.client
                .from('support_requests')
                .select('id')
                .inFilter('status', ['new', 'in_progress'])
            : Future<List<dynamic>>.value(const []),
        Permissions.canManageContent
            ? Supabase.instance.client
                .from('visit_reports')
                .select('id')
                .eq('status', 'new')
            : Future<List<dynamic>>.value(const []),
      ]);
      final response = results[2] as FunctionResponse?;
      final data = response == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      setState(() {
        _reports = (results[0] as List).length +
            (results[3] as List).length +
            (results[4] as List).length;
        _categories = (results[1] as List).length;
        _users = (data['users'] as List? ?? const []).length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _loadSummary();
  }

  @override
  Widget build(BuildContext context) {
    if (!Permissions.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('מרכז ניהול')),
        body: const Center(child: Text('אין הרשאת גישה')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('מרכז ניהול'),
        centerTitle: true,
        actions: const [
          AdminNotificationButton(),
          SizedBox(width: 8),
          HomeButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        color: AppColors.champagne,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 720;
            final compactCards = constraints.maxWidth < 600;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    desktop ? 28 : 16,
                    desktop ? 24 : 16,
                    desktop ? 28 : 16,
                    36,
                  ),
                  children: [
                    const Text(
                      'סקירה וניהול',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'כל כלי הניהול במקום אחד',
                      textAlign: TextAlign.right,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 22),
                    if (_loading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppColors.champagne,
                          ),
                        ),
                      )
                    else
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        mainAxisSpacing: compactCards ? 10 : 14,
                        crossAxisSpacing: compactCards ? 10 : 14,
                        childAspectRatio: compactCards ? 0.82 : 2.05,
                        children: [
                          _AdminCard(
                            compact: compactCards,
                            icon: Icons.card_giftcard_rounded,
                            title: 'ניהול קופונים',
                            subtitle: 'יצירה, עריכה, פרסום ושליחת פוש',
                            value: 'ניהול',
                            onTap: () => _open(const AdminCouponsScreen()),
                            enabled: Permissions.canManageContent,
                          ),
                          _AdminCard(
                            compact: compactCards,
                            icon: Icons.flag_outlined,
                            title: 'דיווחים ופניות',
                            subtitle: 'דיווחים ופניות שממתינים לטיפול',
                            value: _reports == 0 ? 'נקי' : '$_reports',
                            alert: _reports > 0,
                            onTap: () =>
                                _open(const AdminNotificationsScreen()),
                            enabled: Permissions.canManageContent ||
                                Permissions.canManageSupport,
                          ),
                          _AdminCard(
                            compact: compactCards,
                            icon: Icons.category_outlined,
                            title: 'ניהול קטגוריות',
                            subtitle: 'הוספה, עריכה, מחיקה ושינוי סדר',
                            value: '$_categories',
                            onTap: () => _open(const AdminCategoriesScreen()),
                            enabled: Permissions.canManageContent,
                          ),
                          _AdminCard(
                            compact: compactCards,
                            icon: Icons.swap_horiz_rounded,
                            title: 'העברת מקום',
                            subtitle: 'תיקון קטגוריה למקום',
                            value: 'ניהול',
                            onTap: () =>
                                _open(const AdminPlaceCategoryScreen()),
                            enabled: Permissions.isAdmin,
                          ),
                          _AdminCard(
                            compact: compactCards,
                            icon: Icons.people_outline_rounded,
                            title: 'ניהול משתמשים',
                            subtitle: 'חסימה, מחיקה ושליחת הודעה',
                            value: '$_users',
                            onTap: () => _open(const AdminUsersScreen()),
                            enabled: Permissions.canManageUsers,
                          ),
                          _AdminCard(
                            compact: compactCards,
                            icon: Icons.storefront_rounded,
                            title: 'מנהלי מקומות',
                            subtitle: 'שיוך משתמש והרשאות נפרדות לכל מקום',
                            value: 'ניהול',
                            onTap: () =>
                                _open(const AdminPlaceManagersScreen()),
                            enabled: Permissions.canManageUsers,
                          ),
                          _AdminCard(
                            compact: compactCards,
                            icon: Icons.school_outlined,
                            title: 'מסך היכרות',
                            subtitle: 'תצוגה מקדימה של סיפור האפליקציה',
                            value: 'הפעלה',
                            onTap: () => _open(const UserTutorialScreen()),
                          ),
                          _AdminCard(
                            compact: compactCards,
                            icon: Icons.query_stats_rounded,
                            title: 'סטטיסטיקות',
                            subtitle: 'משתמשים, פעילות, שיתופים ומיקום',
                            value: 'צפייה',
                            onTap: () => _open(const AdminStatisticsScreen()),
                          ),
                          _AdminCard(
                            compact: compactCards,
                            icon: Icons.campaign_outlined,
                            title: 'הודעות מערכת',
                            subtitle: 'שליחת עדכוני פוש לכל המשתמשים',
                            value: 'שליחה',
                            enabled: Permissions.isFullAdmin,
                            onTap: () =>
                                _open(const AdminSystemNotificationsScreen()),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final bool compact;
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final bool alert;
  final bool enabled;
  final VoidCallback? onTap;

  const _AdminCard({
    required this.compact,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.alert = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      width: compact ? 34 : 48,
      height: compact ? 34 : 48,
      decoration: BoxDecoration(
        color: AppColors.champagne.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(compact ? 11 : 14),
      ),
      child: Icon(
        icon,
        size: compact ? 19 : 24,
        color: enabled ? AppColors.champagne : AppColors.textMuted,
      ),
    );
    final details = Column(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment:
          compact ? MainAxisAlignment.center : MainAxisAlignment.center,
      crossAxisAlignment:
          compact ? CrossAxisAlignment.center : CrossAxisAlignment.end,
      children: [
        Text(
          title,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.right,
          style: TextStyle(
            color: enabled ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: compact ? 12 : 16,
            fontWeight: FontWeight.w600,
            height: compact ? 1.15 : null,
          ),
        ),
        SizedBox(height: compact ? 3 : 5),
        Text(
          subtitle,
          maxLines: compact ? 2 : 2,
          overflow: TextOverflow.ellipsis,
          textAlign: compact ? TextAlign.center : TextAlign.right,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: compact ? 9.5 : 11.5,
            height: compact ? 1.25 : 1.35,
          ),
        ),
      ],
    );
    final valueBadge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 10,
        vertical: compact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: alert
            ? AppColors.danger.withValues(alpha: 0.12)
            : AppColors.background.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(compact ? 9 : 12),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: alert ? AppColors.danger : AppColors.textSecondary,
          fontSize: compact ? 9 : 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(19),
        child: Ink(
          padding: EdgeInsets.all(compact ? 10 : 17),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(compact ? 16 : 19),
            border: Border.all(
              color: alert
                  ? AppColors.danger.withValues(alpha: 0.38)
                  : AppColors.champagne
                      .withValues(alpha: enabled ? 0.16 : 0.08),
            ),
          ),
          child: compact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [iconBox, details, valueBadge],
                )
              : Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    iconBox,
                    const SizedBox(width: 14),
                    Expanded(child: details),
                    const SizedBox(width: 10),
                    valueBadge,
                  ],
                ),
        ),
      ),
    );
  }
}
