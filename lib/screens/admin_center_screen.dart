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
import 'admin_coupon_statistics_screen.dart';
import 'admin_coupons_screen.dart';

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
      ]);
      final response = results[2] as FunctionResponse?;
      final data = response == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      setState(() {
        _reports = (results[0] as List).length + (results[3] as List).length;
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
                        crossAxisCount: desktop ? 2 : 1,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        childAspectRatio: desktop ? 2.35 : 2.75,
                        children: [
                          _AdminCard(
                            icon: Icons.card_giftcard_rounded,
                            title: 'ניהול קופונים',
                            subtitle: 'יצירה, עריכה, פרסום ושליחת פוש',
                            value: 'ניהול',
                            onTap: () => _open(const AdminCouponsScreen()),
                            enabled: Permissions.canManageContent,
                          ),
                          _AdminCard(
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
                            icon: Icons.category_outlined,
                            title: 'ניהול קטגוריות',
                            subtitle: 'הוספה, עריכה, מחיקה ושינוי סדר',
                            value: '$_categories',
                            onTap: () => _open(const AdminCategoriesScreen()),
                            enabled: Permissions.canManageContent,
                          ),
                          _AdminCard(
                            icon: Icons.people_outline_rounded,
                            title: 'ניהול משתמשים',
                            subtitle: 'חסימה, מחיקה ושליחת הודעה',
                            value: '$_users',
                            onTap: () => _open(const AdminUsersScreen()),
                            enabled: Permissions.canManageUsers,
                          ),
                          _AdminCard(
                            icon: Icons.query_stats_rounded,
                            title: 'סטטיסטיקות',
                            subtitle: 'משתמשים, פעילות, שיתופים ומיקום',
                            value: 'צפייה',
                            onTap: () => _open(const AdminStatisticsScreen()),
                          ),
                          _AdminCard(
                            icon: Icons.confirmation_number_outlined,
                            title: 'סטטיסטיקת קופונים',
                            subtitle: 'כניסות לקופון והצגות קוד',
                            value: 'צפייה',
                            onTap: () =>
                                _open(const AdminCouponStatisticsScreen()),
                          ),
                          const _AdminCard(
                            icon: Icons.campaign_outlined,
                            title: 'הודעות מערכת',
                            subtitle: 'שליחת עדכונים למשתמשים',
                            value: 'בהכנה',
                            enabled: false,
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
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final bool alert;
  final bool enabled;
  final VoidCallback? onTap;

  const _AdminCard({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(19),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: alert
                  ? AppColors.danger.withValues(alpha: 0.38)
                  : AppColors.champagne
                      .withValues(alpha: enabled ? 0.16 : 0.08),
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.champagne.withValues(alpha: 0.055),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: enabled ? AppColors.champagne : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: enabled
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: alert
                      ? AppColors.danger.withValues(alpha: 0.12)
                      : AppColors.background.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    color: alert ? AppColors.danger : AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
