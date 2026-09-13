import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/authentication/widgets/privacy_policy_consent_gate.dart';

void main() {
  testWidgets('continue appears only after accepting the privacy policy',
      (tester) async {
    var checked = false;

    Widget app() => MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => PrivacyAcceptanceScreen(
              checked: checked,
              saving: false,
              onChanged: (value) => setState(() => checked = value),
              onAccept: () {},
            ),
          ),
        );

    await tester.pumpWidget(app());
    expect(find.text('המשך לאפליקציה'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('המשך לאפליקציה'), findsOneWidget);
  });

  testWidgets('existing users see that the privacy policy was updated',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyAcceptanceScreen(
          isUpdate: true,
          checked: false,
          saving: false,
          onChanged: (_) {},
          onAccept: () {},
        ),
      ),
    );

    expect(find.text('מדיניות הפרטיות עודכנה'), findsOneWidget);
    expect(find.textContaining('הוספנו'), findsOneWidget);
  });
}
