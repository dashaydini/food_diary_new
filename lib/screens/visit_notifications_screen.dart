import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/shared_visit_service.dart';
import '../theme/colors.dart';
import '../widgets/home_button.dart';
import 'add_visit_screen.dart';

class VisitNotificationsScreen extends StatefulWidget {
  const VisitNotificationsScreen({super.key});
  @override
  State<VisitNotificationsScreen> createState() =>
      _VisitNotificationsScreenState();
}

class _VisitNotificationsScreenState extends State<VisitNotificationsScreen> {
  late final _service = SharedVisitService(Supabase.instance.client);
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _more = false;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows =
          await _service.notifications(offset: more ? _rows.length : 0);
      if (!mounted) return;
      setState(() {
        _rows = more ? [..._rows, ...rows] : rows;
        _more = rows.length == 50;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'לא ניתן לטעון את הפעילות. נסה שוב.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> row) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final visit = await _service.visit(row['visit_id'].toString());
      final tag = await _service.ownTag(row['visit_id'].toString());
      if (visit == null || tag == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('החוויה או התיוג כבר אינם זמינים.')));
        }
        await _load();
        return;
      }
      final place = await Supabase.instance.client
          .from('places')
          .select('id,name,address,image_url,latitude,longitude,category_id')
          .eq('id', visit['place_id'])
          .single();
      await _service.markRead(row['id'].toString());
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            AddVisitScreen(place: place, visit: visit, viewOnly: true),
      ));
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('לא ניתן לפתוח את החוויה. נסה שוב.')));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('הפעילות שלי'),
            actions: const [HomeButton()],
          ),
          body: Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (_loading || _opening) const LinearProgressIndicator(),
                    if (_error != null)
                      TextButton.icon(
                          onPressed: () => _load(),
                          icon: const Icon(Icons.refresh),
                          label: Text(_error!)),
                    if (!_loading && _error == null && _rows.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('אין עדיין תיוגים בחוויות')),
                    for (final row in _rows) _notification(row),
                    if (_more)
                      TextButton(
                          onPressed: _loading ? null : () => _load(more: true),
                          child: const Text('פעילות נוספת')),
                  ],
                )),
          )),
        ),
      );

  Widget _notification(Map<String, dynamic> row) {
    final visit = row['visits'] as Map? ?? {};
    final profile = visit['profiles'] as Map? ?? {};
    final place = visit['places'] as Map? ?? {};
    final name = profile['display_name']?.toString().trim();
    final read = row['is_read'] == true;
    final date =
        DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal();
    return Card(
      color: AppColors.card,
      child: ListTile(
        onTap: _opening ? null : () => _open(row),
        leading: Icon(
            read ? Icons.alternate_email : Icons.mark_email_unread_outlined,
            color: read ? AppColors.textMuted : AppColors.champagne),
        title: Text(
            '${name?.isNotEmpty == true ? name : 'משתמש'} תייג אותך בחוויה ב${place['name'] ?? 'מקום'}',
            style: TextStyle(
                fontWeight: read ? FontWeight.normal : FontWeight.bold)),
        subtitle: Text(
            '${read ? 'נקראה' : 'חדש'}${date == null ? '' : ' · ${date.day}.${date.month}.${date.year}'}'),
      ),
    );
  }
}
