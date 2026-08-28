import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';

class AdminCenterScreen extends StatefulWidget {
  const AdminCenterScreen({super.key});

  @override
  State<AdminCenterScreen> createState() => _AdminCenterScreenState();
}

class _AdminCenterScreenState extends State<AdminCenterScreen> {
  final _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await _supabase
          .from('visit_image_reports')
          .select(
            'id, image_id, reporter_id, reason, created_at, '
            'visit_images(id, image_url, visit_id)',
          )
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _reports = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון את הדיווחים: $e';
      });
    }
  }

  String _dateText(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return '';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openImage(String imageUrl) async {
    if (imageUrl.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AdminImagePreview(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'מרכז ניהול',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
        ),
        actions: const [
          HomeButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        color: AppColors.champagne,
        backgroundColor: AppColors.background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.brass,
        ),
      );
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          _MessageCard(
            icon: Icons.error_outline,
            message: _error!,
          ),
        ],
      );
    }

    if (_reports.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          _MessageCard(
            icon: Icons.notifications_none_rounded,
            message: 'אין כרגע פריטים חדשים לטיפול.',
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _SectionHeader(
          icon: Icons.flag_outlined,
          title: 'דיווחים על תמונות',
          count: _reports.length,
        ),
        const SizedBox(height: 12),
        ..._reports.map(_buildReportCard),
      ],
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final imageData = report['visit_images'];

    final image = imageData is Map
        ? Map<String, dynamic>.from(imageData)
        : <String, dynamic>{};

    final imageUrl = image['image_url']?.toString() ?? '';
    final reason = report['reason']?.toString().trim() ?? '';
    final reporterId = report['reporter_id']?.toString() ?? '';
    final createdAt = _dateText(report['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.15),
          width: 0.75,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.035),
            blurRadius: 26,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty) ...[
              GestureDetector(
                onTap: () => _openImage(imageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 110,
                    height: 90,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          color: AppColors.background,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textMuted,
                            size: 26,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.flag_outlined,
                        color: AppColors.champagne.withValues(alpha: 0.80),
                        size: 18,
                      ),
                      const SizedBox(width: 7),
                      const Text(
                        'דיווח על תמונה',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      reason,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'מדווח: $reporterId',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                  if (createdAt.isNotEmpty)
                    Text(
                      createdAt,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.5,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.brass,
          size: 23,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.champagne,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MessageCard({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.line,
          width: 0.7,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.brass,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminImagePreview extends StatelessWidget {
  final String imageUrl;

  const _AdminImagePreview({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return const Icon(
                Icons.broken_image_outlined,
                color: AppColors.muted,
                size: 48,
              );
            },
          ),
        ),
      ),
    );
  }
}
