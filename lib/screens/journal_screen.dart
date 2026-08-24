import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/premium_service.dart';
import '../theme/colors.dart';
import 'add_visit_screen.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final SupabaseClient _client = Supabase.instance.client;

  List<Map<String, dynamic>> _visits = [];
  bool _loading = true;
  String? _error;
  int _section = 0;
  // ignore: unused_field
  List<Map<String, dynamic>> _collections = [];
  // ignore: unused_field
  bool _collectionsLoading = false;

@override
  void initState() {
    super.initState();
    _loadVisits();
    _loadCollections();
  }

  Future<void> _loadVisits() async {
    final user = _client.auth.currentUser;

    if (user == null || user.isAnonymous || !PremiumService.isPremium) {
      if (!mounted) return;
      setState(() {
        _visits = [];
        _loading = false;
      });
      return;
    }

    try {
      final rows = await _client
          .from('visits')
          .select(
            'id, place_id, created_at, visit_date, notes, journal_note, '
            'with_whom, favorite_memory, food_rating, drink_rating, '
            'atmosphere_rating, service_rating, cleanliness_rating, '
            'variety_rating, value_rating, rating, drink, drink_price, '
            'image_url, places(id, name, address, image_url, latitude, longitude, categories(title)), '
            'visit_tag_links(*, visit_tags(*)), visit_images(id, image_url, sort_order)',
          )
          .eq('user_id', user.id)
          .order('visit_date', ascending: false)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _visits = List<Map<String, dynamic>>.from(rows);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

    Future<void> _loadCollections() async {
      final user = _client.auth.currentUser;
      if (user == null || user.isAnonymous || !PremiumService.isPremium) return;
  
      try {
        if (mounted) setState(() => _collectionsLoading = true);
  
        final rows = await _client
            .from('journal_collections')
            .select(
              'id, name, description, cover_image_url, created_at, '
              'journal_collection_visits(visit_id)',
            )
            .eq('user_id', user.id)
            .order('created_at', ascending: false);
  
        if (!mounted) return;
  
        setState(() {
          _collections = List<Map<String, dynamic>>.from(rows);
          _collectionsLoading = false;
        });
      } catch (e) {
        if (mounted) setState(() => _collectionsLoading = false);
      }
  }

  Future<void> _toggleMemory(Map<String, dynamic> visit) async {
    final id = visit['id'];
    if (id == null) return;

    final current = visit['favorite_memory'] == true;

    try {
      await _client
          .from('visits')
          .update({'favorite_memory': !current})
          .eq('id', id)
          .eq('user_id', _client.auth.currentUser!.id);

      if (!mounted) return;

      setState(() {
        visit['favorite_memory'] = !current;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('לא ניתן לשמור את הזיכרון: $e')),
      );
    }
  }

  String _date(String? value) {
    if (value == null || value.isEmpty) return '';
    final d = DateTime.tryParse(value);
    if (d == null) return '';

    const months = [
      'ינואר',
      'פברואר',
      'מרץ',
      'אפריל',
      'מאי',
      'יוני',
      'יולי',
      'אוגוסט',
      'ספטמבר',
      'אוקטובר',
      'נובמבר',
      'דצמבר'
    ];

    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  double? _rating(Map<String, dynamic> v) {
    final values = [
      v['food_rating'],
      v['drink_rating'],
      v['atmosphere_rating'],
      v['service_rating'],
      v['cleanliness_rating'],
      v['variety_rating'],
      v['value_rating'],
    ]
        .map((x) => (x as num?)?.toDouble())
        .whereType<double>()
        .where((x) => x > 0)
        .toList();

    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Future<void> _openVisit(Map<String, dynamic> visit) async {
    final place = visit['places'] is Map
        ? Map<String, dynamic>.from(visit['places'] as Map)
        : <String, dynamic>{};

    if (place.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddVisitScreen(
          place: place,
          visit: visit,
          viewOnly: true,
        ),
      ),
    );

    if (mounted) await _loadVisits();
  }

  List<Map<String, dynamic>> get _favorites =>
      _visits.where((v) => v['favorite_memory'] == true).toList();

  int get _placeCount =>
      _visits.map((v) => v['place_id']).where((x) => x != null).toSet().length;

  double? get _average {
    final values = _visits.map(_rating).whereType<double>().toList();

    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  String _categorySummary() {
    final counts = <String, int>{};

    for (final v in _visits) {
      final place = v['places'];
      if (place is! Map) continue;

      final categoryData = place['categories'];
      final category =
          categoryData is Map ? categoryData['title']?.toString().trim() : null;
      if (category == null || category.isEmpty) continue;

      counts[category] = (counts[category] ?? 0) + 1;
    }

    if (counts.isEmpty) return '—';

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    return sorted.first.key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        title: const Text(
          'היומן שלי',
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: AppColors.ink,
            fontSize: 23,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!PremiumService.isPremium) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'היומן שלי זמין למשתמשי Premium.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 16,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.brass,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: TextButton(
          onPressed: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _loadVisits();
          },
          child: const Text('לא ניתן לטעון את היומן — נסה שוב'),
        ),
      );
    }

    return Column(
      children: [
        _buildHeader(),
        const SizedBox(height: 4),
        _buildSections(),
        const SizedBox(height: 4),
        Expanded(child: _buildSectionBody()),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          _stat('${_visits.length}', 'ביקורים'),
          _stat('$_placeCount', 'מקומות'),
          _stat(_average?.toStringAsFixed(1) ?? '—', 'ממוצע'),
          _stat(_categorySummary(), 'קטגוריה מובילה'),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSections() {
    const labels = ['ציר זמן', 'זיכרונות', 'סטטיסטיקות'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = _section == i;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: selected,
              onSelected: (_) => setState(() => _section = i),
              selectedColor: AppColors.brass.withValues(alpha: 0.18),
              backgroundColor: AppColors.card,
              labelStyle: TextStyle(
                color: selected ? AppColors.ink : AppColors.muted,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              side: BorderSide(
                color: selected
                    ? AppColors.brass.withValues(alpha: 0.4)
                    : AppColors.muted.withValues(alpha: 0.12),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionBody() {
    switch (_section) {
      case 1:
        return _buildMemories();
      case 2:
        return _buildStatistics();
      default:
        return _buildTimeline(_visits);
    }
  }

  Widget _buildTimeline(List<Map<String, dynamic>> visits) {
    if (visits.isEmpty) {
      return _empty('היומן שלך עדיין ריק', 'כל ביקור שתוסיף יופיע כאן.');
    }

    return RefreshIndicator(
      color: AppColors.brass,
      backgroundColor: AppColors.card,
      onRefresh: _loadVisits,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: visits.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: AppColors.muted.withValues(alpha: 0.12),
        ),
        itemBuilder: (_, i) => _entry(visits[i]),
      ),
    );
  }

  Widget _entry(Map<String, dynamic> visit) {
    final place = visit['places'] is Map
        ? Map<String, dynamic>.from(visit['places'] as Map)
        : <String, dynamic>{};

    final name = place['name']?.toString().trim().isNotEmpty == true
        ? place['name'].toString().trim()
        : 'מקום ללא שם';

    final address = place['address']?.toString().trim() ?? '';
    final visitImage = visit['image_url']?.toString().trim() ?? '';
    final placeImage = place['image_url']?.toString().trim() ?? '';
    final image = visitImage.isNotEmpty ? visitImage : placeImage;
    final rating = _rating(visit);
    final date = _date(visit['visit_date']?.toString());
    final note =
        (visit['journal_note'] ?? visit['notes'])?.toString().trim() ?? '';
    final withWhom = visit['with_whom']?.toString().trim() ?? '';
    final drink = visit['drink']?.toString().trim() ?? '';

    return InkWell(
      onTap: () => _openVisit(visit),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumbnail(image),
            const SizedBox(width: 10),
            IconButton(
              tooltip: visit['favorite_memory'] == true
                  ? 'הסר מזיכרונות'
                  : 'שמור בזיכרונות',
              onPressed: () => _toggleMemory(visit),
              icon: Icon(
                visit['favorite_memory'] == true
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: visit['favorite_memory'] == true
                    ? AppColors.brass
                    : AppColors.muted,
                size: 21,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _toggleMemory(visit),
                        tooltip: visit['favorite_memory'] == true
                            ? 'הסר מזיכרונות'
                            : 'שמור בזיכרונות',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        icon: Icon(
                          visit['favorite_memory'] == true
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 20,
                          color: visit['favorite_memory'] == true
                              ? AppColors.brass
                              : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 7),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 9,
                    runSpacing: 4,
                    children: [
                      if (date.isNotEmpty) _meta(Icons.event_outlined, date),
                      if (rating != null)
                        _meta(Icons.star_rounded, rating.toStringAsFixed(1)),
                      if (drink.isNotEmpty)
                        _meta(Icons.local_cafe_outlined, drink),
                      if (withWhom.isNotEmpty)
                        _meta(Icons.people_outline_rounded, withWhom),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (visit['visit_tag_links'] is List)
                    _tags(visit['visit_tag_links']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemories() {
    if (_favorites.isEmpty) {
      return _empty(
        'אין עדיין זיכרונות מיוחדים',
        'כל ביקור כבר נמצא ביומן.\nסמן ❤️ ליד ביקור כדי לשמור אותו גם בזיכרונות.',
      );
    }

    return _buildTimeline(_favorites);
  }

  Widget _buildStatistics() {
    final ratings = _visits.map(_rating).whereType<double>().toList();
    final totalImages = _visits.fold<int>(0, (sum, v) {
      final images = v['visit_images'];
      return sum + (images is List ? images.length : 0);
    });

    final drinks = _visits
        .map((v) => v['drink']?.toString().trim())
        .where((v) => v != null && v.isNotEmpty)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
      children: [
        _bigStat('מספר ביקורים', '${_visits.length}', Icons.menu_book_outlined),
        _bigStat('מקומות שונים', '$_placeCount', Icons.place_outlined),
        _bigStat(
          'דירוג אישי ממוצע',
          ratings.isEmpty
              ? '—'
              : (ratings.reduce((a, b) => a + b) / ratings.length)
                  .toStringAsFixed(1),
          Icons.star_outline_rounded,
        ),
        _bigStat('תמונות ביומן', '$totalImages', Icons.photo_library_outlined),
        _bigStat('ביקורים עם משקה', '$drinks', Icons.local_cafe_outlined),
        _bigStat('קטגוריה מובילה', _categorySummary(), Icons.category_outlined),
      ],
    );
  }

  Widget _bigStat(String title, String value, IconData icon) {
    return Card(
      color: AppColors.card,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: AppColors.brass),
        title: Text(
          title,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        trailing: Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _tags(dynamic raw) {
    if (raw is! List || raw.isEmpty) return const SizedBox.shrink();

    final labels = <String>[];

    for (final item in raw) {
      if (item is! Map) continue;
      final tag = item['tags'];

      if (tag is Map) {
        final value = tag['name']?.toString().trim();
        if (value != null && value.isNotEmpty) labels.add(value);
      }
    }

    if (labels.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 5,
        runSpacing: 5,
        children: labels.take(4).map((label) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.brass.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10.5,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.brass),
        const SizedBox(width: 3),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _thumbnail(String url) {
    const size = 72.0;

    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(
          Icons.restaurant_outlined,
          size: 23,
          color: AppColors.muted,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.card,
            child: const Icon(
              Icons.image_outlined,
              size: 23,
              color: AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.menu_book_outlined,
              size: 40,
              color: AppColors.brass,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 21,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
