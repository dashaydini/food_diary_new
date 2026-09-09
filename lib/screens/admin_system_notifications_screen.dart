import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';

class AdminSystemNotificationsScreen extends StatefulWidget {
  const AdminSystemNotificationsScreen({super.key});

  @override
  State<AdminSystemNotificationsScreen> createState() =>
      _AdminSystemNotificationsScreenState();
}

class _AdminSystemNotificationsScreenState
    extends State<AdminSystemNotificationsScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;
  bool _loading = true;
  String _targetUrl = '/';
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final rows = await Supabase.instance.client
          .from('system_notifications')
          .select(
              'id,title,body,target_url,status,recipient_count,sent_count,failed_count,created_at')
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.length < 3 || body.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('יש להזין כותרת ותוכן להודעה')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('שליחת הודעת מערכת'),
        content: const Text(
          'ההודעה תישלח עכשיו לכל המשתמשים שאישרו קבלת התראות. לשלוח?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('שליחה'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _sending = true);
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'send-system-notification',
        body: {
          'title': title,
          'body': body,
          'target_url': _targetUrl,
        },
      );
      final result = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      _titleController.clear();
      _bodyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ההודעה נשלחה ל־${result['sent'] ?? 0} מכשירים (${result['recipients'] ?? 0} משתמשים)',
          ),
        ),
      );
      await _loadHistory();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('שליחת ההודעה נכשלה. נסה שוב.')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _dateText(Object? value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year} · $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (!Permissions.isFullAdmin) {
      return const Scaffold(body: Center(child: Text('אין הרשאת גישה')));
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('הודעות מערכת'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('הודעה חדשה',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _titleController,
                        maxLength: 80,
                        decoration: const InputDecoration(
                          labelText: 'כותרת ההתראה',
                          hintText: 'לדוגמה: עדכון חדש באפליקציה',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _bodyController,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 240,
                        decoration: const InputDecoration(
                          labelText: 'תוכן ההודעה',
                          hintText: 'הודעה קצרה וברורה למשתמשים',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _targetUrl,
                        decoration: const InputDecoration(
                          labelText: 'לאן להגיע בלחיצה על ההתראה?',
                        ),
                        items: const [
                          DropdownMenuItem(value: '/', child: Text('מסך הבית')),
                          DropdownMenuItem(
                            value: '/?open=coupons',
                            child: Text('מסך הקופונים'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _targetUrl = value ?? '/'),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_sending ? 'שולח...' : 'שליחת ההודעה'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text('היסטוריית שליחות',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_history.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('עדיין לא נשלחו הודעות מערכת'),
                  ),
                )
              else
                for (final item in _history)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(
                        item['status'] == 'sent'
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: item['status'] == 'sent'
                            ? Colors.greenAccent
                            : AppColors.danger,
                      ),
                      title: Text(item['title']?.toString() ?? ''),
                      subtitle: Text(
                        '${item['body'] ?? ''}\n${_dateText(item['created_at'])} · נשלחו ${item['sent_count'] ?? 0} · נכשלו ${item['failed_count'] ?? 0}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
