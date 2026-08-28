import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';
import 'add_visit_screen.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  int _reportsCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (!Permissions.isAdmin) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from('visit_image_reports')
          .select('id')
          .eq('status', 'new');

      if (!mounted) return;

      setState(() {
        _reportsCount = rows.length;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _reportsCount = 0;
        _loading = false;
      });
    }
  }

  Future<void> _openReports() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _AdminReportsScreen(),
      ),
    );

    if (mounted) {
      _loadCounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Permissions.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: const Text('התראות'),
          actions: const [
            HomeButton(),
          ],
        ),
        body: const Center(
          child: Text(
            'אין גישה',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'התראות',
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.champagne,
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                  children: [
                    _NotificationCategory(
                      icon: Icons.flag_outlined,
                      title: 'דיווחים',
                      count: _reportsCount,
                      onTap: _openReports,
                    ),
                    const SizedBox(height: 11),
                    const _NotificationCategory(
                      icon: Icons.inbox_outlined,
                      title: 'פניות למנהל',
                      count: 0,
                    ),
                    const SizedBox(height: 11),
                    const _NotificationCategory(
                      icon: Icons.more_horiz,
                      title: 'עוד',
                      count: 0,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _NotificationCategory extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback? onTap;

  const _NotificationCategory({
    required this.icon,
    required this.title,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.035),
            blurRadius: 24,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 17,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.15),
                width: 0.75,
              ),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.champagne.withValues(alpha: 0.04),
                    border: Border.all(
                      color: AppColors.champagne.withValues(alpha: 0.14),
                      width: 0.7,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.champagne.withValues(alpha: 0.80),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (count > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.champagne.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.champagne.withValues(alpha: 0.28),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.champagneSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminReportsScreen extends StatefulWidget {
  const _AdminReportsScreen();

  @override
  State<_AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<_AdminReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final rows = await Supabase.instance.client
          .from('visit_image_reports')
          .select(
            'id, image_id, reporter_id, reason, created_at, status, '
            'visit_images(id, image_url, visit_id, user_id)',
          )
          .eq('status', 'new')
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        _reports = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _reports = [];
        _loading = false;
      });
    }
  }

  Future<void> _markHandled(String reportId) async {
    try {
      await Supabase.instance.client
          .from('visit_image_reports')
          .update({'status': 'handled'}).eq('id', reportId);

      if (!mounted) return;

      setState(() {
        _reports.removeWhere(
          (report) => report['id']?.toString() == reportId,
        );
      });
    } catch (_) {}
  }

  Future<void> _openReport(Map<String, dynamic> report) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminReportDetailsScreen(
          report: report,
          onHandled: () => _markHandled(report['id'].toString()),
        ),
      ),
    );

    if (mounted) {
      await _loadReports();
    }
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
        title: const Text(
          'דיווחים',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.champagne,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadReports,
              color: AppColors.champagne,
              backgroundColor: AppColors.background,
              child: _reports.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 180),
                        Center(
                          child: Text(
                            'אין דיווחים חדשים',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;

                        final columns = width >= 1100
                            ? 4
                            : width >= 760
                                ? 3
                                : width >= 520
                                    ? 2
                                    : 1;

                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: columns == 1 ? 1.7 : 1.08,
                              ),
                              itemCount: _reports.length,
                              itemBuilder: (context, index) {
                                final report = _reports[index];

                                final imageData = report['visit_images'];

                                final image = imageData is Map
                                    ? Map<String, dynamic>.from(imageData)
                                    : <String, dynamic>{};

                                final imageUrl =
                                    image['image_url']?.toString() ?? '';

                                final reason =
                                    report['reason']?.toString().trim() ?? '';

                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(17),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.champagne
                                            .withValues(alpha: 0.035),
                                        blurRadius: 24,
                                        spreadRadius: -6,
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(17),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _openReport(report),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(17),
                                          border: Border.all(
                                            color: AppColors.champagne
                                                .withValues(alpha: 0.15),
                                            width: 0.75,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              child: imageUrl.isEmpty
                                                  ? const Center(
                                                      child: Icon(
                                                        Icons
                                                            .image_not_supported_outlined,
                                                        color:
                                                            AppColors.textMuted,
                                                        size: 30,
                                                      ),
                                                    )
                                                  : Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, __, ___) =>
                                                              const Center(
                                                        child: Icon(
                                                          Icons
                                                              .broken_image_outlined,
                                                          color: AppColors
                                                              .textMuted,
                                                          size: 30,
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                12,
                                                9,
                                                12,
                                                11,
                                              ),
                                              child: Text(
                                                reason.isEmpty
                                                    ? 'דיווח ללא סיבה'
                                                    : reason,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class AdminReportDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final Future<void> Function()? onHandled;

  const AdminReportDetailsScreen({
    super.key,
    required this.report,
    this.onHandled,
  });

  @override
  State<AdminReportDetailsScreen> createState() =>
      _AdminReportDetailsScreenState();
}

class _AdminReportDetailsScreenState extends State<AdminReportDetailsScreen> {
  bool _loading = false;
  bool _working = false;
  String? _error;

  Map<String, dynamic>? _visit;
  Map<String, dynamic>? _place;

  SupabaseClient get _client => Supabase.instance.client;

  Map<String, dynamic> get _image {
    final raw = widget.report['visit_images'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return {};
  }

  String get _imageId =>
      widget.report['image_id']?.toString() ?? _image['id']?.toString() ?? '';

  String get _imageUrl =>
      _image['image_url']?.toString() ??
      widget.report['image_url']?.toString() ??
      '';

  String get _visitId =>
      _image['visit_id']?.toString() ??
      widget.report['visit_id']?.toString() ??
      '';

  @override
  void initState() {
    super.initState();
    _loadVisit();
  }

  Future<void> _loadVisit() async {
    if (_visitId.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final visit = await _client
          .from('visits')
          .select(
            'id, place_id, user_id, visit_date, notes, rating, food, '
            'food_price, total_price, price_level, drink, drink_price, image_url, food_rating, '
            'drink_rating, atmosphere_rating, service_rating, '
            'cleanliness_rating, variety_rating, value_rating, created_at, '
            'profiles(display_name, email, avatar_url), '
            'visit_tag_links(tag_id, visit_tags(name, icon)), '
            'visit_images(id, image_url, sort_order)',
          )
          .eq('id', _visitId)
          .maybeSingle();

      if (visit == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'לא ניתן למצוא את החוויה.';
        });
        return;
      }

      final placeId = visit['place_id']?.toString();

      Map<String, dynamic>? place;

      if (placeId != null && placeId.isNotEmpty) {
        final placeRow = await _client
            .from('places')
            .select()
            .eq('id', placeId)
            .maybeSingle();

        if (placeRow != null) {
          place = Map<String, dynamic>.from(placeRow);
        }
      }

      if (!mounted) return;

      setState(() {
        _visit = Map<String, dynamic>.from(visit);
        _place = place;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון את החוויה: $e';
      });
    }
  }

  Future<void> _openVisit() async {
    if (_visit == null || _place == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן לפתוח את החוויה כרגע'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddVisitScreen(
          place: _place!,
          visit: _visit,
          viewOnly: true,
        ),
      ),
    );
  }

  Future<void> _deleteImage() async {
    if (_imageId.isEmpty) {
      _showMessage('לא ניתן לזהות את התמונה');
      return;
    }

    final confirmed = await _confirm(
      title: 'מחיקת תמונה',
      message: 'האם אתה בטוח שברצונך למחוק את התמונה?',
      confirmText: 'מחיקה',
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      await _client.from('visit_images').delete().eq('id', _imageId);

      const marker = '/storage/v1/object/public/visit-images/';
      final markerIndex = _imageUrl.indexOf(marker);

      if (markerIndex != -1) {
        final filePath = _imageUrl.substring(
          markerIndex + marker.length,
        );

        if (filePath.isNotEmpty) {
          try {
            await _client.storage.from('visit-images').remove([filePath]);
          } catch (_) {}
        }
      }

      await _client.from('visit_image_reports').update(
          {'status': 'handled'}).eq('id', widget.report['id'].toString());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('התמונה נמחקה והדיווח טופל')),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _working = false;
        _error = 'לא ניתן למחוק את התמונה: $e';
      });
    }
  }

  Future<void> _deleteReport() async {
    final reportId = widget.report['id']?.toString();

    if (reportId == null || reportId.isEmpty) {
      _showMessage('לא ניתן לזהות את הדיווח');
      return;
    }

    final confirmed = await _confirm(
      title: 'מחיקת דיווח',
      message: 'האם אתה בטוח שברצונך למחוק את הדיווח?',
      confirmText: 'מחיקה',
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _working = true;
      _error = null;
    });

    try {
      debugPrint('DELETE REPORT: $reportId');

      final deleted = await _client
          .from('visit_image_reports')
          .delete()
          .eq('id', reportId)
          .select('id, status, reason');

      debugPrint('DELETE RESULT: $deleted');

      if (deleted.isEmpty) {
        throw Exception(
          'המחיקה לא החזירה רשומה. ID=$reportId',
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('DELETE ERROR: $e');

      if (!mounted) return;

      setState(() {
        _working = false;
        _error = 'לא ניתן למחוק את הדיווח: $e';
      });
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ביטול'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reason =
        widget.report['reason']?.toString().trim() ?? 'דיווח ללא סיבה';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'טיפול בדיווח',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.champagne,
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    if (_imageUrl.isNotEmpty)
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(17),
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: Image.network(
                                _imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.textMuted,
                                    size: 42,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: AppColors.champagne.withValues(alpha: 0.15),
                          width: 0.75,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.champagne.withValues(alpha: 0.03),
                            blurRadius: 24,
                            spreadRadius: -6,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'מהות הדיווח',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reason,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AppColors.danger.withValues(alpha: 0.88),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _openVisit,
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                        ),
                        label: const Text('עבור לחוויה'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _working ? null : _deleteImage,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                        ),
                        label: const Text('מחיקת התמונה'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _working ? null : _deleteReport,
                        icon: const Icon(
                          Icons.flag_outlined,
                          size: 18,
                        ),
                        label: const Text('מחיקת הדיווח בלבד'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _working
                            ? null
                            : () => _showMessage(
                                  'מערכת ההודעות עדיין לא קיימת באפליקציה.',
                                ),
                        icon: const Icon(
                          Icons.mail_outline,
                          size: 18,
                        ),
                        label: const Text('שליחת הודעה לבעל התמונה'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _working
                            ? null
                            : () => _showMessage(
                                  'מערכת חסימת המשתמשים עדיין לא קיימת באפליקציה.',
                                ),
                        icon: const Icon(
                          Icons.block_outlined,
                          size: 18,
                        ),
                        label: const Text('חסימת משתמש'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
