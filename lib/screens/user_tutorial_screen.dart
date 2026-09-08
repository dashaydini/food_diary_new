import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';

class UserTutorialScreen extends StatefulWidget {
  const UserTutorialScreen({super.key});

  @override
  State<UserTutorialScreen> createState() => _UserTutorialScreenState();
}

class _UserTutorialScreenState extends State<UserTutorialScreen> {
  static const _steps = <_TutorialStep>[
    _TutorialStep(
      icon: Icons.explore_outlined,
      title: 'מוצאים את המקום הבא',
      text:
          'במסך הבית בוחרים תחום, מחפשים מקום בשם או משתמשים במפה ובסינון המתקדם.',
      tip: 'אפשר לשלב אזור, סוג מקום והעדפות כדי לצמצם את התוצאות.',
    ),
    _TutorialStep(
      icon: Icons.storefront_outlined,
      title: 'נכנסים לכרטיס המקום',
      text:
          'בכרטיס המקום תמצאו כתובת, ניווט, תמונות, שעות פתיחה, תפריט וחוויות של משתמשים.',
      tip: 'לחיצה על ניווט פותחת את אפליקציית המפות המועדפת במכשיר.',
    ),
    _TutorialStep(
      icon: Icons.add_comment_outlined,
      title: 'משתפים חוויה',
      text:
          'אחרי ביקור לוחצים על „שיתוף חוויה”, מוסיפים דירוג, מלל, תמונות ופרטים שימושיים.',
      tip: 'אפשר לתייג חברים שהיו איתכם ולהוסיף האשטגים לחיפוש קל.',
    ),
    _TutorialStep(
      icon: Icons.book_outlined,
      title: 'היומן האישי שלכם',
      text:
          'החוויות נשמרות ביומן האישי. אפשר לסמן מועדפים, לשמור מקומות לביקור וליצור אוספים.',
      tip: 'הערות אישיות ביומן נשארות פרטיות ואינן מופיעות למשתמשים אחרים.',
    ),
    _TutorialStep(
      icon: Icons.card_giftcard_rounded,
      title: 'קופונים והטבות',
      text:
          'במסך „הקופונים שלי” רואים הטבות פעילות. נכנסים לקופון ומציגים את הקוד בבית העסק.',
      tip:
          'בהגדרות ניתן לבחור תחומי עניין ואזורים עבור התראות על קופונים חדשים.',
    ),
    _TutorialStep(
      icon: Icons.ios_share_rounded,
      title: 'מתקינים ומשתפים',
      text:
          'אפשר להתקין את BITE THE WAY על מסך הבית ולשתף קישור הזמנה ישירות מהפרופיל.',
      tip:
          'באנדרואיד מופיע כפתור התקנה; באייפון פועלים דרך שיתוף ← הוספה למסך הבית.',
    ),
  ];

  final _controller = PageController();
  int _index = 0;

  void _next() {
    if (_index == _steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Permissions.isAdmin) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('המדריך עדיין אינו פתוח למשתמשים')),
      );
    }
    final last = _index == _steps.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('מדריך למשתמש'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        'שלב ${_index + 1} מתוך ${_steps.length}',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (_index + 1) / _steps.length,
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(99),
                          backgroundColor: AppColors.surfaceRaised,
                          color: AppColors.champagne,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _steps.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) => _TutorialPage(
                      step: _steps[index],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _index == 0
                              ? () => Navigator.of(context).pop()
                              : () => _controller.previousPage(
                                    duration: const Duration(milliseconds: 280),
                                    curve: Curves.easeOutCubic,
                                  ),
                          child: Text(_index == 0 ? 'יציאה' : 'הקודם'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _next,
                          icon: Icon(last
                              ? Icons.check_rounded
                              : Icons.arrow_back_rounded),
                          label: Text(last ? 'סיום' : 'הבא'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  final _TutorialStep step;
  const _TutorialPage({required this.step});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                color: AppColors.champagne.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.champagne.withValues(alpha: 0.34),
                ),
              ),
              child: Icon(step.icon, size: 52, color: AppColors.champagne),
            ),
            const SizedBox(height: 30),
            Text(
              step.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 14),
            Text(
              step.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 17,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.champagne, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      step.tip,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _TutorialStep {
  final IconData icon;
  final String title;
  final String text;
  final String tip;

  const _TutorialStep({
    required this.icon,
    required this.title,
    required this.text,
    required this.tip,
  });
}
