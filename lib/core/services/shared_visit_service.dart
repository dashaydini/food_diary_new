import 'package:supabase_flutter/supabase_flutter.dart';

/// Public experience content only. Never fetch another author's journal notes.
class SharedVisitService {
  SharedVisitService(this.client);
  final SupabaseClient client;

  static const visitFields =
      'id,place_id,user_id,outing_id,source_visit_id,visit_date,created_at,'
      'notes,rating,food,drink,total_price,price_level,image_url,'
      'food_rating,drink_rating,atmosphere_rating,service_rating,'
      'cleanliness_rating,variety_rating,value_rating,'
      'profiles!visits_user_id_fkey(display_name,avatar_url),'
      'visit_images(id,image_url,sort_order),visit_tag_links(tag_id,visit_tags(*))';

  Future<Map<String, dynamic>?> visit(String id) =>
      client.from('visits').select(visitFields).eq('id', id).maybeSingle();

  Future<List<Map<String, dynamic>>> outing(String id) async => await client
      .from('visits')
      .select(visitFields)
      .eq('outing_id', id)
      .order('created_at')
      .order('id');

  Future<Map<String, dynamic>?> ownTag(String visitId) async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) return null;
    return client
        .from('visit_user_tags')
        .select('id,visit_id,user_id')
        .eq('visit_id', visitId)
        .eq('user_id', user.id)
        .maybeSingle();
  }

  Future<void> removeOwnTag(String tagId) async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) throw StateError('יש להתחבר');
    await client
        .from('visit_user_tags')
        .delete()
        .eq('id', tagId)
        .eq('user_id', user.id);
  }

  Future<void> markRead(String tagId) async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) throw StateError('יש להתחבר');
    await client.from('visit_tag_receipts').upsert(
      {'tag_id': tagId, 'user_id': user.id},
      onConflict: 'tag_id',
      ignoreDuplicates: true,
    );
  }

  Future<int> unreadCount() async =>
      (await client.rpc('visit_tag_unread_count') as num).toInt();

  Future<List<Map<String, dynamic>>> notifications({int offset = 0}) async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) return [];
    final rows = await client
        .from('visit_user_tags')
        .select(
          'id,visit_id,created_at,visits!visit_user_tags_visit_id_fkey!inner('
          'id,place_id,user_id,places(name),profiles!visits_user_id_fkey(display_name,avatar_url))',
        )
        .eq('user_id', user.id)
        .neq('visits.user_id', user.id)
        .order('created_at', ascending: false)
        .order('id')
        .range(offset, offset + 49);
    if (rows.isEmpty) return [];
    final receipts = await client
        .from('visit_tag_receipts')
        .select('tag_id')
        .eq('user_id', user.id)
        .inFilter('tag_id', rows.map((r) => r['id']).toList());
    final readIds = receipts.map((r) => r['tag_id']).toSet();
    return rows
        .map((r) => {...r, 'is_read': readIds.contains(r['id'])})
        .toList();
  }

  Future<void> syncParticipants(String visitId, Iterable<String> userIds,
          {Iterable<String> previousUserIds = const []}) =>
      client.rpc('sync_visit_user_tags', params: {
        'p_visit_id': visitId,
        'p_user_ids': userIds.toSet().toList(),
        'p_previous_user_ids': previousUserIds.toSet().toList(),
      });
}
