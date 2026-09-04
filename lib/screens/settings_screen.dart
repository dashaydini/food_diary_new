import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../utils/app_preferences.dart';
import '../core/services/push_notification_service.dart';
import '../widgets/home_button.dart';
import 'legal_screens.dart';
import 'support_requests_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _detourOptionsKm = <double>[2, 5, 10, 20];
  static const _couponRegions = [
    'צפון',
    'חיפה והקריות',
    'מרכז',
    'ירושלים והסביבה',
    'דרום',
    'כל הארץ'
  ];

  bool _loading = true;
  bool _routeNotificationsEnabled = false;
  bool _pushSupported = false;
  bool _pushEnabled = false;
  bool _changingPush = false;
  double _maximumRouteDetourKm = AppPreferences.defaultMaximumRouteDetourKm;
  Set<String> _selectedCategoryIds = {};
  Set<String> _couponCategoryIds = {};
  Set<String> _couponRegionsSelected = {};

  bool _loadingCategories = true;
  List<Map<String, dynamic>> _categories = [];
  String? _categoriesError;

  bool _locationServiceEnabled = false;
  LocationPermission? _locationPermission;
  bool _checkingLocation = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      AppPreferences.routeNotificationsEnabled(),
      AppPreferences.maximumRouteDetourKm(),
      AppPreferences.routeCategoryIds(),
    ]);

    if (!mounted) return;
    setState(() {
      _routeNotificationsEnabled = values[0] as bool;
      _maximumRouteDetourKm = values[1] as double;
      _selectedCategoryIds = values[2] as Set<String>;
      _loading = false;
    });

    await Future.wait([
      _loadCategories(),
      _refreshLocationStatus(),
      _loadPushStatus(),
      _loadCouponNotificationPreferences(),
    ]);
  }

  Future<void> _loadCouponNotificationPreferences() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    try {
      final row = await Supabase.instance.client
          .from('coupon_notification_preferences')
          .select('category_ids,regions')
          .eq('user_id', user.id)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _couponCategoryIds =
              Set<String>.from(row['category_ids'] as List? ?? const []);
          _couponRegionsSelected =
              Set<String>.from(row['regions'] as List? ?? const []);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCouponNotificationPreferences() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    await Supabase.instance.client
        .from('coupon_notification_preferences')
        .upsert({
      'user_id': user.id,
      'category_ids': _couponCategoryIds.toList(),
      'regions': _couponRegionsSelected.toList(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> _loadPushStatus() async {
    try {
      final supported = await PushNotificationService.isSupported();
      final enabled = supported && await PushNotificationService.isEnabled();
      if (mounted) {
        setState(() {
          _pushSupported = supported;
          _pushEnabled = enabled;
        });
      }
    } catch (_) {}
  }

  Future<void> _togglePush(bool enabled) async {
    setState(() => _changingPush = true);
    try {
      if (enabled) {
        await PushNotificationService.enable();
      } else {
        await PushNotificationService.disable();
      }
      if (mounted) setState(() => _pushEnabled = enabled);
      _showMessage(
          enabled ? 'התראות על קופונים חדשים הופעלו' : 'התראות הפוש כובו');
    } catch (_) {
      _showMessage(
          'לא ניתן להפעיל התראות. באייפון יש לפתוח את האפליקציה ממסך הבית.');
    } finally {
      if (mounted) setState(() => _changingPush = false);
    }
  }

  Future<void> _loadCategories() async {
    if (mounted) {
      setState(() {
        _loadingCategories = true;
        _categoriesError = null;
      });
    }

    try {
      final rows = await Supabase.instance.client
          .from('categories')
          .select('id, title, sort_order')
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(rows);
        _loadingCategories = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        _categoriesError = 'לא ניתן לטעון כרגע את הקטגוריות';
      });
    }
  }

  Future<void> _refreshLocationStatus() async {
    try {
      final values = await Future.wait([
        Geolocator.isLocationServiceEnabled(),
        Geolocator.checkPermission(),
      ]);
      if (!mounted) return;
      setState(() {
        _locationServiceEnabled = values[0] as bool;
        _locationPermission = values[1] as LocationPermission;
        _checkingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingLocation = false);
    }
  }

  Future<void> _handleLocationPermission() async {
    try {
      final current = await Geolocator.checkPermission();
      if (current == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
      } else if (current == LocationPermission.denied) {
        await Geolocator.requestPermission();
      } else if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
      }
      await _refreshLocationStatus();
    } catch (_) {
      if (!mounted) return;
      _showMessage('לא ניתן לפתוח כרגע את הגדרות המיקום');
    }
  }

  Future<void> _toggleCategory(String categoryId, bool selected) async {
    setState(() {
      if (selected) {
        _selectedCategoryIds.add(categoryId);
      } else {
        _selectedCategoryIds.remove(categoryId);
      }
    });
    await AppPreferences.setRouteCategoryIds(_selectedCategoryIds);
  }

  Future<void> _selectAllCategories() async {
    setState(() => _selectedCategoryIds.clear());
    await AppPreferences.setRouteCategoryIds(_selectedCategoryIds);
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('איפוס הגדרות הדרך'),
        content: const Text(
          'להחזיר את ההתראות, מרחק הסטייה והקטגוריות לברירת המחדל?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('איפוס'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await AppPreferences.resetRoutePreferences();
    if (!mounted) return;
    setState(() {
      _routeNotificationsEnabled = false;
      _maximumRouteDetourKm = AppPreferences.defaultMaximumRouteDetourKm;
      _selectedCategoryIds.clear();
    });
    _showMessage('הגדרות הדרך אופסו');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('הגדרות אפליקציה'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      _section(
                        title: 'קבלת התראות',
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _pushEnabled,
                              secondary: const Icon(
                                  Icons.notifications_active_outlined),
                              title: const Text('התראות על קופונים ועדכונים'),
                              subtitle: Text(_pushSupported
                                  ? 'קבלת התראה גם כשהאפליקציה סגורה'
                                  : 'באייפון: יש להוסיף את האפליקציה למסך הבית תחילה'),
                              onChanged: !_pushSupported || _changingPush
                                  ? null
                                  : _togglePush,
                            ),
                            const Divider(),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text('קופונים שמעניינים אותי',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 6, children: [
                              for (final category in _categories)
                                FilterChip(
                                  label:
                                      Text(category['title']?.toString() ?? ''),
                                  selected: _couponCategoryIds
                                      .contains(category['id']?.toString()),
                                  onSelected: (selected) {
                                    setState(() {
                                      final id = category['id'].toString();
                                      selected
                                          ? _couponCategoryIds.add(id)
                                          : _couponCategoryIds.remove(id);
                                    });
                                    _saveCouponNotificationPreferences();
                                  },
                                ),
                            ]),
                            const SizedBox(height: 12),
                            const Align(
                                alignment: Alignment.centerRight,
                                child: Text('אזורים מועדפים')),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 6, children: [
                              for (final region in _couponRegions)
                                FilterChip(
                                  label: Text(region),
                                  selected:
                                      _couponRegionsSelected.contains(region),
                                  onSelected: (selected) {
                                    setState(() => selected
                                        ? _couponRegionsSelected.add(region)
                                        : _couponRegionsSelected
                                            .remove(region));
                                    _saveCouponNotificationPreferences();
                                  },
                                ),
                            ]),
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                  'ללא בחירה יתקבלו קופונים מכל התחומים והאזורים.',
                                  style: TextStyle(color: AppColors.textMuted)),
                            ),
                            const Divider(),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: _routeNotificationsEnabled,
                              title: const Text('התראות בדרך'),
                              subtitle: const Text(
                                  'התראה על מקום מומלץ בהמשך המסלול.'),
                              onChanged: (enabled) async {
                                setState(
                                    () => _routeNotificationsEnabled = enabled);
                                await AppPreferences
                                    .setRouteNotificationsEnabled(enabled);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        title: 'העדפות בדרך',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            DropdownButtonFormField<double>(
                              initialValue: _maximumRouteDetourKm,
                              decoration: const InputDecoration(
                                labelText: 'מרחק סטייה מרבי',
                                helperText:
                                    'המרחק המרבי שמקום יכול להוסיף למסלול',
                              ),
                              items: _detourOptionsKm
                                  .map(
                                    (distance) => DropdownMenuItem(
                                      value: distance,
                                      child: Text('${distance.toInt()} ק״מ'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (distance) async {
                                if (distance == null) return;
                                setState(
                                  () => _maximumRouteDetourKm = distance,
                                );
                                await AppPreferences.setMaximumRouteDetourKm(
                                  distance,
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'קטגוריות להצעות בדרך',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'ללא בחירה יוצגו הצעות מכל הקטגוריות.',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildCategoryChoices(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        title: 'הרשאות',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _locationGranted
                                ? Icons.location_on_outlined
                                : Icons.location_off_outlined,
                            color: _locationGranted
                                ? AppColors.success
                                : AppColors.champagne,
                          ),
                          title: const Text('גישה למיקום'),
                          subtitle: Text(_locationStatusText),
                          trailing: TextButton(
                            onPressed: _checkingLocation
                                ? null
                                : _handleLocationPermission,
                            child: Text(_locationActionLabel),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _section(
                        title: 'אודות',
                        child: Column(
                          children: [
                            const ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.info_outline),
                              title: Text('BITE THE WAY'),
                              subtitle: Text(
                                'גרסה 1.0.0 (1) · בעלים: SHAY DINI',
                              ),
                            ),
                            const Divider(),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.privacy_tip_outlined),
                              title: const Text('מדיניות פרטיות'),
                              trailing: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 15,
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PrivacyPolicyScreen(),
                                ),
                              ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.gavel_outlined),
                              title: const Text('תנאי שימוש'),
                              trailing: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 15,
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TermsOfUseScreen(),
                                ),
                              ),
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.contact_support_outlined,
                              ),
                              title: const Text('פנייה להנהלה'),
                              subtitle: const Text(
                                'שליחת שאלה או בקשה וקבלת תשובה באפליקציה',
                              ),
                              trailing: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 15,
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SupportRequestsScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _confirmReset,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('איפוס הגדרות הדרך'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChoices() {
    if (_loadingCategories) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_categoriesError != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _categoriesError!,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: _loadCategories,
            child: const Text('ניסיון נוסף'),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.start,
      children: [
        _categoryChip(
          label: 'כל הקטגוריות',
          selected: _selectedCategoryIds.isEmpty,
          onSelected: (_) => _selectAllCategories(),
        ),
        for (final category in _categories)
          _categoryChip(
            label: category['title']?.toString() ?? '',
            selected: _selectedCategoryIds.contains(
              category['id']?.toString(),
            ),
            onSelected: (selected) {
              final id = category['id']?.toString();
              if (id != null) {
                _toggleCategory(id, selected);
              }
            },
          ),
      ],
    );
  }

  Widget _categoryChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      checkmarkColor: AppColors.background,
      backgroundColor: AppColors.surfaceRaised,
      selectedColor: AppColors.champagne,
      labelStyle: TextStyle(
        color: selected ? AppColors.background : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected ? AppColors.champagne : AppColors.cardBorder,
        width: selected ? 1.5 : 1,
      ),
    );
  }

  bool get _locationGranted {
    return _locationServiceEnabled &&
        (_locationPermission == LocationPermission.always ||
            _locationPermission == LocationPermission.whileInUse);
  }

  String get _locationStatusText {
    if (_checkingLocation) return 'בודק הרשאה…';
    if (!_locationServiceEnabled) return 'שירותי המיקום כבויים';
    return switch (_locationPermission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        'הגישה למיקום פעילה',
      LocationPermission.deniedForever => 'הגישה נחסמה בהגדרות המכשיר',
      _ => 'לא ניתנה גישה למיקום',
    };
  }

  String get _locationActionLabel {
    if (!_locationServiceEnabled) return 'פתיחת הגדרות';
    if (_locationGranted) return 'בדיקה מחדש';
    return 'מתן הרשאה';
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
