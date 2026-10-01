import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../core/services/premium_service.dart';
import '../utils/supabase_image_url.dart';
import '../widgets/home_button.dart';
import '../widgets/premium_preview_dialog.dart';
import 'public_profile_screen.dart';

class FollowersListScreen extends StatefulWidget {
  final String userId;
  final bool showFollowers;

  const FollowersListScreen({
    super.key,
    required this.userId,
    required this.showFollowers,
  });

  @override
  State<FollowersListScreen> createState() => _FollowersListScreenState();
}

class _FollowersListScreenState extends State<FollowersListScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  final Set<String> _notificationWorking = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = widget.showFollowers
          ? await _client
              .from('user_follows')
              .select('follower_id, status')
              .eq('following_id', widget.userId)
              .order('created_at', ascending: false)
          : await _client
              .from('user_follows')
              .select('following_id, status')
              .eq('follower_id', widget.userId)
              .order('created_at', ascending: false);

      final ids = (rows as List)
          .map(
            (row) => row[widget.showFollowers ? 'follower_id' : 'following_id']
                ?.toString(),
          )
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (ids.isEmpty) {
        if (!mounted) return;

        setState(() {
          _users = [];
          _loading = false;
        });
        return;
      }

      final profiles = await _client
          .from('profiles')
          .select('id, display_name, avatar_url')
          .inFilter('id', ids);

      final profileList = List<Map<String, dynamic>>.from(profiles as List);

      final currentUserId = _client.auth.currentUser?.id;
      final ownFollows = currentUserId == null
          ? const <dynamic>[]
          : await _client
              .from('user_follows')
              .select('following_id, notify_on_new_experience, status')
              .eq('follower_id', currentUserId)
              .eq('status', 'accepted')
              .inFilter('following_id', ids);
      final followByUserId = {
        for (final row in ownFollows) row['following_id']?.toString(): row,
      };

      final byId = {
        for (final profile in profileList) profile['id']?.toString(): profile,
      };

      final ordered = <Map<String, dynamic>>[];

      for (final id in ids) {
        final profile = byId[id];
        if (profile != null) {
          final follow = followByUserId[id];
          final sourceRow = rows.firstWhere(
            (row) =>
                row[widget.showFollowers ? 'follower_id' : 'following_id']
                    ?.toString() ==
                id,
          ) as Map;
          ordered.add({
            ...profile,
            '_follow_status': sourceRow['status']?.toString() ?? 'accepted',
            '_is_following': follow != null,
            '_notify_on_new_experience':
                follow?['notify_on_new_experience'] == true,
          });
        }
      }

      if (!mounted) return;

      setState(() {
        _users = ordered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון את הרשימה: $e';
      });
    }
  }

  Future<void> _toggleNotifications(Map<String, dynamic> user) async {
    final userId = user['id']?.toString();
    if (userId == null ||
        userId.isEmpty ||
        _notificationWorking.contains(userId)) {
      return;
    }
    final nextValue = user['_notify_on_new_experience'] != true;
    setState(() => _notificationWorking.add(userId));
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) throw StateError('login_required');
      final updated = await _client
          .from('user_follows')
          .update({'notify_on_new_experience': nextValue})
          .eq('follower_id', currentUserId)
          .eq('following_id', userId)
          .select('following_id')
          .maybeSingle();
      if (updated == null) throw StateError('follow_not_found');
      if (!mounted) return;
      setState(() {
        user['_notify_on_new_experience'] = nextValue;
        _notificationWorking.remove(userId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextValue
              ? 'התראות מ${_name(user)} הופעלו'
              : 'התראות מ${_name(user)} כובו'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _notificationWorking.remove(userId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן לעדכן את ההתראה כרגע')),
      );
    }
  }

  Future<void> _openProfile(String userId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PublicProfileScreen(
          userId: userId,
        ),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  bool get _isOwner => _client.auth.currentUser?.id == widget.userId;

  Future<bool> _ensurePremiumForFollowerManagement() async {
    await PremiumService.refresh();
    if (PremiumService.isPremium) return true;
    if (!mounted) return false;
    final action = await showPremiumRequiredDialog(
      context,
      featureName: 'ניהול עוקבים',
      benefit:
          'עם Premium אפשר להסיר עוקבים לא רצויים או לחסום משתמשים מלשלוח בקשות מעקב חדשות.',
    );
    if (action == PremiumPreviewAction.upgrade && mounted) {
      await openPremiumUpgrade(context, sourceFeature: 'follower_management');
      await PremiumService.refresh();
    }
    return PremiumService.isPremium;
  }

  Future<void> _manageFollower(Map<String, dynamic> user, String action) async {
    final userId = user['id']?.toString();
    if (userId == null || userId.isEmpty) return;
    final pending = user['_follow_status'] == 'pending';

    if (action == 'approve' || action == 'decline') {
      try {
        await _client.rpc(
          'respond_to_follow_request',
          params: {'p_follower_id': userId, 'p_accept': action == 'approve'},
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(action == 'approve'
                  ? 'בקשת המעקב אושרה'
                  : 'בקשת המעקב נדחתה')),
        );
        await _load();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('לא ניתן לעדכן את בקשת המעקב כרגע')),
          );
        }
      }
      return;
    }

    if (!await _ensurePremiumForFollowerManagement()) return;
    if (!mounted) return;
    final isBlock = action == 'block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
            isBlock ? 'לחסום את ${_name(user)}?' : 'להסיר את ${_name(user)}?'),
        content: Text(isBlock
            ? 'המשתמש לא יוכל לעקוב אחריך או לשלוח בקשת מעקב חדשה.'
            : pending
                ? 'בקשת המעקב תוסר.'
                : 'המשתמש יוסר מרשימת העוקבים שלך.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isBlock ? 'חסימה' : 'הסרה'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _client.rpc(
        isBlock ? 'block_user' : 'remove_follower',
        params: {isBlock ? 'p_blocked_id' : 'p_follower_id': userId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isBlock ? 'המשתמש נחסם' : 'המשתמש הוסר')),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא ניתן להשלים את הפעולה כרגע')),
        );
      }
    }
  }

  String _name(Map<String, dynamic> user) {
    final displayName = user['display_name']?.toString().trim();

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return 'משתמש';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.showFollowers ? 'עוקבים' : 'נעקבים';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: const [
          HomeButton(),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.champagne,
              ),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.champagne,
                  backgroundColor: AppColors.background,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _users.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                const SizedBox(height: 180),
                                Center(
                                  child: Text(
                                    widget.showFollowers
                                        ? 'עדיין אין עוקבים'
                                        : 'עדיין אינך עוקב אחרי משתמשים',
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                32,
                              ),
                              itemCount: _users.length + 1,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.champagne
                                          .withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.champagne
                                            .withValues(alpha: 0.13),
                                      ),
                                    ),
                                    child: const Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        Icon(
                                          Icons.notifications_none_rounded,
                                          color: AppColors.champagne,
                                          size: 20,
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'הפעמון מאפשר לבחור ממי לקבל התראה על חוויות ציבוריות חדשות. לקבלת פוש יש להפעיל התראות בהגדרות.',
                                            textAlign: TextAlign.right,
                                            style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                final user = _users[index - 1];
                                final id = user['id']?.toString() ?? '';
                                final avatar =
                                    user['avatar_url']?.toString().trim();

                                return Material(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(17),
                                  child: InkWell(
                                    onTap: id.isEmpty
                                        ? null
                                        : () => _openProfile(id),
                                    borderRadius: BorderRadius.circular(17),
                                    child: Container(
                                      padding: const EdgeInsets.all(13),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(17),
                                        border: Border.all(
                                          color: AppColors.champagne
                                              .withValues(alpha: 0.14),
                                          width: 0.75,
                                        ),
                                      ),
                                      child: Row(
                                        textDirection: TextDirection.rtl,
                                        children: [
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.champagne
                                                    .withValues(
                                                  alpha: 0.24,
                                                ),
                                                width: 0.8,
                                              ),
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: avatar != null &&
                                                    avatar.isNotEmpty
                                                ? Image.network(
                                                    optimizedSupabaseImageUrl(
                                                      avatar,
                                                      width: 160,
                                                      height: 160,
                                                    ),
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            const Icon(
                                                      Icons
                                                          .person_outline_rounded,
                                                      color:
                                                          AppColors.champagne,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons
                                                        .person_outline_rounded,
                                                    color: AppColors.champagne,
                                                  ),
                                          ),
                                          const SizedBox(width: 13),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _name(user),
                                                  textAlign: TextAlign.right,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color:
                                                        AppColors.textPrimary,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (widget.showFollowers &&
                                                    _isOwner &&
                                                    user['_follow_status'] ==
                                                        'pending')
                                                  const Padding(
                                                    padding:
                                                        EdgeInsets.only(top: 3),
                                                    child: Text(
                                                      'בקשת מעקב ממתינה לאישורך',
                                                      style: TextStyle(
                                                        color:
                                                            AppColors.champagne,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          if (widget.showFollowers && _isOwner)
                                            PopupMenuButton<String>(
                                              tooltip: 'ניהול עוקב',
                                              onSelected: (action) =>
                                                  _manageFollower(user, action),
                                              itemBuilder: (_) => [
                                                if (user['_follow_status'] ==
                                                    'pending') ...[
                                                  const PopupMenuItem(
                                                    value: 'approve',
                                                    child: Text('אישור בקשה'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'decline',
                                                    child: Text('דחיית בקשה'),
                                                  ),
                                                ] else
                                                  const PopupMenuItem(
                                                    value: 'remove',
                                                    child: Text('הסרה מעוקבים'),
                                                  ),
                                                const PopupMenuItem(
                                                  value: 'block',
                                                  child: Text('חסימה'),
                                                ),
                                              ],
                                              icon: const Icon(
                                                Icons.more_vert_rounded,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          if (!widget.showFollowers &&
                                              user['_is_following'] == true)
                                            Tooltip(
                                              message:
                                                  user['_notify_on_new_experience'] ==
                                                          true
                                                      ? 'כיבוי התראות'
                                                      : 'קבלת התראות',
                                              child: IconButton(
                                                onPressed: _notificationWorking
                                                        .contains(id)
                                                    ? null
                                                    : () =>
                                                        _toggleNotifications(
                                                          user,
                                                        ),
                                                icon: _notificationWorking
                                                        .contains(id)
                                                    ? const SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 1.3,
                                                          color: AppColors
                                                              .champagne,
                                                        ),
                                                      )
                                                    : Icon(
                                                        user['_notify_on_new_experience'] ==
                                                                true
                                                            ? Icons
                                                                .notifications_active_rounded
                                                            : Icons
                                                                .notifications_none_rounded,
                                                        size: 21,
                                                        color: user['_notify_on_new_experience'] ==
                                                                true
                                                            ? AppColors
                                                                .champagne
                                                            : AppColors
                                                                .textMuted,
                                                      ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ),
    );
  }
}
