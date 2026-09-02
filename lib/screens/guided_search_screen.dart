import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/premium_service.dart';
import '../theme/app_icons.dart';
import '../theme/colors.dart';
import '../widgets/home_button.dart';
import '../widgets/place_card.dart';
import 'place_details_screen.dart';

class GuidedSearchScreen extends StatefulWidget {
  const GuidedSearchScreen({super.key});

  @override
  State<GuidedSearchScreen> createState() => _GuidedSearchScreenState();
}

class _GuidedSearchScreenState extends State<GuidedSearchScreen> {
  static const _premiumAccessRequired = false;
  static const _nearbyRadiusKm = 10.0;
  static const _centralClusterRadiusKm = 1.0;
  static const _centralClusterMinimumNearbyPlaces = 3;

  final _client = Supabase.instance.client;
  final _searchController = TextEditingController();
  final Set<String> _selectedCategoryIds = {};
  final Set<_GuidedChoice> _selectedChoices = {};

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allPlaces = [];
  List<Map<String, dynamic>> _results = [];
  Map<String, Set<String>> _tagNamesByPlace = {};
  Set<String> _visitedPlaceIds = {};
  double _minimumRating = 0;
  double _maximumPriceLevel = 0;
  String _visitFilter = 'all';
  String _sortMode = 'match';
  bool _loading = true;
  bool _searching = false;
  bool _searched = false;
  String? _error;

  bool get _accessAllowed =>
      !_premiumAccessRequired || PremiumService.isPremium;

  bool get _isSignedIn {
    final user = _client.auth.currentUser;
    return user != null && !user.isAnonymous;
  }

  bool get _hasSelection =>
      _searchController.text.trim().isNotEmpty ||
      _selectedCategoryIds.isNotEmpty ||
      _selectedChoices.isNotEmpty ||
      _minimumRating > 0 ||
      _maximumPriceLevel > 0 ||
      _visitFilter != 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final responses = await Future.wait([
        _client
            .from('categories')
            .select('id, title, icon, sort_order')
            .order('sort_order'),
        _client.from('places').select(
              'id, user_id, category_id, name, description, address, '
              'latitude, longitude, image_url, created_at, categories(title)',
            ),
        _client.from('visits').select(
              'id, place_id, user_id, rating, price_level, created_at, '
              'notes',
            ),
      ]);

      final categories = List<Map<String, dynamic>>.from(responses[0]);
      final places = List<Map<String, dynamic>>.from(responses[1]);
      final visits = List<Map<String, dynamic>>.from(responses[2]);
      final metrics = _buildMetrics(visits);
      final tagsByPlace = await _loadTagNames(visits);
      final experienceTextByPlace = <String, String>{};
      for (final visit in visits) {
        final placeId = visit['place_id']?.toString();
        if (placeId == null) continue;
        final experienceText = [
          visit['notes'],
        ].whereType<String>().where((text) => text.trim().isNotEmpty).join(' ');
        if (experienceText.isEmpty) continue;
        experienceTextByPlace[placeId] =
            '${experienceTextByPlace[placeId] ?? ''} $experienceText'.trim();
      }
      final currentUserId = _client.auth.currentUser?.id;
      final visited = <String>{
        for (final visit in visits)
          if (visit['user_id']?.toString() == currentUserId &&
              visit['place_id'] != null)
            visit['place_id'].toString(),
      };

      final enrichedPlaces = places.map((place) {
        final placeId = place['id']?.toString();
        final metric = metrics[placeId] ?? const _PlaceMetric();
        final category = place['categories'];
        final categoryTitle =
            category is Map ? category['title']?.toString() ?? '' : '';
        return <String, dynamic>{
          ...place,
          'category_title': categoryTitle,
          'weighted_rating': metric.averageRating,
          'rating_count': metric.ratingCount,
          'average_price_level': metric.averagePrice,
          'price_rating_count': metric.priceRaterCount,
          'visit_count': metric.visitCount,
          'latest_visit_at': metric.latestVisit?.toIso8601String(),
          'experience_location_text': experienceTextByPlace[placeId] ?? '',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _allPlaces = enrichedPlaces;
        _tagNamesByPlace = tagsByPlace;
        _visitedPlaceIds = visited;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון את אפשרויות הסינון';
      });
    }
  }

  Map<String, _PlaceMetric> _buildMetrics(List<Map<String, dynamic>> visits) {
    final builders = <String, _MetricBuilder>{};
    for (final visit in visits) {
      final placeId = visit['place_id']?.toString();
      if (placeId == null) continue;
      final builder = builders.putIfAbsent(placeId, _MetricBuilder.new);
      builder.visitCount++;
      final createdAt =
          DateTime.tryParse(visit['created_at']?.toString() ?? '');
      if (createdAt != null &&
          (builder.latestVisit == null ||
              createdAt.isAfter(builder.latestVisit!))) {
        builder.latestVisit = createdAt;
      }
      final rating = (visit['rating'] as num?)?.toDouble();
      if (rating != null && rating > 0) {
        builder.ratingSum += rating;
        builder.ratingCount++;
      }
      final price = (visit['price_level'] as num?)?.toDouble();
      if (price != null && price > 0) {
        builder.priceSum += price;
        builder.priceCount++;
        final userId = visit['user_id']?.toString();
        if (userId != null) builder.priceRaters.add(userId);
      }
    }
    return {
      for (final entry in builders.entries) entry.key: entry.value.build(),
    };
  }

  Future<Map<String, Set<String>>> _loadTagNames(
    List<Map<String, dynamic>> visits,
  ) async {
    final visitToPlace = <String, String>{};
    for (final visit in visits) {
      final visitId = visit['id']?.toString();
      final placeId = visit['place_id']?.toString();
      if (visitId != null && placeId != null) visitToPlace[visitId] = placeId;
    }
    if (visitToPlace.isEmpty) return {};
    final rows = await _client
        .from('visit_tag_links')
        .select('visit_id, visit_tags(name)')
        .inFilter('visit_id', visitToPlace.keys.toList());
    final result = <String, Set<String>>{};
    for (final rawRow in rows as List) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      final placeId = visitToPlace[row['visit_id']?.toString()];
      final tag = row['visit_tags'];
      final name = tag is Map ? tag['name']?.toString().trim() : null;
      if (placeId != null && name != null && name.isNotEmpty) {
        result.putIfAbsent(placeId, () => <String>{}).add(name);
      }
    }
    return result;
  }

  Future<void> _search() async {
    if (!_hasSelection) {
      setState(() => _error = 'יש לבחור לפחות אפשרות אחת');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final needsLocation = _selectedChoices.contains(_GuidedChoice.nearby) ||
          _selectedChoices.contains(_GuidedChoice.hourDrive) ||
          _sortMode == 'distance';
      final position = needsLocation ? await _currentPosition() : null;
      final evaluated = _allPlaces
          .map((place) => _evaluatePlace(place, position))
          .where((result) => result.meetsRequiredCriteria)
          .toList()
        ..sort(_compareResults);
      if (!mounted) return;
      setState(() {
        _results = evaluated.map((result) => result.place).toList();
        _searched = true;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  _SearchResult _evaluatePlace(
      Map<String, dynamic> original, Position? position) {
    final place = Map<String, dynamic>.from(original);
    final missing = <String>[];
    var matched = 0;
    var total = 0;
    var meetsRequiredCriteria = true;

    void criterion(
      bool matches,
      String label, {
      bool required = false,
    }) {
      total++;
      if (matches) {
        matched++;
      } else {
        missing.add(label);
        if (required) meetsRequiredCriteria = false;
      }
    }

    if (_selectedCategoryIds.isNotEmpty) {
      criterion(
        _selectedCategoryIds.contains(place['category_id']?.toString()),
        'סוג המקום',
        required: true,
      );
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      final searchable = [place['name'], place['description'], place['address']]
          .join(' ')
          .toLowerCase();
      criterion(
        searchable.contains(query),
        'חיפוש “$query”',
        required: true,
      );
    }

    final placeId = place['id']?.toString() ?? '';
    final placeTags = _tagNamesByPlace[placeId] ?? const <String>{};
    final coords = _coordinates(place);
    double? distanceKm;
    if (position != null && coords != null) {
      distanceKm = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            coords.latitude,
            coords.longitude,
          ) /
          1000;
      place['distance_meters'] = distanceKm * 1000;
    }

    final selectedLocationChoices =
        _selectedChoices.where(_GuidedChoice.locationChoices.contains).toList();
    if (selectedLocationChoices.isNotEmpty) {
      var matchesAnyLocation = false;
      for (final choice in selectedLocationChoices) {
        switch (choice) {
          case _GuidedChoice.nearby:
            matchesAnyLocation |=
                distanceKm != null && distanceKm <= _nearbyRadiusKm;
            break;
          case _GuidedChoice.hourDrive:
            final minutes = distanceKm == null
                ? null
                : (distanceKm * 1.25 / 55 * 60).round();
            matchesAnyLocation |= minutes != null && minutes <= 60;
            break;
          case _GuidedChoice.central:
            matchesAnyLocation |= _isCentralLocation(place);
            break;
          default:
            break;
        }
      }
      criterion(
        matchesAnyLocation,
        selectedLocationChoices.map((choice) => choice.label).join(' או '),
        required: true,
      );
    }

    for (final choice in _selectedChoices
        .where((choice) => !_GuidedChoice.locationChoices.contains(choice))) {
      criterion(choice.tagNames.any(placeTags.contains), choice.label);
    }
    if (_minimumRating > 0) {
      final rating = (place['weighted_rating'] as num?)?.toDouble();
      criterion(
        rating != null && rating >= _minimumRating,
        'דירוג ${_minimumRating.toStringAsFixed(0)} ומעלה',
        required: true,
      );
    }
    if (_maximumPriceLevel > 0) {
      final price = (place['average_price_level'] as num?)?.toDouble();
      criterion(
        price != null && price <= _maximumPriceLevel,
        'מחיר עד ${_priceLabel(_maximumPriceLevel)}',
        required: true,
      );
    }
    if (_visitFilter != 'all') {
      final visited = _visitedPlaceIds.contains(placeId);
      criterion(
        _visitFilter == 'visited' ? visited : !visited,
        _visitFilter == 'visited' ? 'ביקרתי' : 'טרם ביקרתי',
        required: true,
      );
    }

    place['recommendation_reason'] = missing.isEmpty
        ? 'התאמה מלאה · $matched מתוך $total'
        : 'חסר: ${missing.join(' · ')}';
    return _SearchResult(
      place,
      matched,
      distanceKm,
      meetsRequiredCriteria,
    );
  }

  bool _isCentralLocation(Map<String, dynamic> place) {
    final searchable = [
      place['name'],
      place['description'],
      place['address'],
      place['experience_location_text'],
    ].join(' ').toLowerCase();
    const centralLocationMarkers = [
      'קניון',
      'מרכז מסחרי',
      'מרכז קניות',
      'מרכז העיר',
      'לב העיר',
      'העיר העתיקה',
      'מתחם קניות',
      'mall',
      'shopping center',
      'city center',
      'downtown',
    ];
    if (centralLocationMarkers.any(searchable.contains)) return true;

    final coordinates = _coordinates(place);
    if (coordinates == null) return false;
    var nearbyPlaces = 0;
    for (final otherPlace in _allPlaces) {
      if (otherPlace['id'] == place['id']) continue;
      final otherCoordinates = _coordinates(otherPlace);
      if (otherCoordinates != null &&
          _distanceKm(coordinates, otherCoordinates) <=
              _centralClusterRadiusKm) {
        nearbyPlaces++;
      }
    }
    return nearbyPlaces >= _centralClusterMinimumNearbyPlaces;
  }

  int _compareResults(_SearchResult a, _SearchResult b) {
    final matchComparison = b.matched.compareTo(a.matched);
    if (matchComparison != 0) return matchComparison;
    switch (_sortMode) {
      case 'distance':
        return (a.distanceKm ?? double.infinity)
            .compareTo(b.distanceKm ?? double.infinity);
      case 'rating':
        return _ratingOf(b.place).compareTo(_ratingOf(a.place));
      case 'popular':
        return ((b.place['visit_count'] as num?)?.toInt() ?? 0)
            .compareTo((a.place['visit_count'] as num?)?.toInt() ?? 0);
      case 'newest':
        return _dateOf(b.place).compareTo(_dateOf(a.place));
      default:
        final ratingComparison =
            _ratingOf(b.place).compareTo(_ratingOf(a.place));
        return ratingComparison != 0
            ? ratingComparison
            : (a.distanceKm ?? double.infinity)
                .compareTo(b.distanceKm ?? double.infinity);
    }
  }

  DateTime _dateOf(Map<String, dynamic> place) {
    return DateTime.tryParse(
          place['latest_visit_at']?.toString() ??
              place['created_at']?.toString() ??
              '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<Position> _currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('שירותי המיקום כבויים במכשיר');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('לא ניתנה הרשאה למיקום');
    }
    return Geolocator.getCurrentPosition();
  }

  _Coordinates? _coordinates(Map<String, dynamic> place) {
    final latitude = (place['latitude'] as num?)?.toDouble();
    final longitude = (place['longitude'] as num?)?.toDouble();
    return latitude == null || longitude == null
        ? null
        : _Coordinates(latitude, longitude);
  }

  double _distanceKm(_Coordinates first, _Coordinates second) {
    return Geolocator.distanceBetween(
          first.latitude,
          first.longitude,
          second.latitude,
          second.longitude,
        ) /
        1000;
  }

  double _ratingOf(Map<String, dynamic> place) {
    return (place['weighted_rating'] as num?)?.toDouble() ?? 0;
  }

  String _priceLabel(double value) {
    return List.filled(value.round().clamp(1, 4), '₪').join();
  }

  void _selectionChanged(VoidCallback change) {
    setState(() {
      change();
      _searched = false;
      _error = null;
    });
  }

  void _clear() {
    _selectionChanged(() {
      _searchController.clear();
      _selectedCategoryIds.clear();
      _selectedChoices.clear();
      _minimumRating = 0;
      _maximumPriceLevel = 0;
      _visitFilter = 'all';
      _sortMode = 'match';
      _results = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('סינון מתקדם'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 1.5));
    }
    if (!_isSignedIn) {
      return const _MessageState(
        icon: Icons.lock_outline_rounded,
        title: 'יש להתחבר כדי להשתמש בסינון המתקדם',
        message: 'האפשרות מבוססת על נתוני המקומות והחוויות באפליקציה.',
      );
    }
    if (!_accessAllowed) {
      return const _MessageState(
        icon: Icons.workspace_premium_outlined,
        title: 'אפשרות למשתמשי פרימיום',
        message: 'הסינון המתקדם זמין במסגרת BITE THE WAY Premium.',
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
          children: [
            const Text(
              'מה בא לך היום?',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'קטגוריה, מיקום, דירוג ומחיר הם תנאי חובה. באווירה ובסגנון נציג קודם התאמות מלאות ואחריהן את האפשרויות הקרובות ביותר לבחירה שלך.',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              onChanged: (_) => _selectionChanged(() {}),
              decoration: InputDecoration(
                hintText: 'חיפוש בשם, תיאור או כתובת',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () =>
                            _selectionChanged(_searchController.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('סוג מקום', 'אפשר לבחור כמה קטגוריות'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((category) {
                final id = category['id']?.toString() ?? '';
                final selected = _selectedCategoryIds.contains(id);
                return FilterChip(
                  selected: selected,
                  avatar: Icon(
                    AppIcons.categoryIcon(
                      category['icon']?.toString(),
                      title: category['title']?.toString(),
                    ),
                    size: 17,
                  ),
                  label: Text(category['title']?.toString() ?? ''),
                  onSelected: (_) => _selectionChanged(() {
                    selected
                        ? _selectedCategoryIds.remove(id)
                        : _selectedCategoryIds.add(id);
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _sectionTitle(
              'מיקום',
              'מספיק שאחת מאפשרויות המיקום שנבחרו תתאים',
            ),
            const SizedBox(height: 10),
            _choiceGrid(_GuidedChoice.locationChoices),
            const SizedBox(height: 24),
            _sectionTitle('אווירה וסגנון', 'אפשר לשלב כמה העדפות'),
            const SizedBox(height: 10),
            _choiceGrid(_GuidedChoice.tagChoices),
            const SizedBox(height: 24),
            _sectionTitle('דירוג מינימלי', 'לפי דירוגי הקהילה'),
            const SizedBox(height: 10),
            _singleChoiceRow(
              values: const [0, 3, 4, 5],
              selected: _minimumRating,
              label: (value) => value == 0
                  ? 'ללא הגבלה'
                  : '${value.toStringAsFixed(0)}★ ומעלה',
              onSelected: (value) =>
                  _selectionChanged(() => _minimumRating = value),
            ),
            const SizedBox(height: 24),
            _sectionTitle('מחיר מרבי', 'לפי דיווחי המשתמשים'),
            const SizedBox(height: 10),
            _singleChoiceRow(
              values: const [0, 1, 2, 3, 4],
              selected: _maximumPriceLevel,
              label: (value) => value == 0 ? 'ללא הגבלה' : _priceLabel(value),
              onSelected: (value) =>
                  _selectionChanged(() => _maximumPriceLevel = value),
            ),
            const SizedBox(height: 24),
            _sectionTitle('ביקורים', 'אפשר לבחור לפי ההיסטוריה שלך'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _textChoice('all', 'הכול'),
                _textChoice('visited', 'ביקרתי'),
                _textChoice('not_visited', 'טרם ביקרתי'),
              ],
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _sortMode,
              decoration: const InputDecoration(labelText: 'מיון משני'),
              items: const [
                DropdownMenuItem(
                  value: 'match',
                  child: Text('ההתאמה הטובה ביותר'),
                ),
                DropdownMenuItem(
                  value: 'distance',
                  child: Text('המרחק הקצר ביותר'),
                ),
                DropdownMenuItem(value: 'rating', child: Text('דירוג')),
                DropdownMenuItem(value: 'popular', child: Text('פופולריות')),
                DropdownMenuItem(value: 'newest', child: Text('חדש')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _selectionChanged(() => _sortMode = value);
                }
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _hasSelection ? _clear : null,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('ניקוי'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _searching ? null : _search,
                      icon: _searching
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                              ),
                            )
                          : const Icon(Icons.manage_search_rounded),
                      label: const Text('הצגת תוצאות'),
                    ),
                  ),
                ),
              ],
            ),
            if (_searched) ...[
              const SizedBox(height: 32),
              Row(
                children: [
                  Text(
                    '${_results.length} תוצאות',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'לפי מידת ההתאמה',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_results.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        color: AppColors.champagne,
                        size: 30,
                      ),
                      SizedBox(height: 9),
                      Text(
                        'לא נמצאה כרגע התאמה שעומדת בכל תנאי החובה',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'אפשר להרחיב את טווח הנסיעה או לשנות קטגוריה.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              else
                ..._results.map(
                  (place) => Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: PlaceCard(
                      place: place,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlaceDetailsScreen(place: place),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _choiceGrid(List<_GuidedChoice> choices) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: choices.map((choice) {
        final selected = _selectedChoices.contains(choice);
        return FilterChip(
          selected: selected,
          avatar: Icon(choice.icon, size: 17),
          label: Text(choice.label),
          onSelected: (_) => _selectionChanged(() {
            selected
                ? _selectedChoices.remove(choice)
                : _selectedChoices.add(choice);
          }),
        );
      }).toList(),
    );
  }

  Widget _singleChoiceRow({
    required List<double> values,
    required double selected,
    required String Function(double) label,
    required ValueChanged<double> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        return ChoiceChip(
          selected: selected == value,
          label: Text(label(value)),
          onSelected: (_) => onSelected(value),
        );
      }).toList(),
    );
  }

  Widget _textChoice(String value, String label) {
    return ChoiceChip(
      selected: _visitFilter == value,
      label: Text(label),
      onSelected: (_) => _selectionChanged(() => _visitFilter = value),
    );
  }
}

enum _GuidedChoice {
  nearby('קרוב אליי', Icons.near_me_outlined, []),
  hourDrive('עד שעה נסיעה', Icons.schedule_rounded, []),
  central('מיקום מרכזי', Icons.location_city_outlined, []),
  beautiful('מקום יפה', Icons.photo_camera_outlined, ['מקום יפה']),
  dateNight('ערב זוגי', Icons.favorite_outline_rounded, ['מתאים לדייט']),
  children('עם ילדים', Icons.family_restroom_rounded,
      ['ידידותי לילדים', 'מתאים למשפחות']),
  nature('טבע ונוף', Icons.landscape_outlined, ['טבע ונוף']),
  hidden('פינה נסתרת', Icons.explore_outlined, ['פינה נסתרת']),
  localSecret('סוד מקומי', Icons.key_outlined, ['סוד מקומי']);

  final String label;
  final IconData icon;
  final List<String> tagNames;

  const _GuidedChoice(this.label, this.icon, this.tagNames);

  static const locationChoices = [nearby, hourDrive, central];
  static const tagChoices = [
    beautiful,
    dateNight,
    children,
    nature,
    hidden,
    localSecret,
  ];
}

class _Coordinates {
  final double latitude;
  final double longitude;

  const _Coordinates(this.latitude, this.longitude);
}

class _SearchResult {
  final Map<String, dynamic> place;
  final int matched;
  final double? distanceKm;
  final bool meetsRequiredCriteria;

  const _SearchResult(
    this.place,
    this.matched,
    this.distanceKm,
    this.meetsRequiredCriteria,
  );
}

class _MetricBuilder {
  double ratingSum = 0;
  int ratingCount = 0;
  double priceSum = 0;
  int priceCount = 0;
  int visitCount = 0;
  DateTime? latestVisit;
  final Set<String> priceRaters = {};

  _PlaceMetric build() => _PlaceMetric(
        averageRating: ratingCount == 0 ? null : ratingSum / ratingCount,
        ratingCount: ratingCount,
        averagePrice: priceCount == 0 ? null : priceSum / priceCount,
        priceRaterCount: priceRaters.length,
        visitCount: visitCount,
        latestVisit: latestVisit,
      );
}

class _PlaceMetric {
  final double? averageRating;
  final int ratingCount;
  final double? averagePrice;
  final int priceRaterCount;
  final int visitCount;
  final DateTime? latestVisit;

  const _PlaceMetric({
    this.averageRating,
    this.ratingCount = 0,
    this.averagePrice,
    this.priceRaterCount = 0,
    this.visitCount = 0,
    this.latestVisit,
  });
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.champagne.withValues(alpha: 0.16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.champagne, size: 38),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
