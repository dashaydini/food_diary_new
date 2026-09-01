import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../utils/app_preferences.dart';
import '../widgets/home_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _routeNotificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final routeNotificationsEnabled =
        await AppPreferences.routeNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _routeNotificationsEnabled = routeNotificationsEnabled;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('הגדרות אפליקציה'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      _section(
                        title: 'התראות',
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: _routeNotificationsEnabled,
                          title: const Text('התראות בדרך'),
                          subtitle: const Text(
                            'התראה על מקום מומלץ בהמשך המסלול. כבוי כברירת מחדל.',
                          ),
                          onChanged: (enabled) async {
                            setState(
                              () => _routeNotificationsEnabled = enabled,
                            );
                            await AppPreferences.setRouteNotificationsEnabled(
                                enabled);
                          },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
