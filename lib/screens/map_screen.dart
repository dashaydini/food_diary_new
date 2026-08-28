import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../theme/app_icons.dart';
import '../widgets/home_button.dart';
import 'place_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _categories = [];

  String? _selectedCategoryId;

  bool _loading = true;
  String? _error;

  bool _nearbyOnly = false;
  double _nearbyRadiusKm = 10;

  Position? _currentPosition;

  static const LatLng _defaultCenter = LatLng(31.7683, 35.2137);

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    try {
      final client = Supabase.instance.client;

      final results = await Future.wait([
        client
            .from('places')
            .select(
              'id, user_id, category_id, name, description, address, '
              'latitude, longitude, image_url',
            )
            .not('latitude', 'is', null)
            .not('longitude', 'is', null),
        client
            .from('categories')
            .select('id, title, subtitle, icon, sort_order')
            .order('sort_order'),
      ]);

      final places = List<Map<String, dynamic>>.from(results[0] as List);
      final categories = List<Map<String, dynamic>>.from(results[1] as List);

      if (!mounted) return;

      setState(() {
        _places = places;
        _categories = categories;
        _nearbyOnly = false;
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

  List<Map<String, dynamic>> get _filteredPlaces {
    if (_selectedCategoryId == null) {
      return _places;
    }

    return _places
        .where(
          (place) => place['category_id']?.toString() == _selectedCategoryId,
        )
        .toList();
  }

  String _categoryTitle(String? categoryId) {
    if (categoryId == null) return '';

    for (final category in _categories) {
      if (category['id']?.toString() == categoryId) {
        return category['title']?.toString() ?? '';
      }
    }

    return '';
  }

  IconData _categoryIcon(String? categoryId) {
    if (categoryId == null) {
      return Icons.place_outlined;
    }

    for (final category in _categories) {
      if (category['id']?.toString() == categoryId) {
        return AppIcons.categoryIcon(
          category['icon']?.toString(),
          title: category['title']?.toString(),
        );
      }
    }

    return Icons.place_outlined;
  }

  LatLng? _placePoint(Map<String, dynamic> place) {
    final latitude = (place['latitude'] as num?)?.toDouble();
    final longitude = (place['longitude'] as num?)?.toDouble();

    if (latitude == null || longitude == null) {
      return null;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    return LatLng(latitude, longitude);
  }

  void _openPlace(Map<String, dynamic> place) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaceDetailsScreen(
          place: {
            ...place,
            'category_title': _categoryTitle(
              place['category_id']?.toString(),
            ),
          },
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (final place in _filteredPlaces) {
      final point = _placePoint(place);

      if (point == null) continue;

      final categoryId = place['category_id']?.toString();
      final icon = _categoryIcon(categoryId);

      markers.add(
        Marker(
          point: point,
          width: 42,
          height: 42,
          child: GestureDetector(
            onTap: () => _openPlace(place),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background.withValues(alpha: 0.94),
                border: Border.all(
                  color: AppColors.champagne.withValues(alpha: 0.46),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: AppColors.champagne.withValues(alpha: 0.08),
                    blurRadius: 14,
                    spreadRadius: -3,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 19,
                color: AppColors.champagne,
              ),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildRadiusFilter() {
    if (!_nearbyOnly) {
      return const SizedBox.shrink();
    }

    const radii = <double>[1, 5, 10, 25, 50];

    return Positioned(
      top: 66,
      left: 12,
      right: 12,
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          children: radii.map((radius) {
            final selected = _nearbyRadiusKm == radius;

            return Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final position = _currentPosition;
                    if (position == null) return;

                    setState(() {
                      _nearbyRadiusKm = radius;
                    });

                    await _loadNearbyPlaces(position);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.champagne.withValues(alpha: 0.10)
                          : AppColors.background.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppColors.champagne.withValues(alpha: 0.42)
                            : AppColors.champagne.withValues(alpha: 0.15),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${radius.toInt()} ק״מ',
                      style: TextStyle(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          children: [
            _buildFilterChip(
              label: _nearbyOnly ? 'כל המקומות' : 'הכול',
              selected: _selectedCategoryId == null && !_nearbyOnly,
              onTap: () async {
                if (_nearbyOnly) {
                  await _loadMapData();
                  return;
                }

                setState(() {
                  _selectedCategoryId = null;
                });
              },
            ),
            ..._categories.map(
              (category) {
                final id = category['id']?.toString();
                final title = category['title']?.toString() ?? '';

                return _buildFilterChip(
                  label: title,
                  selected: _selectedCategoryId == id,
                  onTap: () {
                    setState(() {
                      _selectedCategoryId = id;
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.champagne.withValues(alpha: 0.10)
                  : AppColors.background.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? AppColors.champagne.withValues(alpha: 0.42)
                    : AppColors.champagne.withValues(alpha: 0.16),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                color:
                    selected ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadNearbyPlaces(Position position) async {
    try {
      final rows = await Supabase.instance.client.rpc(
        'get_nearby_places',
        params: {
          'user_lat': position.latitude,
          'user_lon': position.longitude,
          'radius_km': _nearbyRadiusKm,
        },
      );

      final places = List<Map<String, dynamic>>.from(rows as List);

      if (!mounted) return;

      setState(() {
        _places = places;
        _nearbyOnly = true;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('לא ניתן לטעון מקומות בסביבה: $e'),
        ),
      );
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('שירותי המיקום כבויים'),
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('אין הרשאה להשתמש במיקום'),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      _currentPosition = position;

      await _loadNearbyPlaces(position);

      if (!mounted) return;

      _mapController.move(
        LatLng(
          position.latitude,
          position.longitude,
        ),
        13,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('מציג מקומות בטווח של 10 ק״מ'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן לקבל את המיקום הנוכחי'),
        ),
      );
    }
  }

  Widget _buildMap() {
    final markers = _buildMarkers();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: 8,
            minZoom: 3,
            maxZoom: 19,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fooddiary.app',
            ),
            MarkerLayer(
              markers: markers,
            ),
          ],
        ),
        _buildCategoryFilter(),
        _buildRadiusFilter(),
        Positioned(
          bottom: 18,
          right: 18,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background.withValues(alpha: 0.94),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.30),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              tooltip: 'מיקום נוכחי',
              onPressed: _goToCurrentLocation,
              icon: Icon(
                Icons.my_location_outlined,
                size: 19,
                color: AppColors.champagne.withValues(alpha: 0.90),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 18,
          left: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.20),
                width: 0.75,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '${markers.length} מקומות',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'מפה',
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.champagne,
              ),
            )
          : _error != null
              ? Center(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _loadMapData();
                    },
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                    ),
                    label: const Text('נסה שוב'),
                  ),
                )
              : _buildMap(),
    );
  }
}
