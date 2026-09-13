import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../core/services/privacy_consent_service.dart';
import '../widgets/home_button.dart';
import 'support_requests_screen.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: 'מדיניות פרטיות',
      intro:
          'מדיניות זו מסבירה כיצד BITE THE WAY, המופעלת על ידי SHAY DINI, אוספת ומשתמשת במידע במסגרת האפליקציה.',
      sections: const [
        _LegalSection(
          title: 'מה התווסף בעדכון זה',
          body:
              'הוספנו פירוט על הפעלת שירותי המיקום וסוגי ההתראות כברירת מחדל, על הצורך באישור הרשאות המכשיר ועל האפשרות לכבות כל שירות בהגדרות. תוספת זו מצטרפת למדיניות הקיימת ואינה מחליפה את יתר סעיפיה.',
        ),
        _LegalSection(
          title: 'המידע שאנו אוספים',
          body:
              'בעת יצירת חשבון ושימוש באפליקציה עשויים להישמר פרטי חשבון ופרופיל, מקומות וביקורים, דירוגים, תמונות, העדפות ותוכן שהמשתמש בוחר לפרסם או לשמור. בעת שליחת פנייה נשמרים גם תוכן הפנייה והטיפול בה.',
        ),
        _LegalSection(
          title: 'מיקום, מצלמה והרשאות מכשיר',
          body:
              'תכונות המיקום באפליקציה פעילות כברירת מחדל ומשמשות למקומות קרובים, להצעות בדרך ולחיפוש לפי מיקום. השימוש בפועל כפוף לאישור המיקום של מערכת ההפעלה. ניתן לכבות את השימוש במיקום מתוך הגדרות האפליקציה, ולבטל את הרשאת המכשיר מתוך הגדרות המכשיר. גישה למצלמה או לגלריה מתבצעת רק לאחר פעולה יזומה של המשתמש.',
        ),
        _LegalSection(
          title: 'התראות והעדפות',
          body:
              'העדפות ההתראות מופעלות כברירת מחדל ועשויות לכלול קופונים ומבצעים, תיוגים, עוקבים חדשים, מקומות חדשים והמלצות המותאמות בעזרת AI, הודעות מערכת ועדכונים למנהלי מקומות. שליחת התראה לטלפון מחייבת גם אישור נפרד של מערכת ההפעלה. ניתן לכבות את כלל ההתראות או כל סוג בנפרד במסך ההגדרות.',
        ),
        _LegalSection(
          title: 'מטרות השימוש במידע',
          body:
              'המידע משמש להפעלת החשבון, שמירת היומן וההעדפות, הצגת מקומות והמלצות, שיפור השירות, אבטחה, מניעת שימוש לרעה וטיפול בפניות משתמשים.',
        ),
        _LegalSection(
          title: 'שירותים חיצוניים',
          body:
              'האפליקציה נעזרת ב־Supabase לצורכי אימות, מסד נתונים ואחסון; ב־OpenStreetMap ובשירותיו להצגת מפות וחיפוש כתובות; ובשירותי Apple או Google כאשר המשתמש בוחר להתחבר באמצעותם. שימוש בתכונת AI עשוי להעביר ל־OpenAI את התוכן שהמשתמש שולח אליה. Google AdSense משמש להצגת פרסומות רק לאחר קבלת הסכמה מתאימה.',
        ),
        _LegalSection(
          title: 'שמירה ומחיקה',
          body:
              'המידע נשמר כל עוד הוא נדרש להפעלת השירות, לקיום התחייבויות או לטיפול במחלוקות. ניתן לבקש עיון, תיקון או מחיקה של מידע ושל החשבון באמצעות תיבת הפניות למנהלים באפליקציה.',
        ),
        _LegalSection(
          title: 'אבטחה',
          body:
              'ננקטים אמצעים סבירים להגבלת גישה למידע ולהגנתו. עם זאת, אין מערכת מקוונת המעניקה חסינות מוחלטת מפני תקלות או גישה בלתי מורשית.',
        ),
        _LegalSection(
          title: 'מידע הנשמר במכשיר',
          body:
              'האפליקציה משתמשת באחסון מקומי הכרחי לצורך התחברות, אבטחה, העדפות והתקנה. לאחר אישור לפרסום, Google עשויה להשתמש בעוגיות, באחסון מקומי ובמזהים לצורך הצגת פרסומות ומדידתן. ניתן לדחות שימוש זה או לשנות את הבחירה במסך פרטיות ועוגיות. אם המשתמש מזין מפתח API אישי עבור תכונת AI, המפתח נשמר מקומית במכשיר ומשמש לפנייה ישירה לשירות ה־AI.',
        ),
        _LegalSection(
          title: 'עדכונים למדיניות',
          body:
              'המדיניות עשויה להתעדכן עם שינוי השירות או דרישות הדין. תאריך העדכון יוצג במסמך זה.',
        ),
      ],
      contactCategory: 'privacy',
    );
  }
}

class PrivacyConsentSettingsScreen extends StatefulWidget {
  const PrivacyConsentSettingsScreen({super.key});

  @override
  State<PrivacyConsentSettingsScreen> createState() =>
      _PrivacyConsentSettingsScreenState();
}

class _PrivacyConsentSettingsScreenState
    extends State<PrivacyConsentSettingsScreen> {
  bool _saving = false;

  Future<void> _setAdvertising(bool allowed) async {
    setState(() => _saving = true);
    await PrivacyConsentService.setAdvertisingAllowed(allowed);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(allowed
            ? 'פרסום ומדידת פרסומות אושרו'
            : 'פרסום ומדידת פרסומות נחסמו'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('פרטיות ועוגיות'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: true,
                          onChanged: null,
                          title: Text('אחסון הכרחי'),
                          subtitle: Text(
                            'נדרש להפעלת החשבון, אבטחה והעדפות בסיסיות ולא ניתן לכיבוי',
                          ),
                        ),
                        const Divider(),
                        ValueListenableBuilder<PrivacyConsentChoice>(
                          valueListenable: PrivacyConsentService.choice,
                          builder: (context, choice, _) =>
                              SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: choice == PrivacyConsentChoice.accepted,
                            onChanged: _saving ? null : _setAdvertising,
                            title: const Text('פרסום ומדידת פרסומות'),
                            subtitle: const Text(
                              'שימוש של Google במזהים ובאחסון בדפדפן לצורך פרסום',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'שינוי ההעדפה חל על בקשות פרסום חדשות. אחסון שכבר נוצר על ידי ספק חיצוני עשוי להישאר עד למחיקתו לפי מדיניות הספק או הדפדפן.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _LegalDocumentScreen(
      title: 'תנאי שימוש',
      intro:
          'השימוש ב־BITE THE WAY, המופעלת על ידי SHAY DINI, כפוף לתנאים אלה. שימוש באפליקציה מהווה הסכמה להם.',
      sections: const [
        _LegalSection(
          title: 'השירות',
          body:
              'האפליקציה מאפשרת לגלות ולשמור מקומות, לתעד ביקורים וחוויות, לקבל המלצות ולשתף תוכן קהילתי. תכונות מסוימות עשויות להשתנות, להתווסף או להיפסק.',
        ),
        _LegalSection(
          title: 'חשבון משתמש',
          body:
              'המשתמש אחראי למסירת מידע נכון, לשמירת פרטי ההתחברות ולכל פעילות המתבצעת בחשבונו. יש לדווח באמצעות תיבת הפניות במקרה של חשש לשימוש בלתי מורשה.',
        ),
        _LegalSection(
          title: 'תוכן משתמשים',
          body:
              'המשתמש אחראי לתוכן, לתמונות, לדירוגים ולתגובות שהוא מעלה, ומצהיר שיש לו זכות להשתמש בהם. אין להעלות תוכן פוגעני, מטעה, בלתי חוקי או מפר זכויות. ניתן להסיר תוכן המפר תנאים אלה.',
        ),
        _LegalSection(
          title: 'רישיון להצגת תוכן',
          body:
              'בהעלאת תוכן ציבורי המשתמש מעניק לאפליקציה רשות לא בלעדית להציג, לאחסן ולעבד אותו לצורך הפעלת השירות. הבעלות המקורית בתוכן נשארת בידי המשתמש.',
        ),
        _LegalSection(
          title: 'מיקום, מסלולים והמלצות',
          body:
              'מידע על מיקום, מרחק, מסלול, שעות פתיחה והמלצות עשוי להיות חלקי או לא מעודכן. אין להסתמך על האפליקציה במקום שילוט, הוראות בטיחות, חוקי תנועה או אפליקציית ניווט מוסמכת. הנהג אחראי לנהיגה בטוחה ולהימנעות משימוש מסיח דעת.',
        ),
        _LegalSection(
          title: 'שירותי צד שלישי',
          body:
              'האפליקציה עשויה לפתוח או להשתמש בשירותי מפות, התחברות, אחסון ו־AI של צדדים שלישיים. השימוש בהם כפוף גם לתנאים ולמדיניות שלהם.',
        ),
        _LegalSection(
          title: 'הגבלת אחריות',
          body:
              'השירות ניתן כפי שהוא ובכפוף לזמינות. דירוגים והמלצות מבוססים בין היתר על תוכן משתמשים ואינם התחייבות לאיכות, בטיחות, כשרות, זמינות או התאמה של מקום מסוים.',
        ),
        _LegalSection(
          title: 'השעיה וסיום שימוש',
          body:
              'ניתן להגביל או להפסיק גישה במקרה של הפרת התנאים, פגיעה במשתמשים אחרים, שימוש לרעה או צורך בהגנת השירות. משתמש יכול לבקש לסגור את חשבונו באמצעות תיבת הפניות.',
        ),
        _LegalSection(
          title: 'שינויים בתנאים',
          body:
              'התנאים עשויים להתעדכן מעת לעת. המשך שימוש לאחר פרסום עדכון מהווה הסכמה לנוסח המעודכן.',
        ),
      ],
      contactCategory: 'terms',
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String intro;
  final List<_LegalSection> sections;
  final String contactCategory;

  const _LegalDocumentScreen({
    required this.title,
    required this.intro,
    required this.sections,
    required this.contactCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
              children: [
                Text(
                  intro,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'עודכן לאחרונה: 13 בספטמבר 2026',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                for (final section in sections) ...[
                  Container(
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
                          section.title,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          section.body,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SupportRequestsScreen(
                          initialCategory: contactCategory,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.contact_support_outlined),
                  label: const Text('פנייה להנהלת האפליקציה'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final String body;

  const _LegalSection({required this.title, required this.body});
}
