import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../utils/supabase_image_url.dart';
import 'compact_gallery_preview.dart';

class PlaceGalleryImage {
  final String id;
  final String imageUrl;
  final String author;
  final DateTime? date;
  final bool isCover;

  const PlaceGalleryImage({
    required this.id,
    required this.imageUrl,
    required this.author,
    required this.date,
    this.isCover = false,
  });
}

void openPlaceImageGallery(
  BuildContext context, {
  required List<PlaceGalleryImage> images,
  int initialIndex = 0,
}) {
  if (images.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _GalleryScreen(
        images: images,
        initialIndex: initialIndex.clamp(0, images.length - 1),
      ),
    ),
  );
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
    _images = List<PlaceGalleryImage>.from(widget.images);
  }

  @override
  void didUpdateWidget(covariant PlaceImageGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrls = oldWidget.images.map((image) => image.imageUrl).join('|');
    final newUrls = widget.images.map((image) => image.imageUrl).join('|');
    if (oldUrls != newUrls) {
      _images = List<PlaceGalleryImage>.from(widget.images);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) {
      return const SizedBox.shrink();
    }

    return CompactGalleryPreview(
      imageUrl: _images.first.imageUrl,
      title: 'גלריית המקום',
      subtitle: 'תמונות שהוסיף המקום',
      imageCount: _images.length,
      onTap: () => _openGallery(context, 0),
    );
  }

  void _openGallery(BuildContext context, int initialIndex) {
    openPlaceImageGallery(
      context,
      images: _images,
      initialIndex: initialIndex,
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
                      optimizedSupabaseImageUrl(
                        image.imageUrl,
                        width: 1600,
                        quality: 78,
                        resize: 'contain',
                      ),
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

            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Tooltip(
                    message: 'סגירה',
                    child: IconButton.filled(
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.background.withValues(alpha: 0.94),
                        foregroundColor: AppColors.champagne,
                        side: BorderSide(
                          color: AppColors.champagne.withValues(alpha: 0.45),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 24),
                    ),
                  ),
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
                    widget.images[_currentIndex].isCover
                        ? 'תמונת השער של המקום'
                        : 'הועלה על ידי ${widget.images[_currentIndex].author}'
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
