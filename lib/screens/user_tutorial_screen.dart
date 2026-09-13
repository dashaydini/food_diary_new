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
  static const _pages = <_IntroPageData>[
    _IntroPageData(
      eyebrow: 'הסיפור שלך מתחיל כאן',
      title: 'קודם כול, זה היומן האישי שלך',
      body:
          'כל קפה של בוקר, מסעדה שגילית וחוויה שלא תרצה לשכוח נשמרים במקום אחד — עם תמונות, דירוגים, אנשים ורגעים.',
      note:
          'הערות אישיות נשארות פרטיות. אתה מחליט מה נשמר רק עבורך ומה משתפים.',
      kind: _VisualKind.journal,
      labels: ['רגעים', 'תמונות', 'דירוגים'],
    ),
    _IntroPageData(
      eyebrow: 'הזיכרונות מסודרים מעצמם',
      title: 'כל המקומות שלך. תמיד איתך',
      body:
          'חוזרים בקלות למקומות שאהבת, שומרים מקומות לביקור הבא ורואים את הדרך הקולינרית שלך מתפתחת עם הזמן.',
      note:
          'אפשר לחפש לפי מקום, קטגוריה, מפה או האשטג — בלי לגלול בין מאות זיכרונות.',
      kind: _VisualKind.timeline,
      labels: ['הייתי', 'אהבתי', 'רוצה להגיע'],
    ),
    _IntroPageData(
      eyebrow: 'יומן אישי עם לב קהילתי',
      title: 'משתפים חוויה. עוזרים לכולם',
      body:
          'כשבוחרים לשתף, החוויה הופכת להמלצה אמיתית שעוזרת לאחרים לגלות מקום טוב — ומעניקה לעסקים מקומיים את הפרגון שמגיע להם.',
      note:
          'לא עוד דירוג אנונימי וקר: אנשים, סיפורים ותמונות מהשטח יוצרים קהילה שאפשר לסמוך עליה.',
      kind: _VisualKind.community,
      labels: ['מגלים', 'משתפים', 'מפרגנים'],
    ),
    _IntroPageData(
      eyebrow: 'הפעילות שלך שווה יותר',
      title: 'צוברים נקודות. נהנים מהדרך',
      body:
          'ביקורים, חוויות ופעילות בקהילה צוברים נקודות שמקדמות אותך להטבות — קופונים שווים וגישה למנוי פרימיום.',
      note: 'את יתרת הנקודות וההתקדמות שלך אפשר לראות בכל רגע בפרופיל.',
      kind: _VisualKind.rewards,
      labels: ['נקודות', 'קופונים', 'פרימיום'],
    ),
    _IntroPageData(
      eyebrow: 'BITE THE WAY',
      title: 'הדרך שלך מלאה בסיפורים טובים',
      body:
          'מתעדים את מה שהיה, מגלים את המקום הבא ומתחברים לקהילה שאוהבת אוכל, אנשים ועסקים מקומיים בדיוק כמוך.',
      note: 'מתחילים מחוויה אחת. מכאן היומן כבר ממשיך לגדול יחד איתך.',
      kind: _VisualKind.finish,
      labels: ['לתעד', 'לגלות', 'להרוויח'],
    ),
  ];

  final _controller = PageController();
  int _index = 0;

  Future<void> _goTo(int page) => _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );

  void _next() {
    if (_index == _pages.length - 1) {
      Navigator.of(context).pop();
    } else {
      _goTo(_index + 1);
    }
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
        body: Center(child: Text('מסך ההיכרות עדיין אינו פתוח למשתמשים')),
      );
    }

    final last = _index == _pages.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('איך BITE THE WAY עובדת'),
        actions: const [HomeButton()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) => _IntroPage(
                      data: _pages[index],
                    ),
                  ),
                ),
                _PageDots(
                  count: _pages.length,
                  selected: _index,
                  onSelected: _goTo,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _index == 0
                              ? () => Navigator.of(context).pop()
                              : () => _goTo(_index - 1),
                          child: Text(_index == 0 ? 'אחר כך' : 'הקודם'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _next,
                          icon: Icon(last
                              ? Icons.restaurant_menu_rounded
                              : Icons.arrow_back_rounded),
                          label: Text(last ? 'יוצאים לדרך' : 'ממשיכים'),
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

class _IntroPage extends StatelessWidget {
  const _IntroPage({required this.data});
  final _IntroPageData data;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 650;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, compact ? 8 : 16, 18, 10),
            child: Column(
              children: [
                _StoryVisual(data: data, compact: compact),
                SizedBox(height: compact ? 18 : 26),
                Text(
                  data.eyebrow,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.champagne,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        fontSize: compact ? 25 : 29,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  data.body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: compact ? 15 : 16.5,
                    height: 1.55,
                  ),
                ),
                SizedBox(height: compact ? 14 : 20),
                _NoteCard(text: data.note),
              ],
            ),
          );
        },
      );
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.champagne.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.champagne, size: 18),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      );
}

class _StoryVisual extends StatelessWidget {
  const _StoryVisual({required this.data, required this.compact});
  final _IntroPageData data;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        height: compact ? 190 : 238,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.champagne.withValues(alpha: 0.28),
          ),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF202938), Color(0xFF10151D)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: -54,
              left: -30,
              child: _GlowOrb(size: 170, opacity: 0.10),
            ),
            Positioned(
              bottom: -80,
              right: -25,
              child: _GlowOrb(size: 190, opacity: 0.06),
            ),
            Positioned.fill(child: _VisualContent(kind: data.kind)),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var index = 0; index < data.labels.length; index++) ...[
                    Flexible(child: _FeaturePill(label: data.labels[index])),
                    if (index < data.labels.length - 1)
                      const SizedBox(width: 7),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

class _VisualContent extends StatelessWidget {
  const _VisualContent({required this.kind});
  final _VisualKind kind;

  @override
  Widget build(BuildContext context) {
    switch (kind) {
      case _VisualKind.journal:
        return const _JournalVisual();
      case _VisualKind.timeline:
        return const _TimelineVisual();
      case _VisualKind.community:
        return const _CommunityVisual();
      case _VisualKind.rewards:
        return const _RewardsVisual();
      case _VisualKind.finish:
        return const _FinishVisual();
    }
  }
}

class _JournalVisual extends StatelessWidget {
  const _JournalVisual();

  @override
  Widget build(BuildContext context) => Center(
        child: Transform.rotate(
          angle: -0.04,
          child: Container(
            width: 152,
            height: 116,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0E4C9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 15),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.favorite_rounded,
                        color: Color(0xFF8B604B), size: 19),
                    Text('היומן שלי',
                        style: TextStyle(
                          color: Color(0xFF283545),
                          fontWeight: FontWeight.w800,
                        )),
                  ],
                ),
                SizedBox(height: 13),
                _PaperLine(width: 112),
                SizedBox(height: 8),
                _PaperLine(width: 94),
                SizedBox(height: 8),
                _PaperLine(width: 70),
              ],
            ),
          ),
        ),
      );
}

class _PaperLine extends StatelessWidget {
  const _PaperLine({required this.width});
  final double width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFF5F6D7A).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(99),
        ),
      );
}

class _TimelineVisual extends StatelessWidget {
  const _TimelineVisual();

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 250,
          height: 125,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 30),
                color: AppColors.champagne.withValues(alpha: 0.35),
              ),
              const Positioned(
                right: 24,
                child: _TimelineStop(icon: Icons.coffee_rounded),
              ),
              const _TimelineStop(
                  icon: Icons.restaurant_rounded, featured: true),
              const Positioned(
                left: 24,
                child: _TimelineStop(icon: Icons.local_bar_rounded),
              ),
            ],
          ),
        ),
      );
}

class _TimelineStop extends StatelessWidget {
  const _TimelineStop({required this.icon, this.featured = false});
  final IconData icon;
  final bool featured;

  @override
  Widget build(BuildContext context) => Container(
        width: featured ? 72 : 58,
        height: featured ? 72 : 58,
        decoration: BoxDecoration(
          color: featured ? AppColors.champagne : AppColors.surfaceRaised,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.champagne, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
        ),
        child: Icon(
          icon,
          color: featured ? AppColors.background : AppColors.champagne,
          size: featured ? 31 : 24,
        ),
      );
}

class _CommunityVisual extends StatelessWidget {
  const _CommunityVisual();

  @override
  Widget build(BuildContext context) => Center(
        child: SizedBox(
          width: 230,
          height: 126,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 2,
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: AppColors.champagne,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: AppColors.background, size: 40),
                ),
              ),
              const Positioned(
                right: 7,
                bottom: 5,
                child: _PersonBubble(icon: Icons.person_rounded),
              ),
              const Positioned(
                left: 7,
                bottom: 5,
                child: _PersonBubble(icon: Icons.person_2_rounded),
              ),
              Positioned(
                top: 0,
                right: 48,
                child: Icon(Icons.favorite_rounded,
                    color: AppColors.danger.withValues(alpha: 0.9), size: 25),
              ),
            ],
          ),
        ),
      );
}

class _PersonBubble extends StatelessWidget {
  const _PersonBubble({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.champagneSoft),
        ),
        child: Icon(icon, color: AppColors.champagne, size: 28),
      );
}

class _RewardsVisual extends StatelessWidget {
  const _RewardsVisual();

  @override
  Widget build(BuildContext context) => const Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          textDirection: TextDirection.rtl,
          children: [
            _RewardNode(icon: Icons.stars_rounded, label: 'נקודות'),
            _RewardArrow(),
            _RewardNode(
                icon: Icons.confirmation_number_rounded, label: 'קופון'),
            _RewardArrow(),
            _RewardNode(
                icon: Icons.workspace_premium_rounded, label: 'פרימיום'),
          ],
        ),
      );
}

class _RewardNode extends StatelessWidget {
  const _RewardNode({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.champagne.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.champagneSoft),
            ),
            child: Icon(icon, color: AppColors.champagne, size: 30),
          ),
          const SizedBox(height: 7),
          Text(label,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      );
}

class _RewardArrow extends StatelessWidget {
  const _RewardArrow();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(5, 0, 5, 24),
        child: Icon(Icons.arrow_back_rounded,
            color: AppColors.champagneSoft, size: 19),
      );
}

class _FinishVisual extends StatelessWidget {
  const _FinishVisual();

  @override
  Widget build(BuildContext context) => Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.champagne.withValues(alpha: 0.28),
                  width: 2,
                ),
              ),
            ),
            Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                color: AppColors.champagne,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.route_rounded,
                  color: AppColors.background, size: 52),
            ),
            const Positioned(
              top: 18,
              right: 10,
              child: Icon(Icons.favorite_rounded,
                  color: AppColors.danger, size: 25),
            ),
            const Positioned(
              left: 9,
              bottom: 25,
              child: Icon(Icons.star_rounded,
                  color: AppColors.champagne, size: 27),
            ),
          ],
        ),
      );
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.opacity});
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.champagne.withValues(alpha: opacity),
          shape: BoxShape.circle,
        ),
      );
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.selected,
    required this.onSelected,
  });
  final int count;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (index) => Semantics(
            label: 'עמוד ${index + 1}',
            selected: index == selected,
            button: true,
            child: GestureDetector(
              onTap: () => onSelected(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: index == selected ? 26 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: index == selected
                      ? AppColors.champagne
                      : AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
      );
}

enum _VisualKind { journal, timeline, community, rewards, finish }

class _IntroPageData {
  const _IntroPageData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.note,
    required this.kind,
    required this.labels,
  });
  final String eyebrow;
  final String title;
  final String body;
  final String note;
  final _VisualKind kind;
  final List<String> labels;
}
