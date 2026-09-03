import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/widgets/hashtag_chips.dart';
import 'package:food_diary/widgets/place_card.dart';

void main() {
  testWidgets('hashtag chips wrap on mobile and dispatch selected tag',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    String? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HashtagChips(
      hashtags: const ['שניצל', 'שווארמה', 'אוכל_רחוב'],
      onSelected: (tag) => selected = tag,
    ))));
    await tester.tap(find.text('#שניצל'));
    expect(selected, 'שניצל');
    expect(tester.takeException(), isNull);
  });
  testWidgets('place card shows hashtag evidence without inventing a rating',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(
      width: 340,
      child: PlaceCard(place: {
        'name': 'בית הפול הירוק - נווה זאב',
        'matched_hashtags': ['שניצל'],
        'hashtag_recommendation_reason':
            'האשטאג משותף לחוויה שהערכת בחיוב: #שניצל',
      }),
    ))));
    expect(find.text('מופיע בחוויה: #שניצל'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
