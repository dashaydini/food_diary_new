import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';
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
              .select('follower_id')
              .eq('following_id', widget.userId)
              .order('created_at', ascending: false)
          : await _client
              .from('user_follows')
              .select('following_id')
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
          .select('id, display_name, email, avatar_url')
          .inFilter('id', ids);

      final profileList = List<Map<String, dynamic>>.from(profiles as List);

      final byId = {
        for (final profile in profileList) profile['id']?.toString(): profile,
      };

      final ordered = <Map<String, dynamic>>[];

      for (final id in ids) {
        final profile = byId[id];
        if (profile != null) {
          ordered.add(profile);
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

  String _name(Map<String, dynamic> user) {
    final displayName = user['display_name']?.toString().trim();

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user['email']?.toString().trim();

    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
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
                              itemCount: _users.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final user = _users[index];
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
                                                    avatar,
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
                                            child: Text(
                                              _name(user),
                                              textAlign: TextAlign.right,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_left_rounded,
                                            size: 20,
                                            color: AppColors.champagne
                                                .withValues(alpha: 0.45),
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
