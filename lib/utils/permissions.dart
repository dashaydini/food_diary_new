import 'package:supabase_flutter/supabase_flutter.dart';

class Permissions {
  Permissions._();

  static final _supabase = Supabase.instance.client;

  static String? get currentUserId => _supabase.auth.currentUser?.id;

  static bool _isAdmin = false;

  static bool get isAdmin => _isAdmin;

  static Future<void> load() async {
    final user = _supabase.auth.currentUser;

    if (user == null || user.isAnonymous) {
      _isAdmin = false;
      return;
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();

      _isAdmin = profile?['is_admin'] == true;
    } catch (e) {
      _isAdmin = false;
    }
  }

  static bool canEditPlace(String? ownerId) {
    if (isAdmin) return true;
    return ownerId != null && ownerId == currentUserId;
  }

  static bool canDeletePlace() {
    return isAdmin;
  }

  static bool canEditVisit(String? ownerId) {
    if (isAdmin) return true;
    return ownerId != null && ownerId == currentUserId;
  }

  static bool canDeleteVisit(String? ownerId) {
    if (isAdmin) return true;
    return ownerId != null && ownerId == currentUserId;
  }
}
