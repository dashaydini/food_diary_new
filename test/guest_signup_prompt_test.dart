import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_diary/features/authentication/screens/register_screen.dart';
import 'package:food_diary/features/authentication/widgets/guest_signup_prompt.dart';
import 'package:food_diary/theme/app_theme.dart';

void main() {
  Widget app() => MaterialApp(
        theme: AppTheme.darkTheme,
        home: const GuestSignupPrompt(
          delay: Duration.zero,
          child: Scaffold(body: Text('מסך הבית')),
        ),
      );

  testWidgets('guest sees the signup prompt and can keep browsing',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('מוכנים לגלות את המקום הבא שלכם?'), findsOneWidget);
    expect(find.text('מצטרפים בחינם'), findsOneWidget);
    expect(find.text('מסך הבית'), findsOneWidget);

    await tester.tap(find.text('אולי אחר כך'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('מסך הבית'), findsOneWidget);
  });

  testWidgets('signup action opens registration', (tester) async {
    var registrationRequested = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: GuestSignupPrompt(
        delay: Duration.zero,
        onRegister: () => registrationRequested = true,
        child: const Scaffold(body: Text('מסך הבית')),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('מצטרפים בחינם'));
    await tester.pumpAndSettle();

    expect(registrationRequested, isTrue);
    expect(find.byType(RegisterScreen), findsNothing);
  });
}
