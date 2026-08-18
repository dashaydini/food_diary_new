import 'package:flutter/material.dart';

import '../../../theme/colors.dart';

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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Food Diary',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'יומן האוכל שלך',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 64),
                const Text(
                  'פעם ראשונה באפליקציה?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 28,
                  color: AppColors.muted,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: onRegister,
                    child: const Text(
                      'הרשמה',
                      style: TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'כבר יש לך חשבון?',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: onLogin,
                    child: const Text(
                      'כניסה',
                      style: TextStyle(fontSize: 17),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: onGuest,
                  child: const Text('כניסה כאורח'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
