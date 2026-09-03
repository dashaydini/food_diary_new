import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/shared_visit_service.dart';
import '../screens/visit_notifications_screen.dart';
import '../theme/colors.dart';

/// Refresh while the app is in use, on resume and after opening notifications.
/// This is an in-app indicator, not a background/mobile push subscription.
class VisitNotificationButton extends StatefulWidget {
  const VisitNotificationButton({super.key, this.mobile = true});
  final bool mobile;
  @override
  State<VisitNotificationButton> createState() =>
      _VisitNotificationButtonState();
}

class _VisitNotificationButtonState extends State<VisitNotificationButton>
    with WidgetsBindingObserver {
  Timer? _timer;
  StreamSubscription<AuthState>? _auth;
  int _count = 0;
  bool _failed = false;
  bool _fetching = false;
  final _client = Supabase.instance.client;
  bool get _signedIn =>
      _client.auth.currentUser != null &&
      !_client.auth.currentUser!.isAnonymous;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = _client.auth.onAuthStateChange.listen((_) {
      if (mounted) {
        setState(() {
          _count = 0;
          _failed = false;
        });
      }
      _refresh();
    });
    _start();
  }

  void _start() {
    _timer?.cancel();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
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
    if (!_signedIn || _fetching) return;
    final uid = _client.auth.currentUser!.id;
    _fetching = true;
    try {
      final count = await SharedVisitService(_client).unreadCount();
      if (mounted && uid == _client.auth.currentUser?.id) {
        setState(() {
          _count = count;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && uid == _client.auth.currentUser?.id) {
        setState(() => _failed = true);
      }
    } finally {
      _fetching = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _auth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_signedIn) return const SizedBox.shrink();
    return Tooltip(
      message: _failed ? 'הפעילות שלי — יש לנסות לרענן' : 'הפעילות שלי',
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const VisitNotificationsScreen()));
          if (mounted) _refresh();
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Semantics(
            label: _failed
                ? 'לא ניתן לעדכן את הפעילות'
                : _count > 0
                    ? '$_count תיוגים חדשים'
                    : 'אין תיוגים חדשים',
            child: Badge(
              key: const ValueKey('personal-activity-dot'),
              isLabelVisible: _count > 0 || _failed,
              backgroundColor: _failed ? AppColors.champagne : Colors.red,
              child: Container(
                width: widget.mobile ? 40 : 44,
                height: widget.mobile ? 40 : 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: AppColors.champagne.withValues(alpha: 0.16),
                      width: 0.8),
                ),
                child: Icon(Icons.people_outline_rounded,
                    size: widget.mobile ? 19 : 20, color: AppColors.champagne),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('הפעילות שלי',
              style: TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
        ]),
      ),
    );
  }
}
