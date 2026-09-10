import 'package:flutter/material.dart';

import '../../../core/services/privacy_consent_service.dart';
import '../../../theme/colors.dart';

class PrivacyConsentPromptGate extends StatefulWidget {
  const PrivacyConsentPromptGate({super.key, required this.child});

  final Widget child;

  @override
  State<PrivacyConsentPromptGate> createState() =>
      _PrivacyConsentPromptGateState();
}

class _PrivacyConsentPromptGateState extends State<PrivacyConsentPromptGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checked || !PrivacyConsentService.shouldRequestConsent) return;
    _checked = true;
    if (PrivacyConsentService.choice.value != PrivacyConsentChoice.undecided) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const _ConsentDialog(),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ConsentDialog extends StatelessWidget {
  const _ConsentDialog();

  Future<void> _save(BuildContext context, bool allowed) async {
    await PrivacyConsentService.setAdvertisingAllowed(allowed);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _manage(BuildContext context) async {
    var advertising = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (settingsContext) => StatefulBuilder(
        builder: (context, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surfaceRaised,
            title: const Text('ניהול העדפות פרטיות'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  onChanged: null,
                  title: Text('אחסון הכרחי'),
                  subtitle: Text('נדרש להתחברות, אבטחה והעדפות בסיסיות'),
                ),
                const Divider(),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: advertising,
                  onChanged: (value) => setState(() => advertising = value),
                  title: const Text('פרסום ומדידת פרסומות'),
                  subtitle: const Text(
                    'מאפשר ל־Google להציג ולמדוד פרסומות באמצעות מזהים ואחסון בדפדפן',
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(settingsContext).pop(advertising),
                child: const Text('שמירת הבחירה'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && context.mounted) await _save(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceRaised,
        icon: const Icon(
          Icons.shield_outlined,
          color: AppColors.champagne,
          size: 38,
        ),
        title: const Text('הפרטיות שלך חשובה לנו'),
        content: const Text(
          'אנחנו משתמשים באחסון הכרחי להפעלת האפליקציה. באישורך, Google תוכל להשתמש גם במזהים ובאחסון בדפדפן כדי להציג ולמדוד פרסומות. אפשר לשנות את הבחירה בכל עת בהגדרות.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => _save(context, false),
            child: const Text('דחייה'),
          ),
          OutlinedButton(
            onPressed: () => _manage(context),
            child: const Text('ניהול העדפות'),
          ),
          FilledButton(
            onPressed: () => _save(context, true),
            child: const Text('אישור'),
          ),
        ],
      ),
    );
  }
}
