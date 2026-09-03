import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:food_diary/screens/category_selection_screen.dart';
import 'package:food_diary/screens/journal_screen.dart';
import 'package:food_diary/features/authentication/screens/register_screen.dart';
import 'package:food_diary/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
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
          dynamic data = [];
          if (request.url.path.endsWith('/profiles')) {
            data = [
              {
                'id': 'me',
                'display_name': 'משתמש',
                'registration_completed': true
              }
            ];
          } else if (request.url.path.endsWith('/visit_tag_unread_count')) {
            data = 0;
          }
          if (data is List &&
              (request.headers['accept'] ?? '').contains('vnd.pgrst.object')) {
            data = data.isEmpty ? null : data.first;
          }
          return http.Response(jsonEncode(data), 200,
              request: request, headers: {'content-type': 'application/json'});
        }));
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() => requests.clear());

  Future<void> openMenu(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: const CategorySelectionScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('תפריט'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('יומן אישי'));
    await tester.pumpAndSettle();
  }

  testWidgets('guest journal explains registration and allows dismissing',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openMenu(tester);
    expect(find.text('נדרשת הרשמה'), findsOneWidget);
    expect(find.byType(JournalScreen), findsNothing);
    expect(requests.any((r) => r.url.path.endsWith('/visits')), isFalse);
    await tester.tap(find.text('לא עכשיו'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CategorySelectionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('guest can open registration from the journal prompt',
      (tester) async {
    await openMenu(tester);
    await tester.tap(find.text('להרשמה'));
    await tester.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(JournalScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('signed-in user opens own journal without a registration prompt',
      (tester) async {
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'fake-journal-test',
      'token_type': 'bearer',
      'user': {
        'id': 'me',
        'app_metadata': {},
        'user_metadata': {},
        'aud': 'authenticated',
        'created_at': '2026-09-03T00:00:00Z'
      }
    }));
    await openMenu(tester);
    expect(find.byType(JournalScreen), findsOneWidget);
    expect(find.text('נדרשת הרשמה'), findsNothing);
    expect(
        requests
            .singleWhere((r) => r.url.path.endsWith('/visits'))
            .url
            .queryParameters['user_id'],
        'eq.me');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
