import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/auth_service.dart';
import '../../../theme/colors.dart';
import '../widgets/auth_brand_hero.dart';
import '../widgets/auth_brand_divider.dart';

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: 'חזרה',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        textDirection: TextDirection.ltr,
                        color: AppColors.champagne,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const AuthBrandHero(),
                  const SizedBox(height: 12),
                  const AuthBrandDivider(),
                  const SizedBox(height: 24),
                  const Text(
                    'יצירת חשבון',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      height: 1.15,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'צור את היומן האישי שלך\nוהתחל לשמור חוויות.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 38),
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.cardBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 50,
                          child: OutlinedButton(
                            onPressed: _loading ? null : _registerWithGoogle,
                            child: const Text(
                              'הרשמה עם Google',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 11),
                        SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _registerWithApple,
                            icon: const Icon(Icons.apple, size: 21),
                            label: const Text(
                              'הרשמה עם Apple',
                              style: TextStyle(fontSize: 15),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'או עם מייל',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 22),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'כתובת מייל',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
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
                        const SizedBox(height: 14),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'אימות סיסמה',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
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
                        const SizedBox(height: 14),
                        TextField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          decoration: const InputDecoration(
                            labelText: 'שם משתמש',
                            hintText: 'אופציונלי',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _referralCodeController,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          textCapitalization: TextCapitalization.characters,
                          onSubmitted: (_) {
                            if (!_loading) _register();
                          },
                          decoration: const InputDecoration(
                            labelText: 'קוד הזמנה',
                            hintText: 'אופציונלי',
                            prefixIcon: Icon(Icons.card_giftcard_outlined),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _loading ? null : _register,
                            child: _loading
                                ? const SizedBox(
                                    width: 21,
                                    height: 21,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'יצירת חשבון',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                        if (_message != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text(
                            'כבר יש לי חשבון',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'DISCOVER  •  TASTE  •  REMEMBER',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 2.4,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
