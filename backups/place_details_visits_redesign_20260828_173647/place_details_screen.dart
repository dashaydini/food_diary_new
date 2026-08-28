import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/content_filter.dart';

import 'add_place_screen.dart';
import 'add_visit_screen.dart';
import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';
import '../widgets/visit_card.dart';
import '../widgets/place_image_gallery.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final ContentFilter filter;

  const PlaceDetailsScreen({
    super.key,
    required this.place,
    this.filter = ContentFilter.all,
  });

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  List<Map<String, dynamic>> _visits = [];

  bool _isFavorite = false;
  bool _isWishlist = false;
  bool _loadingPreferences = true;
  bool _savingFavorite = false;
  bool _savingWishlist = false;
  bool _loadingVisits = true;
  String? _visitsError;

  @override
  void initState() {
    super.initState();
    _loadVisits();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final user = Supabase.instance.client.auth.currentUser;
    final placeId = widget.place['id']?.toString();

    if (user == null || user.isAnonymous || placeId == null) {
      if (!mounted) return;
      setState(() {
        _loadingPreferences = false;
      });
      return;
    }

    try {
      final row = await Supabase.instance.client
          .from('user_place_preferences')
          .select('is_favorite, is_wishlist')
          .eq('user_id', user.id)
          .eq('place_id', placeId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _isFavorite = row?['is_favorite'] == true;
        _isWishlist = row?['is_wishlist'] == true;
        _loadingPreferences = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPreferences = false;
      });
    }
  }

  Future<void> _savePreferences({
    required bool isFavorite,
    required bool isWishlist,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    final placeId = widget.place['id']?.toString();

    if (user == null || user.isAnonymous || placeId == null) return;

    final client = Supabase.instance.client;

    if (!isFavorite && !isWishlist) {
      await client
          .from('user_place_preferences')
          .delete()
          .eq('user_id', user.id)
          .eq('place_id', placeId);
      return;
    }

    await client.from('user_place_preferences').upsert(
      {
        'user_id': user.id,
        'place_id': placeId,
        'is_favorite': isFavorite,
        'is_wishlist': isWishlist,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,place_id',
    );
  }

  Future<void> _toggleFavorite() async {
    if (_savingFavorite) return;

    final value = !_isFavorite;

    setState(() {
      _isFavorite = value;
      _savingFavorite = true;
    });

    try {
      await _savePreferences(
        isFavorite: value,
        isWishlist: _isWishlist,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isFavorite = !value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('לא ניתן לעדכן מועדפים: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingFavorite = false;
        });
      }
    }
  }

  Future<void> _toggleWishlist() async {
    if (_savingWishlist) return;

    final value = !_isWishlist;

    setState(() {
      _isWishlist = value;
      _savingWishlist = true;
    });

    try {
      await _savePreferences(
        isFavorite: _isFavorite,
        isWishlist: value,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isWishlist = !value;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('לא ניתן לעדכן Wishlist: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _savingWishlist = false;
        });
      }
    }
  }

  Future<void> _loadVisits() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      final rows = await client
          .from('visits')
          .select(
            'id, place_id, user_id, visit_date, notes, rating, food, food_price, total_price, price_level, '
            'drink, drink_price, image_url, food_rating, drink_rating, '
            'atmosphere_rating, service_rating, cleanliness_rating, '
            'variety_rating, value_rating, created_at, '
            'profiles(display_name, email, avatar_url), '
            'visit_tag_links(tag_id, visit_tags(name, icon)), '
            'visit_images(id, image_url, sort_order)',
          )
          .eq('place_id', widget.place['id'])
          .order('visit_date', ascending: false);

      var visits = List<Map<String, dynamic>>.from(rows);

      if (widget.filter == ContentFilter.mine &&
          user != null &&
          !user.isAnonymous) {
        visits = visits.where((visit) {
          return visit['user_id']?.toString() == user.id;
        }).toList();
      }

      if (!mounted) return;

      setState(() {
        _visits = visits;
        _loadingVisits = false;
        _visitsError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingVisits = false;
        _visitsError = e.toString();
      });
    }
  }

  Future<void> _openNavigation() async {
    final lat = widget.place['latitude'] != null
        ? double.tryParse(widget.place['latitude'].toString())
        : null;
    final lng = widget.place['longitude'] != null
        ? double.tryParse(widget.place['longitude'].toString())
        : null;
    final addr = widget.place['address']?.toString() ?? '';

    if (lat != null && lng != null) {
      await _showNavigationOptions(lat, lng);
    } else if (addr.isNotEmpty) {
      final encodedAddress = Uri.encodeComponent(addr);
      final url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$encodedAddress');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('לא ניתן לפתוח את הניווט')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('אין מיקום זמין לניווט עבור המקום הזה')),
        );
      }
    }
  }

  Future<void> _showNavigationOptions(
    double latitude,
    double longitude,
  ) async {
    if (!mounted) return;

    final googleMaps = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    final waze = Uri.parse(
      'https://www.waze.com/ul?ll=$latitude%2C$longitude&navigate=yes',
    );
    final appleMaps = Uri.parse(
      'https://maps.apple.com/?daddr=$latitude,$longitude',
    );

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'בחר אפליקציית ניווט',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: AppColors.card,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Icons.map_outlined,
                    color: AppColors.muted,
                  ),
                  title: const Text(
                    'Google Maps',
                    style: TextStyle(color: AppColors.card),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await launchUrl(
                      googleMaps,
                      mode: LaunchMode.platformDefault,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.navigation_outlined,
                    color: AppColors.muted,
                  ),
                  title: const Text(
                    'Waze',
                    style: TextStyle(color: AppColors.card),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await launchUrl(
                      waze,
                      mode: LaunchMode.platformDefault,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: AppColors.muted,
                  ),
                  title: const Text(
                    'Apple Maps',
                    style: TextStyle(color: AppColors.card),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await launchUrl(
                      appleMaps,
                      mode: LaunchMode.platformDefault,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editPlace() async {
    final edited = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddPlaceScreen(
          categoryId: widget.place['category_id']?.toString() ?? '',
          categoryTitle: widget.place['category_title']?.toString() ?? '',
          place: widget.place,
        ),
      ),
    );

    if (edited == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deletePlace() async {
    if (!Permissions.canDeletePlace()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('מחיקת מקום'),
          content: const Text(
            'האם אתה בטוח שברצונך למחוק את המקום?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ביטול'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('מחיקה'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client
          .from('places')
          .delete()
          .eq('id', widget.place['id']);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('לא ניתן למחוק את המקום: $e'),
        ),
      );
    }
  }

  Future<void> _navigateToAddVisit() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddVisitScreen(
          place: widget.place,
        ),
      ),
    );

    if (added == true && mounted) {
      setState(() {
        _loadingVisits = true;
      });
      await _loadVisits();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.place['name'] as String? ?? '';
    final description = widget.place['description'] as String? ?? '';
    final address = widget.place['address'] as String? ?? '';
    final imageUrl = widget.place['image_url'] as String? ?? '';

    final canEdit = Permissions.canEditPlace(
      widget.place['user_id']?.toString(),
    );

    final canDelete = Permissions.canDeletePlace();
    final galleryImages = _buildPlaceGalleryImages();
    final isUserLoggedIn =
        !(Supabase.instance.client.auth.currentUser?.isAnonymous ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(name),
        actions: [
          if (widget.place['latitude'] != null &&
              widget.place['longitude'] != null)
            IconButton(
              tooltip: 'ניווט',
              icon: const Icon(
                Icons.navigation_outlined,
                color: AppColors.muted,
              ),
              onPressed: _openNavigation,
            ),
          if (canEdit)
            IconButton(
              tooltip: 'עריכה',
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.muted,
              ),
              onPressed: _editPlace,
            ),
          if (canDelete)
            IconButton(
              tooltip: 'מחיקה',
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.muted,
              ),
              onPressed: _deletePlace,
            ),
          const HomeButton(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            24, 24, 24, 100), // מרווח תחתון למניעת הסתרת תוכן ע"י הכפתור הצף
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                height: 240,
                color: Colors.transparent,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          if (imageUrl.isNotEmpty) const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!_loadingPreferences && isUserLoggedIn) ...[
                _PreferenceButton(
                  icon: Icons.star_rounded,
                  selected: _isFavorite,
                  loading: _savingFavorite,
                  tooltip: 'מועדפים',
                  onPressed: _toggleFavorite,
                ),
                const SizedBox(width: 6),
                _PreferenceButton(
                  icon: Icons.bookmark_rounded,
                  selected: _isWishlist,
                  loading: _savingWishlist,
                  tooltip: 'Wishlist',
                  onPressed: _toggleWishlist,
                ),
              ],
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.muted,
              ),
            ),
          ],
          if (address.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (galleryImages.isNotEmpty) ...[
            const SizedBox(height: 20),
            PlaceImageGallery(
              images: galleryImages,
            ),
          ],
          const SizedBox(height: 32),
          const Text(
            'ביקורים',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _buildVisits(),
        ],
      ),
      floatingActionButton: isUserLoggedIn
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddVisit,
              backgroundColor: AppColors.card,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: const BorderSide(
                  color: AppColors.brass,
                  width: 1,
                ),
              ),
              icon: const Icon(
                Icons.add_rounded,
                color: AppColors.brass,
              ),
              label: const Text(
                'תיעוד ביקור חדש',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  List<PlaceGalleryImage> _buildPlaceGalleryImages() {
    final images = <PlaceGalleryImage>[];

    for (final visit in _visits) {
      final profile = visit['profiles'] as Map<String, dynamic>?;

      final displayName = profile?['display_name'] as String?;
      final email = profile?['email'] as String?;

      final author = (displayName?.trim().isNotEmpty ?? false)
          ? displayName!.trim()
          : (email?.trim().isNotEmpty ?? false)
              ? email!.trim().split('@').first
              : 'משתמש';

      final visitDate = DateTime.tryParse(
        visit['visit_date']?.toString() ?? '',
      );

      final rawImages = visit['visit_images'];

      if (rawImages is! List) continue;

      for (final rawImage in rawImages) {
        if (rawImage is! Map) continue;

        final imageUrl = rawImage['image_url']?.toString() ?? '';

        if (imageUrl.isEmpty) continue;

        images.add(
          PlaceGalleryImage(
            id: rawImage['id']?.toString() ?? '',
            imageUrl: imageUrl,
            author: author,
            date: visitDate,
          ),
        );
      }
    }

    return images;
  }

  Widget _buildVisits() {
    if (_loadingVisits) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_visitsError != null) {
      return Column(
        children: [
          const Text('לא ניתן לטעון את הביקורים'),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _loadingVisits = true;
                _visitsError = null;
              });
              _loadVisits();
            },
            child: const Text('נסה שוב'),
          ),
        ],
      );
    }

    if (_visits.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'אין עדיין ביקורים במקום הזה',
          style: TextStyle(
            color: AppColors.muted,
          ),
        ),
      );
    }

    return Column(
      children: _visits.map((visit) {
        return VisitCard(
          visit: visit,
          place: widget.place,
          onChanged: () async {
            if (!mounted) return;

            setState(() {
              _loadingVisits = true;
            });

            await _loadVisits();
          },
        );
      }).toList(),
    );
  }
}

class _PreferenceButton extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final bool loading;
  final String tooltip;
  final VoidCallback onPressed;

  const _PreferenceButton({
    required this.icon,
    required this.selected,
    required this.loading,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: loading ? null : onPressed,
      visualDensity: VisualDensity.compact,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
              ),
            )
          : Icon(
              icon,
              size: 23,
              color: selected ? AppColors.brass : AppColors.muted,
            ),
    );
  }
}
