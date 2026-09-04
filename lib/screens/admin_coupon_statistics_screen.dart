import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';

class AdminCouponStatisticsScreen extends StatefulWidget {
  const AdminCouponStatisticsScreen({super.key});

  @override
  State<AdminCouponStatisticsScreen> createState() =>
      _AdminCouponStatisticsScreenState();
}

class _AdminCouponStatisticsScreenState
    extends State<AdminCouponStatisticsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Permissions.isAdmin) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('coupon_events')
          .select('coupon_id,event_type,user_id,created_at')
          .order('created_at', ascending: false)
          .limit(5000);
      if (!mounted) return;
      setState(() => _events = List<Map<String, dynamic>>.from(rows));
    } catch (_) {
      if (mounted) setState(() => _error = 'לא ניתן לטעון את הנתונים כרגע');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final opens = _events.where((e) => e['event_type'] == 'coupon_open').length;
    final codeViews =
        _events.where((e) => e['event_type'] == 'code_view').length;
    final users = _events.map((e) => e['user_id']).whereType<String>().toSet();
    final today = DateTime.now();
    final todayViews = _events.where((event) {
      final date =
          DateTime.tryParse(event['created_at']?.toString() ?? '')?.toLocal();
      return event['event_type'] == 'code_view' &&
          date != null &&
          date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
    }).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('סטטיסטיקת קופונים'),
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_error!, textAlign: TextAlign.center),
                )
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatTile('כניסות לקופון', opens, Icons.touch_app_outlined),
                    _StatTile('הצגות קוד', codeViews, Icons.qr_code_2_rounded),
                    _StatTile(
                        'משתמשים ייחודיים', users.length, Icons.people_outline),
                    _StatTile(
                        'הצגות קוד היום', todayViews, Icons.today_outlined),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'קפה לבחירה במתנה',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'הצגת קוד משקפת כוונת מימוש. לאישור מימוש בפועל נדרש אימות של בית העסק.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _StatTile(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.champagne),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 25,
                        fontWeight: FontWeight.w700)),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
