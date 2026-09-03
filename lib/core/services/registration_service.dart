import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registration is an onboarding step, not a replacement for server-side RLS.
class RegistrationService {
  RegistrationService(this.client);
  final SupabaseClient client;
  static const pendingReferralKey = 'pending_referral_code';
  static final Map<String, Future<void>> _pendingApplications = {};

  static Future<void> captureInvitation(Uri uri) async {
    // OAuth uses ?code= for its authorization code, never an invitation.
    final code = uri.queryParameters['ref'] ??
        uri.queryParameters['referral'] ??
        (uri.scheme == 'fooddiary' ? uri.queryParameters['code'] : null);
    if (code == null || code.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(pendingReferralKey, code.trim());
  }

  Future<Map<String, dynamic>> profile() async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) {
      throw const AuthException('Authentication required');
    }
    return client
        .from('profiles')
        .select('id,display_name,registration_completed,referred_by')
        .eq('id', user.id)
        .single();
  }

  Future<String> pendingCode() async =>
      (await SharedPreferences.getInstance())
          .getString(pendingReferralKey)
          ?.trim() ??
      '';

  Future<void> complete({required String name, required String code}) async {
    // Persist the user's correction (including clearing a linked invitation)
    // before completion, so a later session cannot apply the discarded code.
    final prefs = await SharedPreferences.getInstance();
    if (code.trim().isEmpty) {
      await prefs.remove(pendingReferralKey);
    } else {
      await prefs.setString(pendingReferralKey, code.trim());
    }
    await client.rpc('complete_google_registration', params: {
      'p_display_name': name.trim(),
      'p_referral_code': code.trim(),
    });
    // Completion already succeeded on the server. Storage failure must not
    // make the user register again; server-side referral application is idempotent.
    try {
      await (await SharedPreferences.getInstance()).remove(pendingReferralKey);
    } catch (_) {}
  }

  Future<void> applyPendingReferral() async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous) return;
    if (_pendingApplications.containsKey(user.id)) {
      return _pendingApplications[user.id]!;
    }
    final operation = _applyPending(user.id);
    _pendingApplications[user.id] = operation;
    try {
      await operation;
    } finally {
      _pendingApplications.remove(user.id);
    }
  }

  Future<void> _applyPending(String uid) async {
    try {
      final code = await pendingCode();
      if (code.isEmpty) return;
      final data = await profile();
      // New Google users confirm their invitation on the completion screen.
      if (data['registration_completed'] != true ||
          client.auth.currentUser?.id != uid) {
        return;
      }
      await client
          .rpc('apply_referral_code', params: {'p_referral_code': code});
      if (client.auth.currentUser?.id != uid) return;
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(pendingReferralKey)?.trim() == code) {
        await prefs.remove(pendingReferralKey);
      }
    } catch (_) {
      // Keep the invitation for a retry; referral failures never block login.
    }
  }
}
