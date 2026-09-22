import 'package:flutter/material.dart';

import '../screens/premium_upgrade_screen.dart';
import '../theme/colors.dart';

enum PremiumPreviewAction { upgrade, leave }

Future<PremiumPreviewAction?> showPremiumPreviewDialog(
  BuildContext context, {
  required String featureName,
  required String benefit,
}) {
  return showDialog<PremiumPreviewAction>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      icon: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.champagne.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.champagne,
          size: 30,
        ),
      ),
      title: Text('אהבת את $featureName?'),
      content: Text(
        'זו הייתה טעימה מ־BITE THE WAY Premium. $benefit\n\nבחשבון Premium אפשר להמשיך להשתמש באפשרות הזו בלי הגבלה.',
        textAlign: TextAlign.center,
        style: const TextStyle(height: 1.5),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext)
              .pop(PremiumPreviewAction.leave),
          child: const Text('אולי אחר כך'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(dialogContext)
              .pop(PremiumPreviewAction.upgrade),
          icon: const Icon(Icons.workspace_premium_rounded),
          label: const Text('למסלולי Premium'),
        ),
      ],
    ),
  );
}

Future<bool> openPremiumUpgrade(
  BuildContext context, {
  required String sourceFeature,
}) async {
  final upgraded = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => PremiumUpgradeScreen(sourceFeature: sourceFeature),
    ),
  );
  return upgraded == true;
}
