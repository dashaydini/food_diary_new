import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../theme/colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _error = 'יש להזין כתובת מייל';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.sendPasswordResetEmail(email);

      if (!mounted) return;

      setState(() {
        _loading = false;
        _sent = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'לא ניתן לשלוח את מייל איפוס הסיסמה';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('שכחתי סיסמה'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(
                Icons.lock_reset_outlined,
                size: 64,
              ),
              const SizedBox(height: 24),
              const Text(
                'איפוס סיסמה',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'הזן את כתובת המייל שאיתה נרשמת ונשלח אליך קישור לאיפוס הסיסמה.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                onSubmitted: (_) {
                  if (!_loading) {
                    _sendResetEmail();
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'כתובת מייל',
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.danger,
                  ),
                ),
              ],
              if (_sent) ...[
                const SizedBox(height: 24),
                const Text(
                  'שלחנו אליך מייל עם קישור לאיפוס הסיסמה.\n'
                  'בדוק גם את תיקיית הספאם אם המייל לא מופיע.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _sendResetEmail,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(),
                        )
                      : const Text(
                          'שליחת קישור לאיפוס',
                          style: TextStyle(fontSize: 17),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
