import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:food_diary/core/services/registration_service.dart';
import 'package:food_diary/features/authentication/widgets/registration_gate.dart';
import 'package:food_diary/features/authentication/screens/complete_registration_screen.dart';
import 'package:food_diary/main.dart';
import 'package:food_diary/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var completed = false;
  var failed = false;
  final requests = <http.Request>[];
  Map<String, dynamic>? saved;

  Future<void> signIn() async {
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'fake-registration-test',
      'token_type': 'bearer',
      'user': {
        'id': 'me',
        'app_metadata': {'provider': 'google'},
        'user_metadata': {},
        'aud': 'authenticated',
        'created_at': '2026-09-03T00:00:00Z'
      }
    }));
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
        url: 'https://example.test',
        publishableKey: 'test-public',
        authOptions: const FlutterAuthClientOptions(
            autoRefreshToken: false,
            persistSession: false,
            detectSessionInUri: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final table = request.url.path.split('/').last;
          dynamic data = [];
          var status = 200;
          if (failed) {
            status = 503;
            data = {'message': 'Unavailable'};
          } else if (table == 'profiles') {
            data = [
              {
                'id': 'me',
                'display_name': 'משתמש Google',
                'registration_completed': completed,
                'referred_by': null
              }
            ];
          } else if (table == 'complete_google_registration') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['p_referral_code'] == 'WRONG') {
              status = 400;
              data = {'message': 'Invalid referral code', 'code': '22023'};
            } else {
              saved = body;
              completed = true;
              data = null;
            }
          } else if (table == 'apply_referral_code') {
            data = true;
          }
          if (data is List &&
              (request.headers['accept'] ?? '').contains('vnd.pgrst.object')) {
            data = data.isEmpty ? null : data.first;
          }
          return http.Response(jsonEncode(data), status,
              request: request, headers: {'content-type': 'application/json'});
        }));
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() async {
    completed = false;
    failed = false;
    saved = null;
    requests.clear();
    SharedPreferences.setMockInitialValues({});
    await signIn();
  });

  Widget app(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Directionality(textDirection: TextDirection.rtl, child: child));
  Widget gate() => app(const RegistrationGate(
      key: ValueKey('me'), child: Scaffold(body: Text('App content'))));
  Finder nameField() => find.widgetWithText(TextFormField, 'שם לתצוגה');
  Finder codeField() =>
      find.widgetWithText(TextFormField, 'קוד הזמנה (אופציונלי)');

  testWidgets('new Google account must complete registration; referral waits',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(RegistrationService.pendingReferralKey, 'INVITE');
    await RegistrationService(Supabase.instance.client).applyPendingReferral();
    expect(requests.any((r) => r.url.path.endsWith('/apply_referral_code')),
        isFalse);
    await tester.pumpWidget(gate());
    await tester.pumpAndSettle();
    expect(find.byType(CompleteRegistrationScreen), findsOneWidget);
    expect(find.text('App content'), findsNothing);
    expect(find.text('INVITE'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    await tester.enterText(nameField(), 'שם שבחרתי');
    await tester.tap(find.text('סיום הרשמה וכניסה'));
    await tester.pumpAndSettle();
    expect(saved, {'p_display_name': 'שם שבחרתי', 'p_referral_code': 'INVITE'});
    expect(find.text('App content'), findsOneWidget);
    expect(prefs.getString(RegistrationService.pendingReferralKey), isNull);
    expect(
        requests.any((r) => r.url.path.contains('/auth/v1/signup')), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(gate());
    await tester.pumpAndSettle();
    expect(find.byType(CompleteRegistrationScreen), findsNothing);
    expect(find.text('App content'), findsOneWidget);
  });

  testWidgets('invalid code can be corrected or cleared without losing name',
      (tester) async {
    await tester.pumpWidget(gate());
    await tester.pumpAndSettle();
    await tester.enterText(codeField(), 'WRONG');
    await tester.tap(find.text('סיום הרשמה וכניסה'));
    await tester.pumpAndSettle();
    expect(find.textContaining('קוד ההזמנה אינו תקין'), findsOneWidget);
    expect(completed, isFalse);
    expect(find.text('משתמש Google'), findsOneWidget);
    await tester.enterText(codeField(), '');
    await tester.tap(find.text('סיום הרשמה וכניסה'));
    await tester.pumpAndSettle();
    expect(find.text('App content'), findsOneWidget);
    expect(saved?['p_referral_code'], '');
  });

  testWidgets('empty name is blocked and mobile form remains usable',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(gate());
    await tester.pumpAndSettle();
    await tester.enterText(nameField(), ' ');
    await tester.ensureVisible(find.text('סיום הרשמה וכניסה'));
    await tester.tap(find.text('סיום הרשמה וכניסה'));
    await tester.pumpAndSettle();
    expect(find.text('יש להזין שם באורך שני תווים לפחות'), findsOneWidget);
    expect(saved, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing Google or email profiles enter without onboarding',
      (tester) async {
    completed = true;
    await tester.pumpWidget(gate());
    await tester.pumpAndSettle();
    expect(find.text('App content'), findsOneWidget);
    expect(find.byType(CompleteRegistrationScreen), findsNothing);
    expect(saved, isNull);
  });

  testWidgets('profile failure blocks entry and retry recovers',
      (tester) async {
    failed = true;
    await tester.pumpWidget(gate());
    await tester.pumpAndSettle();
    expect(find.text('App content'), findsNothing);
    expect(find.text('ניסיון נוסף'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('ניסיון נוסף'));
    await tester.pumpAndSettle();
    expect(find.byType(CompleteRegistrationScreen), findsOneWidget);
  });

  testWidgets(
      'real AuthGate gates restored Google session and supports signout',
      (tester) async {
    await tester.pumpWidget(app(const AuthGate()));
    await tester.pumpAndSettle();
    expect(find.byType(CompleteRegistrationScreen), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text('התנתקות'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(Supabase.instance.client.auth.currentUser, isNull);
    expect(find.byType(CompleteRegistrationScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
      'OAuth code never replaces invitation and supported invitation links persist',
      () async {
    await RegistrationService.captureInvitation(
        Uri.parse('https://app.test/?ref=INVITE'));
    await RegistrationService.captureInvitation(
        Uri.parse('https://app.test/?code=oauth-secret'));
    final service = RegistrationService(Supabase.instance.client);
    expect(await service.pendingCode(), 'INVITE');
    await RegistrationService.captureInvitation(
        Uri.parse('fooddiary://invite?code=OTHER'));
    expect(await service.pendingCode(), 'OTHER');
  });
}
