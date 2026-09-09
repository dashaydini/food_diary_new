import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import '../screens/register_screen.dart';

class GuestSignupPrompt extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final VoidCallback? onRegister;

  const GuestSignupPrompt({
    super.key,
    required this.child,
    this.delay = const Duration(milliseconds: 700),
    this.onRegister,
  });

  @override
  State<GuestSignupPrompt> createState() => _GuestSignupPromptState();
}

class _GuestSignupPromptState extends State<GuestSignupPrompt> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePrompt());
  }

  Future<void> _schedulePrompt() async {
    if (_shown) return;
    _shown = true;
    if (widget.delay > Duration.zero) await Future<void>.delayed(widget.delay);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (dialogContext) =>
          _GuestSignupDialog(onRegister: widget.onRegister),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _GuestSignupDialog extends StatelessWidget {
  final VoidCallback? onRegister;

  const _GuestSignupDialog({this.onRegister});

  Future<void> _openRegistration(BuildContext context) async {
    final navigator = Navigator.of(context);
    navigator.pop();
    if (onRegister != null) {
      onRegister!();
      return;
    }
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          onAuthSuccess: navigator.pop,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        icon: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.surfaceRaised,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: AppColors.champagne.withValues(alpha: 0.48),
            ),
          ),
          child: const Icon(
            Icons.person_add_alt_1_outlined,
            color: AppColors.champagne,
            size: 29,
          ),
        ),
        title: const Text(
          'מוכנים לגלות את המקום הבא שלכם?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'מצטרפים בחינם ונותנים ל־BITE THE WAY להכיר את הטעם שלכם — כדי שכל המלצה תהיה קצת יותר מדויקת.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Column(
                    children: [
                      _Benefit('שמירת מקומות וחוויות ביומן האישי'),
                      _Benefit('קופונים והטבות לחברי הקהילה'),
                      _Benefit('המלצות שמותאמות לטעם ולהעדפות שלכם'),
                      _Benefit('שיתוף חוויות וקבלת עדכונים חשובים'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: () => _openRegistration(context),
                    child: const Text(
                      'מצטרפים בחינם',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('אולי אחר כך'),
                ),
                const Text(
                  'ההרשמה אורכת פחות מדקה וללא תשלום.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Benefit extends StatelessWidget {
  final String text;

  const _Benefit(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 21,
              height: 21,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.surfaceRaised,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.check, size: 13, color: AppColors.champagne),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}
