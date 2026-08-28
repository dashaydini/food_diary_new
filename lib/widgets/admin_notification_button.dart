import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    await Permissions.load();

    if (!mounted) return;

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !Permissions.isAdmin) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AdminNotificationsScreen(),
          ),
        );
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
        child: Center(
          child: Icon(
            Icons.notifications_none_outlined,
            color: AppColors.champagne.withValues(alpha: 0.82),
            size: 20,
          ),
        ),
      ),
    );
  }
}
