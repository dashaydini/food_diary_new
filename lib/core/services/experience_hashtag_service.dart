import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/experience_hashtags.dart';

class ExperienceHashtagService {
  static Future<List<Map<String, dynamic>>> loadOwnVisits(
    SupabaseClient client,
    String userId,
  ) async {
    const pageSize = 500;
    final visits = <Map<String, dynamic>>[];
    while (true) {
      final rows = await client
          .from('visits')
          .select(
              'id, place_id, rating, price_level, notes, places(category_id)')
          .eq('user_id', userId)
          .order('id', ascending: true)
          .range(visits.length, visits.length + pageSize - 1);
      visits.addAll(rows);
      if (rows.length < pageSize) return visits;
    }
  }

  /// Uses the caller's session and RLS; no privileged keys or global user cache.
  static Future<Map<String, Set<String>>> load(SupabaseClient client) async {
    const pageSize = 500;
    final index = <String, Set<String>>{};
    var offset = 0;
    while (true) {
      final rows = await client
          .from('visits')
          .select('id, place_id, notes')
          .like('notes', '%#%')
          .order('id', ascending: true)
          .range(offset, offset + pageSize - 1);
      final page = ExperienceHashtags.byPlace(rows);
      for (final entry in page.entries) {
        index.putIfAbsent(entry.key, () => <String>{}).addAll(entry.value);
      }
      if (rows.length < pageSize) return index;
      offset += rows.length;
    }
  }
}
