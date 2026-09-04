import 'package:flutter/material.dart';

import '../core/models/coupon.dart';
import '../core/services/coupon_service.dart';
import '../theme/colors.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';

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
      final sent = result['sent'] ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('הקופון פורסם ונשלחו $sent התראות')),
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
        appBar: AppBar(
            title: const Text('ניהול קופונים'), actions: const [HomeButton()]),
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
                            '${coupon.businessName} · ${coupon.isPublished ? 'פורסם' : 'טיוטה'}'),
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
  late final Map<String, TextEditingController> c;
  late DateTime _validUntil;
  bool _saving = false;

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await CouponService.save({
        'title': c['title']!.text.trim(),
        'subtitle': c['subtitle']!.text.trim(),
        'description': c['description']!.text.trim(),
        'code': c['code']!.text.trim().toUpperCase(),
        'business_name': c['business_name']!.text.trim(),
        'address': c['address']!.text.trim(),
        'place_id': c['place_id']!.text.trim().isEmpty
            ? null
            : c['place_id']!.text.trim(),
        'latitude': double.tryParse(c['latitude']!.text),
        'longitude': double.tryParse(c['longitude']!.text),
        'image_url': c['image_url']!.text.trim(),
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

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: Text(widget.coupon == null ? 'קופון חדש' : 'עריכת קופון'),
            actions: const [HomeButton()]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Form(
                  key: _formKey,
                  child: ListView(padding: const EdgeInsets.all(18), children: [
                    _field('title', 'כותרת', required: true),
                    _field('subtitle', 'מלל קצר'),
                    _field('description', 'תיאור', lines: 3),
                    _field('code', 'קוד קופון', required: true),
                    _field('business_name', 'שם בית העסק', required: true),
                    _field('address', 'כתובת'),
                    _field('place_id', 'מזהה כרטיס העסק'),
                    Row(children: [
                      Expanded(child: _field('latitude', 'קו רוחב')),
                      const SizedBox(width: 10),
                      Expanded(child: _field('longitude', 'קו אורך'))
                    ]),
                    _field('image_url', 'כתובת תמונה / נכס'),
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('תוקף'),
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
          {bool required = false, int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
            controller: c[key],
            maxLines: lines,
            validator: required ? _required : null,
            decoration: InputDecoration(labelText: label)),
      );
}
