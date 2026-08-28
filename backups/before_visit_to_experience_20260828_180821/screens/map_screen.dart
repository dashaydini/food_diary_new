import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
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

      markers.add(
        Marker(
          point: point,
          width: 46,
          height: 54,
          child: GestureDetector(
            onTap: () => _openPlace(place),
            child: const Icon(
              Icons.location_pin,
              size: 46,
              color: AppColors.brass,
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
      top: 68,
      left: 12,
      right: 12,
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          children: radii.map((radius) {
            final selected = _nearbyRadiusKm == radius;

            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Material(
                color: selected ? AppColors.brass : AppColors.card,
                elevation: 3,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: () async {
                    final position = _currentPosition;
                    if (position == null) return;

                    setState(() {
                      _nearbyRadiusKm = radius;
                    });

                    await _loadNearbyPlaces(position);
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Text(
                      '${radius.toInt()} ק״מ',
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.ink,
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
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
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: selected ? AppColors.brass : AppColors.card,
        elevation: 3,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
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
          child: Material(
            color: AppColors.card,
            elevation: 4,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: 'מיקום נוכחי',
              icon: const Icon(Icons.my_location),
              color: AppColors.brass,
              onPressed: _goToCurrentLocation,
            ),
          ),
        ),
        Positioned(
          bottom: 18,
          left: 18,
          child: Material(
            color: AppColors.card,
            elevation: 4,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 9,
              ),
              child: Text(
                '${markers.length} מקומות',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
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
        elevation: 0,
        title: const Text('מפה'),
        actions: const [
          HomeButton(),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('לא ניתן לטעון את המפה'),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _loading = true;
                            _error = null;
                          });
                          _loadMapData();
                        },
                        child: const Text('נסה שוב'),
                      ),
                    ],
                  ),
                )
              : _buildMap(),
    );
  }
}
