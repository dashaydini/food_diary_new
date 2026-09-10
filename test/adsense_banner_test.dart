import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/widgets/adsense_banner.dart';

void main() {
  testWidgets('AdSense banner has a safe non-web fallback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AdsenseBanner())),
    );

    expect(find.byType(AdsenseBanner), findsOneWidget);
    expect(tester.getSize(find.byType(AdsenseBanner)), Size.zero);
  });
}
