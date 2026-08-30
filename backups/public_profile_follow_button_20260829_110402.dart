import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';
import 'add_visit_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;

  const PublicProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _client = Supabase.instance.client;

  bool _loading = true;
  bool _followWorking = false;
  String? _error;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _experiences = [];

  int _followersCount = 0;
  int _followingCount = 0;

  bool _isFollowing = false;

  String? get _currentUserId => _client.auth.currentUser?.id;

  bool get _isOwnProfile =>
      _currentUserId != null && _currentUserId == widget.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _client
            .from('profiles')
            .select('id, display_name, email, avatar_url')
            .eq('id', widget.userId)
            .maybeSingle(),
        _client
            .from('visits')
            .select(
              'id, place_id, user_id, visit_date, notes, rating, food, '
              'food_price, total_price, price_level, drink, drink_price, '
              'image_url, food_rating, drink_rating, atmosphere_rating, '
              'service_rating, cleanliness_rating, variety_rating, '
              'value_rating, created_at, '
              'visit_tag_links(tag_id, visit_tags(name, icon)), '
              'visit_images(id, image_url, sort_order), '
              'places(id, name, address, latitude, longitude, image_url, '
              'categories(title))',
            )
            .eq('user_id', widget.userId)
            .order('visit_date', ascending: false),
        _client
            .from('user_follows')
            .select('follower_id')
            .eq('following_id', widget.userId),
        _client
            .from('user_follows')
            .select('following_id')
            .eq('follower_id', widget.userId),
      ]);

      final profileRaw = results[0];

      final profile =
          profileRaw is Map ? Map<String, dynamic>.from(profileRaw) : null;

      final experiences = List<Map<String, dynamic>>.from(results[1] as List);

      final followers = results[2] as List;
      final following = results[3] as List;

      bool isFollowing = false;

      final currentUserId = _currentUserId;

      if (currentUserId != null && currentUserId != widget.userId) {
        final follow = await _client
            .from('user_follows')
            .select('follower_id, following_id')
            .eq('follower_id', currentUserId)
            .eq('following_id', widget.userId)
            .maybeSingle();

        isFollowing = follow != null;
      }

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _experiences = experiences;
        _followersCount = followers.length;
        _followingCount = following.length;
        _isFollowing = isFollowing;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון את הפרופיל: $e';
      });
    }
  }

  Future<void> _toggleFollow() async {
    final currentUserId = _currentUserId;

    if (currentUserId == null ||
        currentUserId == widget.userId ||
        _followWorking) {
      return;
    }

    setState(() {
      _followWorking = true;
    });

    try {
      if (_isFollowing) {
        await _client
            .from('user_follows')
            .delete()
            .eq('follower_id', currentUserId)
            .eq('following_id', widget.userId);

        if (!mounted) return;

        setState(() {
          _isFollowing = false;
          if (_followersCount > 0) {
            _followersCount--;
          }
          _followWorking = false;
        });
      } else {
        await _client.from('user_follows').insert({
          'follower_id': currentUserId,
          'following_id': widget.userId,
        });

        if (!mounted) return;

        setState(() {
          _isFollowing = true;
          _followersCount++;
          _followWorking = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _followWorking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('לא ניתן לעדכן מעקב: $e'),
        ),
      );
    }
  }

  Future<void> _openExperience(
    Map<String, dynamic> experience,
  ) async {
    final placeRaw = experience['places'];

    if (placeRaw is! Map) return;

    final place = Map<String, dynamic>.from(placeRaw);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddVisitScreen(
          place: place,
          visit: experience,
          viewOnly: true,
        ),
      ),
    );

    if (mounted) {
      await _load();
    }
  }

  String _authorName() {
    final name = _profile?['display_name']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email = _profile?['email']?.toString().trim();

    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'משתמש';
  }

  String? _avatarUrl() {
    final value = _profile?['avatar_url']?.toString().trim();

    if (value == null || value.isEmpty) return null;

    return value;
  }

  String _dateText(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return '';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year}';
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
        title: const Text(
          'פרופיל',
          style: TextStyle(
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: Column(
                                children: [
                                  _buildProfileHeader(),
                                  const SizedBox(height: 28),
                                  _buildExperiencesHeader(),
                                  const SizedBox(height: 12),
                                  if (_experiences.isEmpty)
                                    _buildEmpty()
                                  else
                                    ..._experiences.map(
                                      _buildExperienceCard,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildProfileHeader() {
    final avatarUrl = _avatarUrl();
    final name = _authorName();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.16),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.04),
            blurRadius: 32,
            spreadRadius: -7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.40),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.champagne.withValues(alpha: 0.08),
                  blurRadius: 24,
                ),
              ],
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stat(
                value: '${_experiences.length}',
                label: 'חוויות',
              ),
              _divider(),
              _stat(
                value: '$_followersCount',
                label: 'עוקבים',
              ),
              _divider(),
              _stat(
                value: '$_followingCount',
                label: 'נעקבים',
              ),
            ],
          ),
          if (!_isOwnProfile && _currentUserId != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              height: 42,
              child: OutlinedButton(
                onPressed: _followWorking ? null : _toggleFollow,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.champagne,
                  side: BorderSide(
                    color: AppColors.champagne.withValues(
                      alpha: _isFollowing ? 0.22 : 0.42,
                    ),
                    width: 0.8,
                  ),
                  backgroundColor: _isFollowing
                      ? AppColors.champagne.withValues(alpha: 0.05)
                      : AppColors.background,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: _followWorking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.4,
                          color: AppColors.champagne,
                        ),
                      )
                    : Text(
                        _isFollowing ? 'עוקב' : 'עקוב',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: AppColors.surfaceRaised,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_outline_rounded,
        color: AppColors.champagne,
        size: 34,
      ),
    );
  }

  Widget _stat({
    required String value,
    required String label,
  }) {
    return SizedBox(
      width: 82,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      color: AppColors.champagne.withValues(alpha: 0.12),
    );
  }

  Widget _buildExperiencesHeader() {
    return const Align(
      alignment: Alignment.centerRight,
      child: Text(
        'חוויות',
        textAlign: TextAlign.right,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.12),
          width: 0.75,
        ),
      ),
      child: const Text(
        'אין עדיין חוויות להצגה',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildExperienceCard(Map<String, dynamic> experience) {
    final placeRaw = experience['places'];

    final place = placeRaw is Map
        ? Map<String, dynamic>.from(placeRaw)
        : <String, dynamic>{};

    final placeName = place['name']?.toString().trim() ?? 'מקום';
    final food = experience['food']?.toString().trim() ?? '';
    final notes = experience['notes']?.toString().trim() ?? '';
    final date = _dateText(experience['visit_date']);

    final ratingRaw = experience['rating'];
    final rating = ratingRaw is num ? ratingRaw.toDouble() : null;

    final images = experience['visit_images'];

    String? imageUrl;

    if (images is List && images.isNotEmpty) {
      final first = images.first;

      if (first is Map) {
        imageUrl = first['image_url']?.toString();
      }
    }

    imageUrl ??= experience['image_url']?.toString();
    imageUrl ??= place['image_url']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.champagne.withValues(alpha: 0.035),
            blurRadius: 28,
            spreadRadius: -7,
          ),
        ],
      ),
      child: Material(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _openExperience(experience),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.champagne.withValues(alpha: 0.14),
                width: 0.75,
              ),
            ),
            child: Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    width: 74,
                    height: 74,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _experienceImageFallback(),
                          )
                        : _experienceImageFallback(),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (food.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          food,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ] else if (notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          notes,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          date,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (rating != null) ...[
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.champagne,
                        size: 17,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _experienceImageFallback() {
    return Container(
      color: AppColors.surfaceRaised,
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_outlined,
        color: AppColors.textMuted,
        size: 23,
      ),
    );
  }
}
