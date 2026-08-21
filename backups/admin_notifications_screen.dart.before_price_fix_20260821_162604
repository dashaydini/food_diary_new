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
          foregroundColor: AppColors.ink,
          title: const Text('התראות'),
          leading: const HomeButton(),
        ),
        body: const Center(
          child: Text(
            'אין גישה',
            style: TextStyle(color: AppColors.ink),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        title: const Text('התראות'),
        leading: const HomeButton(),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _NotificationCategory(
                  icon: Icons.flag_outlined,
                  title: 'דיווחים',
                  count: _reportsCount,
                  onTap: _openReports,
                ),
                const SizedBox(height: 12),
                const _NotificationCategory(
                  icon: Icons.inbox_outlined,
                  title: 'פניות למנהל',
                  count: 0,
                ),
                const SizedBox(height: 12),
                const _NotificationCategory(
                  icon: Icons.more_horiz,
                  title: 'עוד',
                  count: 0,
                ),
              ],
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
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: AppColors.brass,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brass,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: AppColors.background,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
            ],
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
        builder: (_) => _AdminReportDetailsScreen(
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
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text('דיווחים'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.brass,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadReports,
              color: AppColors.brass,
              backgroundColor: AppColors.card,
              child: _reports.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 220),
                        Center(
                          child: Text(
                            'אין דיווחים חדשים',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(18),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 5,
                        mainAxisSpacing: 6,
                        childAspectRatio: 1.12,
                      ),
                      itemCount: _reports.length,
                      itemBuilder: (context, index) {
                        final report = _reports[index];

                        final imageData = report['visit_images'];
                        final image = imageData is Map
                            ? Map<String, dynamic>.from(imageData)
                            : <String, dynamic>{};

                        final imageUrl = image['image_url']?.toString() ?? '';

                        final reason =
                            report['reason']?.toString().trim() ?? '';

                        return Material(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openReport(report),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: imageUrl.isEmpty
                                      ? const Center(
                                          child: Icon(
                                            Icons.image_not_supported_outlined,
                                            color: AppColors.muted,
                                            size: 36,
                                          ),
                                        )
                                      : Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              color: AppColors.muted,
                                              size: 36,
                                            ),
                                          ),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    10,
                                    12,
                                    12,
                                  ),
                                  child: Text(
                                    reason.isEmpty ? 'דיווח ללא סיבה' : reason,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _AdminReportDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> report;
  final Future<void> Function()? onHandled;

  const _AdminReportDetailsScreen({
    required this.report,
    this.onHandled,
  });

  @override
  State<_AdminReportDetailsScreen> createState() =>
      _AdminReportDetailsScreenState();
}

class _AdminReportDetailsScreenState extends State<_AdminReportDetailsScreen> {
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
            'food_price, drink, drink_price, image_url, food_rating, '
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
          _error = 'לא ניתן למצוא את הביקור.';
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
        _error = 'לא ניתן לטעון את הביקור: $e';
      });
    }
  }

  Future<void> _openVisit() async {
    if (_visit == null || _place == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('לא ניתן לפתוח את הביקור כרגע'),
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
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text('טיפול בדיווח'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.brass,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                if (_imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.network(
                        _imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.muted,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'מהות הדיווח',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        reason,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : _openVisit,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('עבור לביקור'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _working ? null : _deleteImage,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('מחק תמונה'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : _deleteReport,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('מחק דיווח'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _working
                        ? null
                        : () => _showMessage(
                              'מערכת ההודעות עדיין לא קיימת באפליקציה.',
                            ),
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('שלח הודעה לבעל התמונה'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _working
                        ? null
                        : () => _showMessage(
                              'מערכת חסימת המשתמשים עדיין לא קיימת באפליקציה.',
                            ),
                    icon: const Icon(Icons.block_outlined),
                    label: const Text('חסום משתמש'),
                  ),
                ),
              ],
            ),
    );
  }
}
