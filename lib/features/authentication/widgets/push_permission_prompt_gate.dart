import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/push_notification_service.dart';
import '../../../core/services/user_preferences_service.dart';
import '../../../theme/colors.dart';
import '../../../utils/app_preferences.dart';

class PushPermissionPromptGate extends StatefulWidget {
  const PushPermissionPromptGate({super.key, required this.child});

  final Widget child;

  @override
  State<PushPermissionPromptGate> createState() =>
      _PushPermissionPromptGateState();
}

class _PushPermissionPromptGateState extends State<PushPermissionPromptGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked) return;
    _checked = true;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    if (await AppPreferences.pushPermissionPrompted(user.id)) return;
    if (!await PushNotificationService.isSupported()) return;
    if (await PushNotificationService.isEnabled()) {
      await AppPreferences.setPushPermissionPrompted(user.id);
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceRaised,
          icon: const Icon(
            Icons.notifications_active_outlined,
            color: AppColors.champagne,
            size: 38,
          ),
          title: const Text('להישאר מעודכנים?'),
          content: const Text(
            'נוכל לעדכן אותך על קופונים חדשים ועל פעילות שחשובה לך באפליקציה. אפשר לשנות את הבחירה בכל רגע בהגדרות.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('לא עכשיו'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.notifications_none_rounded),
              label: const Text('כן, אפשר לעדכן אותי'),
            ),
          ],
        ),
      ),
    );
    await AppPreferences.setPushPermissionPrompted(user.id);
    final preferencesService = UserPreferencesService(Supabase.instance.client);
    if (accepted != true) {
      try {
        await preferencesService.saveNotificationPreferences(
          user.id,
          const UserNotificationPreferences(
            enabled: false,
            coupons: false,
            tags: false,
            newFollowers: false,
            systemMessages: false,
            managerNewExperience: false,
          ),
        );
        await AppPreferences.setRouteNotificationsEnabled(false);
      } catch (_) {}
      return;
    }
    try {
      await PushNotificationService.enable();
      await preferencesService.saveNotificationPreferences(
        user.id,
        const UserNotificationPreferences(),
      );
      await AppPreferences.setRouteNotificationsEnabled(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן להפעיל התראות כרגע. אפשר לנסות שוב בהגדרות.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
