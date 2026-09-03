import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:food_diary/core/services/shared_visit_service.dart';
import 'package:food_diary/screens/add_visit_screen.dart';
import 'package:food_diary/screens/category_selection_screen.dart';
import 'package:food_diary/screens/visit_notifications_screen.dart';
import 'package:food_diary/widgets/shared_visit_panel.dart';
import 'package:food_diary/widgets/visit_notification_button.dart';
import 'package:food_diary/widgets/admin_notification_button.dart';
import 'package:food_diary/widgets/admin_pending_status.dart';
import 'package:food_diary/widgets/visit_card.dart';
import 'package:food_diary/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const place = {'id': 'place', 'name': 'בית הפול'};
  final original = <String, dynamic>{
    'id': 'original',
    'place_id': 'place',
    'user_id': 'author',
    'outing_id': 'outing',
    'is_shared_response': false,
    'visit_date': '2026-09-01T12:00:00Z',
    'notes': 'החוויה של המחבר #שניצל',
    'rating': 5,
    'profiles': {'display_name': 'שי'},
  };
  var tagged = true;
  var read = false;
  var failed = false;
  var manager = false;
  var pendingSupport = false;
  Map<String, dynamic>? personal;
  Map<String, dynamic>? inserted;
  final requests = <http.Request>[];

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.test',
      publishableKey: 'public-test-key',
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUri: false,
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        dynamic data = <dynamic>[];
        if (failed) {
          return http.Response('{"message":"Unavailable"}', 503,
              request: request, headers: {'content-type': 'application/json'});
        }
        final table = request.url.path.split('/').last;
        final query = request.url.queryParameters;
        switch (table) {
          case 'visit_tag_unread_count':
            data = tagged && !read ? 1 : 0;
          case 'sync_visit_user_tags':
            data = null;
          case 'visit_tag_receipts':
            if (request.method == 'POST') {
              expect(jsonDecode(request.body)['user_id'], 'me');
              read = true;
              data = null;
            } else {
              data = read
                  ? [
                      {'tag_id': 'tag'}
                    ]
                  : [];
            }
          case 'visit_user_tags':
            if (request.method == 'DELETE') {
              expect(query['user_id'], 'eq.me');
              tagged = false;
              data = null;
            } else {
              data = tagged &&
                      (query['visit_id'] == null ||
                          query['visit_id'] == 'eq.original')
                  ? [
                      {
                        'id': 'tag',
                        'visit_id': 'original',
                        'user_id': 'me',
                        'created_at': '2026-09-01T12:00:00Z',
                        'visits': {
                          ...original,
                          'places': {'name': 'בית הפול'}
                        },
                      }
                    ]
                  : [];
            }
          case 'visits':
            if (request.method == 'POST') {
              inserted = Map<String, dynamic>.from(jsonDecode(request.body));
              personal = {
                ...inserted!,
                'id': 'personal',
                'outing_id': 'outing',
                'is_shared_response': true,
                'profiles': {'display_name': 'אני'}
              };
              data = {'id': 'personal'};
            } else if (request.method == 'DELETE') {
              personal = null;
              data = null;
            } else if (request.method == 'PATCH') {
              personal
                  ?.addAll(Map<String, dynamic>.from(jsonDecode(request.body)));
              data = null;
            } else {
              data = [original, if (personal != null) personal!].where((v) {
                return (query['id'] == null ||
                        query['id'] == 'eq.${v['id']}') &&
                    (query['user_id'] == null ||
                        query['user_id'] == 'eq.${v['user_id']}');
              }).toList();
            }
          case 'places':
            data = [place];
          case 'profiles':
            data = [
              {
                'id': 'me',
                'display_name': 'אני',
                'is_admin': manager,
                'admin_role': manager ? 'full_admin' : null
              }
            ];
          case 'support_requests':
            expect(query['limit'], '1');
            expect(
                query['status'],
                allOf(startsWith('in.('), contains('new'),
                    contains('in_progress')));
            data = pendingSupport
                ? [
                    {'id': 'support'}
                  ]
                : [];
          case 'visit_image_reports':
            expect(query['limit'], '1');
            expect(query['status'], 'eq.new');
            data = [];
        }
        if (data is List &&
            (request.headers['accept'] ?? '').contains('vnd.pgrst.object')) {
          data = data.isEmpty ? null : data.first;
        }
        return http.Response(jsonEncode(data), 200,
            request: request, headers: {'content-type': 'application/json'});
      }),
    );
    await Supabase.instance.client.auth.setInitialSession(jsonEncode({
      'access_token': 'fake-local-test-token',
      'token_type': 'bearer',
      'user': {
        'id': 'me',
        'app_metadata': {},
        'user_metadata': {},
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z'
      },
    }));
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(() {
    tagged = true;
    read = false;
    failed = false;
    manager = false;
    pendingSupport = false;
    personal = null;
    inserted = null;
    requests.clear();
  });

  Widget app(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Directionality(textDirection: TextDirection.rtl, child: child));

  testWidgets('notification opens author experience and a blank personal form',
      (tester) async {
    await tester.pumpWidget(app(const VisitNotificationsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('שי תייג אותך בחוויה בבית הפול'), findsOneWidget);
    expect(find.text('הפעילות שלי'), findsOneWidget);
    expect(find.byTooltip('בית'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.textContaining('חדש'), findsOneWidget);
    await tester.tap(find.text('שי תייג אותך בחוויה בבית הפול'));
    await tester.pumpAndSettle();
    expect(read, isTrue);
    expect(find.byTooltip('עריכת חוויה'), findsNothing);
    expect(find.byTooltip('מחיקת חוויה'), findsNothing);
    expect(find.byTooltip('הוספה לזיכרונות המועדפים'), findsNothing);
    await tester.tap(find.text('החוויה שלי מהביקור'));
    await tester.pumpAndSettle();
    final form =
        tester.widget<AddVisitScreen>(find.byType(AddVisitScreen).last);
    expect(form.visit, isNull);
    expect(form.sourceVisit?['id'], 'original');
    expect(form.viewOnly, isFalse);
    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.every((f) => f.controller?.text.isEmpty ?? true), isTrue);
    expect(
        requests
            .where((r) => r.method == 'POST' && r.url.path.endsWith('/visits')),
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('participant saves own notes and returns to shared outing',
      (tester) async {
    await tester.pumpWidget(app(Scaffold(
        body: SingleChildScrollView(
            child: SharedVisitPanel(
                visitId: 'original', place: place, onTagRemoved: () {})))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('החוויה שלי מהביקור'));
    await tester.pumpAndSettle();
    final notes = find.widgetWithText(TextField, 'הערות נוספות / חוויות');
    final formScroll = find
        .descendant(
            of: find.byType(ListView).last, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(notes, 250, scrollable: formScroll);
    await tester.enterText(notes, 'החוויה האישית שלי #שווארמה');
    await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'שמור חוויה'), 300,
        scrollable: formScroll);
    await tester.drag(find.byType(ListView).last, const Offset(0, -150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('שמור חוויה'));
    // Saving remains disabled behind the taste-feedback dialog.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(inserted?['user_id'], 'me');
    expect(inserted?['source_visit_id'], 'original');
    expect(inserted?['notes'], 'החוויה האישית שלי #שווארמה');
    expect(inserted?['rating'], isNull); // Never inherit the author's 5 stars.
    expect(requests.where((r) => r.url.path.endsWith('/sync_visit_user_tags')),
        isEmpty);
    expect(inserted?['visit_date'], startsWith('2026-09-01'));
    expect(find.text('המקום היה לטעמך?'), findsOneWidget);
    await tester.tap(find.text('לא עכשיו'));
    await tester.pumpAndSettle();
    expect(find.text('חוויות מאותו ביקור'), findsOneWidget);
    expect(find.byType(VisitCard), findsOneWidget);
    await tester.tap(find.text('החוויה שלי מהביקור'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('עריכת חוויה'), findsOneWidget);
    expect(
        tester
            .widget<AddVisitScreen>(find.byType(AddVisitScreen).last)
            .visit?['id'],
        'personal');
    await tester.tap(find.byTooltip('עריכת חוויה'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsNothing);
    expect(find.byTooltip('מחיקת חוויה'), findsOneWidget);
    await tester.tap(find.byTooltip('מחיקת חוויה'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('מחיקה'));
    await tester.pumpAndSettle();
    expect(personal, isNull);
    expect(original['notes'], 'החוויה של המחבר #שניצל');
    expect(find.text('החוויה שלי מהביקור'), findsOneWidget);
    final deletion = requests.singleWhere(
        (r) => r.method == 'DELETE' && r.url.path.endsWith('/visits'));
    expect(deletion.url.queryParameters['id'], 'eq.personal');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'self untagging preserves own experience and removes notification',
      (tester) async {
    personal = {...original, 'id': 'personal', 'user_id': 'me', 'rating': 2};
    var removed = false;
    await tester.pumpWidget(app(Scaffold(
        body: SingleChildScrollView(
            child: SharedVisitPanel(
                visitId: 'original',
                place: place,
                onTagRemoved: () {
                  removed = true;
                })))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('הסרת התיוג שלי'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('הסרת התיוג'));
    await tester.pumpAndSettle();
    expect(removed, isTrue);
    expect(tagged, isFalse);
    expect(personal, isNotNull);
    expect(find.text('הסרת התיוג שלי'), findsNothing);
    expect(find.text('החוויה שלי מהביקור'), findsOneWidget);
    expect(
        requests.where(
            (r) => r.method == 'DELETE' && r.url.path.endsWith('/visits')),
        isEmpty);
  });

  testWidgets('badge and error retry remain usable on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester
        .pumpWidget(app(const Scaffold(body: VisitNotificationButton())));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.people_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsNothing);
    final dot = tester
        .widget<Badge>(find.byKey(const ValueKey('personal-activity-dot')));
    expect(dot.isLabelVisible, isTrue);
    expect(dot.label, isNull);
    await tester.tap(find.byTooltip('הפעילות שלי'));
    await tester.pumpAndSettle();
    expect(find.text('שי תייג אותך בחוויה בבית הפול'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester
        .pumpWidget(const SizedBox.shrink()); // Dispose timer/navigation.
    failed = true;
    await tester.pumpWidget(app(const VisitNotificationsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('לא ניתן לטעון את הפעילות. נסה שוב.'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('לא ניתן לטעון את הפעילות. נסה שוב.'));
    await tester.pumpAndSettle();
    expect(find.text('שי תייג אותך בחוויה בבית הפול'), findsOneWidget);
    await tester.pumpWidget(app(const Scaffold()));
  });

  testWidgets('home notification button fits a narrow phone header',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(const CategorySelectionScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(VisitNotificationButton), findsOneWidget);
    expect(find.text('הפעילות שלי'), findsOneWidget);
    expect(tester.getCenter(find.byTooltip('חיפוש חופשי')).dx,
        greaterThan(tester.getCenter(find.text('AI')).dx));
    expect(
        tester.getCenter(find.byTooltip('חיפוש חופשי')).dy,
        closeTo(tester.getCenter(find.byType(VisitNotificationButton)).dy + 60,
            30));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'admin uses menu dots instead of a home bell; dots clear after handling',
      (tester) async {
    manager = true;
    pendingSupport = true;
    await tester.pumpWidget(app(const CategorySelectionScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(AdminNotificationButton), findsNothing);
    expect(find.byType(VisitNotificationButton), findsOneWidget);
    expect(
        tester
            .widget<Badge>(find.byKey(const ValueKey('admin-menu-dot')))
            .isLabelVisible,
        isTrue);
    await tester.tap(find.byTooltip('תפריט — פניות ממתינות לטיפול'));
    await tester.pumpAndSettle();
    expect(find.text('מרכז ניהול'), findsOneWidget);
    expect(
        tester
            .widget<Badge>(find.byKey(const ValueKey('admin-entry-dot')))
            .isLabelVisible,
        isTrue);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    pendingSupport = false;
    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Badge>(find.byKey(const ValueKey('admin-menu-dot')))
            .isLabelVisible,
        isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'pending status only queries authorized sections and clears after role removal',
      (tester) async {
    pendingSupport = true;
    Widget status(bool support) => app(AdminPendingStatus(
          canManageContent: false,
          canManageSupport: support,
          builder: (_, pending, refresh) => Text(pending ? 'pending' : 'clear'),
        ));
    await tester.pumpWidget(status(true));
    await tester.pumpAndSettle();
    expect(find.text('pending'), findsOneWidget);
    expect(requests.any((r) => r.url.path.endsWith('/visit_image_reports')),
        isFalse);
    requests.clear();
    await tester.pumpWidget(status(false));
    await tester.pumpAndSettle();
    expect(find.text('clear'), findsOneWidget);
    expect(requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
      'public group queries exclude private journal fields; participant updates use RPC',
      () async {
    final service = SharedVisitService(Supabase.instance.client);
    await service.outing('outing');
    expect(requests.last.url.queryParameters['outing_id'], 'eq.outing');
    expect(requests.last.url.queryParameters['select'],
        isNot(contains('journal_note')));
    await service
        .syncParticipants('original', ['me', 'me'], previousUserIds: ['me']);
    expect(requests.last.url.path, endsWith('/rpc/sync_visit_user_tags'));
    expect(jsonDecode(requests.last.body)['p_user_ids'], ['me']);
    expect(jsonDecode(requests.last.body)['p_previous_user_ids'], ['me']);
  });
}
