import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/premium_service.dart';
import '../theme/colors.dart';
import '../widgets/home_button.dart';
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
            'variety_rating, value_rating, rating, food, food_price, '
            'drink, drink_price, total_price, price_level, image_url, '
            'places(id, name, address, image_url, latitude, longitude, categories(title)), '
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

  double _expensesBetween(DateTime start, DateTime end) {
    return _visits.fold<double>(0, (total, visit) {
      final visitDate =
          DateTime.tryParse(visit['visit_date']?.toString() ?? '')?.toLocal();
      final price = (visit['total_price'] as num?)?.toDouble();

      if (visitDate == null || price == null || price <= 0) return total;
      if (visitDate.isBefore(start) || !visitDate.isBefore(end)) return total;

      return total + price;
    });
  }

  String _priceText(double value) {
    final amount = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return '₪$amount';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'היומן שלי',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
        ),
        actions: const [
          HomeButton(),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!PremiumService.isPremium) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.champagne.withValues(alpha: 0.15),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.champagne.withValues(alpha: 0.03),
                    blurRadius: 26,
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: const Text(
                'היומן שלי זמין למשתמשי Premium.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.champagne,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _loading = true;
              _error = null;
            });
            _loadVisits();
          },
          icon: const Icon(
            Icons.refresh_rounded,
            size: 18,
          ),
          label: const Text('נסה שוב'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 14 : 24,
                mobile ? 8 : 14,
                mobile ? 14 : 24,
                0,
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildExpenseSummary(),
                  const SizedBox(height: 14),
                  _buildSections(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildSectionBody(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.14),
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.028),
            blurRadius: 24,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: [
          _stat('${_visits.length}', 'חוויות'),
          _stat('$_placeCount', 'מקומות'),
          _stat(_average?.toStringAsFixed(1) ?? '—', 'ממוצע'),
          _stat(_categorySummary(), 'מובילה'),
        ],
      ),
    );
  }

  Widget _buildExpenseSummary() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday % 7));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month);
    final monthEnd = DateTime(now.year, now.month + 1);

    final weeklyTotal = _expensesBetween(weekStart, weekEnd);
    final monthlyTotal = _expensesBetween(monthStart, monthEnd);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.16),
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.025),
            blurRadius: 22,
            spreadRadius: -7,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _expenseStat(
                  _priceText(weeklyTotal),
                  'השבוע',
                  Icons.date_range_outlined,
                ),
              ),
              Container(
                width: 0.7,
                height: 38,
                color: AppColors.lineSoft,
              ),
              Expanded(
                child: _expenseStat(
                  _priceText(monthlyTotal),
                  'החודש',
                  Icons.calendar_month_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          const Text(
            'סיכום הוצאות · רק מחוויות שהוספת',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expenseStat(String value, String label, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.champagne),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSections() {
    const labels = [
      ('ציר זמן', Icons.timeline_rounded),
      ('זיכרונות', Icons.favorite_border_rounded),
      ('סטטיסטיקות', Icons.bar_chart_rounded),
    ];

    return Align(
      alignment: Alignment.centerRight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(labels.length, (i) {
            final selected = _section == i;

            return Padding(
              padding: const EdgeInsets.only(left: 7),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _section = i;
                  });
                },
                borderRadius: BorderRadius.circular(22),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.champagne.withValues(alpha: 0.075)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: selected
                          ? AppColors.champagne.withValues(alpha: 0.35)
                          : AppColors.champagne.withValues(alpha: 0.11),
                      width: 0.75,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        labels[i].$2,
                        size: 15,
                        color: selected
                            ? AppColors.champagneSoft
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        labels[i].$1,
                        style: TextStyle(
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
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
      return _empty(
        'היומן שלך עדיין ריק',
        'כל חוויה שתוסיף תופיע כאן.',
      );
    }

    return RefreshIndicator(
      color: AppColors.champagne,
      backgroundColor: AppColors.background,
      onRefresh: _loadVisits,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 42),
        itemCount: visits.length,
        separatorBuilder: (_, __) => const SizedBox(height: 11),
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
    final favorite = visit['favorite_memory'] == true;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.045),
            blurRadius: 28,
            spreadRadius: -7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _openVisit(visit),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.15),
                width: 0.75,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumbnail(image),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (address.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _toggleMemory(visit),
                            tooltip:
                                favorite ? 'הסר מזיכרונות' : 'שמור בזיכרונות',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            icon: Icon(
                              favorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: favorite
                                  ? AppColors.champagne.withValues(alpha: 0.82)
                                  : AppColors.textMuted.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          if (date.isNotEmpty)
                            _meta(Icons.event_outlined, date),
                          if (rating != null)
                            _meta(
                              Icons.star_rounded,
                              rating.toStringAsFixed(1),
                            ),
                          if (drink.isNotEmpty)
                            _meta(Icons.local_cafe_outlined, drink),
                          if (withWhom.isNotEmpty)
                            _meta(
                              Icons.people_outline_rounded,
                              withWhom,
                            ),
                        ],
                      ),
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
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
        ),
      ),
    );
  }

  Widget _buildMemories() {
    if (_favorites.isEmpty) {
      return _empty(
        'אין עדיין זיכרונות מיוחדים',
        'כל חוויה כבר מופיעה ביומן.\n'
            'סמן את הלב ליד חוויה כדי לשמור אותה גם בזיכרונות.',
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
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 42),
      children: [
        _bigStat(
          'מספר חוויות',
          '${_visits.length}',
          Icons.menu_book_outlined,
        ),
        _bigStat(
          'מקומות שונים',
          '$_placeCount',
          Icons.place_outlined,
        ),
        _bigStat(
          'דירוג אישי ממוצע',
          ratings.isEmpty
              ? '—'
              : (ratings.reduce((a, b) => a + b) / ratings.length)
                  .toStringAsFixed(1),
          Icons.star_outline_rounded,
        ),
        _bigStat(
          'תמונות ביומן',
          '$totalImages',
          Icons.photo_library_outlined,
        ),
        _bigStat(
          'חוויות עם משקה',
          '$drinks',
          Icons.local_cafe_outlined,
        ),
        _bigStat(
          'קטגוריה מובילה',
          _categorySummary(),
          Icons.category_outlined,
        ),
      ],
    );
  }

  Widget _bigStat(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.14),
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.025),
            blurRadius: 22,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.champagne.withValues(alpha: 0.055),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.13),
                width: 0.7,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color: AppColors.champagne.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tags(dynamic raw) {
    if (raw is! List || raw.isEmpty) {
      return const SizedBox.shrink();
    }

    final labels = <String>[];

    for (final item in raw) {
      if (item is! Map) continue;

      final tag = item['visit_tags'] ?? item['tags'];

      if (tag is Map) {
        final value = tag['name']?.toString().trim();

        if (value != null && value.isNotEmpty) {
          labels.add(value);
        }
      }
    }

    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 5,
        runSpacing: 5,
        children: labels.take(4).map((label) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.champagne.withValues(alpha: 0.045),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.16),
                width: 0.7,
              ),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 10,
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
        Icon(
          icon,
          size: 12.5,
          color: AppColors.champagne.withValues(alpha: 0.70),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }

  Widget _thumbnail(String url) {
    const size = 76.0;

    Widget fallback(IconData icon) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.champagne.withValues(alpha: 0.12),
            width: 0.7,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: AppColors.textMuted.withValues(alpha: 0.70),
        ),
      );
    }

    if (url.isEmpty) {
      return fallback(Icons.restaurant_outlined);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.13),
          width: 0.7,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.025),
            blurRadius: 16,
            spreadRadius: -5,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return fallback(Icons.image_outlined);
        },
      ),
    );
  }

  Widget _empty(String title, String subtitle) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 28,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.13),
                width: 0.75,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.champagne.withValues(alpha: 0.025),
                  blurRadius: 24,
                  spreadRadius: -6,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 31,
                  color: AppColors.champagne.withValues(alpha: 0.70),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
