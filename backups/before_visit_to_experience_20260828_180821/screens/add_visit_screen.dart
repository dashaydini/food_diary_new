import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/visit_image_gallery.dart';

class AddVisitScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final Map<String, dynamic>? visit;
  final bool viewOnly;

  const AddVisitScreen({
    super.key,
    required this.place,
    this.visit,
    this.viewOnly = false,
  });

  bool get isEditing => visit != null;

  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  final _foodController = TextEditingController();
  final _drinkController = TextEditingController();
  final _totalPriceController = TextEditingController();
  final _notesController = TextEditingController();

  int _priceLevel = 0;

  final ImagePicker _picker = ImagePicker();

  List<Map<String, dynamic>> _tags = [];
  final Set<String> _selectedTags = {};

  final List<Uint8List> _imageBytes = [];
  final List<String> _imageNames = [];

  DateTime _visitDate = DateTime.now();

  int _foodRating = 0;
  int _drinkRating = 0;
  int _atmosphereRating = 0;
  int _serviceRating = 0;
  int _cleanlinessRating = 0;
  int _varietyRating = 0;
  int _valueRating = 0;

  bool _loadingTags = true;
  bool _saving = false;
  bool _hasChanges = false;
  String? _error;
  bool _isFavoriteMemory = false;

  @override
  void initState() {
    super.initState();
    _loadExistingVisit();
    _loadTags();
  }

  Future<void> _loadExistingVisit() async {
    final visit = widget.visit;
    if (visit == null) return;

    _foodController.text = visit['food']?.toString() ?? '';
    _drinkController.text = visit['drink']?.toString() ?? '';
    _totalPriceController.text = visit['total_price']?.toString() ?? '';
    _priceLevel = (visit['price_level'] as num?)?.toInt() ?? 0;
    _notesController.text = visit['notes']?.toString() ?? '';
    _isFavoriteMemory = visit['favorite_memory'] == true;

    final visitDate = DateTime.tryParse(
      visit['visit_date']?.toString() ?? '',
    );

    if (visitDate != null) {
      _visitDate = visitDate;
    }

    _foodRating = (visit['food_rating'] as num?)?.toInt() ?? 0;
    _drinkRating = (visit['drink_rating'] as num?)?.toInt() ?? 0;
    _atmosphereRating = (visit['atmosphere_rating'] as num?)?.toInt() ?? 0;
    _serviceRating = (visit['service_rating'] as num?)?.toInt() ?? 0;
    _cleanlinessRating = (visit['cleanliness_rating'] as num?)?.toInt() ?? 0;
    _varietyRating = (visit['variety_rating'] as num?)?.toInt() ?? 0;
    _valueRating = (visit['value_rating'] as num?)?.toInt() ?? 0;

    final links =
        (visit['visit_tag_links'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    for (final link in links) {
      final tagId = link['tag_id']?.toString();
      if (tagId != null) {
        _selectedTags.add(tagId);
      }
    }

    try {
      final rows = await Supabase.instance.client
          .from('visit_images')
          .select('id, image_url, sort_order')
          .eq('visit_id', visit['id'])
          .order('sort_order');

      if (!mounted) return;

      final existingImages = List<Map<String, dynamic>>.from(rows);

      setState(() {
        widget.visit?['visit_images'] = existingImages;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _foodController.dispose();
    _drinkController.dispose();
    _totalPriceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    try {
      final rows = await Supabase.instance.client
          .from('visit_tags')
          .select('id, name, icon, category, sort_order')
          .order('category')
          .order('sort_order');

      if (!mounted) return;

      setState(() {
        _tags = List<Map<String, dynamic>>.from(rows);
        _loadingTags = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingTags = false;
        _error = 'לא ניתן לטעון את התגיות';
      });
    }
  }

  Future<void> _pickImages() async {
    if (widget.viewOnly) return;

    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (files.isEmpty) return;

      final bytesList = <Uint8List>[];
      final names = <String>[];

      for (final file in files) {
        bytesList.add(await file.readAsBytes());
        names.add(file.name);
      }

      if (!mounted) return;

      setState(() {
        _imageBytes.addAll(bytesList);
        _imageNames.addAll(names);
        _hasChanges = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'לא ניתן לבחור תמונות';
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    if (widget.viewOnly) return;

    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1400,
        maxHeight: 1400,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      setState(() {
        _imageBytes.add(bytes);
        _imageNames.add(file.name);
        _hasChanges = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'לא ניתן לצלם תמונה';
      });
    }
  }

  Future<void> _showImageOptions() async {
    if (widget.viewOnly) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (widget.viewOnly && widget.visit != null) ...[
                _buildVisitGalleryForViewOnly(),
                SizedBox(height: 18),
              ],
              if (!widget.viewOnly) ...[
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined),
                  title: Text('צילום מנה'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromCamera();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined),
                  title: Text('בחירת תמונות מהגלריה'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImages();
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  double _averageRating() {
    final ratings = [
      _foodRating,
      _drinkRating,
      _atmosphereRating,
      _serviceRating,
      _cleanlinessRating,
      _varietyRating,
      _valueRating,
    ].where((rating) => rating > 0).toList();

    if (ratings.isEmpty) return 0;

    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  Future<List<String>> _uploadImages(String userId) async {
    final urls = <String>[];

    for (var i = 0; i < _imageBytes.length; i++) {
      final extension = (_imageNames[i].split('.').last).toLowerCase();

      final filePath =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_$i.$extension';

      await Supabase.instance.client.storage.from('visit-images').uploadBinary(
            filePath,
            _imageBytes[i],
            fileOptions: FileOptions(
              contentType: 'image/$extension',
              upsert: false,
            ),
          );

      final url = Supabase.instance.client.storage
          .from('visit-images')
          .getPublicUrl(filePath);

      urls.add(url);
    }

    return urls;
  }

  Future<bool> _onWillPop() async {
    if (widget.viewOnly) {
      return true;
    }

    if (!_hasChanges) {
      return true;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('שינויים שלא נשמרו'),
          content: Text('האם לשמור את השינויים לפני היציאה?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop('discard');
              },
              child: Text('יציאה ללא שמירה'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop('cancel');
              },
              child: Text('ביטול'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop('save');
              },
              child: Text('שמור'),
            ),
          ],
        );
      },
    );

    if (!mounted) return false;

    if (result == 'discard') {
      return true;
    } else if (result == 'save') {
      await _saveVisit();
      return true;
    }
    return false;
  }

  Future<void> _handleBack() async {
    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) {
      Navigator.of(context).pop();
    }
  }

  final List<Map<String, dynamic>> _deletedImages = [];

  List<Map<String, dynamic>> _existingVisitImages() {
    if (widget.visit == null) return [];

    final result = <Map<String, dynamic>>[];

    final images = widget.visit!['visit_images'];

    if (images is List) {
      result.addAll(
        images
            .whereType<Map>()
            .map((image) => Map<String, dynamic>.from(image)),
      );
    }

    final legacyImageUrl = widget.visit!['image_url']?.toString();

    if (legacyImageUrl != null && legacyImageUrl.isNotEmpty) {
      final alreadyExists = result.any(
        (image) => image['image_url']?.toString() == legacyImageUrl,
      );

      if (!alreadyExists) {
        result.insert(0, {
          'id': null,
          'image_url': legacyImageUrl,
          'legacy': true,
        });
      }
    }

    result.removeWhere((image) {
      return _deletedImages.any(
        (deleted) =>
            deleted['id']?.toString() == image['id']?.toString() &&
            deleted['image_url']?.toString() == image['image_url']?.toString(),
      );
    });

    return result;
  }

  Future<void> _deleteExistingImage(
    Map<String, dynamic> image,
  ) async {
    if (widget.viewOnly) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('מחיקת תמונה'),
          content: Text(
            'האם אתה בטוח שברצונך למחוק את התמונה?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('ביטול'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('מחיקה'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final imageId = image['id']?.toString();
    final imageUrl = image['image_url']?.toString() ?? '';
    final isLegacy = image['legacy'] == true;

    if (imageUrl.isEmpty) {
      setState(() {
        _error = 'לא ניתן לזהות את התמונה למחיקה';
      });
      return;
    }

    try {
      if (isLegacy) {
        await Supabase.instance.client
            .from('visits')
            .update({'image_url': null}).eq('id', widget.visit!['id']);
      } else {
        if (imageId == null || imageId.isEmpty) {
          setState(() {
            _error = 'לא ניתן לזהות את התמונה למחיקה';
          });
          return;
        }

        await Supabase.instance.client
            .from('visit_images')
            .delete()
            .eq('id', imageId);
      }

      const marker = '/storage/v1/object/public/visit-images/';
      final markerIndex = imageUrl.indexOf(marker);

      if (markerIndex != -1) {
        final filePath = imageUrl.substring(
          markerIndex + marker.length,
        );

        if (filePath.isNotEmpty) {
          try {
            await Supabase.instance.client.storage
                .from('visit-images')
                .remove([filePath]);
          } catch (_) {}
        }
      }

      if (!mounted) return;

      setState(() {
        _deletedImages.add(Map<String, dynamic>.from(image));
        _hasChanges = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'לא ניתן למחוק את התמונה: $e';
      });
    }
  }

  Widget _buildImageGallery() {
    final existingImages = _existingVisitImages();

    if (widget.viewOnly) {
      if (existingImages.isEmpty) {
        return const SizedBox.shrink();
      }

      final profile = widget.visit?['profiles'] as Map<String, dynamic>?;

      final displayName = profile?['display_name']?.toString();
      final email = profile?['email']?.toString();

      final author = (displayName?.trim().isNotEmpty ?? false)
          ? displayName!.trim()
          : (email?.trim().isNotEmpty ?? false)
              ? email!.trim().split('@').first
              : 'משתמש';

      final visitDate = DateTime.tryParse(
        widget.visit?['visit_date']?.toString() ?? '',
      );

      final galleryImages = <VisitImageGalleryImage>[];

      for (final image in existingImages) {
        final imageUrl = image['image_url']?.toString() ?? '';
        if (imageUrl.isEmpty) continue;

        galleryImages.add(
          VisitImageGalleryImage(
            id: image['id']?.toString() ?? '',
            imageUrl: imageUrl,
            author: author,
            date: visitDate,
          ),
        );
      }

      if (galleryImages.isEmpty) {
        return const SizedBox.shrink();
      }

      return VisitImageGallery(
        images: galleryImages,
      );
    }

    final totalImages = existingImages.length + _imageBytes.length;

    if (totalImages == 0) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 165,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totalImages,
        separatorBuilder: (_, __) => SizedBox(width: 10),
        itemBuilder: (context, index) {
          if (index < existingImages.length) {
            final image = existingImages[index];
            final url = image['image_url']?.toString() ?? '';

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    url,
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: AppColors.muted.withValues(alpha: 0.54),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _deleteExistingImage(image),
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          final newIndex = index - existingImages.length;

          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  _imageBytes[newIndex],
                  width: 150,
                  height: 150,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  color: AppColors.muted.withValues(alpha: 0.54),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() {
                        _imageBytes.removeAt(newIndex);
                        _hasChanges = true;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveVisit() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      setState(() {
        _error = 'יש להתחבר כדי לשמור את הביקור';
      });
      return;
    }

    final existingVisit = widget.visit;

    if (existingVisit != null &&
        !Permissions.canEditVisit(existingVisit['user_id']?.toString())) {
      setState(() {
        _error = 'אין לך הרשאה לערוך את הביקור הזה';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final rating = _averageRating();

      if (existingVisit == null) {
        final imageUrls = await _uploadImages(user.id);

        final visit = await Supabase.instance.client
            .from('visits')
            .insert({
              'place_id': widget.place['id'],
              'user_id': user.id,
              'visit_date': _visitDate.toIso8601String(),
              'notes': _notesController.text.trim(),
              'rating': rating == 0 ? null : rating,
              'food': _foodController.text.trim(),
              'drink': _drinkController.text.trim(),
              'total_price': double.tryParse(_totalPriceController.text.trim()),
              'price_level': _priceLevel == 0 ? null : _priceLevel,
              'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
              'food_rating': _foodRating == 0 ? null : _foodRating,
              'drink_rating': _drinkRating == 0 ? null : _drinkRating,
              'atmosphere_rating':
                  _atmosphereRating == 0 ? null : _atmosphereRating,
              'service_rating': _serviceRating == 0 ? null : _serviceRating,
              'cleanliness_rating':
                  _cleanlinessRating == 0 ? null : _cleanlinessRating,
              'variety_rating': _varietyRating == 0 ? null : _varietyRating,
              'value_rating': _valueRating == 0 ? null : _valueRating,
            })
            .select('id')
            .single();

        final visitId = visit['id'] as String;

        if (imageUrls.isNotEmpty) {
          await Supabase.instance.client.from('visit_images').insert(
                imageUrls
                    .asMap()
                    .entries
                    .map(
                      (entry) => {
                        'visit_id': visitId,
                        'user_id': user.id,
                        'image_url': entry.value,
                        'sort_order': entry.key,
                      },
                    )
                    .toList(),
              );
        }

        if (_selectedTags.isNotEmpty) {
          await Supabase.instance.client.from('visit_tag_links').insert(
                _selectedTags
                    .map(
                      (tagId) => {
                        'visit_id': visitId,
                        'tag_id': tagId,
                      },
                    )
                    .toList(),
              );
        }
      } else {
        final visitId = existingVisit['id'].toString();

        await Supabase.instance.client.from('visits').update({
          'visit_date': _visitDate.toIso8601String(),
          'notes': _notesController.text.trim(),
          'rating': rating == 0 ? null : rating,
          'food': _foodController.text.trim(),
          'drink': _drinkController.text.trim(),
          'total_price': double.tryParse(_totalPriceController.text.trim()),
          'price_level': _priceLevel == 0 ? null : _priceLevel,
          'food_rating': _foodRating == 0 ? null : _foodRating,
          'drink_rating': _drinkRating == 0 ? null : _drinkRating,
          'atmosphere_rating':
              _atmosphereRating == 0 ? null : _atmosphereRating,
          'service_rating': _serviceRating == 0 ? null : _serviceRating,
          'cleanliness_rating':
              _cleanlinessRating == 0 ? null : _cleanlinessRating,
          'variety_rating': _varietyRating == 0 ? null : _varietyRating,
          'value_rating': _valueRating == 0 ? null : _valueRating,
        }).eq('id', visitId);

        await Supabase.instance.client
            .from('visit_tag_links')
            .delete()
            .eq('visit_id', visitId);

        if (_selectedTags.isNotEmpty) {
          await Supabase.instance.client.from('visit_tag_links').insert(
                _selectedTags
                    .map(
                      (tagId) => {
                        'visit_id': visitId,
                        'tag_id': tagId,
                      },
                    )
                    .toList(),
              );
        }

        if (_imageBytes.isNotEmpty) {
          final imageUrls = await _uploadImages(user.id);

          final existingImages = _existingVisitImages();

          final nextSortOrder = existingImages.isEmpty
              ? 0
              : existingImages
                      .map(
                        (image) => (image['sort_order'] as num?)?.toInt() ?? 0,
                      )
                      .reduce((a, b) => a > b ? a : b) +
                  1;

          await Supabase.instance.client.from('visit_images').insert(
                imageUrls
                    .asMap()
                    .entries
                    .map(
                      (entry) => {
                        'visit_id': visitId,
                        'user_id': user.id,
                        'image_url': entry.value,
                        'sort_order': nextSortOrder + entry.key,
                      },
                    )
                    .toList(),
              );
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'לא ניתן לשמור את הביקור: $e';
      });
    }
  }

  Future<void> _deleteVisit() async {
    final visit = widget.visit;
    if (visit == null) return;

    final ownerId = visit['user_id']?.toString();

    if (!Permissions.canDeleteVisit(ownerId)) {
      setState(() {
        _error = 'אין לך הרשאה למחוק את הביקור הזה';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('מחיקת ביקור'),
          content: Text('האם אתה בטוח שברצונך למחוק את הביקור?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('ביטול'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('מחיקה'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      await Supabase.instance.client
          .from('visits')
          .delete()
          .eq('id', visit['id']);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'לא ניתן למחוק את הביקור: $e';
      });
    }
  }

  Future<void> _toggleFavoriteMemory() async {
    final visit = widget.visit;
    if (visit == null) return;

    final newValue = !_isFavoriteMemory;

    setState(() {
      _isFavoriteMemory = newValue;
    });

    try {
      await Supabase.instance.client
          .from('visits')
          .update({'favorite_memory': newValue}).eq('id', visit['id']);

      widget.visit?['favorite_memory'] = newValue;
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isFavoriteMemory = !newValue;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('לא ניתן לשמור את הזיכרון: $e')),
      );
    }
  }

  Widget _ratingRow(
    String title,
    int value,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
            ),
          ),
          const SizedBox(width: 18),
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.ltr,
            children: List.generate(5, (index) {
              final rating = index + 1;
              final selected = rating <= value;

              return InkWell(
                onTap: widget.viewOnly ? null : () => onChanged(rating),
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 29,
                  height: 32,
                  child: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 21,
                    color: selected
                        ? AppColors.champagne.withValues(alpha: 0.78)
                        : AppColors.textMuted.withValues(alpha: 0.55),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    String? suffixText,
  }) {
    return TextField(
      controller: controller,
      readOnly: widget.viewOnly,
      onChanged: widget.viewOnly
          ? null
          : (_) {
              _hasChanges = true;
            },
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        suffixText: suffixText,
        suffixStyle: const TextStyle(
          color: AppColors.champagneSoft,
          fontSize: 14,
        ),
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.textMuted.withValues(alpha: 0.90),
          fontSize: 13,
        ),
        floatingLabelStyle: TextStyle(
          color: AppColors.champagne.withValues(alpha: 0.78),
          fontSize: 12,
        ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: AppColors.champagne.withValues(alpha: 0.13),
            width: 0.75,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: AppColors.champagne.withValues(alpha: 0.10),
            width: 0.7,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(
            color: AppColors.champagne.withValues(alpha: 0.50),
            width: 0.9,
          ),
        ),
      ),
    );
  }

  Widget _buildTags() {
    if (_loadingTags) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
          ),
        ),
      );
    }

    final visibleTags = widget.viewOnly
        ? _tags
            .where((tag) => _selectedTags.contains(tag['id'] as String))
            .toList()
        : _tags;

    if (widget.viewOnly && visibleTags.isEmpty) {
      return const Align(
        alignment: Alignment.centerRight,
        child: Text(
          'לא נבחרו תגיות',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
        ),
      );
    }

    Widget buildTag(Map<String, dynamic> tag) {
      final id = tag['id'] as String;
      final selected = _selectedTags.contains(id);

      return InkWell(
        onTap: widget.viewOnly
            ? null
            : () {
                setState(() {
                  if (selected) {
                    _selectedTags.remove(id);
                  } else {
                    _selectedTags.add(id);
                  }

                  _hasChanges = true;
                });
              },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.champagne.withValues(alpha: 0.075)
                : AppColors.background,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.champagne.withValues(alpha: 0.38)
                  : AppColors.champagne.withValues(alpha: 0.12),
              width: 0.75,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.champagne.withValues(alpha: 0.035),
                      blurRadius: 14,
                      spreadRadius: -3,
                    ),
                  ]
                : null,
          ),
          child: Text(
            tag['name'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              color:
                  selected ? AppColors.champagneSoft : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      );
    }

    if (widget.viewOnly) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 7,
            runSpacing: 7,
            children: visibleTags.map(buildTag).toList(),
          ),
        ),
      );
    }

    final categories = <String, List<Map<String, dynamic>>>{};

    for (final tag in visibleTags) {
      final category = tag['category'] as String? ?? 'אחר';
      categories.putIfAbsent(category, () => []).add(tag);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: categories.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    entry.key,
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textMuted.withValues(alpha: 0.82),
                          letterSpacing: 0.1,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 7,
                    runSpacing: 7,
                    children: entry.value.map(buildTag).toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildVisitGalleryForViewOnly() {
    final rawImages = widget.visit?['visit_images'];

    if (rawImages is! List || rawImages.isEmpty) {
      return const SizedBox.shrink();
    }

    final profile = widget.visit?['profiles'] as Map<String, dynamic>?;

    final displayName = profile?['display_name']?.toString();
    final email = profile?['email']?.toString();

    final author = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : (email?.trim().isNotEmpty ?? false)
            ? email!.trim().split('@').first
            : 'משתמש';

    final visitDate = DateTime.tryParse(
      widget.visit?['visit_date']?.toString() ?? '',
    );

    final images = <VisitImageGalleryImage>[];

    for (final rawImage in rawImages) {
      if (rawImage is! Map) continue;

      final imageUrl = rawImage['image_url']?.toString() ?? '';
      if (imageUrl.isEmpty) continue;

      images.add(
        VisitImageGalleryImage(
          id: rawImage['id']?.toString() ?? '',
          imageUrl: imageUrl,
          author: author,
          date: visitDate,
        ),
      );
    }

    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return VisitImageGallery(
      images: images,
    );
  }

  Widget _priceLevelButton(int level) {
    final selected = _priceLevel == level;

    return InkWell(
      onTap: widget.viewOnly
          ? null
          : () {
              setState(() {
                _priceLevel = level;
                _hasChanges = true;
              });
            },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.champagne.withValues(alpha: 0.075)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.champagne.withValues(alpha: 0.38)
                : AppColors.champagne.withValues(alpha: 0.12),
            width: 0.75,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.champagne.withValues(alpha: 0.035),
                    blurRadius: 12,
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: Text(
          List.filled(level, '₪').join(),
          style: TextStyle(
            color: selected ? AppColors.champagneSoft : AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final placeName = widget.place['name']?.toString() ?? 'מקום';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          if (!context.mounted) return;
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            widget.viewOnly
                ? 'פרטי ביקור'
                : widget.isEditing
                    ? 'עריכת ביקור'
                    : 'תיעוד ביקור חדש',
          ),
          leading: IconButton(
            tooltip: 'חזרה',
            icon: const Icon(
              Icons.arrow_forward_rounded,
              textDirection: TextDirection.ltr,
              color: AppColors.champagne,
            ),
            onPressed: _handleBack,
          ),
          actions: [
            if (widget.viewOnly &&
                widget.isEditing &&
                Permissions.canEditVisit(
                  widget.visit?['user_id']?.toString(),
                ))
              IconButton(
                tooltip: 'עריכת ביקור',
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.champagne,
                ),
                onPressed: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AddVisitScreen(
                        place: widget.place,
                        visit: widget.visit,
                        viewOnly: false,
                      ),
                    ),
                  );

                  if (changed == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
              ),
            if (!widget.viewOnly &&
                widget.isEditing &&
                Permissions.canDeleteVisit(
                  widget.visit?['user_id']?.toString(),
                ))
              IconButton(
                tooltip: 'מחיקת ביקור',
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textMuted,
                ),
                onPressed: _deleteVisit,
              ),
            if (widget.isEditing)
              IconButton(
                tooltip: _isFavoriteMemory
                    ? 'הסרה מהזיכרונות המועדפים'
                    : 'הוספה לזיכרונות המועדפים',
                icon: Icon(
                  _isFavoriteMemory
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _isFavoriteMemory
                      ? AppColors.champagne
                      : AppColors.textMuted,
                ),
                onPressed: _toggleFavoriteMemory,
              ),
          ],
        ),
        body: SizedBox(
          width: double.infinity,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            children: [
              Text(
                placeName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'תעד את הביקור שלך',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                ),
              ),
              SizedBox(height: 24),
              _textField(
                _foodController,
                'מה אכלתי?',
              ),
              SizedBox(height: 14),
              _textField(
                _drinkController,
                'מה שתיתי?',
              ),
              SizedBox(height: 20),
              Row(
                textDirection: TextDirection.rtl,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'כמה שילמתי?',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.muted,
                    ),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: _textField(
                      _totalPriceController,
                      '',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      suffixText: '₪',
                    ),
                  ),
                  SizedBox(width: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _priceLevelButton(1),
                      SizedBox(width: 6),
                      _priceLevelButton(2),
                      SizedBox(width: 6),
                      _priceLevelButton(3),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: widget.viewOnly ? null : _showImageOptions,
                icon: Icon(Icons.restaurant_outlined),
                label: Text(
                  _imageBytes.isEmpty
                      ? 'הוספת תמונות של הביקור'
                      : 'הוספת תמונות נוספות',
                ),
              ),
              SizedBox(height: 16),
              _buildImageGallery(),
              SizedBox(height: 24),
              _textField(
                _notesController,
                'הערות נוספות / חוויות',
                maxLines: 3,
              ),
              SizedBox(height: 24),
              Text(
                'דירוגים',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 14),
              _ratingRow('אוכל', _foodRating, (v) {
                setState(() {
                  _foodRating = v;
                  _hasChanges = true;
                });
              }),
              _ratingRow('שתייה', _drinkRating, (v) {
                setState(() {
                  _drinkRating = v;
                  _hasChanges = true;
                });
              }),
              _ratingRow('אווירה', _atmosphereRating, (v) {
                setState(() {
                  _atmosphereRating = v;
                  _hasChanges = true;
                });
              }),
              _ratingRow('שירות', _serviceRating, (v) {
                setState(() {
                  _serviceRating = v;
                  _hasChanges = true;
                });
              }),
              _ratingRow('ניקיון', _cleanlinessRating, (v) {
                setState(() {
                  _cleanlinessRating = v;
                  _hasChanges = true;
                });
              }),
              _ratingRow('מבחר', _varietyRating, (v) {
                setState(() {
                  _varietyRating = v;
                  _hasChanges = true;
                });
              }),
              _ratingRow('תמורה למחיר', _valueRating, (v) {
                setState(() {
                  _valueRating = v;
                  _hasChanges = true;
                });
              }),
              SizedBox(height: 24),
              Text(
                'תגיות',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 12),
              _buildTags(),
              if (_error != null) ...[
                SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              if (!widget.viewOnly) ...[
                SizedBox(height: 30),
                FilledButton(
                  onPressed: _saving ? null : _saveVisit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _saving
                        ? const CircularProgressIndicator.adaptive()
                        : Text(
                            'שמור ביקור',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
