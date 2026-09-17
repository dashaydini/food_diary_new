import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:food_diary/screens/place_ownership_request_screen.dart';
import 'package:food_diary/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
        final data = request.url.path.endsWith('/support_requests')
            ? {'id': 'request-id'}
            : {'ok': true};
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
        'created_at': '2026-01-01T00:00:00Z',
      },
    }));
  });
  tearDownAll(() async => Supabase.instance.dispose());
  setUp(requests.clear);

  testWidgets('ownership request contains place and proof, without a grant',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const PlaceOwnershipRequestScreen(place: {
        'id': 'place-id',
        'name': 'קפה לדוגמה',
      }),
    ));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'דנה ישראלי');
    await tester.enterText(fields.at(1), '0501234567');
    await tester.enterText(fields.at(2), 'dana@example.com');
    await tester.enterText(fields.at(3), 'https://example.com/business');
    await tester.scrollUntilVisible(find.text('שליחת בקשת בעלות'), 180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.tap(find.text('שליחת בקשת בעלות'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();

    final submitted = requests.singleWhere(
        (request) => request.url.path.endsWith('/support_requests'));
    final body = jsonDecode(submitted.body) as Map<String, dynamic>;
    expect(body['category'], 'place_ownership');
    expect(body['place_id'], 'place-id');
    expect(body['message'], contains('https://example.com/business'));
    expect(find.text('לא הצלחנו לשלוח את הבקשה. כדאי לנסות שוב.'), findsNothing);
    expect(
        requests.where((request) =>
            request.url.path.endsWith('/send-event-notification')),
        hasLength(1));
    expect(
        requests
            .where((request) => request.url.path.endsWith('/place_managers')),
        isEmpty);
    expect(tester.takeException(), isNull);
  });
}
