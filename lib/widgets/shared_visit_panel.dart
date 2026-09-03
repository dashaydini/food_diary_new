import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/shared_visit_service.dart';
import '../screens/add_visit_screen.dart';
import '../theme/colors.dart';
import 'visit_card.dart';

class SharedVisitPanel extends StatefulWidget {
  const SharedVisitPanel(
      {super.key,
      required this.visitId,
      required this.place,
      required this.onTagRemoved});
  final String visitId;
  final Map<String, dynamic> place;
  final VoidCallback onTagRemoved;

  @override
  State<SharedVisitPanel> createState() => _SharedVisitPanelState();
}

class _SharedVisitPanelState extends State<SharedVisitPanel> {
  late final _service = SharedVisitService(Supabase.instance.client);
  Map<String, dynamic>? _source;
  Map<String, dynamic>? _tag;
  Map<String, dynamic>? _own;
  List<Map<String, dynamic>> _visits = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final source = await _service.visit(widget.visitId);
      final visits = source == null
          ? <Map<String, dynamic>>[]
          : await _service.outing(source['outing_id'].toString());
      final tag = await _service.ownTag(widget.visitId);
      if (tag != null) await _service.markRead(tag['id'].toString());
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (!mounted) return;
      setState(() {
        _source = source;
        _visits = visits;
        _tag = tag;
        _own = visits.where((v) => v['user_id'] == uid).firstOrNull;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'לא ניתן לטעון את החוויות מאותו ביקור';
        });
      }
    }
  }

  Future<void> _openOwn() async {
    if (_source == null || _busy) return;
    setState(() => _busy = true);
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => AddVisitScreen(
        place: widget.place,
        visit: _own,
        viewOnly: _own != null,
        sourceVisit: _own == null ? _source : null,
      ),
    ));
    if (!mounted) return;
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _remove() async {
    final tag = _tag;
    if (tag == null || _busy) return;
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('הסרת התיוג שלי'),
              content: const Text(
                  'התיוג יוסר מהחוויה. חוויה אישית שכבר כתבת לא תימחק.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('ביטול')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('הסרת התיוג')),
              ],
            ));
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.removeOwnTag(tag['id'].toString());
      widget.onTagRemoved();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('התיוג לא הוסר. אפשר לנסות שוב.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.all(12), child: LinearProgressIndicator());
    }
    if (_error != null) {
      return TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_error!));
    }
    if (_source == null || (_tag == null && _visits.length < 2)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_tag != null) ...[
          const Text('תויגת בחוויה הזו',
              style: TextStyle(color: AppColors.champagne)),
          const SizedBox(height: 8),
        ],
        if ((_tag != null || _own != null) && _own?['id'] != widget.visitId)
          OutlinedButton.icon(
              onPressed: _busy ? null : _openOwn,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('החוויה שלי מהביקור')),
        if (_tag != null)
          TextButton(
              onPressed: _busy ? null : _remove,
              child: const Text('הסרת התיוג שלי')),
        if (_visits.length > 1) ...[
          const SizedBox(height: 12),
          const Text('חוויות מאותו ביקור',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Text('ביקור משותף, חוויה אישית לכל משתתף',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 10),
          for (final visit in _visits.where((v) => v['id'] != widget.visitId))
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VisitCard(
                    visit: visit, place: widget.place, onChanged: _load)),
        ],
      ]),
    );
  }
}
