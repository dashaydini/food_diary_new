import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import '../../../utils/app_preferences.dart';
import '../../authentication/widgets/auth_brand_divider.dart';
import '../../authentication/widgets/auth_brand_hero.dart';

class FirstLaunchGate extends StatefulWidget {
  final Widget child;

  const FirstLaunchGate({
    super.key,
    required this.child,
  });

  @override
  State<FirstLaunchGate> createState() => _FirstLaunchGateState();
}

class _FirstLaunchGateState extends State<FirstLaunchGate> {
  late final Future<bool> _completed = AppPreferences.firstLaunchCompleted();
  bool _completedLocally = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _completed,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true || _completedLocally) return widget.child;

        return FirstLaunchScreen(
          onCompleted: () async {
            await AppPreferences.setFirstLaunchCompleted();
            if (mounted) {
              setState(() {
                _completedLocally = true;
              });
            }
          },
        );
      },
    );
  }
}

class FirstLaunchScreen extends StatelessWidget {
  final Future<void> Function() onCompleted;

  const FirstLaunchScreen({
    super.key,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 36),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 66,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AuthBrandHero(),
                        const SizedBox(height: 12),
                        const AuthBrandDivider(),
                        const SizedBox(height: 28),
                        const Text(
                          'לא רק למצוא מקום.\nלזכור את החוויה.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 35,
                            height: 1.2,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 13),
                        const Text(
                          'BITE THE WAY הוא היומן הקולינרי האישי שלך — למקומות, לטעמים ולאנשים שהיו איתך בדרך.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _FeatureRow(
                          icon: Icons.menu_book_outlined,
                          title: 'היומן שלך',
                          description:
                              'תעד ביקורים, דירוגים, תמונות ומה באמת אהבת.',
                        ),
                        const SizedBox(height: 12),
                        const _FeatureRow(
                          icon: Icons.auto_awesome_outlined,
                          title: 'המלצות שמתאימות לך',
                          description:
                              'גלה מקומות לפי הטעם האישי שלך, לא רק לפי פופולריות.',
                        ),
                        const SizedBox(height: 12),
                        const _FeatureRow(
                          icon: Icons.people_alt_outlined,
                          title: 'חוויות משותפות',
                          description:
                              'שתף ביקורים, תייג חברים והכיר מקומות דרך הקהילה.',
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: FilledButton(
                            onPressed: onCompleted,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.champagne,
                              foregroundColor: AppColors.background,
                            ),
                            child: const Text(
                              'מתחילים לגלות',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.champagne.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.champagne, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
