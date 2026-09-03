import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/experience_hashtag_service.dart';
import '../utils/experience_hashtags.dart';
import '../widgets/home_button.dart';
import '../widgets/place_card.dart';
import 'place_details_screen.dart';

/// Public hashtag discovery is separate from the premium advanced filters.
class HashtagSearchScreen extends StatefulWidget {
  final String hashtag;
  const HashtagSearchScreen({super.key, required this.hashtag});

  static Future<void> open(BuildContext context, String hashtag) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HashtagSearchScreen(hashtag: hashtag),
    ));
  }

  @override
  State<HashtagSearchScreen> createState() => _HashtagSearchScreenState();
}

class _HashtagSearchScreenState extends State<HashtagSearchScreen> {
  List<Map<String, dynamic>> _places = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final client = Supabase.instance.client;
      final index = await ExperienceHashtagService.load(client);
      final ids = index.entries
          .where((entry) => ExperienceHashtags.matchesPlace(
                const {},
                entry.value,
                '#${widget.hashtag}',
              ))
          .map((entry) => entry.key)
          .toList();
      final places = <Map<String, dynamic>>[];
      // Bound URL size and avoid silently truncating results at the API row limit.
      for (var start = 0; start < ids.length; start += 100) {
        final rows = await client
            .from('places')
            .select(
              'id, name, category_id, user_id, description, address, latitude, longitude, image_url, categories(title)',
            )
            .inFilter('id', ids.skip(start).take(100).toList());
        for (final row in rows) {
          final category = row['categories'];
          places.add({
            ...row,
            'category_title': category is Map ? category['title'] : null,
            'matched_hashtags': ExperienceHashtags.matching(
              index[row['id']] ?? {},
              '#${widget.hashtag}',
            ),
          });
        }
      }
      places
          .sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      if (!mounted) return;
      setState(() {
        _places = places;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text('#${widget.hashtag}'), actions: const [HomeButton()]),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _failed
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('לא ניתן לטעון את תוצאות ההאשטאג'),
                      TextButton(
                          onPressed: _load, child: const Text('נסה שוב')),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: Center(
                          child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(18),
                          children: [
                            Text(
                                '${_places.length} מקומות · האשטאגים מתוך חוויות משתמשים'),
                            const SizedBox(height: 16),
                            if (_places.isEmpty)
                              const Text(
                                  'לא נמצאו כרגע חוויות עם ההאשטאג הזה.'),
                            for (final place in _places)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: PlaceCard(
                                    place: place,
                                    onTap: () async {
                                      await Navigator.of(context)
                                          .push(MaterialPageRoute(
                                        builder: (_) =>
                                            PlaceDetailsScreen(place: place),
                                      ));
                                      if (mounted) await _load();
                                    }),
                              ),
                          ],
                        ),
                      )),
                    ),
        ),
      );
}
