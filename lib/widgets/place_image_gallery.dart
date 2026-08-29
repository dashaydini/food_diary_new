import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import 'compact_gallery_preview.dart';

class PlaceGalleryImage {
  final String id;
  final String imageUrl;
  final String author;
  final DateTime? date;

  const PlaceGalleryImage({
    required this.id,
    required this.imageUrl,
    required this.author,
    required this.date,
  });
}

class PlaceImageGallery extends StatefulWidget {
  final List<PlaceGalleryImage> images;

  const PlaceImageGallery({
    super.key,
    required this.images,
  });

  @override
  State<PlaceImageGallery> createState() => _PlaceImageGalleryState();
}

class _PlaceImageGalleryState extends State<PlaceImageGallery> {
  late List<PlaceGalleryImage> _images;

  @override
  void initState() {
    super.initState();

    _images = List<PlaceGalleryImage>.from(widget.images)..shuffle(Random());
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) {
      return const SizedBox.shrink();
    }

    return CompactGalleryPreview(
      imageUrl: _images.first.imageUrl,
      title: 'גלריית המקום',
      subtitle: 'מתוך חוויות במקום',
      imageCount: _images.length,
      onTap: () => _openGallery(context, 0),
    );
  }

  void _openGallery(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _GalleryScreen(
          images: _images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _GalleryScreen extends StatefulWidget {
  final List<PlaceGalleryImage> images;
  final int initialIndex;

  const _GalleryScreen({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<_GalleryScreen> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;

    _controller = PageController(
      initialPage: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _dateText(DateTime? date) {
    if (date == null) return '';

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  Future<void> _reportImage(
    BuildContext context,
    PlaceGalleryImage image,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || user.isAnonymous) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('יש להתחבר כדי לדווח על תמונה'),
        ),
      );
      return;
    }

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surfaceRaised,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: AppColors.champagne.withValues(alpha: 0.18),
                width: 0.8,
              ),
            ),
            title: const Text(
              'דיווח על תמונה',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            content: const Text(
              'בחר את הסיבה לדיווח:',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('ביטול'),
              ),
              ListTile(
                leading: Icon(Icons.report_outlined),
                title: Text('תוכן לא הולם'),
                onTap: () => Navigator.of(dialogContext).pop('תוכן לא הולם'),
              ),
              ListTile(
                leading: Icon(Icons.place_outlined),
                title: Text('התמונה אינה קשורה למקום'),
                onTap: () =>
                    Navigator.of(dialogContext).pop('התמונה אינה קשורה למקום'),
              ),
              ListTile(
                leading: Icon(Icons.warning_amber_outlined),
                title: Text('תמונה פוגענית'),
                onTap: () => Navigator.of(dialogContext).pop('תמונה פוגענית'),
              ),
              ListTile(
                leading: Icon(Icons.copyright_outlined),
                title: Text('זכויות יוצרים'),
                onTap: () => Navigator.of(dialogContext).pop('זכויות יוצרים'),
              ),
              ListTile(
                leading: Icon(Icons.more_horiz),
                title: Text('אחר'),
                onTap: () => Navigator.of(dialogContext).pop('אחר'),
              ),
            ],
          ),
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    try {
      final existing = await Supabase.instance.client
          .from('visit_image_reports')
          .select('id')
          .eq('image_id', image.id)
          .eq('reporter_id', user.id)
          .eq('status', 'new')
          .maybeSingle();

      if (existing != null) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('כבר דיווחת על התמונה הזו'),
          ),
        );
        return;
      }

      await Supabase.instance.client.from('visit_image_reports').insert({
        'image_id': image.id,
        'reporter_id': user.id,
        'reason': reason,
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הדיווח התקבל, תודה'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן לשלוח את הדיווח כרגע'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final image = widget.images[index];

                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      image.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            // מספר תמונה
            Positioned(
              top: 14,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.champagne.withValues(alpha: 0.18),
                      width: 0.75,
                    ),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 10,
              left: 10,
              child: Material(
                color: AppColors.background.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      _reportImage(context, widget.images[_currentIndex]),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          color: AppColors.champagne,
                          size: 18,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'דיווח',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close,
                  color: AppColors.textPrimary,
                  size: 28,
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.champagne.withValues(alpha: 0.18),
                    width: 0.75,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 16,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    'הועלה על ידי ${widget.images[_currentIndex].author}'
                    '${_dateText(widget.images[_currentIndex].date).isNotEmpty ? ' בתאריך ${_dateText(widget.images[_currentIndex].date)}' : ''}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),

            // Navigation arrows for Web/Desktop
            if (widget.images.length > 1) ...[
              Positioned(
                left: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: CircleAvatar(
                    backgroundColor:
                        AppColors.background.withValues(alpha: 0.86),
                    child: IconButton(
                      icon: Icon(Icons.arrow_forward_ios,
                          color: AppColors.champagne, size: 20),
                      onPressed: () {
                        _controller.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: CircleAvatar(
                    backgroundColor:
                        AppColors.background.withValues(alpha: 0.86),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new,
                          color: AppColors.champagne, size: 20),
                      onPressed: () {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
