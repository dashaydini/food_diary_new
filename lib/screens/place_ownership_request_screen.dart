import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/notification_dispatch_service.dart';
import '../features/authentication/screens/login_screen.dart';
import '../theme/colors.dart';
import '../widgets/home_button.dart';

/// A request for human review, not a grant of place-management permissions.
class PlaceOwnershipRequestScreen extends StatefulWidget {
  final Map<String, dynamic> place;

  const PlaceOwnershipRequestScreen({super.key, required this.place});

  @override
  State<PlaceOwnershipRequestScreen> createState() =>
      _PlaceOwnershipRequestScreenState();
}

class _PlaceOwnershipRequestScreenState
    extends State<PlaceOwnershipRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _proof = TextEditingController();
  String _role = 'בעלים';
  String _verification = 'קישור לאתר או לעמוד העסק הרשמי';
  bool _confirmed = false;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _proof.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'יש למלא את השדה' : null;

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('יש לאשר שהפנייה נשלחת בשם בית העסק'),
      ));
      return;
    }
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final placeId = widget.place['id']?.toString();
    if (user == null || user.isAnonymous || placeId == null) return;

    setState(() => _submitting = true);
    try {
      final placeName = widget.place['name']?.toString().trim() ?? 'מקום';
      final message = [
        'בקשה לניהול כרטיס המקום: $placeName',
        'שם הפונה: ${_name.text.trim()}',
        'תפקיד: $_role',
        'טלפון ליצירת קשר: ${_phone.text.trim()}',
        'דוא״ל עסקי: ${_email.text.trim()}',
        'דרך אימות: $_verification',
        'אסמכתא / פרטי אימות: ${_proof.text.trim()}',
        'הפונה הצהיר/ה שהוא/היא מורשה/ית לפנות בשם העסק.',
      ].join('\n');
      final request = await client
          .from('support_requests')
          .insert({
            'user_id': user.id,
            'place_id': placeId,
            'category': 'place_ownership',
            'subject': 'בקשת בעלות · $placeName',
            'message': message,
          })
          .select('id')
          .single();
      await NotificationDispatchService.send(
        eventType: 'support_request',
        resourceId: request['id'].toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('הבקשה נשלחה. מנהל האפליקציה יבדוק ויצור איתך קשר.'),
      ));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('לא הצלחנו לשלוח את הבקשה. כדאי לנסות שוב.'),
      ));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final signedIn = user != null && !user.isAnonymous;
    final placeName = widget.place['name']?.toString() ?? 'המקום';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('אני הבעלים'),
        centerTitle: true,
        actions: const [HomeButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 36),
            children: [
              Text('בקשת ניהול · $placeName',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'ספר לנו איך אפשר ליצור איתך קשר ולאמת את הקשר שלך לעסק. '
                'ההרשאות לא נפתחות אוטומטית; מנהל יבדוק את הבקשה לפני שיוקצו הרשאות.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              if (!signedIn) ...[
                const Text('כדי לשלוח בקשה יש להתחבר לחשבון.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: const Text('כניסה או הרשמה'),
                ),
              ] else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'שם מלא'),
                        textInputAction: TextInputAction.next,
                        validator: _required,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'הקשר שלך לעסק'),
                        items: const ['בעלים', 'מנהל/ת העסק', 'נציג/ה מורשה/ית']
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _role = value ?? _role),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phone,
                        decoration: const InputDecoration(
                            labelText: 'טלפון ליצירת קשר'),
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        validator: (value) {
                          final digits =
                              (value ?? '').replaceAll(RegExp(r'\D'), '');
                          return digits.length < 9
                              ? 'יש להזין מספר טלפון תקין'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                            labelText: 'דוא״ל ליצירת קשר'),
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        validator: (value) =>
                            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(value?.trim() ?? '')
                                ? null
                                : 'יש להזין כתובת דוא״ל תקינה',
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _verification,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'איך נאמת את הבעלות?'),
                        items: const [
                          'קישור לאתר או לעמוד העסק הרשמי',
                          'שיחה למספר העסק שמפורסם לציבור',
                          'מסמך עסקי ללא פרטים רגישים – בתיאום עם המנהל',
                        ]
                            .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value,
                                    overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (value) => setState(
                            () => _verification = value ?? _verification),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _proof,
                        decoration: const InputDecoration(
                          labelText: 'קישור או פירוט אסמכתא',
                          hintText:
                              'למשל קישור לעמוד העסק או הטלפון שמפורסם בו',
                          alignLabelWithHint: true,
                        ),
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 800,
                        validator: (value) => (value?.trim().length ?? 0) < 8
                            ? 'נדרש פירוט קצר שיאפשר אימות'
                            : null,
                      ),
                      const Text(
                        'אין לשלוח תעודת זהות, פרטי בנק או מידע אישי רגיש. '
                        'אם יידרש מסמך, נתאם דרך בטוחה לשליחתו.',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _confirmed,
                        onChanged: (value) =>
                            setState(() => _confirmed = value ?? false),
                        title: const Text('אני מורשה/ית לפנות בשם העסק'),
                      ),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 17,
                                height: 17,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        label: const Text('שליחת בקשת בעלות'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
