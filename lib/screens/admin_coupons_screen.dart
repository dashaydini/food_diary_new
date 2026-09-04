import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/models/coupon.dart';
import '../core/services/coupon_service.dart';
import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';
import 'admin_coupon_statistics_screen.dart';

class AdminCouponsScreen extends StatefulWidget {
  const AdminCouponsScreen({super.key});
  @override
  State<AdminCouponsScreen> createState() => _AdminCouponsScreenState();
}

class _AdminCouponsScreenState extends State<AdminCouponsScreen> {
  bool _loading = true;
  List<Coupon> _coupons = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await CouponService.list(includeDrafts: true);
      if (mounted) setState(() => _coupons = rows);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא ניתן לטעון את הקופונים')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Coupon? coupon]) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CouponEditorScreen(coupon: coupon),
    ));
    await _load();
  }

  Future<void> _publish(Coupon coupon) async {
    try {
      final result = await CouponService.publishAndNotify(coupon.id);
      if (!mounted) return;
      final sent = (result['sent'] as num?)?.toInt() ?? 0;
      final failed = (result['failed'] as num?)?.toInt() ?? 0;
      if (sent == 0 && failed == 0) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.notifications_off_outlined),
            title: const Text('אין עדיין מכשירים רשומים'),
            content: const Text(
              'כדי לקבל פוש, יש לפתוח את האפליקציה בטלפון, להיכנס להגדרות ← קבלת התראות, ולאשר את בקשת המערכת.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('הבנתי'),
              ),
            ],
          ),
        );
        await _load();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(failed == 0
                ? 'הקופון פורסם ונשלחו $sent התראות'
                : 'נשלחו $sent התראות; $failed לא נשלחו')),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('הפרסום לא הושלם. נסה שוב.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('ניהול קופונים'), actions: [
          IconButton(
            tooltip: 'סטטיסטיקה',
            icon: const Icon(Icons.query_stats_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AdminCouponStatisticsScreen(),
            )),
          ),
          const HomeButton(),
        ]),
        floatingActionButton: Permissions.canManageContent
            ? FloatingActionButton.extended(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('קופון חדש'))
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  padding: const EdgeInsets.all(18),
                  itemCount: _coupons.length,
                  itemBuilder: (context, index) {
                    final coupon = _coupons[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: Icon(
                            coupon.isPublished
                                ? Icons.campaign
                                : Icons.edit_note,
                            color: coupon.isPublished
                                ? AppColors.success
                                : AppColors.champagne),
                        title: Text(coupon.title),
                        subtitle: Text(
                            '${coupon.businessName} · ${coupon.validUntil.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) ? 'פג תוקף — חסום למשתמשים' : coupon.isPublished ? 'פורסם' : 'טיוטה'}'),
                        onTap: () => _edit(coupon),
                        trailing: coupon.isPublished
                            ? OutlinedButton.icon(
                                onPressed: () => _publish(coupon),
                                icon: const Icon(Icons.send_rounded, size: 17),
                                label: const Text('שליחת פוש'))
                            : FilledButton(
                                onPressed: () => _publish(coupon),
                                child: const Text('פרסום + פוש')),
                      ),
                    );
                  },
                ),
              ),
      );
}

class _CouponEditorScreen extends StatefulWidget {
  final Coupon? coupon;
  const _CouponEditorScreen({this.coupon});
  @override
  State<_CouponEditorScreen> createState() => _CouponEditorScreenState();
}

class _CouponEditorScreenState extends State<_CouponEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final Map<String, TextEditingController> c;
  late DateTime _validUntil;
  bool _saving = false;
  bool _loadingLocation = false;
  XFile? _selectedImage;
  String? _selectedPlaceId;
  double? _latitude;
  double? _longitude;
  List<Map<String, dynamic>> _placeSuggestions = [];
  int _searchSequence = 0;

  @override
  void initState() {
    super.initState();
    final x = widget.coupon;
    c = {
      'title': TextEditingController(text: x?.title),
      'subtitle': TextEditingController(text: x?.subtitle),
      'description': TextEditingController(text: x?.description),
      'code': TextEditingController(text: x?.code),
      'business_name': TextEditingController(text: x?.businessName),
      'address': TextEditingController(text: x?.address),
      'place_id': TextEditingController(text: x?.placeId),
      'latitude': TextEditingController(text: x?.latitude?.toString()),
      'longitude': TextEditingController(text: x?.longitude?.toString()),
      'image_url': TextEditingController(
          text: x?.imageUrl ?? 'assets/coupons/rosh_hashanah_gift_basket.jpeg'),
    };
    _validUntil = x?.validUntil ?? DateTime.now().add(const Duration(days: 30));
    _selectedPlaceId = x?.placeId;
    _latitude = x?.latitude;
    _longitude = x?.longitude;
    if (widget.coupon == null) _generateCode();
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'שדה חובה' : null;

  void _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final suffix =
        List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
    c['code']!.text = 'BTW-$suffix';
  }

  Future<void> _searchPlaces(String value) async {
    final query = value.trim();
    final sequence = ++_searchSequence;
    if (query.length < 2) {
      if (mounted) setState(() => _placeSuggestions = []);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (sequence != _searchSequence) return;
    try {
      final rows = await Supabase.instance.client
          .from('places')
          .select('id,name,address,latitude,longitude')
          .ilike('name', '%$query%')
          .limit(6);
      if (mounted && sequence == _searchSequence) {
        setState(
            () => _placeSuggestions = List<Map<String, dynamic>>.from(rows));
      }
    } catch (_) {}
  }

  void _selectPlace(Map<String, dynamic> place) {
    setState(() {
      _selectedPlaceId = place['id']?.toString();
      _latitude = (place['latitude'] as num?)?.toDouble();
      _longitude = (place['longitude'] as num?)?.toDouble();
      _placeSuggestions = [];
      c['business_name']!.text = place['name']?.toString() ?? '';
      c['address']!.text = place['address']?.toString() ?? '';
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('permission');
      }
      final position = await Geolocator.getCurrentPosition();
      String? address;
      try {
        final marks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (marks.isNotEmpty) {
          final p = marks.first;
          address = [p.street, p.locality]
              .where((x) => x?.trim().isNotEmpty == true)
              .join(', ');
        }
      } catch (_) {}
      address ??= await _reverseAddress(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _selectedPlaceId = null;
        _latitude = position.latitude;
        _longitude = position.longitude;
        if (address?.isNotEmpty == true) c['address']!.text = address!;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא ניתן לקבל את המיקום הנוכחי')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<String?> _reverseAddress(double lat, double lon) async {
    try {
      final response = await http.get(
          Uri.https('nominatim.openstreetmap.org', '/reverse', {
            'lat': '$lat',
            'lon': '$lon',
            'format': 'jsonv2',
            'accept-language': 'he',
          }),
          headers: const {'User-Agent': 'BiteTheWay/1.0'});
      if (response.statusCode != 200) return null;
      return (jsonDecode(response.body) as Map<String, dynamic>)['display_name']
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('צילום במצלמה'),
            onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('בחירה מהגלריה'),
            onTap: () => Navigator.pop(context, ImageSource.gallery)),
      ])),
    );
    if (source == null) return;
    final image = await _picker.pickImage(
        source: source, imageQuality: 82, maxWidth: 1600, maxHeight: 1600);
    if (mounted && image != null) setState(() => _selectedImage = image);
  }

  Future<String> _uploadImage() async {
    if (_selectedImage == null) return c['image_url']!.text.trim();
    final extension = _selectedImage!.name.split('.').last.toLowerCase();
    final path =
        '${Supabase.instance.client.auth.currentUser!.id}/${const Uuid().v4()}.$extension';
    await Supabase.instance.client.storage.from('coupon-images').uploadBinary(
        path, await _selectedImage!.readAsBytes(),
        fileOptions: const FileOptions(upsert: false));
    return Supabase.instance.client.storage
        .from('coupon-images')
        .getPublicUrl(path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final imageUrl = await _uploadImage();
      await CouponService.save({
        'title': c['title']!.text.trim(),
        'subtitle': c['subtitle']!.text.trim(),
        'description': c['description']!.text.trim(),
        'code': c['code']!.text.trim().toUpperCase(),
        'business_name': c['business_name']!.text.trim(),
        'address': c['address']!.text.trim(),
        'place_id': _selectedPlaceId,
        'latitude': _latitude,
        'longitude': _longitude,
        'image_url': imageUrl,
        'valid_until': _validUntil.toIso8601String().split('T').first,
        'is_unlimited': true,
        'is_published': widget.coupon?.isPublished ?? false,
      }, id: widget.coupon?.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('לא ניתן לשמור את הקופון')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final coupon = widget.coupon;
    if (coupon == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת קופון'),
        content: Text('למחוק לצמית את „${coupon.title}”?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('מחיקה')),
        ],
      ),
    );
    if (confirmed != true) return;
    await CouponService.remove(coupon.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: Text(widget.coupon == null ? 'קופון חדש' : 'עריכת קופון'),
            actions: [
              if (widget.coupon != null)
                IconButton(
                    tooltip: 'מחיקת קופון',
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline)),
              const HomeButton(),
            ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: ListView(padding: const EdgeInsets.all(18), children: [
                    _field('title', 'כותרת', required: true),
                    _field('subtitle', 'מלל קצר'),
                    _field('description', 'תיאור', lines: 3),
                    _field('code', 'קוד קופון',
                        required: true,
                        helper: 'נוצר אוטומטית; אפשר גם לערוך ידנית',
                        suffix: IconButton(
                            tooltip: 'יצירת קוד חדש',
                            onPressed: _generateCode,
                            icon: const Icon(Icons.autorenew_rounded))),
                    _field('business_name', 'שם בית העסק',
                        required: true,
                        helper:
                            'התחל להקליד ובחר עסק קיים כדי למלא את הכתובת והמיקום',
                        onChanged: _searchPlaces),
                    if (_placeSuggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: AppColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.cardBorder)),
                        child: Column(children: [
                          for (final place in _placeSuggestions)
                            ListTile(
                              leading: const Icon(Icons.storefront_outlined),
                              title: Text(place['name']?.toString() ?? ''),
                              subtitle:
                                  Text(place['address']?.toString() ?? ''),
                              onTap: () => _selectPlace(place),
                            )
                        ]),
                      ),
                    _field('address', 'כתובת'),
                    OutlinedButton.icon(
                      onPressed: _loadingLocation ? null : _useCurrentLocation,
                      icon: _loadingLocation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded),
                      label: Text(_loadingLocation
                          ? 'מאתר מיקום...'
                          : 'שימוש במיקום שלי'),
                    ),
                    if (_selectedPlaceId != null ||
                        (_latitude != null && _longitude != null))
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Icon(Icons.check_circle,
                                color: AppColors.success, size: 18),
                            SizedBox(width: 7),
                            Text('המיקום נשמר עם הקופון')
                          ])),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(_selectedImage == null
                            ? 'צילום או בחירת תמונה'
                            : 'נבחרה: ${_selectedImage!.name}')),
                    if (_selectedImage == null &&
                        c['image_url']!.text.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                  height: 150,
                                  child: c['image_url']!.text.startsWith('http')
                                      ? Image.network(c['image_url']!.text,
                                          fit: BoxFit.cover)
                                      : Image.asset(c['image_url']!.text,
                                          fit: BoxFit.cover)))),
                    const SizedBox(height: 10),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('בתוקף עד'),
                        subtitle: Text(
                            '${_validUntil.day}.${_validUntil.month}.${_validUntil.year}'),
                        trailing: const Icon(Icons.calendar_month),
                        onTap: () async {
                          final d = await showDatePicker(
                              context: context,
                              initialDate: _validUntil,
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2035));
                          if (d != null) setState(() => _validUntil = d);
                        }),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'שומר...' : 'שמירת טיוטה')),
                  ]),
                ))),
      );

  Widget _field(String key, String label,
          {bool required = false,
          int lines = 1,
          String? helper,
          Widget? suffix,
          ValueChanged<String>? onChanged}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
            controller: c[key],
            maxLines: lines,
            onChanged: onChanged,
            validator: required ? _required : null,
            decoration: InputDecoration(
                labelText: label, helperText: helper, suffixIcon: suffix)),
      );
}
