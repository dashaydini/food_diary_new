import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';

class AdminPlaceCategoryScreen extends StatefulWidget {
  const AdminPlaceCategoryScreen({super.key});

  @override
  State<AdminPlaceCategoryScreen> createState() =>
      _AdminPlaceCategoryScreenState();
}

class _AdminPlaceCategoryScreenState extends State<AdminPlaceCategoryScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _places = [];
  List<Map<String, dynamic>> _categories = [];
  String _query = '';
  String _categoryFilter = 'all';

  List<Map<String, dynamic>> get _filteredPlaces {
    final query = _query.trim().toLowerCase();
    return _places.where((place) {
      final matchesCategory =
          _categoryFilter == 'all' || place['category_id']?.toString() == _categoryFilter;
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;
      final searchable = [place['name'], place['address']]
          .whereType<Object>()
          .map((value) => value.toString().toLowerCase())
          .join(' ');
      return searchable.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Permissions.isAdmin) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('places')
            .select('id,name,address,category_id')
            .order('name'),
        Supabase.instance.client
            .from('categories')
            .select('id,title,sort_order')
            .order('sort_order'),
      ]);
      if (!mounted) return;
      setState(() {
        _places = List<Map<String, dynamic>>.from(results[0] as List);
        _categories = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון את רשימת המקומות';
      });
    }
  }

  String _categoryTitle(String? categoryId) {
    final category = _categories.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['id']?.toString() == categoryId,
          orElse: () => null,
        );
    return category?['title']?.toString() ?? 'ללא קטגוריה';
  }

  Future<void> _chooseCategory(Map<String, dynamic> place) async {
    final currentId = place['category_id']?.toString();
    final newId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                'העברת ${place['name'] ?? 'המקום'} לקטגוריה',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final id = category['id']?.toString();
                  final selected = id == currentId;
                  return ListTile(
                    title: Text(
                      category['title']?.toString() ?? '',
                      textAlign: TextAlign.right,
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.champagne)
                        : null,
                    onTap: id == null || selected
                        ? null
                        : () => Navigator.of(sheetContext).pop(id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (newId == null || !mounted) return;
    try {
      await Supabase.instance.client
          .from('places')
          .update({'category_id': newId}).eq('id', place['id']);
      if (!mounted) return;
      setState(() => place['category_id'] = newId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${place['name']} הועבר לקטגוריה החדשה')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן להעביר את המקום כרגע')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Permissions.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('העברת מקומות בין קטגוריות')),
        body: const Center(child: Text('אין הרשאת גישה')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('העברת מקומות בין קטגוריות'),
        actions: const [HomeButton()],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: OutlinedButton(
                    onPressed: _load,
                    child: Text('$_error · נסה שוב'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredPlaces.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'בחירת מקום פותחת את רשימת הקטגוריות. רק מנהל יכול לבצע את השינוי.',
                              textAlign: TextAlign.right,
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                              onChanged: (value) => setState(() => _query = value),
                              decoration: InputDecoration(
                                hintText: 'חיפוש לפי שם או כתובת',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: AppColors.surfaceRaised,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              key: ValueKey(_categoryFilter),
                              initialValue: _categoryFilter,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'סינון לפי קטגוריה נוכחית',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('כל הקטגוריות'),
                                ),
                                for (final category in _categories)
                                  DropdownMenuItem(
                                    value: category['id']?.toString(),
                                    child: Text(category['title']?.toString() ?? ''),
                                  ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _categoryFilter = value);
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${_filteredPlaces.length} ${_filteredPlaces.length == 1 ? 'מקום' : 'מקומות'}',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        );
                      }
                      final place = _filteredPlaces[index - 1];
                      return Card(
                        child: ListTile(
                          title: Text(
                            place['name']?.toString() ?? 'מקום',
                            textAlign: TextAlign.right,
                          ),
                          subtitle: Text(
                            _categoryTitle(place['category_id']?.toString()),
                            textAlign: TextAlign.right,
                          ),
                          trailing: const Icon(Icons.swap_horiz_rounded,
                              color: AppColors.champagne),
                          onTap: () => _chooseCategory(place),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
