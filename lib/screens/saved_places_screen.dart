import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/premium_service.dart';
import '../models/content_filter.dart';
import '../theme/colors.dart';
import '../widgets/home_button.dart';
import '../widgets/place_card.dart';
import '../widgets/premium_preview_dialog.dart';
import 'place_details_screen.dart';

class SavedPlacesScreen extends StatefulWidget {
  final ContentFilter filter;

  const SavedPlacesScreen({
    super.key,
    required this.filter,
  }) : assert(
          filter == ContentFilter.favorites || filter == ContentFilter.wishlist,
        );

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _places = [];
  bool _loading = true;
  String? _error;

  bool get _favorites => widget.filter == ContentFilter.favorites;
  String get _title => _favorites ? 'מועדפים' : 'רשימת משאלות';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) {
        setState(() {
          _places = [];
          _loading = false;
          _error = 'יש להירשם כדי לשמור ולצפות ב$_title';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      await PremiumService.refresh();
      final preferences = await _client
          .from('user_place_preferences')
          .select('place_id, updated_at')
          .eq('user_id', user.id)
          .eq(_favorites ? 'is_favorite' : 'is_wishlist', true)
          .order('updated_at', ascending: false);
      final ids = <String>[
        for (final row in preferences)
          if (row['place_id'] != null) row['place_id'].toString(),
      ];

      if (ids.isEmpty) {
        if (mounted) {
          setState(() {
            _places = [];
            _loading = false;
          });
        }
        return;
      }

      final rows = await _client
          .from('places')
          .select(
            'id,user_id,category_id,name,description,address,latitude,'
            'longitude,image_url,created_at,categories(title)',
          )
          .inFilter('id', ids);
      final byId = <String, Map<String, dynamic>>{};
      for (final raw in rows) {
        final place = Map<String, dynamic>.from(raw);
        final category = place['categories'];
        if (category is Map) place['category_title'] = category['title'];
        byId[place['id'].toString()] = place;
      }

      final visits = await _client
          .from('visits')
          .select('place_id,rating,price_level')
          .inFilter('place_id', ids);
      final ratingSums = <String, double>{};
      final ratingCounts = <String, int>{};
      final priceSums = <String, double>{};
      final priceCounts = <String, int>{};
      for (final row in visits) {
        final id = row['place_id']?.toString();
        if (id == null) continue;
        final rating = (row['rating'] as num?)?.toDouble();
        if (rating != null && rating > 0) {
          ratingSums[id] = (ratingSums[id] ?? 0) + rating;
          ratingCounts[id] = (ratingCounts[id] ?? 0) + 1;
        }
        final price = (row['price_level'] as num?)?.toDouble();
        if (price != null && price > 0) {
          priceSums[id] = (priceSums[id] ?? 0) + price;
          priceCounts[id] = (priceCounts[id] ?? 0) + 1;
        }
      }

      final ordered = <Map<String, dynamic>>[];
      for (final id in ids) {
        final place = byId[id];
        if (place == null) continue;
        final ratingCount = ratingCounts[id] ?? 0;
        final priceCount = priceCounts[id] ?? 0;
        ordered.add({
          ...place,
          'weighted_rating':
              ratingCount == 0 ? null : ratingSums[id]! / ratingCount,
          'rating_count': ratingCount,
          'average_price_level':
              priceCount == 0 ? null : priceSums[id]! / priceCount,
          'price_rating_count': priceCount,
        });
      }

      if (!mounted) return;
      setState(() {
        _places = ordered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון כרגע את $_title';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_title),
          centerTitle: true,
          actions: const [HomeButton()],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: _body(),
            ),
          ),
        ),
      );

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    final premium = PremiumService.isPremium;
    final aboveFreeLimit = !premium && _places.length > 5;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  premium
                      ? Icons.workspace_premium_outlined
                      : Icons.bookmarks_outlined,
                  color: AppColors.champagne,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    premium
                        ? '${_places.length} שמורים · ללא הגבלה בחשבון Premium'
                        : aboveFreeLimit
                            ? '${_places.length} שמורים · מכסת החשבון החינמי היא 5'
                            : '${_places.length} מתוך 5 שמורים בחשבון החינמי',
                    style: TextStyle(
                      color: aboveFreeLimit
                          ? AppColors.champagne
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                if (!premium)
                  TextButton(
                    onPressed: () => openPremiumUpgrade(
                      context,
                      sourceFeature: _title,
                    ),
                    child: const Text('ללא הגבלה'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_places.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 90),
              child: Text(
                _favorites
                    ? 'עדיין לא סימנת מקומות כמועדפים'
                    : 'עדיין לא הוספת מקומות לרשימת המשאלות',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            for (final place in _places)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: PlaceCard(
                  place: place,
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PlaceDetailsScreen(place: place),
                    ));
                    if (mounted) await _load();
                  },
                  onNavigate: () =>
                      PlaceCard.showNavigationOptions(context, place),
                ),
              ),
        ],
      ),
    );
  }
}
