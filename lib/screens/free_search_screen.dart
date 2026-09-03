import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/experience_hashtag_service.dart';
import '../theme/colors.dart';
import '../utils/experience_hashtags.dart';
import '../widgets/place_card.dart';
import 'place_details_screen.dart';

/// Free public discovery across all categories, independent of premium filters.
class FreeSearchScreen extends StatefulWidget {
  const FreeSearchScreen({super.key});
  @override
  State<FreeSearchScreen> createState() => _FreeSearchScreenState();
}

class _FreeSearchScreenState extends State<FreeSearchScreen> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _places = [];
  Map<String, Set<String>> _hashtags = {};
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _query.addListener(_searchChanged);
    _load();
  }

  void _searchChanged() => setState(() {});

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadPlaces() async {
    final places = <Map<String, dynamic>>[];
    for (var offset = 0;; offset += 500) {
      final rows = await Supabase.instance.client
          .from('places')
          .select(
            'id,name,category_id,user_id,description,address,latitude,longitude,image_url,categories(title)',
          )
          .order('id')
          .range(offset, offset + 499);
      places.addAll(rows);
      if (rows.length < 500) break;
    }
    places.sort((a, b) =>
        (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''));
    return places;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final results = await Future.wait([
        _loadPlaces(),
        ExperienceHashtagService.load(Supabase.instance.client),
      ]);
      if (!mounted) return;
      setState(() {
        _places = results[0] as List<Map<String, dynamic>>;
        _hashtags = results[1] as Map<String, Set<String>>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.text.trim();
    final matches = query.isEmpty
        ? <Map<String, dynamic>>[]
        : _places
            .where(
              (place) => ExperienceHashtags.matchesPlace(
                  place, _hashtags[place['id']] ?? {}, query),
            )
            .toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('חיפוש חופשי')),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              child: TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: 'שם, תיאור, כתובת או #האשטאג',
                  helperText: 'חיפוש בכל הקטגוריות · פתוח לכולם',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'ניקוי החיפוש',
                          onPressed: _query.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _failed
                        ? Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                const Text('לא ניתן לטעון את החיפוש'),
                                TextButton(
                                    onPressed: _load,
                                    child: const Text('נסה שוב')),
                              ]))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 18),
                              itemCount: matches.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(query.isEmpty
                                        ? 'מה מחפשים? אפשר לחפש גם האשטאג מתוך חוויה.'
                                        : matches.isEmpty
                                            ? 'לא נמצאו מקומות התואמים לחיפוש'
                                            : '${matches.length} מקומות מכל הקטגוריות'),
                                  );
                                }
                                final place = matches[index - 1];
                                final category = place['categories'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: PlaceCard(
                                      place: {
                                        ...place,
                                        'category_title': category is Map
                                            ? category['title']
                                            : null,
                                        'matched_hashtags':
                                            ExperienceHashtags.matching(
                                                _hashtags[place['id']] ?? {},
                                                query),
                                      },
                                      onTap: () async {
                                        FocusScope.of(context).unfocus();
                                        await Navigator.of(context)
                                            .push(MaterialPageRoute(
                                          builder: (_) =>
                                              PlaceDetailsScreen(place: place),
                                        ));
                                        if (mounted) await _load();
                                      }),
                                );
                              },
                            ))),
          ]),
        )),
      ),
    );
  }
}
