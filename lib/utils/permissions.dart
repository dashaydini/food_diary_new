import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/premium_service.dart';

class Permissions {
  Permissions._();

  static final _supabase = Supabase.instance.client;

  static String? get currentUserId => _supabase.auth.currentUser?.id;

  static bool get isAdmin => PremiumService.isAdmin;
  static String? get adminRole => PremiumService.adminRole;
  static bool get isFullAdmin => adminRole == 'full_admin';
  static bool get canManageContent =>
      isFullAdmin || adminRole == 'content_admin';
  static bool get canManageUsers => isFullAdmin || adminRole == 'support_admin';

  static Future<void> load() async {
    await PremiumService.load();
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
