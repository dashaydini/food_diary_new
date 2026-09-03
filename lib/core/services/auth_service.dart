import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const _localGuestKey = 'local_guest_mode';
  static bool _localGuestMode = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  bool get isGuest => currentUser?.isAnonymous ?? _localGuestMode;

  static bool get isLocalGuest => _localGuestMode;

  static Future<void> initializeGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;

    if (currentUser?.isAnonymous ?? false) {
      _localGuestMode = true;

      try {
        await client.auth.signOut();
      } catch (error) {
        debugPrint('STALE ANONYMOUS SESSION CLEANUP ERROR: $error');
      }

      try {
        await prefs.setBool(_localGuestKey, true);
      } catch (error) {
        debugPrint('LOCAL GUEST PERSISTENCE ERROR: $error');
      }
      return;
    }

    if (currentUser != null) {
      _localGuestMode = false;
      await prefs.remove(_localGuestKey);
      return;
    }

    _localGuestMode = prefs.getBool(_localGuestKey) ?? false;
  }

  static Future<void> clearLocalGuestMode() async {
    _localGuestMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localGuestKey);
  }

  Future<Session?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    await clearLocalGuestMode();
    final response = await _supabase.auth.signUp(
      email: email.trim(),
      password: password,
    );

    debugPrint(
      'SIGN UP: user=${response.user?.id}, session=${response.session != null}, '
      'identities=${response.user?.identities?.length ?? 0}',
    );

    final identities = response.user?.identities ?? [];

    // Supabase can return an apparently successful response for an
    // email that already exists. In that case identities is empty.
    if (identities.isEmpty) {
      return null;
    }

    return response.session;
  }

  Future<void> ensureProfileDisplayName() async {
    final user = _supabase.auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final email = user.email?.trim();
    if (email == null || email.isEmpty) return;

    final response = await _supabase
        .from('profiles')
        .select('display_name')
        .eq('id', user.id)
        .maybeSingle();

    final currentName = response?['display_name']?.toString().trim();

    if (currentName != null && currentName.isNotEmpty) {
      return;
    }

    final fallbackName = email.split('@').first.trim();

    if (fallbackName.isEmpty) return;

    await _supabase.from('profiles').upsert({
      'id': user.id,
      'display_name': fallbackName,
    });
  }

  Future<bool> emailExists(String email) async {
    try {
      final result = await _supabase.rpc(
        'check_email_exists',
        params: {
          'email_to_check': email.trim(),
        },
      );

      debugPrint('CHECK EMAIL EXISTS: $result');
      return result == true;
    } catch (e) {
      debugPrint('CHECK EMAIL EXISTS ERROR: $e');
      rethrow;
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await clearLocalGuestMode();
    await _supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      throw const AuthException('יש להזין כתובת מייל');
    }

    final redirectTo = kIsWeb
        ? '${Uri.base.origin}${Uri.base.path}'
        : 'fooddiary://password-reset';

    await _supabase.auth.resetPasswordForEmail(
      trimmedEmail,
      redirectTo: redirectTo,
    );
  }

  Future<void> updatePassword(String password) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: password),
    );
  }

  Future<void> signInWithGoogle() async {
    await clearLocalGuestMode();
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}${Uri.base.path}'
        : 'fooddiary://login-callback';

    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
      queryParams: {
        'prompt': 'select_account',
      },
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  Future<void> signInWithApple() async {
    await clearLocalGuestMode();
    final redirectTo = kIsWeb
        ? '${Uri.base.origin}${Uri.base.path}'
        : 'fooddiary://login-callback';

    await _supabase.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: redirectTo,
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
  }

  Future<void> signInAsGuest() async {
    _localGuestMode = true;

    if (_supabase.auth.currentSession != null) {
      try {
        await _supabase.auth.signOut();
      } catch (error) {
        // A deleted or expired legacy anonymous session must never block the
        // local, serverless guest experience.
        debugPrint('GUEST SESSION CLEANUP ERROR: $error');
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localGuestKey, true);
    } catch (error) {
      // Persistence is convenient across restarts, but the current guest
      // session can still work entirely in memory.
      debugPrint('LOCAL GUEST PERSISTENCE ERROR: $error');
    }
  }

  Future<void> signOut() async {
    await clearLocalGuestMode();
    await _supabase.auth.signOut();
  }
}
