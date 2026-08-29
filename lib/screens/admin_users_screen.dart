import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  String? _busyUserId;
  String _accountFilter = 'all';
  String? _callerRole;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (!Permissions.canManageUsers) {
      setState(() {
        _loading = false;
        _error = 'אין הרשאת גישה';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'admin-users',
        body: {'action': 'list'},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final rawUsers = data['users'] as List? ?? const [];

      if (!mounted) return;
      setState(() {
        _users = rawUsers
            .whereType<Map>()
            .map((user) => Map<String, dynamic>.from(user))
            .toList();
        _callerRole = data['caller_role']?.toString();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון את המשתמשים: $error';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _users.where((user) {
      final name = user['display_name']?.toString().toLowerCase() ?? '';
      final email = user['email']?.toString().toLowerCase() ?? '';
      final matchesQuery =
          query.isEmpty || name.contains(query) || email.contains(query);
      final premium = user['is_premium'] == true;
      final admin = user['is_admin'] == true;
      final matchesType = switch (_accountFilter) {
        'free' => !premium,
        'premium' => premium,
        'admin' => admin,
        _ => true,
      };
      return matchesQuery && matchesType;
    }).toList();
  }

  bool get _isFullAdmin => _callerRole == 'full_admin';

  bool _isBlocked(Map<String, dynamic> user) {
    final date = DateTime.tryParse(user['banned_until']?.toString() ?? '');
    return date != null && date.isAfter(DateTime.now());
  }

  bool _isActive(Map<String, dynamic> user) {
    final lastSignIn =
        DateTime.tryParse(user['last_sign_in_at']?.toString() ?? '');
    return lastSignIn != null &&
        lastSignIn.isAfter(DateTime.now().subtract(const Duration(days: 30)));
  }

  String _dateText(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'לא ידוע';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Future<void> _runAction(
    Map<String, dynamic> user,
    String action, {
    String? banDuration,
    String? banLabel,
  }) async {
    final userId = user['id']?.toString();
    if (userId == null) return;

    final destructive = action == 'delete';
    final blocked = _isBlocked(user);
    final name = user['display_name']?.toString().trim();
    final displayName = name?.isNotEmpty == true
        ? name!
        : user['email']?.toString() ?? 'המשתמש';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          destructive
              ? 'מחיקת משתמש'
              : blocked
                  ? 'שחרור חסימה'
                  : 'חסימת משתמש',
        ),
        content: Text(
          destructive
              ? 'למחוק לצמיתות את $displayName? לא ניתן לבטל פעולה זו.'
              : blocked
                  ? 'לאפשר ל־$displayName להתחבר שוב?'
                  : 'לחסום את $displayName מהתחברות לאפליקציה${banLabel == null ? '' : ' למשך $banLabel'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(destructive ? 'מחיקה' : 'אישור'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyUserId = userId);
    try {
      await Supabase.instance.client.functions.invoke(
        'admin-users',
        body: {
          'action': action,
          'user_id': userId,
          if (banDuration != null) 'ban_duration': banDuration,
        },
      );
      await _loadUsers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('הפעולה נכשלה: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _chooseBlockDuration(Map<String, dynamic> user) async {
    final selection =
        await showModalBottomSheet<({String value, String label})>(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'משך החסימה',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              for (final option in const [
                (value: '24h', label: '24 שעות'),
                (value: '168h', label: '7 ימים'),
                (value: '720h', label: '30 ימים'),
                (value: '876000h', label: 'ללא הגבלת זמן'),
              ])
                ListTile(
                  leading: const Icon(
                    Icons.block_rounded,
                    color: AppColors.champagne,
                  ),
                  title: Text(option.label, textAlign: TextAlign.right),
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
            ],
          ),
        ),
      ),
    );

    if (selection == null || !mounted) return;
    await _runAction(
      user,
      'block',
      banDuration: selection.value,
      banLabel: selection.label,
    );
  }

  Future<void> _invokeManagementAction(
    Map<String, dynamic> user,
    Map<String, dynamic> body,
  ) async {
    final userId = user['id']?.toString();
    if (userId == null) return;
    setState(() => _busyUserId = userId);
    try {
      await Supabase.instance.client.functions.invoke(
        'admin-users',
        body: {'user_id': userId, ...body},
      );
      await _loadUsers();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('הפעולה נכשלה: $error')),
      );
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  Future<void> _choosePremiumDuration(Map<String, dynamic> user) async {
    final selection = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('גישה לפרימיום', textAlign: TextAlign.right),
            ),
            for (final option in const [
              (value: '7d', label: '7 ימים'),
              (value: '30d', label: '30 ימים'),
              (value: '90d', label: '90 ימים'),
              (value: '365d', label: 'שנה'),
              (value: 'unlimited', label: 'ללא הגבלת זמן'),
              (value: 'remove', label: 'הסרת פרימיום'),
            ])
              ListTile(
                leading: Icon(
                  option.value == 'remove'
                      ? Icons.remove_circle_outline
                      : Icons.workspace_premium_outlined,
                  color: option.value == 'remove'
                      ? AppColors.danger
                      : AppColors.champagne,
                ),
                title: Text(option.label, textAlign: TextAlign.right),
                onTap: () => Navigator.pop(sheetContext, option.value),
              ),
          ],
        ),
      ),
    );
    if (selection == null || !mounted) return;
    await _invokeManagementAction(user, {
      'action': 'set_premium',
      'duration': selection,
    });
  }

  Future<void> _chooseAdminRole(Map<String, dynamic> user) async {
    final role = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('הרשאות ניהול', textAlign: TextAlign.right),
            ),
            for (final option in const [
              (value: 'user', label: 'משתמש רגיל', icon: Icons.person_outline),
              (
                value: 'support_admin',
                label: 'מנהל תמיכה — משתמשים וחסימות',
                icon: Icons.support_agent_outlined,
              ),
              (
                value: 'content_admin',
                label: 'מנהל תוכן — קטגוריות ודיווחים',
                icon: Icons.category_outlined,
              ),
              (
                value: 'full_admin',
                label: 'מנהל מלא — כל ההרשאות',
                icon: Icons.admin_panel_settings_outlined,
              ),
            ])
              ListTile(
                leading: Icon(option.icon, color: AppColors.champagne),
                title: Text(option.label, textAlign: TextAlign.right),
                onTap: () => Navigator.pop(sheetContext, option.value),
              ),
          ],
        ),
      ),
    );
    if (role == null || !mounted) return;
    await _invokeManagementAction(user, {
      'action': 'set_role',
      'role': role,
    });
  }

  String _roleLabel(String? role) => switch (role) {
        'full_admin' => 'מנהל מלא',
        'content_admin' => 'מנהל תוכן',
        'support_admin' => 'מנהל תמיכה',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers;
    final activeCount = _users.where(_isActive).length;
    final premiumCount =
        _users.where((user) => user['is_premium'] == true).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('ניהול משתמשים'),
        actions: const [HomeButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: _loadUsers,
            color: AppColors.champagne,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.champagne,
                    ),
                  )
                : _error != null
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                        ],
                      )
                    : ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryCard(
                                  label: 'פרימיום',
                                  value: '$premiumCount',
                                  icon: Icons.workspace_premium_outlined,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SummaryCard(
                                  label: 'פעילים ב־30 יום',
                                  value: '$activeCount',
                                  icon: Icons.bolt_rounded,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _SummaryCard(
                                  label: 'חשבונות רשומים',
                                  value: '${_users.length}',
                                  icon: Icons.people_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                    value: 'all', label: Text('הכול')),
                                ButtonSegment(
                                    value: 'free', label: Text('חינם')),
                                ButtonSegment(
                                  value: 'premium',
                                  label: Text('פרימיום'),
                                ),
                                ButtonSegment(
                                  value: 'admin',
                                  label: Text('ניהול'),
                                ),
                              ],
                              selected: {_accountFilter},
                              onSelectionChanged: (selection) {
                                setState(
                                    () => _accountFilter = selection.first);
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            textAlign: TextAlign.right,
                            decoration: const InputDecoration(
                              hintText: 'חיפוש לפי שם או אימייל',
                              prefixIcon: Icon(Icons.search_rounded),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (users.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(30),
                              child: Text(
                                'לא נמצאו משתמשים',
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            ...users.map(_buildUserCard),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final id = user['id']?.toString() ?? '';
    final name = user['display_name']?.toString().trim();
    final email = user['email']?.toString() ?? '';
    final blocked = _isBlocked(user);
    final active = _isActive(user);
    final busy = _busyUserId == id;
    final bannedUntil = _dateText(user['banned_until']);
    final premium = user['is_premium'] == true;
    final premiumUntil = user['premium_expires_at'];
    final role = user['admin_role']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: blocked
              ? AppColors.danger.withValues(alpha: 0.34)
              : AppColors.champagne.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.card,
            foregroundColor: AppColors.champagne,
            child: Text(
              (name?.isNotEmpty == true ? name!.characters.first : '?'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  name?.isNotEmpty == true ? name! : 'ללא שם',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _AccountBadge(
                      label: premium
                          ? premiumUntil == null
                              ? 'פרימיום'
                              : 'פרימיום עד ${_dateText(premiumUntil)}'
                          : 'חינם',
                      highlighted: premium,
                    ),
                    if (role != null)
                      _AccountBadge(
                        label: _roleLabel(role),
                        highlighted: true,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  blocked
                      ? 'חסום עד $bannedUntil'
                      : '${active ? 'פעיל' : 'לא פעיל'} · כניסה אחרונה ${_dateText(user['last_sign_in_at'])}',
                  style: TextStyle(
                    color: blocked
                        ? AppColors.danger
                        : active
                            ? AppColors.success
                            : AppColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 1.4),
            )
          else
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'block') {
                  _chooseBlockDuration(user);
                } else if (action == 'premium') {
                  _choosePremiumDuration(user);
                } else if (action == 'role') {
                  _chooseAdminRole(user);
                } else {
                  _runAction(user, action);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: blocked ? 'unblock' : 'block',
                  child: Text(blocked ? 'שחרור חסימה' : 'חסימה'),
                ),
                if (_isFullAdmin) ...[
                  const PopupMenuItem(
                    value: 'premium',
                    child: Text('ניהול פרימיום'),
                  ),
                  const PopupMenuItem(
                    value: 'role',
                    child: Text('הרשאות ניהול'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('מחיקה'),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _AccountBadge extends StatelessWidget {
  final String label;
  final bool highlighted;

  const _AccountBadge({required this.label, required this.highlighted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.champagne.withValues(alpha: 0.09)
            : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              AppColors.champagne.withValues(alpha: highlighted ? 0.22 : 0.09),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlighted ? AppColors.champagneSoft : AppColors.textMuted,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.champagne, size: 20),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
