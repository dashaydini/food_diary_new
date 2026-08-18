import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

class DiscoverHomeScreen extends StatelessWidget {
  const DiscoverHomeScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      (
        "בתי קפה",
        "COFFEE & CAFÉS",
        const Icon(
          Icons.coffee_outlined,
          size: 45,
          color: Color(0xFFE1A080),
        ),
      ),
      (
        "עגלות קפה",
        "COFFEE CARTS",
        const _CoffeeCartIcon(),
      ),
      (
        "מסעדות",
        "RESTAURANTS & DINING",
        const Icon(
          Icons.restaurant_outlined,
          size: 45,
          color: Color(0xFFE1A080),
        ),
      ),
      (
        "פוד טראק",
        "STREET FOOD",
        const Icon(
          Icons.local_shipping_outlined,
          size: 45,
          color: Color(0xFFE1A080),
        ),
      ),
      (
        "פאבים",
        "BARS & NIGHTLIFE",
        const Icon(
          Icons.local_bar_outlined,
          size: 45,
          color: Color(0xFFE1A080),
        ),
      ),
      (
        "מאפיות",
        "BAKERIES & PASTRY",
        const Icon(
          Icons.bakery_dining_outlined,
          size: 45,
          color: Color(0xFFE1A080),
        ),
      ),
      (
        "ברים",
        "COCKTAILS & WINE",
        const Icon(
          Icons.wine_bar_outlined,
          size: 45,
          color: Color(0xFFE1A080),
        ),
      ),
      (
        "אוכל רחוב",
        "STREET FOOD",
        const Icon(
          Icons.takeout_dining_outlined,
          size: 45,
          color: Color(0xFFE1A080),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF080808),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(26, 28, 26, 20),
                child: Column(
                  children: [
                    // --------------------------------------------------
                    // LOGO
                    // --------------------------------------------------

                    const Text(
                      "F O O D   D I A R Y",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 3.8,
                        color: Color(0xFFE5B79E),
                      ),
                    ),

                    const SizedBox(height: 25),

                    // --------------------------------------------------
                    // DECORATIVE LINE
                    // --------------------------------------------------

                    _DecorativeLine(
                      width: constraints.maxWidth * 0.72,
                    ),

                    const SizedBox(height: 43),

                    // --------------------------------------------------
                    // MAIN TITLE
                    // --------------------------------------------------

                    const Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        "מה תרצה לגלות?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w300,
                          height: 1.15,
                          color: Color(0xFFF1DDC9),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    _SmallDecorativeLine(
                      width: 190,
                    ),

                    const SizedBox(height: 27),

                    const Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        "בחר קטגוריה",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3.0,
                          color: Color(0xFFB89582),
                        ),
                      ),
                    ),

                    const SizedBox(height: 38),

                    // --------------------------------------------------
                    // CATEGORY CARDS
                    // --------------------------------------------------

                    ...categories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: _CategoryCard(
                          title: category.$1,
                          subtitle: category.$2,
                          icon: category.$3,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HomeScreen(
                                  categoryTitle: category.$1,
                                  itemName: category.$1 == "עגלות קפה"
                                      ? "עגלה"
                                      : category.$1,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // --------------------------------------------------
                    // FOOTER DECORATION
                    // --------------------------------------------------

                    const Text(
                      "✦",
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFFE09C7B),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      "D I S C O V E R   •   T A S T E   •   E X P E R I E N C E",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 2.2,
                        color: Color(0xFF9B7668),
                      ),
                    ),

                    const SizedBox(height: 4),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ================================================================
// CUSTOM COFFEE CART ICON
// ================================================================

class _CoffeeCartIcon extends StatelessWidget {
  const _CoffeeCartIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CoffeeCartPainter(),
      size: const Size(45, 45),
    );
  }
}

class _CoffeeCartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE1A080)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cart = Path()
      ..moveTo(7, 15)
      ..lineTo(38, 15)
      ..lineTo(34, 31)
      ..lineTo(11, 31)
      ..close();

    canvas.drawPath(cart, paint);

    // גגון
    final roof = Path()
      ..moveTo(5, 15)
      ..lineTo(40, 15)
      ..lineTo(36, 9)
      ..lineTo(9, 9)
      ..close();

    canvas.drawPath(roof, paint);

    // ידית
    canvas.drawLine(
      const Offset(11, 31),
      const Offset(7, 36),
      paint,
    );

    // גלגלים
    canvas.drawCircle(
      const Offset(15, 36),
      2.5,
      paint,
    );

    canvas.drawCircle(
      const Offset(31, 36),
      2.5,
      paint,
    );

    // ספל קטן
    final cup = Path()
      ..moveTo(19, 19)
      ..lineTo(27, 19)
      ..lineTo(26, 26)
      ..lineTo(20, 26)
      ..close();

    canvas.drawPath(cup, paint);

    canvas.drawArc(
      Rect.fromLTWH(25, 20, 5, 5),
      -1.5,
      2.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ================================================================
// DECORATIVE LINE
// ================================================================

class _DecorativeLine extends StatelessWidget {
  final double width;

  const _DecorativeLine({
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.7,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00000000),
                    Color(0xFFB97D65),
                    Color(0xFFE1A184),
                  ],
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              "✦",
              style: TextStyle(
                fontSize: 17,
                color: Color(0xFFE4A083),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.7,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFE1A184),
                    Color(0xFFB97D65),
                    Color(0x00000000),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// SMALL DECORATIVE LINE
// ================================================================

class _SmallDecorativeLine extends StatelessWidget {
  final double width;

  const _SmallDecorativeLine({
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.7,
              color: const Color(0xFFB87C66),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              "✦",
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFE19A7B),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.7,
              color: const Color(0xFFB87C66),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// CATEGORY CARD
// ================================================================

class _CategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget icon;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const champagne = Color(0xFFE7D6B5);
    const champagneSoft = Color(0xFFCDBB9A);
    const roseGold = Color(0xFFB8897B);
    const roseGoldDark = Color(0xFF76544C);
    const surface = Color(0xFF12100F);
    const surfaceTop = Color(0xFF181412);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        splashColor: roseGold.withValues(alpha: 0.08),
        highlightColor: roseGold.withValues(alpha: 0.04),
        child: Container(
          height: 82,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                surfaceTop,
                surface,
                Color(0xFF0E0C0B),
              ],
            ),
            border: Border.all(
              color: roseGold,
              width: 0.8,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 18,
                spreadRadius: 0,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // ICON
              SizedBox(
                width: 82,
                child: Center(
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: IconTheme(
                      data: const IconThemeData(
                        color: champagne,
                        size: 27,
                      ),
                      child: icon,
                    ),
                  ),
                ),
              ),

              // ROSE-GOLD DIVIDER
              Container(
                width: 0.7,
                height: 46,
                color: roseGoldDark,
              ),

              // TEXT
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(
                    right: 20,
                    left: 14,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        title,
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.2,
                          color: champagne,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.7,
                          color: champagneSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}
