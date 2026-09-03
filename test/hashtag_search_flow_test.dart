import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:food_diary/screens/hashtag_search_screen.dart';
import 'package:food_diary/screens/places_screen.dart';
import 'package:food_diary/screens/free_search_screen.dart';
import 'package:food_diary/screens/category_selection_screen.dart';
import 'package:food_diary/widgets/visit_card.dart';
import 'package:food_diary/widgets/place_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var failed = false;
  var notes = '#שניצל #שווארמה #אוכל_רחוב';
  final places = [
    {
      'id': 'p',
      'name': 'בית הפול הירוק - נווה זאב',
      'category_id': 'street',
      'categories': {'title': 'אוכל רחוב'}
    },
    {
      'id': 'other',
      'name': 'מקום נוסף',
      'category_id': 'cafe',
      'categories': {'title': 'בתי קפה'}
    },
    {
      'id': 'pizza',
      'name': 'פיצה',
      'category_id': 'street',
      'categories': {'title': 'אוכל רחוב'}
    },
  ];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'public-test-key',
      authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          persistSession: false,
          detectSessionInUri: false),
      httpClient: MockClient((request) async {
        if (failed) {
          return http.Response('{"message":"Unavailable"}', 403,
              request: request, headers: {'content-type': 'application/json'});
        }
        List<Map<String, dynamic>> rows;
        switch (request.url.path.split('/').last) {
          case 'places':
            final filter = request.url.queryParameters['id'];
            rows = places
                .where((p) =>
                    filter == null ||
                    filter.contains('"${p['id']}"') ||
                    filter
                        .substring(3, filter.length - 1)
                        .split(',')
                        .contains(p['id']))
                .toList();
          case 'categories':
            rows = [
              {'id': 'street', 'title': 'אוכל רחוב', 'sort_order': 0},
              {'id': 'cafe', 'title': 'בתי קפה', 'sort_order': 1}
            ];
          case 'visits':
            rows = [
              {'id': 'v', 'place_id': 'p', 'notes': notes, 'rating': 4.5},
              {'id': 'v2', 'place_id': 'p', 'notes': notes, 'rating': 4.5},
              {'id': 'v3', 'place_id': 'other', 'notes': '#שניצל'},
            ];
          default:
            rows = [];
        }
        return http.Response(jsonEncode(rows), 200,
            request: request, headers: {'content-type': 'application/json'});
      }),
    );
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() {
    failed = false;
    notes = '#שניצל #שווארמה #אוכל_רחוב';
  });

  testWidgets('category screen no longer exposes free search', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: PlacesScreen(categoryId: 'street', categoryTitle: 'אוכל רחוב')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('חיפוש חופשי'), findsNothing);
    expect(find.byType(PlaceCard), findsNWidgets(2));
  });

  testWidgets(
      'free home search matches names and hashtags across all categories for guests',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CategorySelectionScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('חיפוש חופשי'));
    await tester.pumpAndSettle();
    expect(find.byType(FreeSearchScreen), findsOneWidget);
    expect(find.byType(PlaceCard), findsNothing);
    await tester.enterText(find.byType(TextField), '#שניצל');
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(2));
    expect(find.text('2 מקומות מכל הקטגוריות'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'שניצל');
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(2));
    await tester.enterText(find.byType(TextField), '#פיצה');
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNothing);
    await tester.enterText(find.byType(TextField), 'פיצה');
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsOneWidget);
    await tester.tap(find.byTooltip('ניקוי החיפוש'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'free search is usable on a narrow RTL screen and retries failed loading',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    failed = true;
    await tester.pumpWidget(const MaterialApp(home: FreeSearchScreen()));
    await tester.pumpAndSettle();
    expect(find.text('לא ניתן לטעון את החיפוש'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('נסה שוב'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '#שניצל');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'clicking visit hashtag opens cross-category results, deduplicated by place',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: VisitCard(
      visit: const {'notes': '#שניצל', 'user_id': 'owner'},
      place: places.first,
    ))));
    await tester.tap(find.text('#שניצל'));
    await tester.pumpAndSettle();
    expect(find.byType(HashtagSearchScreen), findsOneWidget);
    expect(find.byType(PlaceCard), findsNWidgets(2));
    expect(find.text('בית הפול הירוק - נווה זאב'), findsOneWidget);
    expect(find.text('מקום נוסף'), findsOneWidget);
    expect(tester.takeException(), isNull);
    notes = 'ההאשטאג נמחק מהחוויה';
    final refresh =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    await refresh.onRefresh();
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsOneWidget);
    expect(find.text('בית הפול הירוק - נווה זאב'), findsNothing);
  });

  testWidgets('hashtag loader exposes an error and retry recovers',
      (tester) async {
    failed = true;
    await tester.pumpWidget(
        const MaterialApp(home: HashtagSearchScreen(hashtag: 'שניצל')));
    await tester.pumpAndSettle();
    expect(find.text('לא ניתן לטעון את תוצאות ההאשטאג'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('נסה שוב'));
    await tester.pumpAndSettle();
    expect(find.byType(PlaceCard), findsNWidgets(2));
  });
}
