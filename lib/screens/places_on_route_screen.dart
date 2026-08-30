import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';
import '../widgets/navigation_app_picker.dart';
import '../widgets/place_card.dart';
import 'place_details_screen.dart';

class PlacesOnRouteScreen extends StatefulWidget {
  const PlacesOnRouteScreen({super.key});

  @override
  State<PlacesOnRouteScreen> createState() => _PlacesOnRouteScreenState();
}

class _PlacesOnRouteScreenState extends State<PlacesOnRouteScreen> {
  static const _maximumRelevantDetourKm = 20.0;

  final _client = Supabase.instance.client;
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _availableTags = [];
  final Set<String> _selectedCategoryIds = {};
  final Set<String> _selectedTagIds = {};
  final Map<String, Set<String>> _placeTagIds = {};
  final Set<String> _selectedStopIds = {};
  List<_RoutePlace> _results = [];
  Map<String, dynamic>? _routeOrigin;
  Map<String, dynamic>? _routeDestination;

  bool _useCurrentLocation = true;
  bool _loading = false;
  String? _error;
  double _minimumRating = 0;
  int _maximumPriceLevel = 0;
  DateTime? _lastGeocodeRequest;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await _client
          .from('categories')
          .select('id, title, sort_order')
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(rows);
      });
    } catch (_) {}
  }

  Future<void> _findPlaces() async {
    final destinationText = _destinationController.text.trim();
    final originText = _originController.text.trim();
    if (destinationText.isEmpty ||
        (!_useCurrentLocation && originText.isEmpty)) {
      setState(() => _error = 'יש להזין נקודת יציאה ויעד');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });

    try {
      final _GeoPoint origin = _useCurrentLocation
          ? await _currentLocation()
          : await _geocode(originText);
      final destination = await _geocode(destinationText);

      _routeOrigin = {
        'latitude': origin.latitude,
        'longitude': origin.longitude,
      };
      _routeDestination = {
        'name': destinationText,
        'address': destinationText,
        'latitude': destination.latitude,
        'longitude': destination.longitude,
      };

      final queryResults = await Future.wait([
        _client
            .from('places')
            .select(
              'id, user_id, category_id, name, description, address, '
              'latitude, longitude, image_url, created_at, categories(title)',
            )
            .not('latitude', 'is', null)
            .not('longitude', 'is', null),
        _client
            .from('visits')
            .select('id, place_id, user_id, rating, price_level'),
      ]);

      final places = List<Map<String, dynamic>>.from(queryResults[0]);
      final visits = List<Map<String, dynamic>>.from(queryResults[1]);
      await _loadPlaceTags(visits);
      final metrics = _buildMetrics(visits);
      final routeLengthKm = _distanceKm(origin, destination);
      final results = <_RoutePlace>[];

      for (final place in places) {
        final categoryId = place['category_id']?.toString();
        if (_selectedCategoryIds.isNotEmpty &&
            !_selectedCategoryIds.contains(categoryId)) {
          continue;
        }
        final placeId = place['id']?.toString();
        if (_selectedTagIds.isNotEmpty &&
            !_selectedTagIds.any(
              (tagId) => _placeTagIds[placeId]?.contains(tagId) ?? false,
            )) {
          continue;
        }

        final latitude = (place['latitude'] as num?)?.toDouble();
        final longitude = (place['longitude'] as num?)?.toDouble();
        if (latitude == null || longitude == null) continue;
        final point = _GeoPoint(latitude, longitude);
        final projection = _projectOnSegment(origin, destination, point);
        final estimatedDetourKm = projection.distanceFromLineKm * 2.4;
        if (estimatedDetourKm > _maximumRelevantDetourKm) continue;

        final metric = metrics[placeId] ?? const _PlaceMetric();
        if (_minimumRating > 0 &&
            (metric.averageRating == null ||
                metric.averageRating! < _minimumRating)) {
          continue;
        }
        if (_maximumPriceLevel > 0 &&
            (metric.averagePrice == null ||
                metric.averagePrice! > _maximumPriceLevel)) {
          continue;
        }

        final alongKm = routeLengthKm * projection.fraction;
        final addedMinutes = _estimatedAddedMinutes(estimatedDetourKm);
        final category = place['categories'];
        final categoryTitle =
            category is Map ? category['title']?.toString() ?? '' : '';
        final enriched = <String, dynamic>{
          ...place,
          'category_title': categoryTitle,
          'weighted_rating': metric.averageRating,
          'rating_count': metric.ratingCount,
          'average_price_level': metric.averagePrice,
          'price_rating_count': metric.priceRaterCount,
          'route_added_minutes': addedMinutes,
          'recommendation_reason': 'בעוד כ־${alongKm.toStringAsFixed(1)} ק״מ · '
              'מוסיף כ־$addedMinutes דקות לנסיעה',
        };
        results.add(
          _RoutePlace(
            place: enriched,
            alongKm: alongKm,
          ),
        );
      }

      results.sort((a, b) => a.alongKm.compareTo(b.alongKm));
      if (!mounted) return;
      setState(() {
        _results = results;
        _selectedStopIds.removeWhere(
          (id) => !results.any((result) => result.id == id),
        );
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<_GeoPoint> _currentLocation() async {
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
    final position = await Geolocator.getCurrentPosition();
    return _GeoPoint(position.latitude, position.longitude);
  }

  Future<_GeoPoint> _geocode(String address) async {
    final lastRequest = _lastGeocodeRequest;
    if (lastRequest != null) {
      final wait =
          const Duration(seconds: 1) - DateTime.now().difference(lastRequest);
      if (!wait.isNegative) await Future<void>.delayed(wait);
    }
    _lastGeocodeRequest = DateTime.now();

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': address,
      'format': 'jsonv2',
      'limit': '1',
      'accept-language': 'he',
    });
    final response = await http.get(
      uri,
      headers: const {'User-Agent': 'BiteTheWay/1.0'},
    );
    if (response.statusCode != 200) {
      throw Exception('לא ניתן לחפש את הכתובת כרגע');
    }
    final rows = jsonDecode(response.body) as List<dynamic>;
    if (rows.isEmpty) throw Exception('לא נמצאה הכתובת "$address"');
    final row = rows.first as Map<String, dynamic>;
    final latitude = double.tryParse(row['lat']?.toString() ?? '');
    final longitude = double.tryParse(row['lon']?.toString() ?? '');
    if (latitude == null || longitude == null) {
      throw Exception('לא התקבל מיקום תקין עבור "$address"');
    }
    return _GeoPoint(latitude, longitude);
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

  Future<void> _loadPlaceTags(List<Map<String, dynamic>> visits) async {
    _availableTags = [];
    _placeTagIds.clear();
    final visitToPlace = <String, String>{};
    for (final visit in visits) {
      final visitId = visit['id']?.toString();
      final placeId = visit['place_id']?.toString();
      if (visitId != null && placeId != null) {
        visitToPlace[visitId] = placeId;
      }
    }
    if (visitToPlace.isEmpty) return;

    final rows = await _client
        .from('visit_tag_links')
        .select('visit_id, tag_id, visit_tags(id, name, icon)')
        .inFilter('visit_id', visitToPlace.keys.toList());
    final tagsById = <String, Map<String, dynamic>>{};
    for (final rawRow in rows as List) {
      final row = Map<String, dynamic>.from(rawRow as Map);
      final visitId = row['visit_id']?.toString();
      final tagId = row['tag_id']?.toString();
      final placeId = visitId == null ? null : visitToPlace[visitId];
      if (tagId == null || placeId == null) continue;
      _placeTagIds.putIfAbsent(placeId, () => <String>{}).add(tagId);
      final tag = row['visit_tags'];
      if (tag is Map && (tag['name']?.toString().trim() ?? '').isNotEmpty) {
        tagsById[tagId] = {
          'id': tagId,
          'name': tag['name'].toString(),
          'icon': tag['icon']?.toString(),
        };
      }
    }
    _availableTags = tagsById.values.toList()
      ..sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );
    _selectedTagIds.removeWhere((id) => !tagsById.containsKey(id));
  }

  Future<void> _showTagSelector() async {
    if (_availableTags.isEmpty) return;
    final selected = Set<String>.from(_selectedTagIds);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.75,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'סינון לפי תגיות',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: _availableTags.map((tag) {
                          final id = tag['id'].toString();
                          return CheckboxListTile(
                            value: selected.contains(id),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              tag['name'].toString(),
                              textAlign: TextAlign.right,
                            ),
                            onChanged: (enabled) {
                              setSheetState(() {
                                enabled == true
                                    ? selected.add(id)
                                    : selected.remove(id);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(selected),
                      child: const Text('החל סינון'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _selectedTagIds
        ..clear()
        ..addAll(result);
    });
    await _findPlaces();
  }

  double _distanceKm(_GeoPoint first, _GeoPoint second) {
    return Geolocator.distanceBetween(
          first.latitude,
          first.longitude,
          second.latitude,
          second.longitude,
        ) /
        1000;
  }

  int _estimatedAddedMinutes(double detourKm) {
    const estimatedMinutesPerKm = 2.0;
    const roundingInterval = 5;
    final rawMinutes = detourKm * estimatedMinutesPerKm;
    return math.max(
      roundingInterval,
      (rawMinutes / roundingInterval).ceil() * roundingInterval,
    );
  }

  _Projection _projectOnSegment(
    _GeoPoint start,
    _GeoPoint end,
    _GeoPoint point,
  ) {
    final referenceLatitude = (start.latitude + end.latitude) / 2;
    final longitudeScale = math.cos(referenceLatitude * math.pi / 180);
    final endX = (end.longitude - start.longitude) * longitudeScale;
    final endY = end.latitude - start.latitude;
    final pointX = (point.longitude - start.longitude) * longitudeScale;
    final pointY = point.latitude - start.latitude;
    final lengthSquared = endX * endX + endY * endY;
    final rawFraction = lengthSquared == 0
        ? 0.0
        : (pointX * endX + pointY * endY) / lengthSquared;
    final fraction = rawFraction.clamp(0.0, 1.0).toDouble();
    final projected = _GeoPoint(
      start.latitude + (end.latitude - start.latitude) * fraction,
      start.longitude + (end.longitude - start.longitude) * fraction,
    );
    return _Projection(
      fraction: fraction,
      distanceFromLineKm: _distanceKm(projected, point),
    );
  }

  void _toggleStop(String id) {
    setState(() {
      if (!_selectedStopIds.remove(id)) {
        _selectedStopIds.add(id);
      }
    });
  }

  List<_RoutePlace> get _selectedStops =>
      _results.where((result) => _selectedStopIds.contains(result.id)).toList();

  Future<void> _showSelectedStops() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final stops = _selectedStops;
            final addedMinutes = stops.fold<int>(
              0,
              (total, stop) =>
                  total +
                  ((stop.place['route_added_minutes'] as num?)?.toInt() ?? 0),
            );
            return Directionality(
              textDirection: TextDirection.rtl,
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.75,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'העצירות שלך בדרך',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'לפי סדר ההתקדמות ליעד · תוספת כוללת משוערת כ־$addedMinutes דקות',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: stops.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final stop = stops[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.champagne,
                                  foregroundColor: AppColors.background,
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(
                                  stop.place['name']?.toString() ?? '',
                                  textAlign: TextAlign.right,
                                ),
                                subtitle: Text(
                                  'מוסיף כ־${stop.place['route_added_minutes']} דקות',
                                  textAlign: TextAlign.right,
                                ),
                                trailing: IconButton(
                                  tooltip: 'הסר עצירה',
                                  onPressed: () {
                                    _toggleStop(stop.id);
                                    setSheetState(() {});
                                    if (_selectedStopIds.isEmpty) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: stops.isEmpty || _routeDestination == null
                              ? null
                              : () async {
                                  Navigator.of(sheetContext).pop();
                                  await NavigationAppPicker.show(
                                    this.context,
                                    _routeDestination!,
                                    from: _routeOrigin,
                                    waypoints: stops
                                        .map((stop) => stop.place)
                                        .toList(),
                                    title:
                                        'התחלת ניווט עם ${stops.length} ${stops.length == 1 ? 'עצירה' : 'עצירות'}',
                                  );
                                },
                          icon: const Icon(Icons.navigation_rounded),
                          label: const Text('התחל ניווט'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('מקומות בדרך'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 700;
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    mobile ? 16 : 28,
                    18,
                    mobile ? 16 : 28,
                    36,
                  ),
                  children: [
                    _buildRouteForm(),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                    if (_loading) ...[
                      const SizedBox(height: 28),
                      const Center(
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ] else if (_results.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'נמצאו ${_results.length} מקומות לאורך הדרך המשוערת',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._results.map(
                        (result) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: PlaceCard(
                            place: result.place,
                            actionLabel: _selectedStopIds.contains(result.id)
                                ? 'נוסף למסלול'
                                : 'הוסף עצירה',
                            actionIcon: _selectedStopIds.contains(result.id)
                                ? Icons.check_circle_outline_rounded
                                : Icons.add_location_alt_outlined,
                            actionSelected:
                                _selectedStopIds.contains(result.id),
                            onNavigate: () => _toggleStop(result.id),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PlaceDetailsScreen(
                                  place: result.place,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else if (_error == null) ...[
                      const SizedBox(height: 28),
                      const Text(
                        'מזינים נקודת יציאה ויעד כדי למצוא מקומות לאורך הדרך.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _selectedStopIds.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: FilledButton.icon(
                    onPressed: _showSelectedStops,
                    icon: const Icon(Icons.alt_route_rounded),
                    label: Text(
                      'המשך עם ${_selectedStopIds.length} '
                      '${_selectedStopIds.length == 1 ? 'עצירה' : 'עצירות'}',
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildRouteForm() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'מאיפה יוצאים?',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('המיקום הנוכחי')),
              ButtonSegment(value: false, label: Text('כתובת אחרת')),
            ],
            selected: {_useCurrentLocation},
            onSelectionChanged: (value) {
              setState(() => _useCurrentLocation = value.first);
            },
          ),
          if (!_useCurrentLocation) ...[
            const SizedBox(height: 12),
            _addressField(_originController, 'כתובת יציאה'),
          ],
          const SizedBox(height: 16),
          const Text(
            'מה היעד?',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _addressField(_destinationController, 'כתובת יעד'),
          const SizedBox(height: 18),
          const Text(
            'קטגוריות בדרך',
            textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 7,
            runSpacing: 7,
            children: _categories.map((category) {
              final id = category['id']?.toString() ?? '';
              final selected = _selectedCategoryIds.contains(id);
              return FilterChip(
                selected: selected,
                showCheckmark: true,
                checkmarkColor: AppColors.background,
                selectedColor: AppColors.champagne,
                backgroundColor: AppColors.inputBg,
                side: BorderSide(
                  color: selected ? AppColors.champagne : AppColors.cardBorder,
                  width: selected ? 1.2 : 0.8,
                ),
                label: Text(category['title']?.toString() ?? ''),
                labelStyle: TextStyle(
                  color:
                      selected ? AppColors.background : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                onSelected: (isSelected) {
                  setState(() {
                    isSelected
                        ? _selectedCategoryIds.add(id)
                        : _selectedCategoryIds.remove(id);
                  });
                },
              );
            }).toList(),
          ),
          if (_availableTags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _showTagSelector,
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: Text(
                  _selectedTagIds.isEmpty
                      ? 'סינון לפי תגיות'
                      : '${_selectedTagIds.length} תגיות נבחרו',
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _optionRow(
            title: 'דירוג מינימלי',
            values: const [0, 3, 4, 5],
            selected: _minimumRating,
            label: (value) {
              if (value == 0) return 'הכול';
              if (value == 5) return '5★';
              return '${value.toInt()}★ ומעלה';
            },
            onSelected: (value) => setState(() => _minimumRating = value),
          ),
          const SizedBox(height: 16),
          const Text(
            'רמת מחיר מקסימלית',
            textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 7),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 7,
            children: [0, 1, 2, 3, 4].map((price) {
              return ChoiceChip(
                selected: _maximumPriceLevel == price,
                label: Text(
                  price == 0 ? 'כל המחירים' : List.filled(price, '₪').join(),
                ),
                onSelected: (_) => setState(() => _maximumPriceLevel = price),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _findPlaces,
            icon: const Icon(Icons.route_outlined),
            label: const Text('מצא מקומות בדרך'),
          ),
          const SizedBox(height: 10),
          const Text(
            'המסלול והסטייה הם הערכה בלבד · נתוני כתובות © OpenStreetMap',
            textAlign: TextAlign.right,
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _addressField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.location_on_outlined),
      ),
    );
  }

  Widget _optionRow({
    required String title,
    required List<double> values,
    required double selected,
    required String Function(double) label,
    required ValueChanged<double> onSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 7),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 7,
          runSpacing: 7,
          children: values.map((value) {
            return ChoiceChip(
              selected: selected == value,
              label: Text(label(value)),
              onSelected: (_) => onSelected(value),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _GeoPoint {
  final double latitude;
  final double longitude;

  const _GeoPoint(this.latitude, this.longitude);
}

class _Projection {
  final double fraction;
  final double distanceFromLineKm;

  const _Projection({
    required this.fraction,
    required this.distanceFromLineKm,
  });
}

class _RoutePlace {
  final Map<String, dynamic> place;
  final double alongKm;

  const _RoutePlace({
    required this.place,
    required this.alongKm,
  });

  String get id => place['id']?.toString() ?? '';
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
