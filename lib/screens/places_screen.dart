import 'place_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_place_screen.dart';

import '../models/content_filter.dart';
import '../theme/colors.dart';
import '../widgets/home_button.dart';
import '../widgets/place_card.dart';

class PlacesScreen extends StatefulWidget {
  final String categoryId;
  final String categoryTitle;
  final ContentFilter filter;

  const PlacesScreen({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    this.filter = ContentFilter.all,
  });

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _allPlaces = [];

  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _availableTags = [];
  List<Map<String, dynamic>> _availableCategories = [];
  final Set<String> _selectedTagIds = {};
  final Set<String> _selectedCategoryIds = {};
  final Map<String, Set<String>> _placeTagIds = {};
  final Set<String> _visitedPlaceIds = {};

  bool _matchAllTags = true;
  bool _nearMe = false;
  bool _loadingLocation = false;
  Position? _currentPosition;
  double _minimumRating = 0;
  double _maximumPriceLevel = 0;
  String _visitFilter = 'all';
  String _sortMode = 'name';
  bool _loading = true;
  bool _advancedFilterOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds.add(widget.categoryId);
    _searchController.addListener(_applyAdvancedFilters);
    _loadPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      final results = await Future.wait([
        client
            .from('places')
            .select(
              'id, user_id, category_id, name, description, address, '
              'latitude, longitude, image_url, created_at',
            )
            .order('name'),
        client
            .from('categories')
            .select('id, title, sort_order')
            .order('sort_order'),
      ]);

      final rows = results[0];
      _availableCategories = List<Map<String, dynamic>>.from(results[1]);

      var places = List<Map<String, dynamic>>.from(rows);

      // Calculate the weighted place score from all rated visits.
      if (places.isNotEmpty) {
        final placeIds = places
            .map((place) => place['id']?.toString())
            .whereType<String>()
            .toList();

        if (placeIds.isNotEmpty) {
          final visitRows = await client
              .from('visits')
              .select('place_id, user_id, rating, price_level, created_at')
              .inFilter('place_id', placeIds);

          final ratingSums = <String, double>{};
          final ratingCounts = <String, int>{};
          final priceSums = <String, double>{};
          final priceCounts = <String, int>{};
          final priceRaterIds = <String, Set<String>>{};
          final visitCounts = <String, int>{};
          final latestVisits = <String, DateTime>{};

          _visitedPlaceIds.clear();

          if (user != null && !user.isAnonymous) {
            final ownVisitRows = await client
                .from('visits')
                .select('place_id')
                .eq('user_id', user.id)
                .inFilter('place_id', placeIds);

            for (final row in ownVisitRows as List) {
              final placeId = row['place_id']?.toString();
              if (placeId != null) _visitedPlaceIds.add(placeId);
            }
          }

          for (final row in visitRows as List) {
            final placeId = row['place_id']?.toString();
            final rating = (row['rating'] as num?)?.toDouble();
            final priceLevel = (row['price_level'] as num?)?.toDouble();
            final raterId = row['user_id']?.toString();

            if (placeId == null) continue;

            visitCounts[placeId] = (visitCounts[placeId] ?? 0) + 1;

            final createdAt = DateTime.tryParse(
              row['created_at']?.toString() ?? '',
            );
            if (createdAt != null &&
                (latestVisits[placeId] == null ||
                    createdAt.isAfter(latestVisits[placeId]!))) {
              latestVisits[placeId] = createdAt;
            }

            if (rating != null && rating > 0) {
              ratingSums[placeId] = (ratingSums[placeId] ?? 0) + rating;
              ratingCounts[placeId] = (ratingCounts[placeId] ?? 0) + 1;
            }

            if (priceLevel != null && priceLevel > 0) {
              priceSums[placeId] = (priceSums[placeId] ?? 0) + priceLevel;
              priceCounts[placeId] = (priceCounts[placeId] ?? 0) + 1;
              if (raterId != null) {
                priceRaterIds.putIfAbsent(placeId, () => <String>{}).add(
                      raterId,
                    );
              }
            }
          }

          places = places.map((place) {
            final placeId = place['id']?.toString();
            final count = placeId == null ? 0 : (ratingCounts[placeId] ?? 0);
            final sum = placeId == null ? 0.0 : (ratingSums[placeId] ?? 0.0);

            return {
              ...place,
              'weighted_rating': count > 0 ? sum / count : null,
              'rating_count': count,
              'average_price_level': (priceCounts[placeId] ?? 0) > 0
                  ? (priceSums[placeId] ?? 0) / priceCounts[placeId]!
                  : null,
              'price_rating_count': priceRaterIds[placeId]?.length ?? 0,
              'visit_count': visitCounts[placeId] ?? 0,
              'latest_visit_at': latestVisits[placeId]?.toIso8601String(),
            };
          }).toList();
        }
      }

      if (user != null && !user.isAnonymous) {
        final filter = widget.filter;

        if (filter == ContentFilter.mine) {
          final myVisits = await client
              .from('visits')
              .select('place_id')
              .eq('user_id', user.id);

          final myPlaceIds = {
            for (final row in myVisits as List)
              if (row['place_id'] != null) row['place_id'].toString(),
          };

          places = places.where((place) {
            final ownerId = place['user_id']?.toString();
            final placeId = place['id']?.toString();

            return ownerId == user.id || myPlaceIds.contains(placeId);
          }).toList();
        } else if (filter == ContentFilter.favorites ||
            filter == ContentFilter.wishlist) {
          final preferenceRows = await client
              .from('user_place_preferences')
              .select('place_id, is_favorite, is_wishlist')
              .eq('user_id', user.id);

          final ids = <String>{};

          for (final row in preferenceRows as List) {
            final enabled = filter == ContentFilter.favorites
                ? row['is_favorite'] == true
                : row['is_wishlist'] == true;

            if (enabled && row['place_id'] != null) {
              ids.add(row['place_id'].toString());
            }
          }

          places = places.where((place) {
            return ids.contains(place['id']?.toString());
          }).toList();
        } else if (filter == ContentFilter.nearby) {
          try {
            final serviceEnabled = await Geolocator.isLocationServiceEnabled();

            if (!serviceEnabled) {
              places = [];
            } else {
              var permission = await Geolocator.checkPermission();

              if (permission == LocationPermission.denied) {
                permission = await Geolocator.requestPermission();
              }

              if (permission == LocationPermission.denied ||
                  permission == LocationPermission.deniedForever) {
                places = [];
              } else {
                final position = await Geolocator.getCurrentPosition();

                final nearbyRows = await client.rpc(
                  'get_nearby_places',
                  params: {
                    'user_lat': position.latitude,
                    'user_lon': position.longitude,
                    'radius_km': 10,
                  },
                );

                final nearbyIds = {
                  for (final row in nearbyRows as List)
                    if (row['id'] != null) row['id'].toString(),
                };

                places = places.where((place) {
                  return nearbyIds.contains(place['id']?.toString());
                }).toList();
              }
            }
          } catch (e) {
            debugPrint('NEARBY FILTER ERROR: $e');
            places = [];
          }
        }
      }

      await _loadPlaceTags(client, places);

      if (!mounted) return;

      setState(() {
        _allPlaces = places;
        _loading = false;
        _error = null;
      });

      _applyAdvancedFilters();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadPlaceTags(
    SupabaseClient client,
    List<Map<String, dynamic>> places,
  ) async {
    _availableTags = [];
    _placeTagIds.clear();

    if (places.isEmpty) return;

    try {
      final placeIds = places
          .map((place) => place['id']?.toString())
          .whereType<String>()
          .toList();

      if (placeIds.isEmpty) return;

      final visitRows = await client
          .from('visits')
          .select('id, place_id')
          .inFilter('place_id', placeIds);

      final visitToPlace = <String, String>{};

      for (final row in visitRows as List) {
        final visitId = row['id']?.toString();
        final placeId = row['place_id']?.toString();

        if (visitId != null && placeId != null) {
          visitToPlace[visitId] = placeId;
        }
      }

      if (visitToPlace.isEmpty) return;

      final visitIds = visitToPlace.keys.toList();

      final linkRows = await client
          .from('visit_tag_links')
          .select('visit_id, tag_id, visit_tags(id, name, icon)')
          .inFilter('visit_id', visitIds);

      final tagsById = <String, Map<String, dynamic>>{};

      for (final row in linkRows as List) {
        final visitId = row['visit_id']?.toString();
        final tagId = row['tag_id']?.toString();

        if (visitId == null || tagId == null) continue;

        final placeId = visitToPlace[visitId];

        if (placeId == null) continue;

        _placeTagIds.putIfAbsent(placeId, () => <String>{}).add(tagId);

        final tag = row['visit_tags'];

        if (tag is Map) {
          tagsById[tagId] = {
            'id': tagId,
            'name': tag['name']?.toString() ?? '',
            'icon': tag['icon']?.toString(),
          };
        }
      }

      _availableTags = tagsById.values
          .where((tag) => (tag['name']?.toString() ?? '').isNotEmpty)
          .toList()
        ..sort(
          (a, b) => (a['name'] as String).compareTo(
            b['name'] as String,
          ),
        );

      _selectedTagIds.removeWhere(
        (id) => !_availableTags.any((tag) => tag['id'] == id),
      );
    } catch (e) {
      debugPrint('ADVANCED FILTER TAGS ERROR: $e');
      _availableTags = [];
      _placeTagIds.clear();
    }
  }

  void _applyAdvancedFilters() {
    if (!mounted) return;

    final query = _searchController.text.trim().toLowerCase();

    var filtered = List<Map<String, dynamic>>.from(_allPlaces);

    if (_selectedCategoryIds.isNotEmpty) {
      filtered = filtered.where((place) {
        return _selectedCategoryIds.contains(place['category_id']?.toString());
      }).toList();
    }

    if (query.isNotEmpty) {
      filtered = filtered.where((place) {
        final name = place['name']?.toString().toLowerCase() ?? '';
        final description =
            place['description']?.toString().toLowerCase() ?? '';
        final address = place['address']?.toString().toLowerCase() ?? '';

        return name.contains(query) ||
            description.contains(query) ||
            address.contains(query);
      }).toList();
    }

    if (_selectedTagIds.isNotEmpty) {
      filtered = filtered.where((place) {
        final placeId = place['id']?.toString();

        if (placeId == null) return false;

        final placeTags = _placeTagIds[placeId] ?? <String>{};

        if (_matchAllTags) {
          return _selectedTagIds.every(placeTags.contains);
        }

        return _selectedTagIds.any(placeTags.contains);
      }).toList();
    }

    if (_minimumRating > 0) {
      filtered = filtered.where((place) {
        final rating = (place['weighted_rating'] as num?)?.toDouble();
        return rating != null && rating >= _minimumRating;
      }).toList();
    }

    if (_maximumPriceLevel > 0) {
      filtered = filtered.where((place) {
        final price = (place['average_price_level'] as num?)?.toDouble();
        return price != null && price <= _maximumPriceLevel;
      }).toList();
    }

    if (_visitFilter == 'visited') {
      filtered = filtered.where((place) {
        return _visitedPlaceIds.contains(place['id']?.toString());
      }).toList();
    } else if (_visitFilter == 'not_visited') {
      filtered = filtered.where((place) {
        return !_visitedPlaceIds.contains(place['id']?.toString());
      }).toList();
    }

    final position = _currentPosition;
    if (_nearMe && position != null) {
      filtered = filtered.where((place) {
        final latitude = (place['latitude'] as num?)?.toDouble();
        final longitude = (place['longitude'] as num?)?.toDouble();
        if (latitude == null || longitude == null) return false;

        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          latitude,
          longitude,
        );
        place['distance_meters'] = distance;
        return distance <= 20000;
      }).toList();
    } else {
      for (final place in filtered) {
        place.remove('distance_meters');
      }
    }

    filtered.sort((a, b) {
      if (_nearMe) {
        return ((a['distance_meters'] as num?)?.toDouble() ?? double.infinity)
            .compareTo(
          (b['distance_meters'] as num?)?.toDouble() ?? double.infinity,
        );
      }

      switch (_sortMode) {
        case 'rating':
          return ((b['weighted_rating'] as num?)?.toDouble() ?? -1)
              .compareTo((a['weighted_rating'] as num?)?.toDouble() ?? -1);
        case 'popular':
          return ((b['visit_count'] as num?)?.toInt() ?? 0)
              .compareTo((a['visit_count'] as num?)?.toInt() ?? 0);
        case 'newest':
          final aDate = DateTime.tryParse(
                a['latest_visit_at']?.toString() ??
                    a['created_at']?.toString() ??
                    '',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = DateTime.tryParse(
                b['latest_visit_at']?.toString() ??
                    b['created_at']?.toString() ??
                    '',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        default:
          return (a['name']?.toString() ?? '')
              .compareTo(b['name']?.toString() ?? '');
      }
    });

    setState(() {
      _places = filtered;
    });
  }

  bool get _hasAdvancedFilter {
    return _searchController.text.trim().isNotEmpty ||
        _selectedTagIds.isNotEmpty ||
        _selectedCategoryIds.length != 1 ||
        !_selectedCategoryIds.contains(widget.categoryId) ||
        _nearMe ||
        _minimumRating > 0 ||
        _maximumPriceLevel > 0 ||
        _visitFilter != 'all' ||
        _sortMode != 'name';
  }

  String _tagLabel() {
    if (_selectedTagIds.isEmpty) {
      return 'בחירת תגיות';
    }

    if (_selectedTagIds.length == 1) {
      final id = _selectedTagIds.first;
      final tag = _availableTags.cast<Map<String, dynamic>?>().firstWhere(
            (tag) => tag?['id']?.toString() == id,
            orElse: () => null,
          );

      final name = tag?['name']?.toString();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }

    return '${_selectedTagIds.length} תגיות נבחרו';
  }

  Future<void> _openAdvancedFilter() async {
    setState(() {
      _advancedFilterOpen = !_advancedFilterOpen;
    });
  }

  Future<void> _showTagSelector() async {
    if (_availableTags.isEmpty) return;

    final selected = Set<String>.from(_selectedTagIds);
    var matchAll = _matchAllTags;

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'סינון לפי תגיות',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('כל התגיות'),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('לפחות אחת'),
                        ),
                      ],
                      selected: {matchAll},
                      onSelectionChanged: (value) {
                        setSheetState(() {
                          matchAll = value.first;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableTags.length,
                        itemBuilder: (context, index) {
                          final tag = _availableTags[index];
                          final id = tag['id']?.toString();

                          if (id == null) return const SizedBox.shrink();

                          final isSelected = selected.contains(id);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selected.add(id);
                                } else {
                                  selected.remove(id);
                                }
                              });
                            },
                            title: Text(
                              tag['name']?.toString() ?? '',
                              textAlign: TextAlign.right,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop({
                            'tags': selected,
                            'matchAll': matchAll,
                          });
                        },
                        child: const Text(
                          'החל סינון',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;

    final tags = result['tags'];

    setState(() {
      _selectedTagIds
        ..clear()
        ..addAll(
          tags is Set<String> ? tags : Set<String>.from(tags as Iterable),
        );

      _matchAllTags = result['matchAll'] == true;
    });

    _applyAdvancedFilters();
  }

  Future<void> _showCategorySelector() async {
    if (_availableCategories.isEmpty) return;

    final selected = Set<String>.from(_selectedCategoryIds);

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'סינון לפי קטגוריות',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableCategories.length,
                        itemBuilder: (context, index) {
                          final category = _availableCategories[index];
                          final id = category['id']?.toString();
                          if (id == null) return const SizedBox.shrink();

                          return CheckboxListTile(
                            value: selected.contains(id),
                            title: Text(
                              category['title']?.toString() ?? '',
                              textAlign: TextAlign.right,
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selected.add(id);
                                } else {
                                  selected.remove(id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.of(context).pop(selected),
                        child: const Text('החל סינון'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      _selectedCategoryIds
        ..clear()
        ..addAll(result);
    });
    _applyAdvancedFilters();
  }

  Future<void> _toggleNearMe() async {
    if (_nearMe) {
      setState(() {
        _nearMe = false;
      });
      _applyAdvancedFilters();
      return;
    }

    setState(() => _loadingLocation = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
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
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _nearMe = true;
        _loadingLocation = false;
      });
      _applyAdvancedFilters();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _clearAdvancedFilter() {
    _searchController.clear();

    setState(() {
      _selectedTagIds.clear();
      _selectedCategoryIds
        ..clear()
        ..add(widget.categoryId);
      _matchAllTags = true;
      _nearMe = false;
      _minimumRating = 0;
      _maximumPriceLevel = 0;
      _visitFilter = 'all';
      _sortMode = 'name';
    });

    _applyAdvancedFilters();
  }

  Widget _buildSelectedTagChips() {
    if (_selectedTagIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedTags = _availableTags
        .where(
          (tag) => _selectedTagIds.contains(tag['id']?.toString()),
        )
        .toList();

    if (selectedTags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 7,
          runSpacing: 7,
          children: selectedTags.map((tag) {
            final id = tag['id']?.toString();
            final name = tag['name']?.toString() ?? '';

            if (id == null || name.isEmpty) {
              return const SizedBox.shrink();
            }

            return InputChip(
              label: Text(
                name,
                textDirection: TextDirection.rtl,
              ),
              deleteIcon: const Icon(
                Icons.close,
                size: 16,
              ),
              onDeleted: () {
                setState(() {
                  _selectedTagIds.remove(id);
                });
                _applyAdvancedFilters();
              },
              backgroundColor: AppColors.card,
              side: BorderSide(
                color: AppColors.brass.withValues(alpha: 0.35),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAdvancedFilterBar() {
    if (!_advancedFilterOpen) {
      return const SizedBox.shrink();
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.champagne.withValues(alpha: 0.16),
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.champagne.withValues(alpha: 0.035),
                blurRadius: 28,
                spreadRadius: -7,
              ),
            ],
          ),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'חיפוש וסינון',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'חיפוש בשם, תיאור או כתובת',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _applyAdvancedFilters();
                          },
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    selected: _nearMe,
                    onSelected: (_) => _toggleNearMe(),
                    avatar: _loadingLocation
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          )
                        : const Icon(Icons.near_me_outlined, size: 17),
                    label: const Text('קרוב אליי'),
                  ),
                  ActionChip(
                    onPressed: _showCategorySelector,
                    avatar: const Icon(Icons.category_outlined, size: 17),
                    label: Text(
                      _selectedCategoryIds.length == 1
                          ? 'קטגוריה אחת'
                          : '${_selectedCategoryIds.length} קטגוריות',
                    ),
                  ),
                  ActionChip(
                    onPressed: _showTagSelector,
                    avatar: const Icon(Icons.local_offer_outlined, size: 17),
                    label: Text(_tagLabel()),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'דירוג מינימלי',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final rating in <double>[0, 3, 4, 5])
                      ChoiceChip(
                        selected: _minimumRating == rating,
                        onSelected: (_) {
                          setState(() => _minimumRating = rating);
                          _applyAdvancedFilters();
                        },
                        label: Text(
                          rating == 0
                              ? 'כל הדירוגים'
                              : '${rating.toStringAsFixed(0)}★ ומעלה',
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'רמת מחיר',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final price in <double>[0, 1, 2, 3, 4])
                      ChoiceChip(
                        selected: _maximumPriceLevel == price,
                        onSelected: (_) {
                          setState(() => _maximumPriceLevel = price);
                          _applyAdvancedFilters();
                        },
                        label: Text(
                          price == 0
                              ? 'כל רמות המחיר'
                              : List.filled(price.round(), '₪').join(),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sortMode,
                      decoration: const InputDecoration(labelText: 'מיון'),
                      items: const [
                        DropdownMenuItem(value: 'name', child: Text('לפי שם')),
                        DropdownMenuItem(value: 'rating', child: Text('דירוג')),
                        DropdownMenuItem(
                            value: 'popular', child: Text('פופולריות')),
                        DropdownMenuItem(value: 'newest', child: Text('חדש')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _sortMode = value);
                        _applyAdvancedFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (Supabase.instance.client.auth.currentUser != null &&
                      !(Supabase
                              .instance.client.auth.currentUser?.isAnonymous ??
                          true))
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _visitFilter,
                        decoration: const InputDecoration(labelText: 'ביקורים'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('הכול')),
                          DropdownMenuItem(
                              value: 'visited', child: Text('ביקרתי')),
                          DropdownMenuItem(
                            value: 'not_visited',
                            child: Text('טרם ביקרתי'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _visitFilter = value);
                          _applyAdvancedFilters();
                        },
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _buildSelectedTagChips(),
              if (_selectedTagIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _matchAllTags
                          ? 'התוצאה חייבת לכלול את כל התגיות'
                          : 'התוצאה חייבת לכלול לפחות תגית אחת',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              if (_hasAdvancedFilter)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _places.isEmpty
                          ? 'לא נמצאו מקומות התואמים לסינון'
                          : 'נמצאו ${_places.length} ${_places.length == 1 ? 'מקום' : 'מקומות'}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color:
                            _places.isEmpty ? AppColors.muted : AppColors.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              if (_hasAdvancedFilter)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearAdvancedFilter,
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('ניקוי הסינון'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isAnonymous = currentUser == null || currentUser.isAnonymous;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.categoryTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
        ),
        actions: [
          const HomeButton(),
          IconButton(
            tooltip: 'חיפוש וסינון',
            onPressed: _openAdvancedFilter,
            icon: Icon(
              _hasAdvancedFilter
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
              color: _hasAdvancedFilter
                  ? AppColors.champagne
                  : AppColors.textMuted,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildAdvancedFilterBar(),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: !isAnonymous
          ? FloatingActionButton.extended(
              onPressed: () async {
                final added = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => AddPlaceScreen(
                      categoryId: widget.categoryId,
                      categoryTitle: widget.categoryTitle,
                    ),
                  ),
                );

                if (added == true && mounted) {
                  _loadPlaces();
                }
              },
              backgroundColor: AppColors.background,
              foregroundColor: AppColors.champagne,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: AppColors.champagne.withValues(alpha: 0.28),
                  width: 0.9,
                ),
              ),
              icon: const Icon(
                Icons.add_rounded,
                size: 20,
              ),
              label: const Text(
                'הוספת מקום חדש',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('לא ניתן לטעון את המקומות'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadPlaces();
              },
              child: const Text('נסה שוב'),
            ),
          ],
        ),
      );
    }

    if (_places.isEmpty) {
      return const Center(
        child: Text('לא נמצאו מקומות התואמים לסינון'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                mobile ? 16 : 28,
                mobile ? 12 : 20,
                mobile ? 16 : 28,
                28,
              ),
              itemCount: _places.length,
              separatorBuilder: (_, __) => SizedBox(height: mobile ? 12 : 16),
              itemBuilder: (context, index) {
                final place = _places[index];
                final placeId = place['id']?.toString();
                final categoryId = place['category_id']?.toString();
                final category = _availableCategories
                    .cast<Map<String, dynamic>?>()
                    .firstWhere(
                      (item) => item?['id']?.toString() == categoryId,
                      orElse: () => null,
                    );
                final categoryTitle =
                    category?['title']?.toString() ?? widget.categoryTitle;

                final placeTagIds = placeId == null
                    ? <String>{}
                    : (_placeTagIds[placeId] ?? <String>{});

                final displayTags = _availableTags
                    .where(
                      (tag) => placeTagIds.contains(tag['id']?.toString()),
                    )
                    .toList();

                return PlaceCard(
                  place: {
                    ...place,
                    'category_title': categoryTitle,
                    'display_tags': displayTags,
                  },
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaceDetailsScreen(
                          place: {
                            ...place,
                            'category_title': categoryTitle,
                          },
                        ),
                      ),
                    ).then((_) => _loadPlaces());
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
