import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';

class AdminPlaceManagersScreen extends StatefulWidget {
  const AdminPlaceManagersScreen({super.key});

  @override
  State<AdminPlaceManagersScreen> createState() =>
      _AdminPlaceManagersScreenState();
}

class _AdminPlaceManagersScreenState extends State<AdminPlaceManagersScreen> {
  static const permissionLabels = <String, String>{
    'replies': 'תגובות רשמיות לחוויות',
    'menu': 'פרסום ועריכת תפריט',
    'hours': 'עדכון שעות פתיחה',
    'gallery': 'ניהול גלריית המקום',
    'details': 'עריכת פרטי המקום',
    'coupons': 'יצירת קופונים ומבצעים',
    'statistics': 'צפייה בסטטיסטיקות העסק',
  };

  bool _loading = true;
  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _assignments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        Supabase.instance.client
            .from('places')
            .select('id,name,address')
            .order('name'),
        Supabase.instance.client.functions
            .invoke('admin-users', body: {'action': 'list'}),
        Supabase.instance.client
            .from('place_managers')
            .select('id,place_id,user_id,permissions,status,created_at')
            .order('created_at', ascending: false),
      ]);
      final userData = Map<String, dynamic>.from(
          (results[1] as FunctionResponse).data as Map);
      if (!mounted) return;
      setState(() {
        _places = List<Map<String, dynamic>>.from(results[0] as List);
        _users = List<Map<String, dynamic>>.from(
            userData['users'] as List? ?? const []);
        _assignments = List<Map<String, dynamic>>.from(results[2] as List);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא ניתן לטעון את מנהלי המקומות')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _placeName(String? id) =>
      _places
          .where((place) => place['id']?.toString() == id)
          .map((place) => place['name']?.toString() ?? 'מקום')
          .firstOrNull ??
      'מקום';

  String _placeLabel(Map<String, dynamic> place) {
    final name = place['name']?.toString().trim() ?? '';
    final address = place['address']?.toString().trim() ?? '';
    return address.isEmpty ? name : '$name - $address';
  }

  String _userName(String? id) =>
      _users.where((user) => user['id']?.toString() == id).map((user) {
        final name = user['display_name']?.toString().trim();
        final email = user['email']?.toString().trim();
        return name?.isNotEmpty == true ? name! : (email ?? 'משתמש');
      }).firstOrNull ??
      'משתמש';

  String _userLabel(Map<String, dynamic> user) {
    final name = user['display_name']?.toString().trim() ?? '';
    final email = user['email']?.toString().trim() ?? '';
    if (name.isEmpty) return email.isEmpty ? 'משתמש' : email;
    return email.isEmpty ? name : '$name - $email';
  }

  Iterable<Map<String, dynamic>> _matches(
    TextEditingValue value,
    List<Map<String, dynamic>> source,
    String Function(Map<String, dynamic>) label,
  ) {
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) return source.take(8);
    return source
        .where((item) => label(item).toLowerCase().contains(query))
        .take(8);
  }

  Future<void> _edit([Map<String, dynamic>? assignment]) async {
    String? placeId = assignment?['place_id']?.toString();
    String? userId = assignment?['user_id']?.toString();
    var active = assignment?['status'] != 'suspended';
    final selected = assignment == null
        ? permissionLabels.keys.toSet()
        : Set<String>.from(
            assignment['permissions'] as List? ?? const <String>[]);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(
                assignment == null ? 'הגדרת מנהל מקום' : 'עריכת הרשאות מנהל'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Autocomplete<Map<String, dynamic>>(
                    initialValue: TextEditingValue(
                        text: placeId == null ? '' : _placeName(placeId)),
                    displayStringForOption: _placeLabel,
                    optionsBuilder: (value) =>
                        _matches(value, _places, _placeLabel),
                    onSelected: (place) =>
                        setDialogState(() => placeId = place['id']?.toString()),
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmitted) =>
                            TextField(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: assignment != null,
                      onChanged: assignment == null
                          ? (_) => setDialogState(() => placeId = null)
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'חיפוש מקום',
                        hintText: 'הקלד שם או כתובת',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Autocomplete<Map<String, dynamic>>(
                    initialValue: TextEditingValue(
                        text: userId == null ? '' : _userName(userId)),
                    displayStringForOption: _userLabel,
                    optionsBuilder: (value) => _matches(
                      value,
                      _users
                          .where((user) => user['is_anonymous'] != true)
                          .toList(),
                      _userLabel,
                    ),
                    onSelected: (user) =>
                        setDialogState(() => userId = user['id']?.toString()),
                    fieldViewBuilder:
                        (context, controller, focusNode, onSubmitted) =>
                            TextField(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: assignment != null,
                      onChanged: assignment == null
                          ? (_) => setDialogState(() => userId = null)
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'חיפוש משתמש',
                        hintText: 'הקלד שם או כתובת מייל',
                        prefixIcon: Icon(Icons.person_search_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('הרשאות פעילות',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  for (final permission in permissionLabels.entries)
                    SwitchListTile.adaptive(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(permission.key),
                      title: Text(permission.value),
                      onChanged: (enabled) => setDialogState(() =>
                          enabled == true
                              ? selected.add(permission.key)
                              : selected.remove(permission.key)),
                    ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    title: const Text('החשבון פעיל כמנהל מקום'),
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('ביטול'),
              ),
              FilledButton(
                onPressed: placeId != null && userId != null
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('שמירה'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true || placeId == null || userId == null) return;
    final values = {
      'place_id': placeId,
      'user_id': userId,
      'permissions': selected.toList(),
      'status': active ? 'active' : 'suspended',
      'assigned_by': Supabase.instance.client.auth.currentUser!.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      if (assignment == null) {
        await Supabase.instance.client
            .from('place_managers')
            .upsert(values, onConflict: 'place_id,user_id');
      } else {
        await Supabase.instance.client
            .from('place_managers')
            .update(values)
            .eq('id', assignment['id']);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('מנהל המקום וההרשאות נשמרו')),
        );
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('השמירה נכשלה. נסה שוב.')),
        );
      }
    }
  }

  Future<void> _remove(Map<String, dynamic> assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('הסרת מנהל מקום'),
        content: Text(
            'להסיר את ${_userName(assignment['user_id']?.toString())} מניהול המקום?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('הסרה')),
        ],
      ),
    );
    if (confirmed != true) return;
    await Supabase.instance.client
        .from('place_managers')
        .delete()
        .eq('id', assignment['id']);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('מנהלי מקומות'),
          actions: const [HomeButton()],
        ),
        floatingActionButton: Permissions.canManageUsers
            ? FloatingActionButton.extended(
                onPressed: () => _edit(),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('הגדרת מנהל'),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _assignments.isEmpty
                ? const Center(child: Text('עדיין לא הוגדרו מנהלי מקומות'))
                : ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: _assignments.length,
                    itemBuilder: (context, index) {
                      final item = _assignments[index];
                      final permissions = Set<String>.from(
                          item['permissions'] as List? ?? const []);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Icon(item['status'] == 'active'
                                ? Icons.storefront_rounded
                                : Icons.pause_rounded),
                          ),
                          title: Text(_userName(item['user_id']?.toString())),
                          subtitle: Text(
                            '${_placeName(item['place_id']?.toString())}\n${permissions.map((key) => permissionLabels[key]).whereType<String>().join(' · ')}',
                          ),
                          isThreeLine: true,
                          onTap: () => _edit(item),
                          trailing: IconButton(
                            tooltip: 'הסרת מנהל',
                            onPressed: () => _remove(item),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ),
                      );
                    },
                  ),
      );
}
