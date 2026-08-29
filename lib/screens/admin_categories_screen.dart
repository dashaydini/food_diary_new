import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_icons.dart';
import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (!Permissions.canManageContent) {
      setState(() {
        _loading = false;
        _error = 'אין הרשאת גישה';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('categories')
          .select('id, title, subtitle, icon, sort_order')
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _categories = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון קטגוריות: $error';
      });
    }
  }

  Future<void> _editCategory([Map<String, dynamic>? category]) async {
    final titleController =
        TextEditingController(text: category?['title']?.toString() ?? '');
    final subtitleController =
        TextEditingController(text: category?['subtitle']?.toString() ?? '');
    final iconController =
        TextEditingController(text: category?['icon']?.toString() ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(category == null ? 'קטגוריה חדשה' : 'עריכת קטגוריה'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                textAlign: TextAlign.right,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'שם הקטגוריה'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: subtitleController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'תיאור קצר'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  labelText: 'שם אייקון',
                  hintText: 'restaurant',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              Navigator.pop(dialogContext, {
                'title': title,
                'subtitle': subtitleController.text.trim(),
                'icon': iconController.text.trim(),
              });
            },
            child: const Text('שמירה'),
          ),
        ],
      ),
    );

    titleController.dispose();
    subtitleController.dispose();
    iconController.dispose();
    if (result == null) return;

    try {
      if (category == null) {
        final maxOrder = _categories.fold<int>(
          0,
          (value, item) =>
              (item['sort_order'] as num?)?.toInt().clamp(value, 999999) ??
              value,
        );
        await Supabase.instance.client.from('categories').insert({
          'id': 'category_${DateTime.now().millisecondsSinceEpoch}',
          ...result,
          'sort_order': maxOrder + 1,
        });
      } else {
        await Supabase.instance.client
            .from('categories')
            .update(result)
            .eq('id', category['id']);
      }
      await _loadCategories();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('השמירה נכשלה: $error')),
      );
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final categoryId = category['id']?.toString();
    if (categoryId == null) return;

    final places = await Supabase.instance.client
        .from('places')
        .select('id')
        .eq('category_id', categoryId)
        .limit(1);
    if (places.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן למחוק קטגוריה שמכילה מקומות'),
        ),
      );
      return;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('מחיקת קטגוריה'),
        content: Text('למחוק את ${category['title']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('מחיקה'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('categories')
          .delete()
          .eq('id', categoryId);
      await _loadCategories();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('המחיקה נכשלה: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ניהול קטגוריות'),
        actions: const [HomeButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _editCategory(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('קטגוריה חדשה'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.champagne),
                )
              : _error != null
                  ? Center(child: Text(_error!))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
                      itemCount: _categories.length,
                      onReorderItem: (oldIndex, newIndex) async {
                        setState(() {
                          final item = _categories.removeAt(oldIndex);
                          _categories.insert(newIndex, item);
                        });
                        try {
                          for (var index = 0;
                              index < _categories.length;
                              index++) {
                            await Supabase.instance.client
                                .from('categories')
                                .update({'sort_order': index}).eq(
                                    'id', _categories[index]['id']);
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('שמירת הסדר נכשלה: $error')),
                            );
                          }
                        }
                      },
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return Container(
                          key: ValueKey(category['id']),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color:
                                  AppColors.champagne.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Row(
                            textDirection: TextDirection.rtl,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  AppIcons.categoryIcon(
                                    category['icon']?.toString(),
                                    title: category['title']?.toString(),
                                  ),
                                  color: AppColors.champagne,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      category['title']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      category['subtitle']?.toString() ?? '',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'עריכה',
                                onPressed: () => _editCategory(category),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'מחיקה',
                                onPressed: () => _deleteCategory(category),
                                icon: const Icon(Icons.delete_outline),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle_rounded),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}
