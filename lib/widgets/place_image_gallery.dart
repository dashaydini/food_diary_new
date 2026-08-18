import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';

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

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: _images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final image = _images[index];

          return GestureDetector(
            onTap: () => _openGallery(context, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 110,
                height: 92,
                child: Image.network(
                  image.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      color: AppColors.card,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.muted,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
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
            title: const Text('דיווח על תמונה'),
            content: const Text('בחר את הסיבה לדיווח:'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('ביטול'),
              ),
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('תוכן לא הולם'),
                onTap: () => Navigator.of(dialogContext).pop('תוכן לא הולם'),
              ),
              ListTile(
                leading: const Icon(Icons.place_outlined),
                title: const Text('התמונה אינה קשורה למקום'),
                onTap: () =>
                    Navigator.of(dialogContext).pop('התמונה אינה קשורה למקום'),
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: const Text('תמונה פוגענית'),
                onTap: () => Navigator.of(dialogContext).pop('תמונה פוגענית'),
              ),
              ListTile(
                leading: const Icon(Icons.copyright_outlined),
                title: const Text('זכויות יוצרים'),
                onTap: () => Navigator.of(dialogContext).pop('זכויות יוצרים'),
              ),
              ListTile(
                leading: const Icon(Icons.more_horiz),
                title: const Text('אחר'),
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
      backgroundColor: Colors.black,
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
            Positioned(
              top: 10,
              left: 10,
              child: Material(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () =>
                      _reportImage(context, widget.images[_currentIndex]),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'דיווח',
                          style: TextStyle(
                            color: Colors.white,
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
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
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
                  color: Colors.black.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    'הועלה על ידי ${widget.images[_currentIndex].author}'
                    '${_dateText(widget.images[_currentIndex].date).isNotEmpty ? ' בתאריך ${_dateText(widget.images[_currentIndex].date)}' : ''}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
