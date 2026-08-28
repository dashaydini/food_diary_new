import '../widgets/category_card.dart';
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
  ContentFilter _contentFilter = ContentFilter.all;
  final GlobalKey _filterButtonKey = GlobalKey();
  List<PlaceCategory> _categories = [];
  bool _loading = true;
  String? _error;
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      constraints.maxWidth < 700 ? 20 : 32,
                      22,
                      constraints.maxWidth < 700 ? 20 : 32,
                      28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 34),
                        _buildTitle(),
                        const SizedBox(height: 30),
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

  Widget _buildHeader() {
    return Row(
      children: [
        PopupMenuButton<String>(
          color: AppColors.card,
          surfaceTintColor: Colors.transparent,
          tooltip: 'תפריט',
          offset: const Offset(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: AppColors.cardBorder.withValues(alpha: 0.85),
            ),
          ),
          icon: _headerActionIcon(Icons.menu_rounded),
          onSelected: (value) {
            switch (value) {
              case 'favorites':
                break;
              case 'wishlist':
                break;
              case 'journal':
                _openJournal();
                break;
              case 'profile':
                _openProfile();
                break;
              case 'settings':
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'favorites',
              child: Row(
                children: [
                  Icon(Icons.favorite_outline),
                  SizedBox(width: 10),
                  Text('מועדפים'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'wishlist',
              child: Row(
                children: [
                  Icon(Icons.bookmark_outline),
                  SizedBox(width: 10),
                  Text('רשימת משאלות'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'journal',
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined),
                  SizedBox(width: 10),
                  Text('יומן אישי'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline),
                  SizedBox(width: 10),
                  Text('ניהול פרופיל'),
                ],
              ),
            ),
            PopupMenuItem(
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
        const SizedBox(width: 10),
        InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: _openMap,
          child: _headerActionIcon(Icons.map_outlined),
        ),
        const Spacer(),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'BITE THE WAY',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.champagne,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 2.4,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'CULINARY JOURNEY',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 8,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerActionIcon(IconData icon) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: AppColors.cardBorder,
          width: 0.8,
        ),
      ),
      child: Icon(
        icon,
        size: 20,
        color: AppColors.champagne,
      ),
    );
  }

  Widget _buildTitle() {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'שלום $_greetingName',
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'DISCOVER',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.champagne,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 3.2,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'לאן הולכים?',
              textAlign: TextAlign.right,
              style: theme.textTheme.headlineLarge?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 40,
                height: 1.08,
                fontWeight: FontWeight.w300,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'בחר קטגוריה וגלה את החוויה הבאה שלך.',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 17),
            Container(
              width: 54,
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    AppColors.champagne,
                    AppColors.champagne.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
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
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final cat = _categories[index];
        return CategoryCard(
          title: cat.title,
          subtitle: cat.subtitle,
          icon: cat.iconName == 'coffee_cart'
              ? Icons.storefront_outlined
              : cat.icon,
          onTap: () {
            // ניווט למסך הקטגוריות / סינון המקומות
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PlacesScreen(categoryId: cat.id, categoryTitle: cat.title),
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
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlacesScreen(
                    categoryId: category.id, categoryTitle: category.title),
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
                    category.iconName == 'coffee_cart'
                        ? Icons.storefront_outlined
                        : category.icon,
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
                  const Icon(Icons.drag_handle, color: AppColors.muted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
