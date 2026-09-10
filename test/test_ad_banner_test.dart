import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/theme/app_theme.dart';
import 'package:food_diary/widgets/test_ad_banner.dart';

void main() {
  testWidgets('test advertisement is compact and clearly labelled',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: SizedBox(
            width: 390,
            child: TestAdBanner(),
          ),
        ),
      ),
    );

    expect(find.text('פרסומת · תצוגת בדיקה'), findsOneWidget);
    expect(find.text('המקום הבא שלכם מתחיל כאן'), findsOneWidget);
    expect(tester.getSize(find.byType(TestAdBanner)).height, lessThan(110));
  });
}
