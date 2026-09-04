import '../widgets/category_card.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content_filter.dart';
import '../theme/colors.dart';
import '../theme/app_icons.dart';
import '../utils/permissions.dart';
import '../widgets/admin_pending_status.dart';
import '../widgets/visit_notification_button.dart';
import '../features/authentication/screens/register_screen.dart';
import '../main.dart' show AuthGate;

import 'places_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'journal_screen.dart';
import 'admin_center_screen.dart';
import 'recommendations_screen.dart';
import 'places_on_route_screen.dart';
import 'settings_screen.dart';
import 'guided_search_screen.dart';
import 'free_search_screen.dart';
import 'my_coupons_screen.dart';

class PlaceCategory {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String iconName;

  const PlaceCategory({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconName,
  });
}

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  // ignore: prefer_final_fields
  bool _editingOrder = false;
  bool _savingOrder = false;
  ContentFilter _contentFilter = ContentFilter.all;
  final GlobalKey _filterButtonKey = GlobalKey();
  List<PlaceCategory> _categories = [];
  bool _loading = true;
  String? _error;
  String _greetingName = 'אורח';
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    _loadPermissions();
    _loadCategories();
    _loadGreeting();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _loadPermissions();
      _loadGreeting();
    });
  }

  Future<void> _loadPermissions() async {
    await Permissions.load();

    if (!mounted) return;

    setState(() {});
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadGreeting() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null || user.isAnonymous) {
      if (!mounted) return;

      setState(() {
        _greetingName = 'אורח';
      });
      return;
    }

    try {
      final row = await client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final displayName = row?['display_name']?.toString().trim();

      setState(() {
        _greetingName = displayName != null && displayName.isNotEmpty
            ? displayName
            : 'אורח';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _greetingName = 'אורח';
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;

      final rows = await client
          .from('categories')
          .select('id, title, subtitle, icon, sort_order')
          .order('sort_order');

      var categories = (rows as List)
          .map(
            (row) => PlaceCategory(
              id: row['id'] as String,
              title: row['title'] as String,
              subtitle: row['subtitle'] as String,
              icon: AppIcons.categoryIcon(
                row['icon']?.toString(),
                title: row['title']?.toString(),
              ),
              iconName: row['icon'] as String? ?? '',
            ),
          )
          .toList();

      if (_contentFilter != ContentFilter.all &&
          _contentFilter != ContentFilter.nearby &&
          user != null &&
          !user.isAnonymous) {
        final categoryIds = <String>{};

        if (_contentFilter == ContentFilter.mine) {
          final myPlaces = await client
              .from('places')
              .select('category_id')
              .eq('user_id', user.id);

          final myVisits = await client
              .from('visits')
              .select('place_id')
              .eq('user_id', user.id);

          final myPlaceIds = {
            for (final row in myVisits as List)
              if (row['place_id'] != null) row['place_id'].toString(),
          };

          for (final row in myPlaces as List) {
            if (row['category_id'] != null) {
              categoryIds.add(row['category_id'].toString());
            }
          }

          if (myPlaceIds.isNotEmpty) {
            final visitedPlaces = await client
                .from('places')
                .select('category_id')
                .inFilter('id', myPlaceIds.toList());

            for (final row in visitedPlaces as List) {
              if (row['category_id'] != null) {
                categoryIds.add(row['category_id'].toString());
              }
            }
          }
        } else {
          final preferenceRows = await client
              .from('user_place_preferences')
              .select('place_id, is_favorite, is_wishlist')
              .eq('user_id', user.id);

          final placeIds = <String>{};

          for (final row in preferenceRows as List) {
            final enabled = _contentFilter == ContentFilter.favorites
                ? row['is_favorite'] == true
                : row['is_wishlist'] == true;

            if (enabled && row['place_id'] != null) {
              placeIds.add(row['place_id'].toString());
            }
          }

          if (placeIds.isNotEmpty) {
            final filteredPlaces = await client
                .from('places')
                .select('category_id')
                .inFilter('id', placeIds.toList());

            for (final row in filteredPlaces as List) {
              if (row['category_id'] != null) {
                categoryIds.add(row['category_id'].toString());
              }
            }
          }
        }

        categories = categories
            .where((category) => categoryIds.contains(category.id))
            .toList();
      }

      // Personal category order is relevant only for authenticated users.
      if (user != null && !user.isAnonymous) {
        final orderRows = await client
            .from('user_category_order')
            .select('category_id, sort_order')
            .eq('user_id', user.id)
            .order('sort_order');

        final orderMap = <String, int>{
          for (final row in orderRows as List)
            row['category_id'] as String: row['sort_order'] as int,
        };
        categories.sort((a, b) {
          final aOrder = orderMap[a.id];
          final bOrder = orderMap[b.id];

          if (aOrder == null && bOrder == null) return 0;
          if (aOrder == null) return 1;
          if (bOrder == null) return -1;

          return aOrder.compareTo(bOrder);
        });
      }

      if (!mounted) return;

      setState(() {
        _categories = categories;
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

  Future<void> _toggleCategoryOrderEditing() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שינוי סדר זמין לאחר התחברות')),
      );
      return;
    }

    if (!_editingOrder) {
      setState(() => _editingOrder = true);
      return;
    }

    setState(() => _savingOrder = true);
    try {
      await Supabase.instance.client.from('user_category_order').upsert(
        [
          for (var index = 0; index < _categories.length; index++)
            {
              'user_id': user.id,
              'category_id': _categories[index].id,
              'sort_order': index,
            },
        ],
        onConflict: 'user_id,category_id',
      );
      if (!mounted) return;
      setState(() => _editingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('סדר הקטגוריות נשמר')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן לשמור את הסדר כרגע')),
      );
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  String _filterLabel(ContentFilter filter) {
    switch (filter) {
      case ContentFilter.favorites:
        return 'מועדפים';
      case ContentFilter.wishlist:
        return 'רשימת משאלות';
      case ContentFilter.all:
        return 'כל התכנים';
      case ContentFilter.mine:
        return 'תכנים שלי';
      case ContentFilter.nearby:
        return 'מקומות קרובים';
    }
  }

  // ignore: unused_element
  Future<void> _openFilter() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || user.isAnonymous) {
      return;
    }

    final renderObject = _filterButtonKey.currentContext?.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final buttonPosition = renderObject.localToGlobal(Offset.zero);
    final buttonSize = renderObject.size;

    final selected = await showGeneralDialog<ContentFilter>(
      context: context,
      barrierLabel: 'סינון',
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final menuWidth = 235.0;

        final right = screenWidth - buttonPosition.dx - buttonSize.width;

        return Stack(
          children: [
            Positioned(
              top: buttonPosition.dy + buttonSize.height + 8,
              right: right,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: menuWidth,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.brass.withValues(alpha: 0.32),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.20),
                        blurRadius: 28,
                        spreadRadius: 0,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 8, 20, 11),
                          child: Text(
                            'סינון',
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          height: 0.7,
                          color: AppColors.line,
                        ),
                        for (final filter in ContentFilter.values)
                          InkWell(
                            onTap: () {
                              Navigator.of(dialogContext).pop(filter);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                              child: Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Icon(
                                    _contentFilter == filter
                                        ? Icons.check_circle_outline
                                        : Icons.circle_outlined,
                                    size: 19,
                                    color: _contentFilter == filter
                                        ? AppColors.brass
                                        : AppColors.muted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _filterLabel(filter),
                                      textAlign: TextAlign.right,
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                        color: _contentFilter == filter
                                            ? AppColors.ink
                                            : AppColors.muted,
                                        fontSize: 15,
                                        fontWeight: _contentFilter == filter
                                            ? FontWeight.w500
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.94,
              end: 1.0,
            ).animate(curved),
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );

    if (selected == null || selected == _contentFilter || !mounted) {
      return;
    }

    setState(() {
      _contentFilter = selected;
      _loading = true;
    });

    await _loadCategories();
  }

  Future<void> _openJournal() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || user.isAnonymous) {
      final register = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('נדרשת הרשמה'),
            content: const Text(
                'כדי להשתמש ביומן האישי ולשמור את החוויות שלך, צריך להירשם לאפליקציה.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('לא עכשיו'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('להרשמה'),
              ),
            ],
          ),
        ),
      );
      if (register != true || !mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RegisterScreen(
          onAuthSuccess: () {
            if (!mounted) return;
            // Use the regular auth/completion flow, not a direct journal route.
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const AuthGate()),
              (route) => false,
            );
          },
        ),
      ));
      return;
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const JournalScreen(),
      ),
    );
  }

  void _openMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MapScreen(),
      ),
    );
  }

  Future<void> _openProfile() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
      ),
    );

    if (changed == true) {
      await _loadGreeting();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mobile = constraints.maxWidth < 700;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      mobile ? 16 : 32,
                      mobile ? 12 : 20,
                      mobile ? 16 : 32,
                      mobile ? 16 : 26,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(mobile: mobile),
                        SizedBox(height: mobile ? 22 : 30),
                        _buildTitle(mobile: mobile),
                        SizedBox(height: mobile ? 14 : 22),
                        Expanded(
                          child: _buildCategories(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required bool mobile}) {
    return AdminPendingStatus(
      canManageContent: Permissions.isAdmin && Permissions.canManageContent,
      canManageSupport: Permissions.isAdmin && Permissions.canManageSupport,
      builder: (context, pending, refresh) => _buildHeaderContent(
          mobile: mobile,
          pendingAdminItems: pending,
          refreshAdminStatus: refresh),
    );
  }

  Widget _buildHeaderContent(
      {required bool mobile,
      required bool pendingAdminItems,
      required VoidCallback refreshAdminStatus}) {
    final signedIn = Supabase.instance.client.auth.currentUser != null &&
        !(Supabase.instance.client.auth.currentUser?.isAnonymous ?? true);
    final actions = Row(
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!mobile && signedIn) ...[
          VisitNotificationButton(mobile: mobile),
          SizedBox(width: mobile ? 7 : 10),
        ],
        PopupMenuButton<String>(
          color: AppColors.card,
          surfaceTintColor: Colors.transparent,
          tooltip: pendingAdminItems ? 'תפריט — פניות ממתינות לטיפול' : 'תפריט',
          onOpened: refreshAdminStatus,
          offset: const Offset(0, 64),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: AppColors.cardBorder.withValues(alpha: 0.85),
            ),
          ),
          child: _labeledHeaderAction(
            label: 'תפריט',
            child: Badge(
              key: const ValueKey('admin-menu-dot'),
              isLabelVisible: pendingAdminItems,
              backgroundColor: Colors.red,
              child: _headerActionIcon(
                Icons.menu_rounded,
                mobile: mobile,
              ),
            ),
          ),
          onSelected: (value) {
            switch (value) {
              case 'favorites':
                break;
              case 'wishlist':
                break;
              case 'journal':
                _openJournal();
                break;
              case 'coupons':
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MyCouponsScreen(),
                  ),
                );
                break;
              case 'advanced_filter':
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GuidedSearchScreen(),
                  ),
                );
                break;
              case 'category_order':
                if (!_editingOrder) _toggleCategoryOrderEditing();
                break;
              case 'profile':
                _openProfile();
                break;
              case 'admin':
                Navigator.of(context)
                    .push(
                  MaterialPageRoute(
                    builder: (_) => const AdminCenterScreen(),
                  ),
                )
                    .then((_) {
                  refreshAdminStatus();
                });
                break;
              case 'settings':
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'favorites',
              child: Row(
                children: [
                  Icon(Icons.favorite_outline),
                  SizedBox(width: 10),
                  Text('מועדפים'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'wishlist',
              child: Row(
                children: [
                  Icon(Icons.bookmark_outline),
                  SizedBox(width: 10),
                  Text('רשימת משאלות'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'journal',
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined),
                  SizedBox(width: 10),
                  Text('יומן אישי'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'coupons',
              child: Row(
                children: [
                  Icon(Icons.card_giftcard_rounded),
                  SizedBox(width: 10),
                  Text('הקופונים שלי'),
                ],
              ),
            ),
            if (Supabase.instance.client.auth.currentUser != null &&
                !(Supabase.instance.client.auth.currentUser?.isAnonymous ??
                    true)) ...[
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'advanced_filter',
                child: Row(
                  children: [
                    Icon(Icons.filter_alt_outlined),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('סינון מתקדם'),
                          Text(
                            'חיפוש לפי כמה העדפות יחד',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'category_order',
                child: Row(
                  children: [
                    Icon(Icons.swap_vert_rounded),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('סידור קטגוריות'),
                          Text(
                            'שינוי סדר התצוגה במסך הבית',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
            ],
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline),
                  SizedBox(width: 10),
                  Text('ניהול פרופיל'),
                ],
              ),
            ),
            if (Permissions.isAdmin) ...[
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'admin',
                child: Row(
                  children: [
                    Badge(
                      key: const ValueKey('admin-entry-dot'),
                      isLabelVisible: pendingAdminItems,
                      backgroundColor: Colors.red,
                      child: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: AppColors.champagne,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'מרכז ניהול',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
            ],
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined),
                  SizedBox(width: 10),
                  Text('הגדרות אפליקציה'),
                ],
              ),
            ),
          ],
        ),
        SizedBox(width: mobile ? 7 : 10),
        InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: _openMap,
          child: _labeledHeaderAction(
            label: 'מפת מקומות',
            child: _headerActionIcon(
              Icons.map_outlined,
              mobile: mobile,
            ),
          ),
        ),
        SizedBox(width: mobile ? 7 : 10),
        InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PlacesOnRouteScreen(),
              ),
            );
          },
          child: _labeledHeaderAction(
            label: 'בדרך',
            child: _headerActionIcon(
              Icons.route_outlined,
              mobile: mobile,
            ),
          ),
        ),
        SizedBox(width: mobile ? 12 : 18),
        Expanded(
          child: mobile
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'שלום $_greetingName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: mobile ? 16 : 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
        ),
        _freeSearchButton(mobile: mobile),
        if (Supabase.instance.client.auth.currentUser != null &&
            !(Supabase.instance.client.auth.currentUser?.isAnonymous ??
                true)) ...[
          SizedBox(width: mobile ? 12 : 18),
          InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecommendationsScreen(),
                ),
              );
            },
            child: _labeledHeaderAction(
              label: 'AI',
              child: _aiHeaderActionIcon(mobile: mobile),
            ),
          ),
        ],
      ],
    );
    if (!mobile) return actions;
    return Column(
      children: [
        Row(
          textDirection: TextDirection.rtl,
          children: [
            if (signedIn) ...[
              const VisitNotificationButton(),
              const SizedBox(width: 12),
            ],
            Expanded(
                child: Text('שלום $_greetingName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w400))),
          ],
        ),
        const SizedBox(height: 12),
        actions,
      ],
    );
  }

  Widget _freeSearchButton({required bool mobile}) => Tooltip(
        message: 'חיפוש חופשי',
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const FreeSearchScreen(),
          )),
          child: _labeledHeaderAction(
              label: 'חיפוש',
              child: _headerActionIcon(Icons.search_rounded, mobile: mobile)),
        ),
      );

  Widget _labeledHeaderAction({
    required String label,
    required Widget child,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 72),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 9.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerActionIcon(
    IconData icon, {
    required bool mobile,
  }) {
    final size = mobile ? 40.0 : 44.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.16),
          width: 0.8,
        ),
      ),
      child: Icon(
        icon,
        size: mobile ? 19 : 20,
        color: AppColors.champagne,
      ),
    );
  }

  Widget _aiHeaderActionIcon({required bool mobile}) {
    final size = mobile ? 40.0 : 44.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF7C5CFC),
            Color(0xFF3D8BFF),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFF9E91FF).withValues(alpha: 0.72),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B63FF).withValues(alpha: 0.22),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        size: mobile ? 19 : 20,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTitle({required bool mobile}) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(
          child: Text(
            _editingOrder ? 'עריכת סדר הקטגוריות' : 'קטגוריות',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: mobile ? 23 : 27,
                  height: 1.1,
                  fontWeight: FontWeight.w300,
                ),
          ),
        ),
        if (_editingOrder)
          TextButton.icon(
            onPressed: _savingOrder ? null : _toggleCategoryOrderEditing,
            icon: _savingOrder
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('שמירה'),
          ),
      ],
    );
  }

  Widget _buildCategories() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: AppColors.brass,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'לא ניתן לטעון את הקטגוריות',
              style: TextStyle(
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _loadCategories();
              },
              child: const Text('נסה שוב'),
            ),
          ],
        ),
      );
    }

    return _buildCategoryList();
  }

  Widget _buildCategoryList() {
    if (_editingOrder) {
      return ReorderableListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _categories.length,
        buildDefaultDragHandles: false,
        onReorderItem: (oldIndex, newIndex) {
          setState(() {
            final category = _categories.removeAt(oldIndex);
            _categories.insert(newIndex, category);
          });
        },
        itemBuilder: (context, index) {
          final category = _categories[index];

          return Padding(
            key: ValueKey(category.id),
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildCategory(
              category,
              index: index,
              showDragHandle: true,
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 720;

        if (desktop) {
          return GridView.builder(
            padding: EdgeInsets.zero,
            itemCount: _categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 78,
            ),
            itemBuilder: (context, index) {
              final cat = _categories[index];

              return CategoryCard(
                title: cat.title,
                subtitle: cat.subtitle,
                icon: cat.icon,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlacesScreen(
                        categoryId: cat.id,
                        categoryTitle: cat.title,
                      ),
                    ),
                  );
                },
              );
            },
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final cat = _categories[index];

            return SizedBox(
              height: 76,
              child: CategoryCard(
                title: cat.title,
                subtitle: cat.subtitle,
                icon: cat.icon,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlacesScreen(
                        categoryId: cat.id,
                        categoryTitle: cat.title,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategory(
    PlaceCategory category, {
    Key? key,
    int index = 0,
    bool showDragHandle = false,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: showDragHandle
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PlacesScreen(
                        categoryId: category.id,
                        categoryTitle: category.title,
                      ),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line, width: 1),
                  ),
                  child: Icon(
                    category.icon,
                    color: AppColors.ink,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        category.title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category.subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
                if (showDragHandle) ...[
                  const SizedBox(width: 12),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        color: AppColors.champagne,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
