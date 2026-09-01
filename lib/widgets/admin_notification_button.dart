import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/admin_notifications_screen.dart';
import '../theme/colors.dart';
import '../utils/permissions.dart';

class AdminNotificationButton extends StatefulWidget {
  const AdminNotificationButton({super.key});

  @override
  State<AdminNotificationButton> createState() =>
      _AdminNotificationButtonState();
}

class _AdminNotificationButtonState extends State<AdminNotificationButton> {
  bool _loading = true;
  int _pendingCount = 0;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    await Permissions.load();

    if (!mounted) return;
    if (!Permissions.isAdmin) {
      setState(() => _loading = false);
      return;
    }
    await _loadCount();
    _subscribeToChanges();
  }

  Future<void> _loadCount() async {
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait<List<dynamic>>([
        Permissions.canManageContent
            ? client
                .from('visit_image_reports')
                .select('id')
                .eq('status', 'new')
            : Future<List<dynamic>>.value(const []),
        Permissions.canManageSupport
            ? client
                .from('support_requests')
                .select('id')
                .inFilter('status', ['new', 'in_progress'])
            : Future<List<dynamic>>.value(const []),
      ]);
      if (!mounted) return;
      setState(() {
        _pendingCount = results[0].length + results[1].length;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeToChanges() {
    if (_channel != null) return;
    _channel = Supabase.instance.client
        .channel('admin-pending-${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'visit_image_reports',
          callback: (_) => _loadCount(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'support_requests',
          callback: (_) => _loadCount(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      Supabase.instance.client.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !Permissions.isAdmin) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AdminNotificationsScreen(),
          ),
        );
        if (mounted) await _loadCount();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.champagne.withValues(alpha: 0.22),
            width: 0.75,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.champagne.withValues(alpha: 0.03),
              blurRadius: 16,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Icon(
                _pendingCount > 0
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_outlined,
                color: AppColors.champagne.withValues(alpha: 0.82),
                size: 20,
              ),
            ),
            if (_pendingCount > 0)
              Positioned(
                top: -5,
                left: -5,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  height: 19,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.background, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _pendingCount > 99 ? '99+' : '$_pendingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
