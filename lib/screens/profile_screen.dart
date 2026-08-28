import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../core/services/auth_service.dart';
import '../features/authentication/screens/login_screen.dart';
import '../theme/colors.dart';
import '../widgets/home_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AuthService _authService = AuthService();

  String? _avatarUrl;
  bool _uploadingAvatar = false;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  int _points = 0;
  int _level = 1;
  String _levelName = 'מתחיל';
  String? _referralCode;
  int _referralCount = 0;

  bool _isGuest = false;
  bool _loggingIn = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'יש להתחבר כדי לצפות בפרופיל';
      });
      return;
    }

    final isGuest = user.isAnonymous;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('display_name, points, level, referral_code, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final displayName = profile?['display_name']?.toString() ?? '';
      final avatarUrl = profile?['avatar_url']?.toString();

      if (isGuest) {
        setState(() {
          _isGuest = true;
          _displayNameController.text = displayName;
          _avatarUrl = avatarUrl;
          _loading = false;
          _error = null;
        });
        return;
      }

      final referralCount = await Supabase.instance.client.rpc(
        'get_referral_count',
        params: {'p_user_id': user.id},
      );

      String levelName = 'מתחיל';

      final points = (profile?['points'] as num?)?.toInt() ?? 0;

      try {
        final result = await Supabase.instance.client.rpc(
          'get_user_level',
          params: {'p_points': points},
        );

        if (result is String && result.trim().isNotEmpty) {
          levelName = result;
        }
      } catch (_) {}

      if (!mounted) return;

      final levelValue = profile?['level'];

      setState(() {
        _isGuest = false;
        _displayNameController.text = displayName;
        _avatarUrl = avatarUrl;

        _points = points;

        _level = levelValue is num
            ? levelValue.toInt()
            : int.tryParse(levelValue?.toString() ?? '') ?? 1;

        _levelName = levelName;
        _referralCode = profile?['referral_code'] as String?;
        _referralCount = (referralCount as num?)?.toInt() ?? 0;

        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'שגיאה בטעינת הפרופיל: $e';
      });
    }
  }

  Future<void> _changeProfileImage() async {
    if (_isGuest || _uploadingAvatar) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('צילום תמונת פרופיל'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('בחירה מהגלריה'),
                onTap: () {
                  Navigator.pop(context, ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    try {
      setState(() {
        _uploadingAvatar = true;
        _error = null;
      });

      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1000,
        maxHeight: 1000,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image == null) {
        if (mounted) {
          setState(() {
            _uploadingAvatar = false;
          });
        }
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;

      if (user == null || user.isAnonymous) {
        throw Exception('משתמש אורח אינו יכול לערוך פרופיל');
      }

      final bytes = await image.readAsBytes();
      final path = '${user.id}/avatar.jpg';

      await Supabase.instance.client.storage.from('avatars').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      final baseUrl =
          Supabase.instance.client.storage.from('avatars').getPublicUrl(path);

      final publicUrl = '$baseUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      await Supabase.instance.client.from('profiles').update({
        'avatar_url': publicUrl,
      }).eq('id', user.id);

      if (!mounted) return;

      setState(() {
        _avatarUrl = publicUrl;
        _uploadingAvatar = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _uploadingAvatar = false;
        _error = 'שגיאה בעדכון תמונת הפרופיל: $e';
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_isGuest) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || user.isAnonymous) return;

    final displayName = _displayNameController.text.trim();

    if (displayName.isEmpty) {
      setState(() {
        _error = 'יש להזין שם משתמש';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.from('profiles').update({
        'display_name': displayName,
      }).eq('id', user.id);

      if (!mounted) return;

      setState(() {
        _saving = false;
        _editing = false;
      });

      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הפרופיל נשמר'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'לא ניתן לשמור את הפרופיל';
      });
    }
  }

  Future<void> _shareReferralCode() async {
    final code = _referralCode?.trim();

    if (code == null || code.isEmpty) return;

    final inviteUrl =
        'https://dashaydini.github.io/food_diary_new/?ref=${Uri.encodeComponent(code)}';

    final text = 'הצטרף אליי ל-Food Diary 👋\n$inviteUrl';

    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: text));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('קישור ההזמנה הועתק ללוח'),
        ),
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(text: text),
    );
  }

  Future<void> _googleLogin() async {
    if (_loggingIn) return;

    setState(() {
      _loggingIn = true;
    });

    try {
      await _authService.signInWithGoogle();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loggingIn = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ההתחברות עם Google נכשלה'),
        ),
      );
    }
  }

  Future<void> _appleLogin() async {
    if (_loggingIn) return;

    setState(() {
      _loggingIn = true;
    });

    try {
      await _authService.signInWithApple();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loggingIn = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ההתחברות עם Apple נכשלה'),
        ),
      );
    }
  }

  Widget _buildAvatar({bool editable = true}) {
    return Center(
      child: GestureDetector(
        onTap: editable ? _changeProfileImage : null,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.background,
                border: Border.all(
                  color: AppColors.champagne.withValues(alpha: 0.22),
                  width: 0.9,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.champagne.withValues(alpha: 0.05),
                    blurRadius: 28,
                    spreadRadius: -5,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: Container(
                  color: AppColors.background,
                  child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                      ? Image.network(
                          _avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Icon(
                              Icons.person_outline_rounded,
                              size: 50,
                              color:
                                  AppColors.textMuted.withValues(alpha: 0.70),
                            );
                          },
                        )
                      : Icon(
                          Icons.person_outline_rounded,
                          size: 50,
                          color: AppColors.textMuted.withValues(alpha: 0.70),
                        ),
                ),
              ),
            ),
            if (editable)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                  border: Border.all(
                    color: AppColors.champagne.withValues(alpha: 0.28),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.champagne.withValues(alpha: 0.04),
                      blurRadius: 12,
                      spreadRadius: -3,
                    ),
                  ],
                ),
                child: _uploadingAvatar
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                        ),
                      )
                    : Icon(
                        Icons.camera_alt_outlined,
                        size: 17,
                        color: AppColors.champagne.withValues(alpha: 0.82),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.16),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.035),
            blurRadius: 26,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.champagne.withValues(alpha: 0.06),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.18),
                width: 0.8,
              ),
            ),
            child: Icon(
              Icons.star_rounded,
              size: 22,
              color: AppColors.champagne.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'נקודות',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$_points',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _levelName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'רמה $_level',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReferralCard() {
    final code = _referralCode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.16),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.03),
            blurRadius: 26,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.group_outlined,
                  size: 21,
                  color: AppColors.champagne.withValues(alpha: 0.78),
                ),
                const SizedBox(width: 9),
                const Text(
                  'חבר מביא חבר',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'הזמן חברים להצטרף לאפליקציה וצבור נקודות.',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: AppColors.champagne.withValues(alpha: 0.11),
                  width: 0.7,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'קוד ההזמנה שלי',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          code ?? 'אין קוד',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: code == null ? null : _shareReferralCode,
                    tooltip: 'שיתוף קוד ההזמנה',
                    icon: Icon(
                      Icons.share_outlined,
                      size: 19,
                      color: AppColors.champagne.withValues(alpha: 0.76),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 18,
                  color: AppColors.textMuted.withValues(alpha: 0.80),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_referralCount ${_referralCount == 1 ? 'חבר הצטרף' : 'חברים הצטרפו'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                mobile ? 16 : 28,
                mobile ? 18 : 24,
                mobile ? 16 : 28,
                32,
              ),
              children: [
                _buildAvatar(editable: false),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.champagne.withValues(alpha: 0.14),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.champagne.withValues(alpha: 0.025),
                        blurRadius: 24,
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: const Text(
                    'בעת חיבור כאורח, ניתן לצפות במקומות וחוויות קיימים. '
                    'אין אפשרות לערוך פרופיל.\n\n'
                    'נא להתחבר עם חשבון Google או Apple על מנת ליהנות '
                    'משאר האפשרויות של היישום.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _loggingIn ? null : _googleLogin,
                    icon: const Icon(
                      Icons.g_mobiledata,
                      size: 28,
                    ),
                    label: const Text(
                      'התחברות עם Google',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _loggingIn ? null : _appleLogin,
                    icon: const Icon(
                      Icons.apple,
                      size: 22,
                    ),
                    label: const Text(
                      'התחברות עם Apple',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildLogoutButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRegisteredContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                mobile ? 16 : 28,
                mobile ? 18 : 24,
                mobile ? 16 : 28,
                32,
              ),
              children: [
                _buildAvatar(editable: _editing),
                const SizedBox(height: 20),
                TextField(
                  controller: _displayNameController,
                  readOnly: !_editing,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    labelText: 'שם משתמש',
                    filled: true,
                    fillColor: AppColors.background,
                    suffixIcon: _editing
                        ? Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: AppColors.champagne.withValues(alpha: 0.55),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 15,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: AppColors.champagne.withValues(alpha: 0.13),
                        width: 0.75,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(
                        color: AppColors.champagne.withValues(alpha: 0.48),
                        width: 0.9,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _buildPointsCard(),
                const SizedBox(height: 14),
                _buildReferralCard(),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.danger.withValues(alpha: 0.88),
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_editing) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.7,
                              ),
                            )
                          : const Text(
                              'שמירת פרופיל',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _buildLogoutButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoutButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _logout,
        icon: Icon(
          Icons.logout_outlined,
          size: 17,
          color: AppColors.textMuted.withValues(alpha: 0.78),
        ),
        label: Text(
          'התנתקות',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted.withValues(alpha: 0.88),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null && _displayNameController.text.isEmpty && !_isGuest) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _isGuest ? _buildGuestContent() : _buildRegisteredContent();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'הפרופיל שלי',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w400,
              ),
        ),
        actions: [
          const HomeButton(),
          if (!_loading && !_isGuest && !_editing)
            IconButton(
              tooltip: 'עריכת פרופיל',
              onPressed: () {
                setState(() {
                  _editing = true;
                  _error = null;
                });
              },
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: AppColors.champagne.withValues(alpha: 0.85),
              ),
            ),
        ],
      ),
      body: _buildContent(),
    );
  }
}
