import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../models/content_filter.dart';

import 'add_place_screen.dart';
import 'add_visit_screen.dart';
import 'place_ownership_request_screen.dart';
import '../theme/app_icons.dart';
import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../utils/supabase_image_url.dart';
import '../utils/image_upload_policy.dart';
import '../widgets/home_button.dart';
import '../widgets/visit_card.dart';
import '../widgets/place_image_gallery.dart';
import '../widgets/navigation_app_picker.dart';

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
  String? _creatorName;
  DateTime? _placeCreatedAt;
  String? _businessMenu;
  String? _openingHours;
  List<Map<String, dynamic>> _menuFiles = [];
  List<Map<String, dynamic>> _openingSchedule = [];
  List<Map<String, dynamic>> _businessGallery = [];
  Map<String, Map<String, dynamic>> _officialReplies = {};
  bool _canReplyOfficially = false;
  bool _uploadingPlacePhotos = false;

  @override
  void initState() {
    super.initState();
    _loadVisits();
    _loadPreferences();
    _loadAttribution();
    _loadBusinessContent();
  }

  Future<void> _loadBusinessContent() async {
    final placeId = widget.place['id']?.toString();
    if (placeId == null) return;
    try {
      final client = Supabase.instance.client;
      final results = await Future.wait([
        client
            .from('place_menus')
            .select('content,files,file_url,file_name,file_type')
            .eq('place_id', placeId)
            .maybeSingle(),
        client
            .from('place_opening_hours')
            .select('content,schedule')
            .eq('place_id', placeId)
            .maybeSingle(),
        client
            .from('place_gallery_images')
            .select('id,image_url,created_at')
            .eq('place_id', placeId)
            .order('created_at', ascending: false),
        client
            .from('place_official_replies')
            .select('id,visit_id,body,created_by')
            .eq('place_id', placeId),
      ]);
      var canReply = Permissions.isAdmin;
      final user = client.auth.currentUser;
      if (!canReply && user != null && !user.isAnonymous) {
        final access = await client
            .from('place_managers')
            .select('id')
            .eq('place_id', placeId)
            .eq('user_id', user.id)
            .eq('status', 'active')
            .contains('permissions', ['replies']).maybeSingle();
        canReply = access != null;
      }
      if (!mounted) return;
      setState(() {
        _businessMenu = (results[0] as Map?)?['content']?.toString();
        _openingHours = (results[1] as Map?)?['content']?.toString();
        final menuRow = results[0] as Map?;
        final savedMenuFiles = menuRow?['files'];
        _menuFiles = savedMenuFiles is List
            ? [
                for (final item in savedMenuFiles)
                  if (item is Map) Map<String, dynamic>.from(item)
              ]
            : menuRow?['file_url']?.toString().trim().isNotEmpty == true
                ? [
                    {
                      'url': menuRow!['file_url'],
                      'name': menuRow['file_name'],
                      'type': menuRow['file_type'],
                    }
                  ]
                : [];
        final schedule = (results[1] as Map?)?['schedule'];
        _openingSchedule = schedule is List
            ? [
                for (final item in schedule)
                  Map<String, dynamic>.from(item as Map)
              ]
            : [];
        _businessGallery = List<Map<String, dynamic>>.from(results[2] as List);
        _officialReplies = {
          for (final row in List<Map<String, dynamic>>.from(results[3] as List))
            row['visit_id'].toString(): row,
        };
        _canReplyOfficially = canReply;
      });
    } catch (_) {
      // Business content is optional and must not block the place page.
    }
  }

  Future<void> _editOfficialReply(Map<String, dynamic> visit) async {
    final visitId = visit['id'].toString();
    final controller = TextEditingController(
        text: _officialReplies[visitId]?['body']?.toString());
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('תגובה רשמית של בית העסק'),
        content: TextField(
            controller: controller, minLines: 3, maxLines: 8, maxLength: 2000),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ביטול')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('פרסום תגובה')),
        ],
      ),
    );
    if (save == true && controller.text.trim().length >= 2) {
      await Supabase.instance.client.from('place_official_replies').upsert({
        'place_id': widget.place['id'],
        'visit_id': visitId,
        'body': controller.text.trim(),
        'created_by': Supabase.instance.client.auth.currentUser!.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'visit_id');
      await _loadBusinessContent();
    }
    controller.dispose();
  }

  Future<void> _deleteOfficialReply(String visitId) async {
    final reply = _officialReplies[visitId];
    if (reply == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת תגובה רשמית'),
        content: const Text('למחוק את התגובה מהחוויה?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('מחיקה')),
        ],
      ),
    );
    if (confirmed != true) return;
    await Supabase.instance.client
        .from('place_official_replies')
        .delete()
        .eq('id', reply['id']);
    await _loadBusinessContent();
  }

  Future<void> _loadAttribution() async {
    final placeId = widget.place['id']?.toString();
    if (placeId == null || placeId.isEmpty) return;

    try {
      final client = Supabase.instance.client;
      final place = await client
          .from('places')
          .select('user_id, created_at')
          .eq('id', placeId)
          .maybeSingle();
      final creatorId = place?['user_id']?.toString();
      String? creatorName;

      if (creatorId != null && creatorId.isNotEmpty) {
        final profile = await client
            .from('profiles')
            .select('display_name')
            .eq('id', creatorId)
            .maybeSingle();
        final value = profile?['display_name']?.toString().trim();
        if (value != null && value.isNotEmpty) creatorName = value;
      }

      if (!mounted) return;
      setState(() {
        _creatorName = creatorId == null ? null : (creatorName ?? 'משתמש');
        _placeCreatedAt = DateTime.tryParse(
          place?['created_at']?.toString() ?? '',
        )?.toLocal();
      });
    } catch (_) {
      // Attribution is secondary and must not block the place screen.
    }
  }

  String _formatCreatedAt(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}.'
      '${value.month.toString().padLeft(2, '0')}.${value.year}';

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
            'variety_rating, value_rating, created_at, outing_id, source_visit_id, is_shared_response, '
            'profiles(display_name, avatar_url), '
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
    await NavigationAppPicker.show(context, widget.place);
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

  void _openCoverImage(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  optimizedSupabaseImageUrl(
                    url,
                    width: 1600,
                    quality: 80,
                    resize: 'contain',
                  ),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SafeArea(
            child: IconButton.filled(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _addPlacePhotos() async {
    if (_uploadingPlacePhotos) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) return;

    // Community photos remain attached to an actual visit so the existing
    // image-report and immediate-hide flow applies to every new photo.
    Map<String, dynamic>? ownVisit;
    try {
      ownVisit = await client
          .from('visits')
          .select('id')
          .eq('place_id', widget.place['id'])
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('לא הצלחנו לבדוק את החוויות שלך כרגע'),
      ));
      return;
    }
    if (!mounted) return;
    if (ownVisit == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('כדי להוסיף תמונות לגלריה, יש לשתף חוויה במקום קודם.'),
      ));
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('צילום במצלמה'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('בחירה מהגלריה'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    List<XFile> picked;
    try {
      picked = source == ImageSource.camera
          ? [
              if (await picker.pickImage(
                source: source,
                imageQuality: ImageUploadPolicy.photoQuality,
                maxWidth: ImageUploadPolicy.photoMaxDimension,
                maxHeight: ImageUploadPolicy.photoMaxDimension,
              )
                  case final image?)
                image,
            ]
          : await picker.pickMultiImage(
              imageQuality: ImageUploadPolicy.photoQuality,
              maxWidth: ImageUploadPolicy.photoMaxDimension,
              maxHeight: ImageUploadPolicy.photoMaxDimension,
            );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('לא ניתן לפתוח את המצלמה או הגלריה כרגע'),
      ));
      return;
    }
    if (picked.isEmpty || !mounted) return;
    setState(() => _uploadingPlacePhotos = true);

    var saved = 0;
    try {
      final visitId = ownVisit['id'].toString();
      final lastImage = await client
          .from('visit_images')
          .select('sort_order')
          .eq('visit_id', visitId)
          .order('sort_order', ascending: false)
          .limit(1)
          .maybeSingle();
      final nextSortOrder =
          ((lastImage?['sort_order'] as num?)?.toInt() ?? -1) + 1;
      for (final image in picked.take(5)) {
        final extension = image.name.split('.').last.toLowerCase();
        final contentType = switch (extension) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => null,
        };
        if (contentType == null) throw StateError('unsupported_image_type');
        final bytes = await image.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024) {
          throw StateError('image_too_large');
        }
        final path = '${user.id}/${const Uuid().v4()}.$extension';
        await client.storage.from('visit-images').uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: false),
            );
        final url = client.storage.from('visit-images').getPublicUrl(path);
        await client.from('visit_images').insert({
          'visit_id': visitId,
          'user_id': user.id,
          'image_url': url,
          'sort_order': nextSortOrder + saved,
        });
        saved++;
      }
      await _loadVisits();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved == 1
            ? 'התמונה נוספה לגלריית המקום'
            : '$saved תמונות נוספו לגלריית המקום'),
      ));
    } catch (_) {
      if (saved > 0) await _loadVisits();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved > 0
            ? '$saved תמונות נשמרו. את שאר התמונות לא הצלחנו להעלות.'
            : 'לא הצלחנו להעלות את התמונות. ניתן לבחור JPG, PNG או WebP.'),
      ));
    } finally {
      if (mounted) setState(() => _uploadingPlacePhotos = false);
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

    final currentUser = Supabase.instance.client.auth.currentUser;
    final isUserLoggedIn = currentUser != null && !currentUser.isAnonymous;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
        ),
        actions: [
          if (widget.place['latitude'] != null &&
              widget.place['longitude'] != null)
            IconButton(
              tooltip: 'ניווט',
              icon: const Icon(
                Icons.navigation_outlined,
                color: AppColors.champagne,
              ),
              onPressed: _openNavigation,
            ),
          const HomeButton(),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  mobile ? 16 : 28,
                  mobile ? 14 : 20,
                  mobile ? 16 : 28,
                  110,
                ),
                children: [
                  if (imageUrl.isNotEmpty)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.champagne.withValues(alpha: 0.035),
                            blurRadius: 34,
                            spreadRadius: -7,
                          ),
                        ],
                      ),
                      child: Material(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(19),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openCoverImage(imageUrl),
                          child: SizedBox(
                            width: double.infinity,
                            height: mobile ? 190 : 260,
                            child: Image.network(
                              optimizedSupabaseImageUrl(
                                imageUrl,
                                width: mobile ? 900 : 1400,
                                quality: 78,
                                resize: 'contain',
                              ),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (imageUrl.isNotEmpty) SizedBox(height: mobile ? 18 : 24),
                  Row(
                    textDirection: TextDirection.rtl,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        AppIcons.categoryIcon(
                          widget.place['category_icon']?.toString(),
                          title: widget.place['category_title']?.toString(),
                        ),
                        size: mobile ? 19 : 21,
                        color: AppColors.champagneSoft,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Wrap(
                          textDirection: TextDirection.rtl,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              name,
                              textAlign: TextAlign.right,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontSize: mobile ? 24 : 28,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            Tooltip(
                              message: 'בקשת בעלות על המקום',
                              child: ActionChip(
                                avatar: const Icon(Icons.verified_user_outlined,
                                    size: 14),
                                label: const Text('אני הבעלים',
                                    style: TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PlaceOwnershipRequestScreen(
                                      place: widget.place,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                        const SizedBox(width: 4),
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
                  if (_creatorName != null || _placeCreatedAt != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      [
                        if (_creatorName != null) 'נוצר על ידי $_creatorName',
                        if (_placeCreatedAt != null)
                          'בתאריך ${_formatCreatedAt(_placeCreatedAt!)}',
                      ].join(' · '),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                            fontSize: mobile ? 11 : 12,
                          ),
                    ),
                  ],
                  if (canEdit || canDelete) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (canEdit)
                            _PlaceManagementButton(
                              icon: Icons.edit_outlined,
                              label: 'עריכת מקום',
                              onPressed: _editPlace,
                            ),
                          if (canDelete)
                            _PlaceManagementButton(
                              icon: Icons.delete_outline,
                              label: 'מחיקת מקום',
                              color: AppColors.danger,
                              onPressed: _deletePlace,
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                            fontSize: mobile ? 13 : 14,
                            height: 1.5,
                          ),
                    ),
                  ],
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      textDirection: TextDirection.rtl,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: AppColors.champagne,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address,
                            textAlign: TextAlign.right,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: mobile ? 12 : 13,
                                      height: 1.45,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_openingSchedule.isNotEmpty ||
                      _openingHours?.trim().isNotEmpty == true ||
                      _menuFiles.isNotEmpty ||
                      _businessMenu?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 18),
                    if (_openingSchedule.isNotEmpty)
                      _OpeningHoursCard(schedule: _openingSchedule)
                    else if (_openingHours?.trim().isNotEmpty == true)
                      _BusinessInfoCard(
                        title: 'שעות פתיחה',
                        icon: Icons.schedule_rounded,
                        content: _openingHours!,
                      ),
                    if (_menuFiles.isNotEmpty)
                      _MenuFilesCard(
                        files: _menuFiles,
                        note: _businessMenu,
                      )
                    else if (_businessMenu?.trim().isNotEmpty == true)
                      _BusinessInfoCard(
                        title: 'תפריט',
                        icon: Icons.restaurant_menu_rounded,
                        content: _businessMenu!,
                      ),
                  ],
                  SizedBox(height: mobile ? 18 : 24),
                  if (galleryImages.isNotEmpty)
                    PlaceImageGallery(
                      images: galleryImages,
                    ),
                  if (isUserLoggedIn) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed:
                            _uploadingPlacePhotos ? null : _addPlacePhotos,
                        icon: _uploadingPlacePhotos
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('הוספת תמונות לגלריית המקום'),
                      ),
                    ),
                  ],
                  SizedBox(height: mobile ? 26 : 34),
                  Text(
                    'חוויות',
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: mobile ? 20 : 22,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildVisits(),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: isUserLoggedIn
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddVisit,
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
                'שיתוף חוויה',
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

  List<PlaceGalleryImage> _buildPlaceGalleryImages() {
    final images = <PlaceGalleryImage>[];

    for (final image in _businessGallery) {
      final url = image['image_url']?.toString() ?? '';
      if (url.isEmpty) continue;
      images.add(PlaceGalleryImage(
        id: image['id']?.toString() ?? '',
        imageUrl: url,
        author: 'בית העסק',
        date: DateTime.tryParse(image['created_at']?.toString() ?? ''),
      ));
    }

    for (final visit in _visits) {
      final profile = visit['profiles'] as Map<String, dynamic>?;

      final displayName = profile?['display_name'] as String?;
      final author = (displayName?.trim().isNotEmpty ?? false)
          ? displayName!.trim()
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
          const Text('לא ניתן לטעון את החוויות'),
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
          'אין עדיין חוויות במקום הזה',
          style: TextStyle(
            color: AppColors.muted,
          ),
        ),
      );
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final visit in _visits) {
      final key = visit['outing_id']?.toString() ?? visit['id'].toString();
      grouped.putIfAbsent(key, () => []).add(visit);
    }

    return Column(
      children: grouped.values.map((outing) {
        if (outing.length > 1) {
          return _SharedOutingReviews(
            visits: outing,
            reviewBuilder: (visit) => VisitCard(
              visit: visit,
              place: widget.place,
              groupedReview: true,
              officialReply: _officialReplies[visit['id']?.toString()]?['body']
                  ?.toString(),
              canReply: _canReplyOfficially,
              onReply: () => _editOfficialReply(visit),
              canDeleteOfficialReply: Permissions.canManageContent ||
                  _officialReplies[visit['id']?.toString()]?['created_by']
                          ?.toString() ==
                      Supabase.instance.client.auth.currentUser?.id,
              onDeleteOfficialReply: () =>
                  _deleteOfficialReply(visit['id'].toString()),
              onChanged: _reloadVisits,
            ),
          );
        }
        final visit = outing.single;
        return VisitCard(
          visit: visit,
          place: widget.place,
          officialReply:
              _officialReplies[visit['id']?.toString()]?['body']?.toString(),
          canReply: _canReplyOfficially,
          onReply: () => _editOfficialReply(visit),
          canDeleteOfficialReply: Permissions.canManageContent ||
              _officialReplies[visit['id']?.toString()]?['created_by']
                      ?.toString() ==
                  Supabase.instance.client.auth.currentUser?.id,
          onDeleteOfficialReply: () =>
              _deleteOfficialReply(visit['id'].toString()),
          onChanged: _reloadVisits,
        );
      }).toList(),
    );
  }

  Future<void> _reloadVisits() async {
    if (!mounted) return;
    setState(() => _loadingVisits = true);
    await _loadVisits();
  }
}

class _SharedOutingReviews extends StatelessWidget {
  const _SharedOutingReviews({
    required this.visits,
    required this.reviewBuilder,
  });

  final List<Map<String, dynamic>> visits;
  final Widget Function(Map<String, dynamic> visit) reviewBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ביקור משותף',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${visits.length} משתתפים · ביקורת נפרדת לכל אחד',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          for (final visit in visits) reviewBuilder(visit),
        ],
      ),
    );
  }
}

class _OpeningHoursCard extends StatelessWidget {
  final List<Map<String, dynamic>> schedule;
  const _OpeningHoursCard({required this.schedule});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(textDirection: TextDirection.rtl, children: [
              Icon(Icons.schedule_rounded,
                  color: AppColors.champagne, size: 20),
              SizedBox(width: 8),
              Text('שעות פתיחה', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            for (final day in schedule)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(textDirection: TextDirection.rtl, children: [
                  Expanded(child: Text(day['label']?.toString() ?? '')),
                  Text(
                      day['open'] == true
                          ? '${day['from']}–${day['to']}'
                          : 'סגור',
                      style: TextStyle(
                          color: day['open'] == true
                              ? AppColors.textPrimary
                              : AppColors.textMuted)),
                ]),
              ),
          ]),
        ),
      );
}

class _MenuFilesCard extends StatelessWidget {
  final List<Map<String, dynamic>> files;
  final String? note;
  const _MenuFilesCard({required this.files, this.note});

  Future<void> _openPdf(BuildContext context, String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן לפתוח את קובץ ה־PDF')),
      );
    }
  }

  void _openImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  optimizedSupabaseImageUrl(
                    url,
                    width: 1600,
                    quality: 80,
                    resize: 'contain',
                  ),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SafeArea(
            child: IconButton.filled(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(textDirection: TextDirection.rtl, children: [
              Icon(Icons.restaurant_menu_rounded,
                  color: AppColors.champagne, size: 20),
              SizedBox(width: 8),
              Text('תפריט', style: TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            for (final file in files) ...[
              if (file['type']?.toString() == 'image')
                Semantics(
                  button: true,
                  label: 'פתיחת תמונת תפריט',
                  child: InkWell(
                    onTap: () => _openImage(context, file['url'].toString()),
                    borderRadius: BorderRadius.circular(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                          optimizedSupabaseImageUrl(file['url'].toString(),
                              width: 1400, quality: 80, resize: 'contain'),
                          height: 300,
                          fit: BoxFit.contain),
                    ),
                  ),
                )
              else
                FilledButton.icon(
                  onPressed: () => _openPdf(context, file['url'].toString()),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(
                    file['name']?.toString().trim().isNotEmpty == true
                        ? file['name'].toString()
                        : 'פתיחת התפריט',
                  ),
                ),
              const SizedBox(height: 10),
            ],
            if (note?.trim().isNotEmpty == true) ...[
              Text(note!, textAlign: TextAlign.right),
            ],
          ]),
        ),
      );
}

class _BusinessInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;

  const _BusinessInfoCard(
      {required this.title, required this.icon, required this.content});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(textDirection: TextDirection.rtl, children: [
              Icon(icon, color: AppColors.champagne, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Text(content, textAlign: TextAlign.right),
          ]),
        ),
      );
}

class _PlaceManagementButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _PlaceManagementButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        textStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: color.withValues(alpha: 0.34)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
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
