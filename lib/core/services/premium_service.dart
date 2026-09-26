import 'package:supabase_flutter/supabase_flutter.dart';

class PremiumService {
  PremiumService._();

  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Opens Premium for every signed-in account in dedicated Google Play test
  /// builds. Production builds keep this disabled unless the explicit Dart
  /// define is supplied at build time.
  static const bool _playTestingPremium = bool.fromEnvironment(
    'BTW_PLAY_TESTING_PREMIUM',
    defaultValue: false,
  );

  static bool _isPremium = false;
  static bool _isAdmin = false;
  static bool _previewAsFree = false;
  static String? _adminRole;
  static bool _loaded = false;

  static bool get _signedInPlayTester {
    final user = _supabase.auth.currentUser;
    return _playTestingPremium && user != null && !user.isAnonymous;
  }

  static bool get isPremium =>
      (_signedInPlayTester || _isPremium || _isAdmin) && !_previewAsFree;
  static bool get playTestingPremiumEnabled => _playTestingPremium;
  static bool get isAdmin => _isAdmin;
  static bool get previewAsFree => _previewAsFree;
  static String? get adminRole => _adminRole;
  static bool get isLoaded => _loaded;

  static Future<void> load() async {
    final user = _supabase.auth.currentUser;

    _isPremium = false;
    _isAdmin = false;
    _adminRole = null;
    _loaded = true;

    if (user == null || user.isAnonymous) {
      return;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('is_admin, admin_role')
          .eq('id', user.id)
          .maybeSingle();

      _isAdmin = profile?['is_admin'] == true;
      _adminRole = profile?['admin_role']?.toString();

      if (_isAdmin) {
        _isPremium = true;
        return;
      }

      final subscription = await _supabase
          .from('user_subscriptions')
          .select('plan, status, expires_at')
          .eq('user_id', user.id)
          .eq('plan', 'premium')
          .eq('status', 'active')
          .order('expires_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (subscription == null) {
        return;
      }

      final expiresAtValue = subscription['expires_at'];

      if (expiresAtValue == null) {
        _isPremium = true;
        return;
      }

      final expiresAt = DateTime.tryParse(
        expiresAtValue.toString(),
      );

      _isPremium = expiresAt == null || expiresAt.isAfter(DateTime.now());
    } catch (_) {
      _isPremium = false;
    }
  }

  static void clear() {
    _isPremium = false;
    _isAdmin = false;
    _adminRole = null;
    _loaded = false;
    _previewAsFree = false;
  }

  /// Lets an administrator test premium gates without changing account data.
  static void setAdminFreePreview(bool enabled) {
    _previewAsFree = _isAdmin && enabled;
  }

  static Future<bool> refresh() async {
    await load();
    return isPremium;
  }
}
