import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';

class AdminCouponStatisticsScreen extends StatefulWidget {
  final String? placeId;
  final String? placeName;

  const AdminCouponStatisticsScreen({
    super.key,
    this.placeId,
    this.placeName,
  });

  @override
  State<AdminCouponStatisticsScreen> createState() =>
      _AdminCouponStatisticsScreenState();
}

class _AdminCouponStatisticsScreenState
    extends State<AdminCouponStatisticsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _visits = [];
  Map<String, Map<String, dynamic>> _usersById = {};
  int _periodDays = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Permissions.isAdmin && widget.placeId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final from = DateTime.now()
          .subtract(Duration(days: _periodDays))
          .toUtc()
          .toIso8601String();
      var visitQuery = Supabase.instance.client
          .from('visits')
          .select('id,user_id,rating,visit_date,created_at')
          .gte('created_at', from);
      if (widget.placeId != null) {
        visitQuery = visitQuery.eq('place_id', widget.placeId!);
      }
      final visitRows =
          await visitQuery.order('created_at', ascending: false).limit(5000);
      _visits = List<Map<String, dynamic>>.from(visitRows);
      var eventQuery = Supabase.instance.client
          .from('coupon_events')
          .select('coupon_id,event_type,user_id,created_at')
          .gte('created_at', from);
      var loadCouponEvents = true;
      if (widget.placeId != null) {
        final couponRows = await Supabase.instance.client
            .from('coupons')
            .select('id')
            .eq('place_id', widget.placeId!);
        final couponIds = List<Map<String, dynamic>>.from(couponRows)
            .map((row) => row['id']?.toString())
            .whereType<String>()
            .toList();
        if (couponIds.isEmpty) {
          loadCouponEvents = false;
        } else {
          eventQuery = eventQuery.inFilter('coupon_id', couponIds);
        }
      }
      final rows = loadCouponEvents
          ? List<Map<String, dynamic>>.from(await eventQuery
              .order('created_at', ascending: false)
              .limit(5000))
          : <Map<String, dynamic>>[];
      final userIds = rows
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final usersById = <String, Map<String, dynamic>>{};
      if (Permissions.canManageUsers) {
        final response = await Supabase.instance.client.functions
            .invoke('admin-users', body: {'action': 'list'});
        final data = Map<String, dynamic>.from(response.data as Map);
        for (final raw in data['users'] as List? ?? const []) {
          if (raw is! Map) continue;
          final user = Map<String, dynamic>.from(raw);
          final id = user['id']?.toString();
          if (id != null && userIds.contains(id)) usersById[id] = user;
        }
      } else if (userIds.isNotEmpty) {
        final profiles = await Supabase.instance.client
            .from('profiles')
            .select('id,display_name')
            .inFilter('id', userIds);
        for (final raw in List<Map<String, dynamic>>.from(profiles)) {
          usersById[raw['id'].toString()] = raw;
        }
      }
      if (!mounted) return;
      setState(() {
        _events = rows;
        _usersById = usersById;
      });
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
    final visitors =
        _visits.map((e) => e['user_id']).whereType<String>().toSet();
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
        title: Text(widget.placeName == null
            ? 'סטטיסטיקה'
            : 'סטטיסטיקה · ${widget.placeName}'),
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
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final option in const [
                    (7, 'שבוע'),
                    (30, 'חודש'),
                    (90, '3 חודשים'),
                    (365, 'שנה')
                  ])
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: _periodDays == option.$1,
                      onSelected: (_) {
                        setState(() => _periodDays = option.$1);
                        _load();
                      },
                    ),
                ]),
                const SizedBox(height: 14),
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
                    _StatTile('חוויות שנוספו', _visits.length,
                        Icons.store_mall_directory_outlined),
                    _StatTile('משתמשים שביקרו', visitors.length,
                        Icons.groups_outlined),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'כל חוויה שנוספה מייצגת ביקור שתועד. מספר המשתמשים שביקרו סופר חשבונות ייחודיים.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 22),
                const Text(
                  'פעילות משתמשים אחרונה',
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
                const SizedBox(height: 12),
                if (_events.isEmpty)
                  const Text('עדיין אין פעילות')
                else
                  for (final event in _events.take(100)) _activityTile(event),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> event) {
    final id = event['user_id']?.toString() ?? '';
    final user = _usersById[id];
    final name = user?['display_name']?.toString().trim();
    final email = user?['email']?.toString().trim();
    final label = name?.isNotEmpty == true
        ? name!
        : email?.isNotEmpty == true
            ? email!
            : 'משתמש ${id.length > 8 ? id.substring(0, 8) : id}';
    final date =
        DateTime.tryParse(event['created_at']?.toString() ?? '')?.toLocal();
    final dateText = date == null
        ? ''
        : '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Card(
      child: ListTile(
        leading: Icon(event['event_type'] == 'code_view'
            ? Icons.qr_code_2_rounded
            : Icons.touch_app_outlined),
        title: Text(label),
        subtitle: Text(event['event_type'] == 'code_view'
            ? 'הציג/ה את קוד הקופון'
            : 'נכנס/ה לקופון'),
        trailing: Text(dateText,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
