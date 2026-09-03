import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A lightweight presence check, scoped to the manager's existing permissions.
/// The management screen retains its own bell and detailed counts.
class AdminPendingStatus extends StatefulWidget {
  const AdminPendingStatus(
      {super.key,
      required this.canManageContent,
      required this.canManageSupport,
      required this.builder});
  final bool canManageContent;
  final bool canManageSupport;
  final Widget Function(BuildContext, bool, VoidCallback) builder;
  @override
  State<AdminPendingStatus> createState() => _AdminPendingStatusState();
}

class _AdminPendingStatusState extends State<AdminPendingStatus>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _pending = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void didUpdateWidget(covariant AdminPendingStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.canManageContent != widget.canManageContent ||
        oldWidget.canManageSupport != widget.canManageSupport) {
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _refresh();
    if (widget.canManageContent || widget.canManageSupport) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    if (!widget.canManageContent && !widget.canManageSupport) {
      if (mounted) setState(() => _pending = false);
      return;
    }
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    try {
      final results = await Future.wait<List<dynamic>>([
        widget.canManageContent
            ? client
                .from('visit_image_reports')
                .select('id')
                .eq('status', 'new')
                .limit(1)
            : Future.value([]),
        widget.canManageSupport
            ? client
                .from('support_requests')
                .select('id')
                .inFilter('status', ['new', 'in_progress']).limit(1)
            : Future.value([]),
      ]);
      if (mounted &&
          generation == _generation &&
          uid == client.auth.currentUser?.id) {
        setState(() => _pending = results.any((rows) => rows.isNotEmpty));
      }
    } catch (_) {
      // Preserve the last known pending state through transient network errors.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _pending, _refresh);
}
