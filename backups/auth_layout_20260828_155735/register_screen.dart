import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/auth_service.dart';
import '../../../theme/colors.dart';

class RegisterScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;

  const RegisterScreen({
    super.key,
    this.onAuthSuccess,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _referralCodeController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;
  String? _message;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _saveReferralCodeForLater(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_referral_code', trimmed);
  }

  Future<void> _applyReferralCodeIfPossible(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;

    final user = _authService.currentUser;
    if (user == null || user.isAnonymous) {
      await _saveReferralCodeForLater(trimmed);
      return;
    }

    try {
      await Supabase.instance.client.rpc(
        'apply_referral_code',
        params: {'p_referral_code': trimmed},
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_referral_code');
    } catch (_) {
      // Referral code must never block registration.
    }
  }

  Future<void> _registerWithGoogle() async {
    if (_loading) return;

    final referralCode = _referralCodeController.text.trim();
    if (referralCode.isNotEmpty) {
      await _saveReferralCodeForLater(referralCode);
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      await _authService.signInWithGoogle();
      await _applyReferralCodeIfPossible(referralCode);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'ההרשמה עם Google נכשלה';
      });
    }
  }

  Future<void> _registerWithApple() async {
    if (_loading) return;

    final referralCode = _referralCodeController.text.trim();
    if (referralCode.isNotEmpty) {
      await _saveReferralCodeForLater(referralCode);
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      await _authService.signInWithApple();
      await _applyReferralCodeIfPossible(referralCode);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'ההרשמה עם Apple נכשלה';
      });
    }
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final referralCode = _referralCodeController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _error = 'יש להזין כתובת מייל';
        _message = null;
      });
      return;
    }

    if (!email.contains('@')) {
      setState(() {
        _error = 'כתובת המייל אינה תקינה';
        _message = null;
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _error = 'הסיסמה חייבת להכיל לפחות 6 תווים';
        _message = null;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _error = 'הסיסמאות אינן תואמות';
        _message = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      final session = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      if (session == null) {
        setState(() {
          _error = 'כתובת המייל הזו כבר רשומה. נסה להתחבר.';
          _message = null;
        });
        return;
      }

      final user = _authService.currentUser;
      if (user != null) {
        final displayName =
            username.isNotEmpty ? username : email.split('@').first.trim();

        if (displayName.isNotEmpty) {
          await Supabase.instance.client.from('profiles').upsert({
            'id': user.id,
            'display_name': displayName,
          });
        }

        if (referralCode.isNotEmpty) {
          await _applyReferralCodeIfPossible(referralCode);
        }
      } else if (referralCode.isNotEmpty) {
        await _saveReferralCodeForLater(referralCode);
      }

      widget.onAuthSuccess?.call();
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'שגיאת הרשמה: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'שגיאה: $e';
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
        title: const Text('הרשמה'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'יצירת חשבון',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'כתובת המייל תהיה כתובת הכניסה שלך לאפליקציה.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _loading ? null : _registerWithGoogle,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.muted.withValues(alpha: 0.35),
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          'G',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'הרשמה עם Google',
                        style: TextStyle(fontSize: 17),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _loading ? null : _registerWithApple,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.apple,
                        size: 25,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'הרשמה עם Apple',
                        style: TextStyle(fontSize: 17),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'או עם מייל',
                      style: TextStyle(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'כתובת מייל',
                  hintText: 'name@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'סיסמה',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_loading) {
                    _register();
                  }
                },
                decoration: InputDecoration(
                  labelText: 'אימות סיסמה',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'שם משתמש (אופציונלי)',
                  hintText: 'איך תרצה שיופיע שמך?',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referralCodeController,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'קוד הזמנה (אופציונלי)',
                  hintText: 'הזן קוד שקיבלת מחבר',
                  prefixIcon: Icon(Icons.card_giftcard_outlined),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(),
                        )
                      : const Text(
                          'הרשמה',
                          style: TextStyle(fontSize: 17),
                        ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.danger,
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 20),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        Navigator.of(context).pop();
                      },
                child: const Text('כבר יש לי חשבון'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
