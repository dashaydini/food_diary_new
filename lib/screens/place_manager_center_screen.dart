import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';
import 'place_details_screen.dart';

class PlaceManagerCenterScreen extends StatefulWidget {
  const PlaceManagerCenterScreen({super.key});

  @override
  State<PlaceManagerCenterScreen> createState() =>
      _PlaceManagerCenterScreenState();
}

class _PlaceManagerCenterScreenState extends State<PlaceManagerCenterScreen> {
  static const _tools = <({String key, String title, IconData icon})>[
    (key: 'replies', title: 'תגובות לחוויות', icon: Icons.forum_outlined),
    (key: 'menu', title: 'תפריט', icon: Icons.restaurant_menu_rounded),
    (key: 'hours', title: 'שעות פתיחה', icon: Icons.schedule_rounded),
    (key: 'gallery', title: 'גלריית המקום', icon: Icons.photo_library_outlined),
    (
      key: 'details',
      title: 'פרטי המקום',
      icon: Icons.edit_location_alt_outlined
    ),
    (
      key: 'coupons',
      title: 'קופונים ומבצעים',
      icon: Icons.card_giftcard_rounded
    ),
    (key: 'statistics', title: 'סטטיסטיקות', icon: Icons.query_stats_rounded),
  ];

  bool _loading = true;
  List<Map<String, dynamic>> _managedPlaces = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final assignments = List<Map<String, dynamic>>.from(
        await Supabase.instance.client
            .from('place_managers')
            .select('place_id,permissions,status')
            .eq('user_id', user.id)
            .eq('status', 'active'),
      );
      final ids =
          assignments.map((item) => item['place_id'].toString()).toList();
      final places = ids.isEmpty
          ? <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(await Supabase.instance.client
              .from('places')
              .select(
                  'id,name,address,image_url,category_id,latitude,longitude')
              .inFilter('id', ids));
      final byId = {for (final place in places) place['id'].toString(): place};
      if (!mounted) return;
      setState(() {
        _managedPlaces = assignments.map((assignment) {
          final place =
              byId[assignment['place_id'].toString()] ?? <String, dynamic>{};
          return {...place, 'manager_permissions': assignment['permissions']};
        }).toList();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא ניתן לטעון את כלי ניהול העסק')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTool(Map<String, dynamic> place, String key) {
    if (key == 'details') {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlaceDetailsScreen(place: place),
      ));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('הכלי יתחבר למסך העריכה בשלב הבא')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('ניהול העסק שלי'),
          actions: const [HomeButton()],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _managedPlaces.isEmpty
                ? const Center(child: Text('לא נמצאו מקומות בניהול החשבון'))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(18),
                      itemCount: _managedPlaces.length,
                      itemBuilder: (context, index) {
                        final place = _managedPlaces[index];
                        final permissions = Set<String>.from(
                            place['manager_permissions'] as List? ?? const []);
                        return Card(
                          margin: const EdgeInsets.only(bottom: 18),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(place['name']?.toString() ?? 'מקום',
                                    textAlign: TextAlign.right,
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                if ((place['address']?.toString() ?? '')
                                    .isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(place['address'].toString(),
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            color: AppColors.textMuted)),
                                  ),
                                const SizedBox(height: 16),
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount:
                                      MediaQuery.sizeOf(context).width < 520
                                          ? 2
                                          : 3,
                                  childAspectRatio: 1.45,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  children: [
                                    for (final tool in _tools)
                                      _ManagerTool(
                                        title: tool.title,
                                        icon: tool.icon,
                                        enabled: permissions.contains(tool.key),
                                        onTap: () => _openTool(place, tool.key),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      );
}

class _ManagerTool extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ManagerTool({
    required this.title,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: enabled
                ? AppColors.champagne.withValues(alpha: 0.10)
                : AppColors.surfaceRaised.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: enabled
                  ? AppColors.champagne.withValues(alpha: 0.38)
                  : AppColors.cardBorder,
            ),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(enabled ? icon : Icons.lock_outline_rounded,
                color: enabled ? AppColors.champagne : AppColors.textMuted),
            const SizedBox(height: 7),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        enabled ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
            if (!enabled)
              const Text('לא כלול בהרשאה',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ]),
        ),
      );
}
