import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:food_diary/screens/category_selection_screen.dart';
import 'package:food_diary/screens/journal_screen.dart';
import 'package:food_diary/screens/my_coupons_screen.dart';
import 'package:food_diary/screens/places_on_route_screen.dart';
import 'package:food_diary/features/authentication/screens/login_screen.dart';
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
  setUp(() async {
    requests.clear();
    await Supabase.instance.client.auth.signOut();
    requests.clear();
  });

  Future<void> openMenuItem(WidgetTester tester, String label) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: const CategorySelectionScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('תפריט'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('guest journal explains registration and allows dismissing',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openMenuItem(tester, 'יומן אישי');
    expect(find.text('יש להתחבר כדי לפתוח יומן אישי'), findsOneWidget);
    expect(
        find.text(
            'שמור ביקורים, דירוגים ותמונות ובנה יומן קולינרי שהוא כולו שלך.'),
        findsOneWidget);
    expect(find.byType(JournalScreen), findsNothing);
    expect(requests.any((r) => r.url.path.endsWith('/visits')), isFalse);
    await tester.tap(find.text('לא עכשיו'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CategorySelectionScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('guest can open login from the journal prompt', (tester) async {
    await openMenuItem(tester, 'יומן אישי');
    await tester.tap(find.text('להתחברות'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
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
    await openMenuItem(tester, 'יומן אישי');
    expect(find.byType(JournalScreen), findsOneWidget);
    expect(find.text('יש להתחבר כדי לפתוח יומן אישי'), findsNothing);
    expect(
        requests
            .singleWhere((r) => r.url.path.endsWith('/visits'))
            .url
            .queryParameters['user_id'],
        'eq.me');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('guest route feature explains its value before login',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: const CategorySelectionScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('בדרך'));
    await tester.pumpAndSettle();
    expect(find.byType(PlacesOnRouteScreen), findsNothing);
    expect(find.text('יש להתחבר כדי למצוא מקומות בדרך'), findsOneWidget);
    expect(
        find.text(
            'בחר יעד וקבל הצעות לעצירות אוכל שוות לאורך המסלול — בלי לחפש ובלי לסטות סתם.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('guest coupons explain their value before login', (tester) async {
    await openMenuItem(tester, 'הקופונים שלי');
    expect(find.byType(MyCouponsScreen), findsNothing);
    expect(find.text('יש להתחבר כדי לפתוח את הקופונים שלך'), findsOneWidget);
    expect(
        find.text('צבור נקודות ופתח הטבות וקופונים ששמורים במיוחד לחשבון שלך.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
