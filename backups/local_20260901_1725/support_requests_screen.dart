import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';

const supportCategoryLabels = <String, String>{
  'general': 'פנייה כללית',
  'privacy': 'פרטיות ומידע אישי',
  'terms': 'תנאי שימוש',
  'technical': 'בעיה טכנית',
  'report': 'דיווח על תוכן',
};

const supportStatusLabels = <String, String>{
  'new': 'חדשה',
  'in_progress': 'בטיפול',
  'resolved': 'נענתה',
  'closed': 'נסגרה',
};

class SupportRequestsScreen extends StatefulWidget {
  final String initialCategory;

  const SupportRequestsScreen({
    super.key,
    this.initialCategory = 'general',
  });

  @override
  State<SupportRequestsScreen> createState() => _SupportRequestsScreenState();
}

class _SupportRequestsScreenState extends State<SupportRequestsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  List<Map<String, dynamic>> _requests = [];
  late String _category;
  bool _loading = true;
  bool _submitting = false;
  String? _deletingRequestId;
  String? _error;

  User? get _user => Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _category = supportCategoryLabels.containsKey(widget.initialCategory)
        ? widget.initialCategory
        : 'general';
    _loadRequests();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    final user = _user;
    if (user == null || user.isAnonymous) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final rows = await Supabase.instance.client
          .from('support_requests')
          .select(
            'id, category, subject, message, status, admin_reply, '
            'responded_at, created_at, updated_at',
          )
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _requests = List<Map<String, dynamic>>.from(rows);
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון כרגע את הפניות';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = _user;
    if (user == null || user.isAnonymous) return;

    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.from('support_requests').insert({
        'user_id': user.id,
        'category': _category,
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
      });
      _subjectController.clear();
      _messageController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הפנייה נשלחה להנהלת האפליקציה')),
      );
      await _loadRequests();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שליחת הפנייה נכשלה. נסה שוב מאוחר יותר')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteRequest(Map<String, dynamic> request) async {
    final requestId = request['id']?.toString() ?? '';
    if (requestId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('מחיקת הפנייה'),
        content: const Text(
          'למחוק את הפנייה לצמיתות? לא ניתן לבטל את הפעולה ולא יהיה ניתן לראות את תשובת ההנהלה.',
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

    setState(() => _deletingRequestId = requestId);
    try {
      final deletedRows = await Supabase.instance.client
          .from('support_requests')
          .delete()
          .eq('id', requestId)
          .select('id');
      if (deletedRows.isEmpty) throw StateError('Request was not deleted');
      await _loadRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('הפנייה נמחקה')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן למחוק כרגע את הפנייה')),
      );
    } finally {
      if (mounted) setState(() => _deletingRequestId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('פנייה להנהלה'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final user = _user;
    if (user == null || user.isAnonymous) {
      return ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _panel(
            child: const Column(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.champagne,
                  size: 36,
                ),
                SizedBox(height: 14),
                Text(
                  'יש להתחבר כדי לשלוח פנייה',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'החיבור לחשבון מאפשר להנהלה להשיב לפנייה בתוך האפליקציה ולשמור על פרטיות השיחה.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: AppColors.champagne,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
        children: [
          _panel(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'פנייה חדשה',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'נושא הפנייה'),
                    items: supportCategoryLabels.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: _submitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _category = value);
                            }
                          },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subjectController,
                    enabled: !_submitting,
                    maxLength: 120,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'כותרת'),
                    validator: (value) {
                      final length = value?.trim().length ?? 0;
                      if (length < 3) return 'יש להזין כותרת קצרה וברורה';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageController,
                    enabled: !_submitting,
                    maxLength: 4000,
                    minLines: 5,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      labelText: 'תוכן הפנייה',
                      alignLabelWithHint: true,
                    ),
                    validator: (value) {
                      final length = value?.trim().length ?? 0;
                      if (length < 10) return 'יש לפרט מעט יותר על הפנייה';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(_submitting ? 'שולח…' : 'שליחת פנייה'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'הפניות שלי',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            _errorPanel()
          else if (_requests.isEmpty)
            _panel(
              child: const Text(
                'עדיין לא נשלחו פניות.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
            )
          else
            ..._requests.map(_requestCard),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final requestId = request['id']?.toString() ?? '';
    final status = request['status']?.toString() ?? 'new';
    final reply = request['admin_reply']?.toString().trim();
    final createdAt =
        DateTime.tryParse(request['created_at']?.toString() ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: Text(
                    request['subject']?.toString() ?? '',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${supportCategoryLabels[request['category']] ?? 'פנייה'}${createdAt == null ? '' : ' · ${_formatDate(createdAt)}'}',
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Text(
              request['message']?.toString() ?? '',
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (reply != null && reply.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.champagne.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: AppColors.champagne.withValues(alpha: 0.18),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'תשובת ההנהלה',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.champagne,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reply,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _deletingRequestId == null
                    ? () => _deleteRequest(request)
                    : null,
                icon: _deletingRequestId == requestId
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: const Text('מחיקת הפנייה'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final resolved = status == 'resolved' || status == 'closed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: (resolved ? AppColors.success : AppColors.champagne)
            .withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        supportStatusLabels[status] ?? status,
        style: TextStyle(
          color: resolved ? AppColors.success : AppColors.champagne,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _errorPanel() {
    return _panel(
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Text(
              _error!,
              textAlign: TextAlign.right,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
              onPressed: _loadRequests, child: const Text('ניסיון נוסף')),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.16),
        ),
      ),
      child: child,
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}.${twoDigits(local.month)}.${local.year}';
  }
}
