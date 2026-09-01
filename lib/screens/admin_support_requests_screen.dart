import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';
import 'support_requests_screen.dart';

class AdminSupportRequestsScreen extends StatefulWidget {
  const AdminSupportRequestsScreen({super.key});

  @override
  State<AdminSupportRequestsScreen> createState() =>
      _AdminSupportRequestsScreenState();
}

class _AdminSupportRequestsScreenState
    extends State<AdminSupportRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  Map<String, Map<String, dynamic>> _profilesByUserId = {};
  bool _loading = true;
  String? _error;
  String _filter = 'open';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!Permissions.canManageSupport) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('support_requests')
          .select(
            'id, user_id, category, subject, message, status, admin_reply, '
            'responded_by, responded_at, created_at, updated_at',
          )
          .order('created_at', ascending: false);

      final requests = List<Map<String, dynamic>>.from(rows);
      final userIds = requests
          .map((request) => request['user_id']?.toString() ?? '')
          .where((userId) => userId.isNotEmpty)
          .toSet()
          .toList();
      final profilesByUserId = <String, Map<String, dynamic>>{};

      if (userIds.isNotEmpty) {
        try {
          final profileRows = await Supabase.instance.client
              .from('profiles')
              .select('id, display_name')
              .inFilter('id', userIds);
          for (final rawProfile in profileRows) {
            final profile = Map<String, dynamic>.from(rawProfile);
            final userId = profile['id']?.toString() ?? '';
            if (userId.isNotEmpty) profilesByUserId[userId] = profile;
          }
        } catch (_) {
          // The inbox remains usable with a short user ID as a fallback.
        }
      }

      if (!mounted) return;
      setState(() {
        _requests = requests;
        _profilesByUserId = profilesByUserId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון את תיבת הפניות';
      });
    }
  }

  Iterable<Map<String, dynamic>> get _filteredRequests {
    return switch (_filter) {
      'new' => _requests.where((request) => request['status'] == 'new'),
      'closed' => _requests.where(
          (request) =>
              request['status'] == 'resolved' || request['status'] == 'closed',
        ),
      'all' => _requests,
      _ => _requests.where(
          (request) =>
              request['status'] == 'new' || request['status'] == 'in_progress',
        ),
    };
  }

  Future<void> _openRequest(Map<String, dynamic> request) async {
    final userId = request['user_id']?.toString() ?? '';
    final requestWithSender = <String, dynamic>{
      ...request,
      'sender_name': _senderName(userId),
      'sender_short_id': _shortId(userId),
    };
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceRaised,
      builder: (sheetContext) =>
          _SupportRequestSheet(request: requestWithSender),
    );
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (!Permissions.canManageSupport) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('פניות למנהל')),
        body: const Center(child: Text('אין הרשאת גישה')),
      );
    }

    final requests = _filteredRequests.toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('פניות למנהל'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.champagne,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 34),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterChip('open', 'פתוחות'),
                      _filterChip('new', 'חדשות'),
                      _filterChip('closed', 'טופלו'),
                      _filterChip('all', 'הכול'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(36),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    _errorCard()
                  else if (requests.isEmpty)
                    const _EmptySupportRequests()
                  else
                    ...requests.map(_requestCard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final status = request['status']?.toString() ?? 'new';
    final createdAt =
        DateTime.tryParse(request['created_at']?.toString() ?? '');
    final userId = request['user_id']?.toString() ?? '';
    final senderName = _senderName(userId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: () => _openRequest(request),
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: status == 'new'
                    ? AppColors.champagne.withValues(alpha: 0.30)
                    : AppColors.cardBorder,
              ),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Icon(
                  status == 'new'
                      ? Icons.mark_email_unread_outlined
                      : Icons.mail_outline_rounded,
                  color: AppColors.champagne,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        request['subject']?.toString() ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'מאת: $senderName · ${supportCategoryLabels[request['category']] ?? 'פנייה'}${createdAt == null ? '' : ' · ${_formatDate(createdAt)}'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  supportStatusLabels[status] ?? status,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 7),
                const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textMuted,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(onPressed: _load, child: const Text('ניסיון נוסף')),
        ],
      ),
    );
  }

  String _shortId(String value) {
    if (value.length <= 8) return value;
    return value.substring(0, 8);
  }

  String _senderName(String userId) {
    final displayName =
        _profilesByUserId[userId]?['display_name']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final shortId = _shortId(userId);
    return shortId.isEmpty ? 'משתמש לא מזוהה' : 'משתמש $shortId';
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year}';
  }
}

class _SupportRequestSheet extends StatefulWidget {
  final Map<String, dynamic> request;

  const _SupportRequestSheet({required this.request});

  @override
  State<_SupportRequestSheet> createState() => _SupportRequestSheetState();
}

class _SupportRequestSheetState extends State<_SupportRequestSheet> {
  late final TextEditingController _replyController;
  late String _status;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController(
      text: widget.request['admin_reply']?.toString() ?? '',
    );
    _status = widget.request['status']?.toString() ?? 'new';
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final reply = _replyController.text.trim();
    if (reply.isNotEmpty && reply.length < 2) return;

    setState(() => _saving = true);
    try {
      final changes = <String, dynamic>{
        'status': _status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (reply.isNotEmpty) {
        changes.addAll({
          'admin_reply': reply,
          'responded_by': user.id,
          'responded_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      await Supabase.instance.client
          .from('support_requests')
          .update(changes)
          .eq('id', widget.request['id']);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שמירת הטיפול נכשלה')),
      );
    }
  }

  Future<void> _delete() async {
    final requestId = widget.request['id']?.toString() ?? '';
    if (requestId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('מחיקת הפנייה'),
        content: Text(
          'למחוק לצמיתות את הפנייה של ${widget.request['sender_name'] ?? 'המשתמש'}? לא ניתן לבטל את הפעולה.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('מחיקה'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final deletedRows = await Supabase.instance.client
          .from('support_requests')
          .delete()
          .eq('id', requestId)
          .select('id');
      if (deletedRows.isEmpty) throw StateError('Request was not deleted');
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        const SnackBar(content: Text('הפנייה נמחקה')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן למחוק כרגע את הפנייה')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.request['subject']?.toString() ?? '',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'מאת: ${widget.request['sender_name'] ?? 'משתמש לא מזוהה'}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.champagne,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${supportCategoryLabels[widget.request['category']] ?? 'פנייה'} · מזהה ${widget.request['sender_short_id'] ?? ''}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    widget.request['message']?.toString() ?? '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'סטטוס'),
                  items: supportStatusLabels.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: _saving || _deleting
                      ? null
                      : (value) {
                          if (value != null) setState(() => _status = value);
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _replyController,
                  enabled: !_saving && !_deleting,
                  minLines: 4,
                  maxLines: 9,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'תשובה למשתמש',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _saving || _deleting ? null : _delete,
                        icon: _deleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline_rounded),
                        label: Text(_deleting ? 'מוחק…' : 'מחיקה'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _saving || _deleting ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'שומר…' : 'שמירת טיפול'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySupportRequests extends StatelessWidget {
  const _EmptySupportRequests();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_outlined, color: AppColors.champagne, size: 34),
          SizedBox(height: 10),
          Text(
            'אין פניות בתצוגה זו',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
