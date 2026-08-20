import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/authentication/screens/login_screen.dart';
import 'features/authentication/screens/register_screen.dart';
import 'features/authentication/screens/reset_password_screen.dart';
import 'features/authentication/screens/welcome_screen.dart';
import 'screens/category_selection_screen.dart';
import 'theme/app_theme.dart';
import 'utils/permissions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qvqrretduhivnxrquzte.supabase.co',
    publishableKey: 'sb_publishable_sUSiHvHBVYZBsNDwHz49_A_QJ2vzDMP',
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await Permissions.load();

  runApp(const FoodDiaryApp());
}

class FoodDiaryApp extends StatelessWidget {
  const FoodDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Food Diary',
      theme: AppTheme.light,
      locale: const Locale('he', 'IL'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;

  Session? _session;
  Future<void>? _permissionsFuture;
  String? _permissionsUserId;
  bool _isPasswordRecovery = false;
  bool _checkingWebAuthCallback = true;

  @override
  void initState() {
    super.initState();

    _session = Supabase.instance.client.auth.currentSession;

    _handleWebAuthCallback();
    _handleReferralLink();

    debugPrint(
      'AUTH GATE INIT: session = ${_session != null}, '
      'user = ${_session?.user.id}',
    );

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (!mounted) return;

      debugPrint(
        'AUTH EVENT: ${state.event}, '
        'session = ${state.session != null}, '
        'user = ${state.session?.user.id}',
      );

      if (state.event == AuthChangeEvent.passwordRecovery) {
        setState(() {
          _session = state.session;
          _isPasswordRecovery = true;
        });
        return;
      }

      _updateSession(state.session);

      // לאחר התחברות OAuth, נסה להחיל קוד הזמנה שנשמר לפני ההפניה.
      if (state.session != null &&
          !state.session!.user.isAnonymous &&
          (state.event == AuthChangeEvent.signedIn ||
              state.event == AuthChangeEvent.tokenRefreshed)) {
        _applyPendingReferralCode();
      }
    });
  }

  Future<void> _handleWebAuthCallback() async {
    try {
      // Supabase handles the OAuth callback and PKCE exchange on Web.
      // Do not call exchangeCodeForSession() manually here.
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null && mounted) {
        setState(() {
          _session = session;
        });

        debugPrint(
          'AUTH CALLBACK: existing session found, '
          'user=${session.user.id}',
        );
      }
    } catch (e) {
      debugPrint('AUTH CALLBACK ERROR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _checkingWebAuthCallback = false;
        });
      }
    }
  }

  Future<void> _handleReferralLink() async {
    try {
      final uri = Uri.base;

      String? code = uri.queryParameters['ref'] ??
          uri.queryParameters['referral'] ??
          uri.queryParameters['code'];

      // Also support custom app links such as:
      // fooddiary://invite?code=ABC123
      if ((code == null || code.trim().isEmpty) && uri.scheme == 'fooddiary') {
        code = uri.queryParameters['code'] ??
            uri.queryParameters['ref'] ??
            uri.queryParameters['referral'];
      }

      if (code == null || code.trim().isEmpty) return;

      final trimmed = code.trim();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_referral_code', trimmed);

      debugPrint('REFERRAL LINK SAVED: $trimmed');
    } catch (e) {
      debugPrint('REFERRAL LINK ERROR: $e');
    }
  }

  Future<void> _applyPendingReferralCode() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || user.isAnonymous) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString('pending_referral_code')?.trim();

      if (code == null || code.isEmpty) return;

      final result = await Supabase.instance.client.rpc(
        'apply_referral_code',
        params: {'p_referral_code': code},
      );

      debugPrint('REFERRAL APPLY RESULT: $result');

      // Remove it after a successful RPC call.
      await prefs.remove('pending_referral_code');
    } catch (e) {
      debugPrint('REFERRAL APPLY ERROR: $e');
    }
  }

  void _updateSession(Session? session) {
    debugPrint(
      'AUTH GATE: session = ${session != null}, '
      'user = ${session?.user.id}',
    );

    if (!mounted) return;

    setState(() {
      _session = session;

      if (session != null && !session.user.isAnonymous) {
        _applyPendingReferralCode();
      }

      if (session == null || session.user.isAnonymous) {
        _permissionsFuture = null;
        _permissionsUserId = null;
      } else if (_permissionsUserId != session.user.id) {
        _permissionsUserId = session.user.id;
        _permissionsFuture = Permissions.load();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingWebAuthCallback) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final session = _session;

    if (_isPasswordRecovery) {
      return ResetPasswordScreen(
        onCompleted: () {
          final currentSession = Supabase.instance.client.auth.currentSession;

          if (!mounted || currentSession == null) return;

          setState(() {
            _session = currentSession;
            _isPasswordRecovery = false;
            _permissionsFuture = null;
            _permissionsUserId = null;
          });
        },
      );
    }

    if (session == null) {
      return WelcomeScreen(
        onLogin: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LoginScreen(
                onAuthSuccess: () {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        },
        onRegister: () {
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
        },
        onGuest: () async {
          try {
            await Supabase.instance.client.auth.signInAnonymously();
          } catch (_) {
            if (!context.mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('לא ניתן להיכנס כאורח'),
              ),
            );
          }
        },
      );
    }

    if (session.user.isAnonymous) {
      return const CategorySelectionScreen();
    }

    return FutureBuilder<void>(
      key: ValueKey(session.user.id),
      future: _permissionsFuture,
      builder: (context, permissionsSnapshot) {
        if (permissionsSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return const CategorySelectionScreen();
      },
    );
  }
}
