import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';
import '../widgets/visit_card.dart';
import 'place_details_screen.dart';

/// Recent public experiences shared by people the current user follows.
class FollowingFeedScreen extends StatefulWidget {
  const FollowingFeedScreen({super.key});

  @override
  State<FollowingFeedScreen> createState() => _FollowingFeedScreenState();
}

class _FollowingFeedScreenState extends State<FollowingFeedScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  List<Map<String, dynamic>> _visits = const [];
  bool _loading = true;
  bool _hasFollowing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (!mounted) return;
      setState(() {
        _visits = const [];
        _hasFollowing = false;
        _loading = false;
        _error = null;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final followRows = await _client
          .from('user_follows')
          .select('following_id')
          .eq('follower_id', user.id);
      final followingIds = <String>{
        for (final row in followRows)
          if (row['following_id'] != null) row['following_id'].toString(),
      }.toList();

      if (followingIds.isEmpty) {
        if (!mounted) return;
        setState(() {
          _visits = const [];
          _hasFollowing = false;
          _loading = false;
        });
        return;
      }

      final visits = <Map<String, dynamic>>[];
      // Keep each request comfortably below URL-length limits for users who
      // follow many people.
      for (var start = 0; start < followingIds.length; start += 80) {
        final ids = followingIds.skip(start).take(80).toList();
        final rows = await _client
            .from('visits')
            .select(
              'id,place_id,user_id,outing_id,source_visit_id,visit_date,'
              'created_at,notes,rating,food,drink,total_price,price_level,'
              'image_url,food_rating,drink_rating,atmosphere_rating,'
              'service_rating,cleanliness_rating,variety_rating,value_rating,'
              'profiles!visits_user_id_fkey(display_name,avatar_url),'
              'visit_images(id,image_url,sort_order),'
              'visit_tag_links(tag_id,visit_tags(*)),'
              'places(id,name,address,image_url,latitude,longitude,user_id,'
              'category_id,categories(title))',
            )
            .inFilter('user_id', ids)
            .order('created_at', ascending: false)
            .limit(50);
        visits.addAll(List<Map<String, dynamic>>.from(rows));
      }

      visits.sort((a, b) {
        final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
        final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
        return (bDate ?? DateTime(0)).compareTo(aDate ?? DateTime(0));
      });

      if (!mounted) return;
      setState(() {
        _visits = visits.take(50).toList(growable: false);
        _hasFollowing = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון כרגע את הפעילות של הנעקבים';
      });
    }
  }

  Future<void> _openPlace(Map<String, dynamic> place) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaceDetailsScreen(place: place),
    ));
    if (mounted) await _load();
  }

  Map<String, dynamic> _placeFor(Map<String, dynamic> visit) {
    final raw = visit['places'];
    if (raw is! Map) return <String, dynamic>{};
    final place = Map<String, dynamic>.from(raw);
    final category = place['categories'];
    if (category is Map) {
      place['category_title'] = category['title'];
    }
    return place;
  }

  Widget _emptyState() {
    final title = _hasFollowing
        ? 'עדיין אין שיתופים חדשים'
        : 'כאן יופיעו חוויות של אנשים שתעקוב אחריהם';
    final subtitle = _hasFollowing
        ? 'חוויות חדשות של הנעקבים שלך יופיעו כאן.'
        : 'אפשר להתחיל לעקוב דרך פרופיל של משתמש שמעניין אותך.';
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 72),
      children: [
        Icon(
          Icons.people_alt_outlined,
          size: 44,
          color: AppColors.champagne.withValues(alpha: 0.9),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('מה חדש אצל נעקבים'),
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _load,
                          child: const Text('ניסיון נוסף'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _visits.isEmpty
                        ? _emptyState()
                        : Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(18, 20, 18, 40),
                                itemCount: _visits.length,
                                itemBuilder: (context, index) {
                                  final visit = _visits[index];
                                  final place = _placeFor(visit);
                                  final placeName =
                                      place['name']?.toString().trim() ?? '';
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (placeName.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            right: 4,
                                            bottom: 8,
                                          ),
                                          child: InkWell(
                                            onTap: () => _openPlace(place),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.place_outlined,
                                                  size: 18,
                                                  color: AppColors.champagne,
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    placeName,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color:
                                                          AppColors.champagne,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      VisitCard(
                                        visit: visit,
                                        place: place,
                                        onChanged: _load,
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                  ),
      ),
    );
  }
}
