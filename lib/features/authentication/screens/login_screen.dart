import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/registration_service.dart';
import '../../../screens/category_selection_screen.dart';
import '../../../theme/colors.dart';
import '../../../utils/app_preferences.dart';
import '../widgets/auth_brand_hero.dart';
import '../widgets/auth_brand_divider.dart';
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

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _showRegisterButton = false;
  String? _error;
  StreamSubscription<AuthState>? _authSubscription;
  bool _oauthInProgress = false;
  bool _authCompleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadRememberedEmail();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) {
        final user = state.session?.user;
        if (user == null || user.isAnonymous) return;
        _finishAuthenticatedSession();
      },
    );
  }

  Future<void> _loadRememberedEmail() async {
    final email = await AppPreferences.rememberedLoginEmail();
    if (!mounted || email == null) return;
    setState(() {
      _emailController.text = email;
      _rememberMe = true;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !_oauthInProgress) return;

    // Returning from the browser without a session means the user closed or
    // cancelled Google. Never leave the login button spinning indefinitely.
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || !_oauthInProgress || _authCompleted) return;
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && !user.isAnonymous) {
        _finishAuthenticatedSession();
        return;
      }
      setState(() {
        _oauthInProgress = false;
        _loading = false;
        _error = 'הכניסה עם Google לא הושלמה. אפשר לנסות שוב.';
      });
    });
  }

  void _finishAuthenticatedSession() {
    if (!mounted || _authCompleted) return;
    _authCompleted = true;
    _oauthInProgress = false;

    // The root AuthGate listens to the same event and loads the account.
    // Close this temporary screen immediately; profile/referral work must
    // never keep the user on a spinner.
    unawaited(_authService.ensureProfileDisplayName().catchError((_) {}));
    unawaited(_applyPendingReferralCode().catchError((_) {}));
    widget.onAuthSuccess?.call();
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
      await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      await AppPreferences.setRememberedLoginEmail(
        _rememberMe ? email : null,
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
    await RegistrationService(Supabase.instance.client).applyPendingReferral();
  }

  Future<void> _loginWithGoogle() async {
    await _startOAuth(
      action: _authService.signInWithGoogle,
    );
  }

  Future<void> _startOAuth({
    required Future<void> Function() action,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
      _oauthInProgress = true;
      _authCompleted = false;
    });

    try {
      await action();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _oauthInProgress = false;
        _error = _googleSignInErrorMessage(error);
      });
    }
  }

  String _googleSignInErrorMessage(Object error) {
    final details = error.toString().toLowerCase();
    if (details.contains('service_version_update_required') ||
        details.contains('google play services out of date')) {
      return 'כדי להתחבר עם Google יש לעדכן את שירותי Google Play במכשיר ואז לנסות שוב.';
    }
    if (details.contains('canceled') || details.contains('cancelled')) {
      return 'ההתחברות בוטלה. אפשר לנסות שוב.';
    }
    if (details.contains('clientconfigurationerror') ||
        details.contains('developer_error')) {
      return 'הגדרת ההתחברות עם Google אינה תקינה עדיין. נסה שוב בעוד כמה דקות.';
    }
    return 'ההתחברות עם Google נכשלה. אפשר לנסות שוב.';
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
                    'ברוכים הבאים',
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
                    'התחבר והמשך אל המקומות,\nהחוויות והקהילה שלך.',
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
                            onPressed: _loading ? null : _loginWithGoogle,
                            child: const Text(
                              'התחברות עם Google',
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
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_loading) _loginWithEmail();
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
                        const SizedBox(height: 8),
                        Material(
                          color: Colors.transparent,
                          child: CheckboxListTile(
                            value: _rememberMe,
                            onChanged: _loading
                                ? null
                                : (value) {
                                    setState(() {
                                      _rememberMe = value ?? false;
                                    });
                                  },
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                            title: const Text(
                              'זכור אותי',
                              style: TextStyle(fontSize: 14),
                            ),
                            subtitle: const Text(
                              'כתובת המייל בלבד — הסיסמה אינה נשמרת',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
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
                                        builder: (_) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                            child: const Text(
                              'שכחתי סיסמה',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _loading ? null : _loginWithEmail,
                            child: _loading
                                ? const SizedBox(
                                    width: 21,
                                    height: 21,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'כניסה',
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
                        if (_showRegisterButton) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _loading ? null : _openRegister,
                            child: const Text('יצירת חשבון'),
                          ),
                        ],
                        const SizedBox(height: 13),
                        TextButton(
                          onPressed: _loading ? null : _openRegister,
                          child: const Text(
                            'עדיין אין לך חשבון?  הרשמה',
                          ),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _guestLogin,
                          child: const Text(
                            'המשך כאורח',
                            style: TextStyle(
                              color: AppColors.champagneSoft,
                            ),
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
