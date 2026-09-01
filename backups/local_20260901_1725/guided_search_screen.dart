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
  static const _centralRadiusKm = 2.0;

  final _client = Supabase.instance.client;
  final Set<String> _selectedCategoryIds = {};

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _allPlaces = [];
  List<Map<String, dynamic>> _results = [];
  Map<String, Set<String>> _tagNamesByPlace = {};
  _GuidedChoice? _selectedChoice;
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

  @override
  void initState() {
    super.initState();
    _loadData();
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
        _client
            .from('visits')
            .select('id, place_id, user_id, rating, price_level'),
      ]);

      final categories = List<Map<String, dynamic>>.from(responses[0]);
      final places = List<Map<String, dynamic>>.from(responses[1]);
      final visits = List<Map<String, dynamic>>.from(responses[2]);
      final metrics = _buildMetrics(visits);
      final tagsByPlace = await _loadTagNames(visits);

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
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _categories = categories;
        _allPlaces = enrichedPlaces;
        _tagNamesByPlace = tagsByPlace;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון את אפשרויות החיפוש';
      });
    }
  }

  Map<String, _PlaceMetric> _buildMetrics(
    List<Map<String, dynamic>> visits,
  ) {
    final builders = <String, _MetricBuilder>{};

    for (final visit in visits) {
      final placeId = visit['place_id']?.toString();
      if (placeId == null) continue;
      final builder = builders.putIfAbsent(placeId, _MetricBuilder.new);
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
      if (visitId != null && placeId != null) {
        visitToPlace[visitId] = placeId;
      }
    }
    if (visitToPlace.isEmpty) return {};

    final rows = await _client
        .from('visit_tag_links')
        .select('visit_id, visit_tags(name)')
        .inFilter('visit_id', visitToPlace.keys.toList());
    final result = <String, Set<String>>{};

    for (final rawRow in rows as List) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      final visitId = row['visit_id']?.toString();
      final placeId = visitId == null ? null : visitToPlace[visitId];
      final tag = row['visit_tags'];
      final name = tag is Map ? tag['name']?.toString().trim() : null;
      if (placeId != null && name != null && name.isNotEmpty) {
        result.putIfAbsent(placeId, () => <String>{}).add(name);
      }
    }

    return result;
  }

  Future<void> _search() async {
    final choice = _selectedChoice;
    if (choice == null) {
      setState(() => _error = 'יש לבחור מה מתאים לך היום');
      return;
    }

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      var places = _allPlaces.where((place) {
        return _selectedCategoryIds.isEmpty ||
            _selectedCategoryIds.contains(place['category_id']?.toString());
      }).toList();

      if (choice.locationBased) {
        final position =
            choice == _GuidedChoice.central ? null : await _currentPosition();
        places = _filterByLocation(places, choice, position);
      } else {
        final user = _client.auth.currentUser;
        if (user == null || user.isAnonymous) {
          throw Exception('יש להתחבר כדי להשתמש בסינון לפי אווירה');
        }
        places = _filterByTags(places, choice);
      }

      if (!mounted) return;
      setState(() {
        _results = places;
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

  List<Map<String, dynamic>> _filterByLocation(
    List<Map<String, dynamic>> places,
    _GuidedChoice choice,
    Position? position,
  ) {
    if (choice == _GuidedChoice.central) {
      final ranked = <Map<String, dynamic>>[];
      for (final place in places) {
        final coords = _coordinates(place);
        if (coords == null) continue;
        var nearbyCount = 0;
        for (final other in _allPlaces) {
          if (other['id'] == place['id']) continue;
          final otherCoords = _coordinates(other);
          if (otherCoords == null) continue;
          if (_distanceKm(coords, otherCoords) <= _centralRadiusKm) {
            nearbyCount++;
          }
        }
        ranked.add({
          ...place,
          '_central_count': nearbyCount,
          'recommendation_reason': nearbyCount == 1
              ? 'מקום קולינרי נוסף בסביבה הקרובה'
              : '$nearbyCount מקומות קולינריים נוספים בסביבה הקרובה',
        });
      }
      ranked.sort((a, b) {
        final density = ((b['_central_count'] as int?) ?? 0)
            .compareTo((a['_central_count'] as int?) ?? 0);
        if (density != 0) return density;
        return _ratingOf(b).compareTo(_ratingOf(a));
      });
      return ranked;
    }

    if (position == null) return [];
    final ranked = <Map<String, dynamic>>[];
    for (final place in places) {
      final coords = _coordinates(place);
      if (coords == null) continue;
      final distanceKm = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            coords.latitude,
            coords.longitude,
          ) /
          1000;
      final estimatedDrivingMinutes = (distanceKm * 1.25 / 55 * 60).round();

      final matches = choice == _GuidedChoice.nearby
          ? distanceKm <= _nearbyRadiusKm
          : estimatedDrivingMinutes <= 60;
      if (!matches) continue;

      ranked.add({
        ...place,
        '_distance_km': distanceKm,
        'distance_meters': distanceKm * 1000,
        'recommendation_reason': choice == _GuidedChoice.nearby
            ? 'קרוב למיקום שלך'
            : 'כ־$estimatedDrivingMinutes דקות נסיעה לפי הערכת מרחק',
      });
    }
    ranked.sort(
      (a, b) => ((a['_distance_km'] as num?)?.toDouble() ?? double.infinity)
          .compareTo(
        (b['_distance_km'] as num?)?.toDouble() ?? double.infinity,
      ),
    );
    return ranked;
  }

  List<Map<String, dynamic>> _filterByTags(
    List<Map<String, dynamic>> places,
    _GuidedChoice choice,
  ) {
    final wantedTags = choice.tagNames;
    final filtered = places.where((place) {
      final placeId = place['id']?.toString();
      final placeTags = _tagNamesByPlace[placeId] ?? const <String>{};
      return wantedTags.any(placeTags.contains);
    }).map((place) {
      return <String, dynamic>{
        ...place,
        'recommendation_reason': choice.label,
      };
    }).toList();

    filtered.sort((a, b) => _ratingOf(b).compareTo(_ratingOf(a)));
    return filtered;
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
    if (latitude == null || longitude == null) return null;
    return _Coordinates(latitude, longitude);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('מומלץ עבורך'),
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
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 40),
          children: [
            const Text(
              'מה בא לך היום?',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 29,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'בחר סוג מקום ואופי חיפוש, ואנחנו נצמצם עבורך את האפשרויות.',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textMuted, height: 1.45),
            ),
            const SizedBox(height: 24),
            _sectionTitle('איזה סוג מקום?'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              alignment: WrapAlignment.start,
              children: [
                _categoryChip(
                  id: '',
                  title: 'כל הקטגוריות',
                  icon: Icons.apps_rounded,
                ),
                ..._categories.map(
                  (category) => _categoryChip(
                    id: category['id']?.toString() ?? '',
                    title: category['title']?.toString() ?? '',
                    icon: AppIcons.categoryIcon(
                      category['icon']?.toString(),
                      title: category['title']?.toString(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            _sectionTitle('איפה ואיך?'),
            const SizedBox(height: 10),
            _choiceGrid(_GuidedChoice.locationChoices),
            const SizedBox(height: 26),
            _sectionTitle('איזו אווירה?'),
            const SizedBox(height: 10),
            _choiceGrid(_GuidedChoice.tagChoices),
            if (_error != null) ...[
              const SizedBox(height: 18),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : const Icon(Icons.search_rounded),
                label: const Text('מצא לי מקום'),
              ),
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
                  _sectionTitle('מקומות שמתאימים לבחירה'),
                ],
              ),
              const SizedBox(height: 12),
              if (_results.isEmpty)
                const _MessageState(
                  icon: Icons.search_off_rounded,
                  title: 'לא נמצאו מקומות מתאימים',
                  message:
                      'נסה לבחור קטגוריה אחרת או אפשרות חיפוש שונה. ככל שיתווספו מקומות ותגיות, התוצאות ישתפרו.',
                )
              else
                ..._results.map(
                  (place) => Padding(
                    padding: const EdgeInsets.only(bottom: 13),
                    child: PlaceCard(
                      place: place,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PlaceDetailsScreen(place: place),
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _categoryChip({
    required String id,
    required String title,
    required IconData icon,
  }) {
    final selected = id.isEmpty
        ? _selectedCategoryIds.isEmpty
        : _selectedCategoryIds.contains(id);
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 17,
        color: selected ? AppColors.background : AppColors.textMuted,
      ),
      label: Text(title),
      onSelected: (_) {
        setState(() {
          if (id.isEmpty) {
            _selectedCategoryIds.clear();
          } else if (selected) {
            _selectedCategoryIds.remove(id);
          } else {
            _selectedCategoryIds.add(id);
          }
          _searched = false;
        });
      },
    );
  }

  Widget _choiceGrid(List<_GuidedChoice> choices) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final itemWidth = width >= 700
            ? (width - 20) / 3
            : width >= 440
                ? (width - 10) / 2
                : width;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: choices.map((choice) {
            final selected = _selectedChoice == choice;
            return SizedBox(
              width: itemWidth,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedChoice = choice;
                    _searched = false;
                    _error = null;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 170),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.champagne
                        : AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          selected ? AppColors.champagne : AppColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        choice.icon,
                        color: selected
                            ? AppColors.background
                            : AppColors.champagne,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          choice.label,
                          style: TextStyle(
                            color: selected
                                ? AppColors.background
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (selected)
                        const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.background,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

enum _GuidedChoice {
  nearby('קרוב אליי', Icons.near_me_outlined, true, []),
  hourDrive('עד שעה נסיעה', Icons.schedule_rounded, true, []),
  central('מיקום מרכזי', Icons.location_city_outlined, true, []),
  beautiful('מקום יפה', Icons.photo_camera_outlined, false, ['מקום יפה']),
  dateNight('ערב זוגי', Icons.favorite_outline_rounded, false, ['מתאים לדייט']),
  children('עם ילדים', Icons.family_restroom_rounded, false, [
    'ידידותי לילדים',
    'מתאים למשפחות',
  ]),
  nature('טבע ונוף', Icons.landscape_outlined, false, ['טבע ונוף']),
  hidden('פינה נסתרת', Icons.explore_outlined, false, ['פינה נסתרת']),
  localSecret('סוד מקומי', Icons.key_outlined, false, ['סוד מקומי']);

  final String label;
  final IconData icon;
  final bool locationBased;
  final List<String> tagNames;

  const _GuidedChoice(
    this.label,
    this.icon,
    this.locationBased,
    this.tagNames,
  );

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

class _MetricBuilder {
  double ratingSum = 0;
  int ratingCount = 0;
  double priceSum = 0;
  int priceCount = 0;
  final Set<String> priceRaters = {};

  _PlaceMetric build() {
    return _PlaceMetric(
      averageRating: ratingCount == 0 ? null : ratingSum / ratingCount,
      ratingCount: ratingCount,
      averagePrice: priceCount == 0 ? null : priceSum / priceCount,
      priceRaterCount: priceRaters.length,
    );
  }
}

class _PlaceMetric {
  final double? averageRating;
  final int ratingCount;
  final double? averagePrice;
  final int priceRaterCount;

  const _PlaceMetric({
    this.averageRating,
    this.ratingCount = 0,
    this.averagePrice,
    this.priceRaterCount = 0,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
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
            style: const TextStyle(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
