import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/content_filter.dart';
import '../core/services/premium_service.dart';
import '../theme/colors.dart';

import 'places_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'journal_screen.dart';
import '../widgets/admin_notification_button.dart';

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
  List<PlaceCategory> _categories = [];
  bool _loading = true;
  String? _error;
  bool _editingOrder = false;
  ContentFilter _contentFilter = ContentFilter.all;
  final GlobalKey _filterButtonKey = GlobalKey();
  String _greetingName = 'אורח';
  StreamSubscription<AuthState>? _authSubscription;

  static const Map<String, IconData> _icons = {
    'coffee_outlined': Icons.coffee_outlined,
    'restaurant_outlined': Icons.restaurant_outlined,
    'local_shipping_outlined': Icons.local_shipping_outlined,
    'local_bar_outlined': Icons.local_bar_outlined,
  };

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadGreeting();

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      _loadGreeting();
    });
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
              icon: _icons[row['icon']] ?? Icons.place_outlined,
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

  Future<void> _saveCategoryOrder() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      for (var i = 0; i < _categories.length; i++) {
        await Supabase.instance.client.from('user_category_order').upsert({
          'user_id': user.id,
          'category_id': _categories[i].id,
          'sort_order': i,
        });
      }

      if (!mounted) return;

      setState(() {
        _editingOrder = false;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('לא ניתן לשמור את הסדר: $e'),
        ),
      );
    }
  }

  void _selectCategory(
    BuildContext context,
    PlaceCategory category,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlacesScreen(
          categoryId: category.id,
          categoryTitle: category.title,
          filter: _contentFilter,
        ),
      ),
    );
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
                        color: Colors.black.withValues(alpha: 0.20),
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
      return;
    }

    if (!PremiumService.isPremium) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'היומן שלי',
              textAlign: TextAlign.right,
            ),
            content: const Text(
              'היומן האישי זמין למשתמשי Premium.',
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 62),
                _buildTitle(),
                const SizedBox(height: 52),
                Expanded(
                  child: _buildCategories(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = Supabase.instance.client.auth.currentUser;
    final canFilter = user != null && !user.isAnonymous;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      textDirection: TextDirection.rtl,
      children: [
        if (canFilter)
          GestureDetector(
            onTap: _openJournal,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.brass.withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 21,
                color: AppColors.brass,
              ),
            ),
          ),
        if (canFilter) const SizedBox(width: 12),
        GestureDetector(
          onTap: _openMap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.brass.withValues(alpha: 0.45),
                width: 0.8,
              ),
            ),
            child: const Icon(
              Icons.map_outlined,
              size: 21,
              color: AppColors.brass,
            ),
          ),
        ),
        if (canFilter) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _editingOrder ? _saveCategoryOrder : _openFilter,
            child: Container(
              key: _filterButtonKey,
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.brass.withValues(alpha: 0.45),
                  width: 0.8,
                ),
              ),
              child: Icon(
                _editingOrder
                    ? Icons.check_outlined
                    : Icons.filter_alt_outlined,
                size: 21,
                color: AppColors.brass,
              ),
            ),
          ),
        ],
        const AdminNotificationButton(),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _openProfile,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.brass.withValues(alpha: 0.45),
                width: 0.8,
              ),
            ),
            child: const Icon(
              Icons.person_outline,
              size: 22,
              color: AppColors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'שלום $_greetingName',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'DISCOVER',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: AppColors.brass,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 3.5,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'לאן הולכים?',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 38,
              fontWeight: FontWeight.w400,
              height: 1.05,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'בחר מקום, גלה משהו חדש.',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 36,
            child: Divider(
              color: AppColors.brass,
              thickness: 1,
              height: 1,
            ),
          ),
        ],
      ),
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
        onReorderItem: (oldIndex, newIndex) {
          setState(() {
            final category = _categories.removeAt(oldIndex);
            _categories.insert(newIndex, category);
          });
        },
        itemBuilder: (context, index) {
          final category = _categories[index];

          return _buildCategory(
            category,
            key: ValueKey(category.id),
            showDragHandle: true,
          );
        },
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        return _buildCategory(_categories[index]);
      },
    );
  }

  Widget _buildCategoryIcon(PlaceCategory category) {
    if (category.iconName == 'coffee_cart') {
      return const Icon(
        Icons.storefront_outlined,
        color: AppColors.brass,
        size: 22,
      );
    }

    return Icon(
      category.icon,
      color: AppColors.brass,
      size: 22,
    );
  }

  Widget _buildCategory(
    PlaceCategory category, {
    Key? key,
    bool showDragHandle = false,
  }) {
    return Material(
      key: key,
      color: Colors.transparent,
      child: InkWell(
        onTap: _editingOrder ? null : () => _selectCategory(context, category),
        splashColor: AppColors.brass.withValues(alpha: 0.04),
        highlightColor: AppColors.brass.withValues(alpha: 0.02),
        child: Container(
          height: 88,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.line,
                width: 0.7,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildCategoryIcon(category),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.title,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      category.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 9.5,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (showDragHandle)
                const Icon(
                  Icons.drag_handle,
                  size: 21,
                  color: AppColors.brass,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
