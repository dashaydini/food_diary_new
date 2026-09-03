import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/registration_service.dart';
import '../../../theme/colors.dart';

class CompleteRegistrationScreen extends StatefulWidget {
  const CompleteRegistrationScreen(
      {super.key, required this.profile, required this.onCompleted});
  final Map<String, dynamic> profile;
  final VoidCallback onCompleted;

  @override
  State<CompleteRegistrationScreen> createState() =>
      _CompleteRegistrationScreenState();
}

class _CompleteRegistrationScreenState
    extends State<CompleteRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
      text: widget.profile['display_name']?.toString() ?? '');
  final _code = TextEditingController();
  final _service = RegistrationService(Supabase.instance.client);
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCode();
  }

  Future<void> _loadCode() async {
    try {
      final code = await _service.pendingCode();
      if (mounted) _code.text = code;
    } catch (_) {
      // Manual invitation entry remains available if local storage is unavailable.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _loading || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.complete(name: _name.text, code: _code.text);
      if (mounted) widget.onCompleted();
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(() => _error = error.code == '22023'
            ? 'קוד ההזמנה אינו תקין. אפשר לתקן אותו או להסיר אותו ולהמשיך.'
            : 'לא ניתן להשלים את ההרשמה כרגע. נסה שוב.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'לא ניתן להשלים את ההרשמה כרגע. נסה שוב.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (mounted) setState(() => _error = 'לא ניתן להתנתק כרגע. נסה שוב.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const Text('השלמת הרשמה')),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                  key: _form,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.person_add_alt_1_outlined,
                            size: 40, color: AppColors.champagne),
                        const SizedBox(height: 20),
                        const Text('ברוכים הבאים ל־BITE THE WAY',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        const Text(
                            'ההתחברות עם Google הצליחה. כדי להיכנס לאפליקציה, יש להשלים הרשמה קצרה — אין צורך בסיסמה נוספת.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        TextFormField(
                            controller: _name,
                            enabled: !_saving,
                            textInputAction: TextInputAction.next,
                            maxLength: 60,
                            decoration: const InputDecoration(
                                labelText: 'שם לתצוגה',
                                helperText:
                                    'השם שיופיע לצד החוויות והתגובות שלך'),
                            validator: (value) =>
                                (value?.trim().length ?? 0) < 2
                                    ? 'יש להזין שם באורך שני תווים לפחות'
                                    : null),
                        const SizedBox(height: 16),
                        TextFormField(
                            controller: _code,
                            enabled: !_loading && !_saving,
                            autocorrect: false,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                                labelText: 'קוד הזמנה (אופציונלי)',
                                helperText:
                                    'קיבלת הזמנה מחבר? הקוד יקשר את ההצטרפות שלך אליו.'),
                            onFieldSubmitted: (_) => _save()),
                        const SizedBox(height: 24),
                        if (_error != null) ...[
                          Text(_error!,
                              style: const TextStyle(color: AppColors.danger)),
                          const SizedBox(height: 16),
                        ],
                        FilledButton(
                            onPressed: _saving || _loading ? null : _save,
                            child: Text(
                                _saving ? 'שומר...' : 'סיום הרשמה וכניסה')),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: _saving ? null : _signOut,
                            child: const Text('התנתקות')),
                      ])),
            ),
          ))),
        ),
      );
}
