import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';

class VisitImageGalleryImage {
  final String id;
  final String imageUrl;
  final String author;
  final DateTime? date;

  const VisitImageGalleryImage({
    required this.id,
    required this.imageUrl,
    required this.author,
    required this.date,
  });
}

class VisitImageGallery extends StatefulWidget {
  final List<VisitImageGalleryImage> images;

  const VisitImageGallery({
    super.key,
    required this.images,
  });

  @override
  State<VisitImageGallery> createState() => _VisitImageGalleryState();
}

class _VisitImageGalleryState extends State<VisitImageGallery> {
  late final List<VisitImageGalleryImage> _images;

  @override
  void initState() {
    super.initState();
    _images = List<VisitImageGalleryImage>.from(widget.images);
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: _images.length,
        separatorBuilder: (_, __) => SizedBox(width: 10),
        itemBuilder: (context, index) {
          final image = _images[index];

          return GestureDetector(
            onTap: () => _openGallery(context, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 118,
                height: 96,
                child: Image.network(
                  image.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      color: AppColors.background,
                      alignment: Alignment.center,
                      child: Icon(
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
        builder: (_) => _VisitGalleryScreen(
          images: _images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _VisitGalleryScreen extends StatefulWidget {
  final List<VisitImageGalleryImage> images;
  final int initialIndex;

  const _VisitGalleryScreen({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_VisitGalleryScreen> createState() => _VisitGalleryScreenState();
}

class _VisitGalleryScreenState extends State<_VisitGalleryScreen> {
  static const int _loopSize = 100000;

  late final PageController _controller;
  late int _currentIndex;

  int get _count => widget.images.length;

  @override
  void initState() {
    super.initState();

    final middle = _loopSize ~/ 2;
    final initialPage = middle - (middle % _count) + widget.initialIndex;

    _currentIndex = widget.initialIndex;

    _controller = PageController(
      initialPage: initialPage,
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
    final image = widget.images[_currentIndex];
    final dateText = _dateText(image.date);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: _loopSize,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index % _count;
                });
              },
              itemBuilder: (context, index) {
                final realIndex = index % _count;

                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.network(
                      widget.images[realIndex].imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) {
                        return Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.muted,
                          size: 48,
                        );
                      },
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
                    color: Colors.white.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / $_count',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

            // סגירה
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: EdgeInsets.all(9),
                    child: Icon(
                      Icons.close,
                      color: AppColors.textPrimary,
                      size: 25,
                    ),
                  ),
                ),
              ),
            ),

            // דיווח
            Positioned(
              top: 10,
              left: 10,
              child: Material(
                color: Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _reportImage(context, image),
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
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                        SizedBox(width: 7),
                        Text(
                          'דיווח',
                          style: TextStyle(
                            color: AppColors.textPrimary,
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

            // פרטי התמונה
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
                  color: Colors.white.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    'הועלה על ידי ${image.author}'
                    '${dateText.isNotEmpty ? ' בתאריך $dateText' : ''}',
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
                    backgroundColor: AppColors.muted.withValues(alpha: 0.38),
                    child: IconButton(
                      icon: Icon(Icons.arrow_forward_ios,
                          color: AppColors.textPrimary, size: 20),
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
                    backgroundColor: AppColors.muted.withValues(alpha: 0.38),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new,
                          color: AppColors.textPrimary, size: 20),
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

  Future<void> _reportImage(
    BuildContext context,
    VisitImageGalleryImage image,
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
            title: Text('דיווח על תמונה'),
            content: Text(
              'בחר את הסיבה לדיווח:',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: Text('ביטול'),
              ),
              ListTile(
                leading: Icon(Icons.report_outlined),
                title: Text('תוכן לא הולם'),
                onTap: () {
                  Navigator.of(dialogContext).pop('תוכן לא הולם');
                },
              ),
              ListTile(
                leading: Icon(Icons.place_outlined),
                title: Text('התמונה אינה קשורה למקום'),
                onTap: () {
                  Navigator.of(dialogContext).pop('התמונה אינה קשורה למקום');
                },
              ),
              ListTile(
                leading: Icon(Icons.warning_amber_outlined),
                title: Text('תמונה פוגענית'),
                onTap: () {
                  Navigator.of(dialogContext).pop('תמונה פוגענית');
                },
              ),
              ListTile(
                leading: Icon(Icons.copyright_outlined),
                title: Text('זכויות יוצרים'),
                onTap: () {
                  Navigator.of(dialogContext).pop('זכויות יוצרים');
                },
              ),
              ListTile(
                leading: Icon(Icons.more_horiz),
                title: Text('אחר'),
                onTap: () {
                  Navigator.of(dialogContext).pop('אחר');
                },
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
}
