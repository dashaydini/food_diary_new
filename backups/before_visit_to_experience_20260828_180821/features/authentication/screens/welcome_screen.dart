import 'package:flutter/material.dart';

import '../../../theme/colors.dart';
import '../widgets/auth_brand_hero.dart';
import '../widgets/auth_brand_divider.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  final VoidCallback onGuest;

  const WelcomeScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
    required this.onGuest,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 34,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 68,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 460,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AuthBrandHero(),
                        const SizedBox(height: 12),
                        const AuthBrandDivider(),
                        const SizedBox(height: 26),
                        const Text(
                          'הטעם שלך.\nהיומן שלך.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 39,
                            height: 1.18,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -0.7,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'שמור מקומות, תעד ביקורים\nוגלה מחדש את החוויות שאהבת.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.65,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(
                            22,
                            28,
                            22,
                            24,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.cardBorder,
                              width: 0.8,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'מתחילים כאן',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 7),
                              const Text(
                                'הצטרף ל־Bite The Way ושמור את כל החוויות שלך במקום אחד',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 25),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: FilledButton(
                                  onPressed: onRegister,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.champagne,
                                    foregroundColor: AppColors.background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                  child: const Text(
                                    'יצירת חשבון',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: OutlinedButton(
                                  onPressed: onLogin,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: const BorderSide(
                                      color: AppColors.cardBorder,
                                      width: 0.8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                  child: const Text(
                                    'כבר יש לי חשבון',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              TextButton(
                                onPressed: onGuest,
                                child: const Text(
                                  'המשך כאורח',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.champagneSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 34),
                        const Text(
                          'DISCOVER  •  TASTE  •  REMEMBER',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2.6,
                            color: AppColors.textMuted,
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
