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

      Navigator.of(context).pop(true);
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
              width: 104,
              height: 104,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.card,
              ),
              clipBehavior: Clip.antiAlias,
              child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                  ? Image.network(
                      _avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const Icon(
                          Icons.person_outline,
                          size: 52,
                          color: AppColors.muted,
                        );
                      },
                    )
                  : const Icon(
                      Icons.person_outline,
                      size: 52,
                      color: AppColors.muted,
                    ),
            ),
            if (editable)
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.card,
                ),
                child: _uploadingAvatar
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.star_rounded,
            size: 34,
            color: AppColors.brass,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'נקודות',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$_points',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _levelName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'רמה $_level',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.group_outlined,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'חבר מביא חבר',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'הזמן חברים להצטרף לאפליקציה וצבור נקודות.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
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
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        code ?? 'אין קוד',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: code == null ? null : _shareReferralCode,
                  icon: const Icon(Icons.share_outlined),
                  tooltip: 'שיתוף קוד ההזמנה',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.people_outline, size: 22),
              const SizedBox(width: 10),
              Text(
                '$_referralCount ${_referralCount == 1 ? 'חבר הצטרף' : 'חברים הצטרפו'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuestContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      children: [
        _buildAvatar(editable: false),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            'בעת חיבור כאורח, ניתן לצפות במקומות וחוויות קיימים. '
            'אין אפשרות לערוך פרופיל.\n\n'
            'נא להתחבר עם חשבון Google או Apple על מנת ליהנות '
            'משאר האפשרויות של היישום.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _loggingIn ? null : _googleLogin,
            icon: const Icon(
              Icons.g_mobiledata,
              size: 30,
            ),
            label: const Text(
              'התחברות עם Google',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            onPressed: _loggingIn ? null : _appleLogin,
            icon: const Icon(
              Icons.apple,
              size: 24,
            ),
            label: const Text(
              'התחברות עם Apple',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _buildLogoutButton(),
      ],
    );
  }

  Widget _buildRegisteredContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      children: [
        _buildAvatar(),
        const SizedBox(height: 18),
        TextField(
          controller: _displayNameController,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            labelText: 'שם משתמש',
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildPointsCard(),
        const SizedBox(height: 18),
        _buildReferralCard(),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            textAlign: TextAlign.right,
            style: const TextStyle(color: Colors.red),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _saving ? null : _saveProfile,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'שמירת פרופיל',
                    style: TextStyle(fontSize: 17),
                  ),
          ),
        ),
        const SizedBox(height: 28),
        _buildLogoutButton(),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return TextButton.icon(
      onPressed: _logout,
      icon: const Icon(
        Icons.logout_outlined,
        size: 19,
      ),
      label: const Text(
        'התנתקות',
        style: TextStyle(fontSize: 15),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.muted,
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
        elevation: 0,
        actions: const [
          HomeButton(),
        ],
        centerTitle: false,
        title: const Text(
          'הפרופיל שלי',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildContent(),
    );
  }
}
