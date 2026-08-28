import 'place_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_place_screen.dart';

import '../models/content_filter.dart';
import '../core/services/premium_service.dart';
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
  final Set<String> _selectedTagIds = {};
  final Map<String, Set<String>> _placeTagIds = {};

  bool _matchAllTags = true;
  bool _loading = true;
  bool _advancedFilterOpen = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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

      var rows = await client
          .from('places')
          .select(
            'id, user_id, category_id, name, description, address, '
            'latitude, longitude, image_url',
          )
          .eq('category_id', widget.categoryId)
          .order('name');

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
              .select('place_id, rating')
              .inFilter('place_id', placeIds);

          final ratingSums = <String, double>{};
          final ratingCounts = <String, int>{};

          for (final row in visitRows as List) {
            final placeId = row['place_id']?.toString();
            final rating = (row['rating'] as num?)?.toDouble();

            if (placeId == null || rating == null || rating <= 0) {
              continue;
            }

            ratingSums[placeId] = (ratingSums[placeId] ?? 0) + rating;
            ratingCounts[placeId] = (ratingCounts[placeId] ?? 0) + 1;
          }

          places = places.map((place) {
            final placeId = place['id']?.toString();
            final count = placeId == null ? 0 : (ratingCounts[placeId] ?? 0);
            final sum = placeId == null ? 0.0 : (ratingSums[placeId] ?? 0.0);

            return {
              ...place,
              'weighted_rating': count > 0 ? sum / count : null,
              'rating_count': count,
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

    setState(() {
      _places = filtered;
    });
  }

  bool get _hasAdvancedFilter {
    return _searchController.text.trim().isNotEmpty ||
        _selectedTagIds.isNotEmpty;
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
    if (!PremiumService.isPremium) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('סינון מתקדם'),
            content: const Text(
              'הסינון המתקדם זמין למשתמשי Premium.',
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('סגור'),
              ),
            ],
          );
        },
      );

      return;
    }

    setState(() {
      _advancedFilterOpen = !_advancedFilterOpen;
    });
  }

  Future<void> _showTagSelector() async {
    if (!PremiumService.isPremium || _availableTags.isEmpty) return;

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
                            secondary: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: isSelected
                                  ? AppColors.brass
                                  : AppColors.muted,
                            ),
                            controlAffinity: ListTileControlAffinity.trailing,
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

  void _clearAdvancedFilter() {
    _searchController.clear();

    setState(() {
      _selectedTagIds.clear();
      _matchAllTags = true;
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
    if (!PremiumService.isPremium || !_advancedFilterOpen) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
      child: Column(
        children: [
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
                    color: _places.isEmpty ? AppColors.muted : AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showTagSelector,
                  icon: const Icon(Icons.local_offer_outlined),
                  label: Text(_tagLabel()),
                ),
              ),
              if (_hasAdvancedFilter) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _clearAdvancedFilter,
                  tooltip: 'ניקוי הסינון',
                  icon: const Icon(Icons.filter_alt_off_outlined),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAnonymous =
        Supabase.instance.client.auth.currentUser?.isAnonymous ?? false;

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
          if (!isAnonymous)
            IconButton(
              tooltip: 'סינון מתקדם',
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
      return Center(
        child: Text(
          'אין עדיין מקומות בקטגוריה ${widget.categoryTitle}',
          textAlign: TextAlign.center,
        ),
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
                    'category_title': widget.categoryTitle,
                    'display_tags': displayTags,
                  },
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlaceDetailsScreen(place: place),
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
