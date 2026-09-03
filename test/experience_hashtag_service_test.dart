import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:food_diary/core/services/experience_hashtag_service.dart';

void main() {
  test('loads beyond first page and selects only public hashtag fields',
      () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.test',
      'public-test-key',
      httpClient: MockClient((request) async {
        calls++;
        expect(request.url.queryParameters['select'], 'id,place_id,notes');
        expect(request.url.queryParameters['notes'], 'like.%#%');
        expect(request.url.queryParameters['order'], startsWith('id.asc'));
        final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
        final rows = offset == 0
            ? List.generate(
                500, (i) => {'id': '$i', 'place_id': 'a', 'notes': '#קפה'})
            : [
                {'id': '500', 'place_id': 'b', 'notes': '#שניצל'}
              ];
        return http.Response(jsonEncode(rows), 200,
            request: request, headers: {'content-type': 'application/json'});
      }),
    );
    final index = await ExperienceHashtagService.load(client);
    expect(calls, 2);
    expect(index, {
      'a': {'קפה'},
      'b': {'שניצל'}
    });
    await client.dispose();
  });
  test('personal statistics query is scoped to signed-in user', () async {
    final client = SupabaseClient(
      'https://example.test',
      'public-test-key',
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['user_id'], 'eq.own-user');
        expect(request.url.queryParameters['select'],
            isNot(contains('journal_note')));
        return http.Response('[]', 200,
            request: request, headers: {'content-type': 'application/json'});
      }),
    );
    expect(await ExperienceHashtagService.loadOwnVisits(client, 'own-user'),
        isEmpty);
    await client.dispose();
  });
}
