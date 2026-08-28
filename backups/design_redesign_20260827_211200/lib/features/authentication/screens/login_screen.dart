import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../screens/category_selection_screen.dart';
import '../../../theme/colors.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;

  const LoginScreen({
    super.key,
    this.onAuthSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _showRegisterButton = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithEmail() async {
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() {
        _error = 'יש להזין כתובת מייל';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _error = 'יש להזין סיסמה';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _showRegisterButton = false;
    });

    try {
      final emailExists = await _authService.emailExists(email);

      if (!emailExists) {
        if (!mounted) return;

        setState(() {
          _loading = false;
          _error = 'משתמש לא רשום';
          _showRegisterButton = true;
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;

      debugPrint('LOGIN EMAIL CHECK ERROR: $e');

      setState(() {
        _loading = false;
        _error = 'לא ניתן לבדוק את המשתמש כרגע';
        _showRegisterButton = false;
      });
      return;
    }

    try {
      await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      await _authService.ensureProfileDisplayName();
      await _applyPendingReferralCode();

      if (!mounted) return;

      widget.onAuthSuccess?.call();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'כתובת המייל או הסיסמה שגויים';
        _showRegisterButton = false;
      });
    }
  }

  Future<void> _applyPendingReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('pending_referral_code')?.trim();

    if (code == null || code.isEmpty) return;

    try {
      final result = await Supabase.instance.client.rpc(
        'apply_referral_code',
        params: {'p_referral_code': code},
      );

      // Whether valid or already used, the pending code should not
      // be attempted again on every login.
      if (result is bool) {
        await prefs.remove('pending_referral_code');
      }
    } catch (_) {
      // Referral handling must never block login.
    }
  }

  Future<void> _loginWithGoogle() async {
    await _startOAuth(
      action: _authService.signInWithGoogle,
    );
  }

  Future<void> _loginWithApple() async {
    await _startOAuth(
      action: _authService.signInWithApple,
    );
  }

  Future<void> _startOAuth({
    required Future<void> Function() action,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await action();
      await _applyPendingReferralCode();

      if (!mounted) return;

      widget.onAuthSuccess?.call();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'ההתחברות נכשלה';
      });
    }
  }

  Future<void> _guestLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.signInAsGuest();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const CategorySelectionScreen(),
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'לא ניתן להיכנס כאורח';
      });
    }
  }

  void _openRegister() {
    if (_loading) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          onAuthSuccess: () {
            if (!mounted) return;
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('כניסה'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'ברוכים הבאים',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'התחבר כדי להמשיך ל־Food Diary',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _loginWithGoogle,
                  child: const Text(
                    'התחברות עם Google',
                    style: TextStyle(fontSize: 17),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _loading ? null : _loginWithApple,
                  child: const Text(
                    'התחברות עם Apple',
                    style: TextStyle(fontSize: 17),
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
              const SizedBox(height: 24),
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
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_loading) {
                    _loginWithEmail();
                  }
                },
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
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                  child: const Text('שכחתי סיסמה'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : _loginWithEmail,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(),
                        )
                      : const Text(
                          'כניסה',
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
                    color: Colors.red,
                  ),
                ),
              ],
              if (_showRegisterButton) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _openRegister,
                    child: const Text(
                      'הרשמה',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: _loading ? null : _openRegister,
                child: const Text('פעם ראשונה? הרשמה'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _loading ? null : _guestLogin,
                child: const Text('כניסה כאורח'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
