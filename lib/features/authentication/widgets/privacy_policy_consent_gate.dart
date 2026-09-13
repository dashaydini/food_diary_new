import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/user_preferences_service.dart';
import '../../../screens/legal_screens.dart';
import '../../../theme/colors.dart';
import '../../../utils/app_preferences.dart';

class PrivacyPolicyConsentGate extends StatefulWidget {
  const PrivacyPolicyConsentGate({super.key, required this.child});

  final Widget child;

  @override
  State<PrivacyPolicyConsentGate> createState() =>
      _PrivacyPolicyConsentGateState();
}

class _PrivacyPolicyConsentGateState extends State<PrivacyPolicyConsentGate> {
  late final UserPreferencesService _service;
  late Future<bool> _accepted;
  bool _checked = false;
  bool _saving = false;
  bool _isPolicyUpdate = false;

  @override
  void initState() {
    super.initState();
    _service = UserPreferencesService(Supabase.instance.client);
    _accepted = _load();
  }

  Future<bool> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return true;
    final acceptedVersion =
        await _service.acceptedPrivacyPolicyVersion(user.id);
    final createdAt = DateTime.tryParse(user.createdAt);
    _isPolicyUpdate = acceptedVersion != null ||
        (createdAt != null &&
            createdAt.isBefore(UserPreferencesService.privacyPolicyUpdatedAt));
    return acceptedVersion == UserPreferencesService.privacyPolicyVersion;
  }

  Future<void> _accept() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous || !_checked) return;
    setState(() => _saving = true);
    try {
      await _service.acceptCurrentPrivacyPolicy(user.id);
      await AppPreferences.setLocationFeaturesEnabled(true);
      try {
        if (await Geolocator.isLocationServiceEnabled() &&
            await Geolocator.checkPermission() == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
      } catch (_) {}
      if (mounted) setState(() => _accepted = Future.value(true));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן לשמור את האישור. נסו שוב.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _accepted,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: FilledButton.icon(
                  onPressed: () => setState(() => _accepted = _load()),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('ניסיון נוסף'),
                ),
              ),
            );
          }
          if (snapshot.data == true) return widget.child;
          return PrivacyAcceptanceScreen(
            isUpdate: _isPolicyUpdate,
            checked: _checked,
            saving: _saving,
            onChanged: (value) => setState(() => _checked = value),
            onAccept: _accept,
          );
        },
      );
}

class PrivacyAcceptanceScreen extends StatelessWidget {
  const PrivacyAcceptanceScreen({
    super.key,
    this.isUpdate = false,
    required this.checked,
    required this.saving,
    required this.onChanged,
    required this.onAccept,
  });

  final bool isUpdate;
  final bool checked;
  final bool saving;
  final ValueChanged<bool> onChanged;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 24),
                  const Icon(
                    Icons.privacy_tip_outlined,
                    size: 52,
                    color: AppColors.champagne,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isUpdate
                        ? 'מדיניות הפרטיות עודכנה'
                        : 'הפרטיות שלך חשובה לנו',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isUpdate
                        ? 'הוספנו למדיניות הקיימת הסבר ברור על שירותי המיקום ועל סוגי ההתראות. ההעדפות פעילות כברירת מחדל, בכפוף לאישור המכשיר, ואפשר לשנות אותן בכל רגע בהגדרות.'
                        : 'לפני שמתחילים, חשוב לקרוא ולאשר את מדיניות הפרטיות. תכונות המיקום וההתראות פעילות כברירת מחדל, בכפוף לאישור המכשיר, ואפשר לשנות אותן בכל רגע בהגדרות.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('לקריאת מדיניות הפרטיות'),
                  ),
                  const SizedBox(height: 14),
                  CheckboxListTile(
                    value: checked,
                    onChanged:
                        saving ? null : (value) => onChanged(value == true),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'קראתי ואני מאשר/ת את מדיניות הפרטיות',
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: checked
                        ? FilledButton.icon(
                            key: const ValueKey('continue'),
                            onPressed: saving ? null : onAccept,
                            icon: saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_back_rounded),
                            label: const Text('המשך לאפליקציה'),
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('hidden'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
