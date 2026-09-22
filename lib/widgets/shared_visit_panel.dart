import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/services/shared_visit_service.dart';
import '../theme/colors.dart';
import '../utils/image_upload_policy.dart';
import 'visit_card.dart';
import 'half_star_rating.dart';

class SharedVisitPanel extends StatefulWidget {
  const SharedVisitPanel(
      {super.key,
      required this.visitId,
      required this.place,
      required this.onTagRemoved});
  final String visitId;
  final Map<String, dynamic> place;
  final VoidCallback onTagRemoved;

  @override
  State<SharedVisitPanel> createState() => _SharedVisitPanelState();
}

class _SharedVisitPanelState extends State<SharedVisitPanel> {
  late final _service = SharedVisitService(Supabase.instance.client);
  Map<String, dynamic>? _source;
  Map<String, dynamic>? _tag;
  Map<String, dynamic>? _own;
  List<Map<String, dynamic>> _visits = [];
  bool _loading = true;
  bool _busy = false;
  bool _editing = false;
  double _rating = 0;
  final _notes = TextEditingController();
  final _extraFood = TextEditingController();
  final _extraDrink = TextEditingController();
  final _extraPrice = TextEditingController();
  final _photos = <XFile>[];
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    _extraFood.dispose();
    _extraDrink.dispose();
    _extraPrice.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final source = await _service.visit(widget.visitId);
      final visits = source == null
          ? <Map<String, dynamic>>[]
          : await _service.outing(source['outing_id'].toString());
      final tag = await _service.ownTag(widget.visitId);
      if (tag != null) await _service.markRead(tag['id'].toString());
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (!mounted) return;
      setState(() {
        _source = source;
        _visits = visits;
        _tag = tag;
        _own = visits.where((v) => v['user_id'] == uid).firstOrNull;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'לא ניתן לטעון את החוויות מאותו ביקור';
        });
      }
    }
  }

  void _openOwn() {
    if (_source == null || _busy) return;
    final own = _own;
    setState(() {
      _rating = ((own?['rating'] as num?)?.toDouble() ?? 0).clamp(0, 5);
      _notes.text = own?['notes']?.toString() ?? '';
      _extraFood.text = own?['food']?.toString() ?? '';
      _extraDrink.text = own?['drink']?.toString() ?? '';
      _extraPrice.text = own?['total_price']?.toString() ?? '';
      _photos.clear();
      _editing = true;
    });
  }

  Future<void> _pickPhotos() async {
    try {
      final selected = await ImagePicker().pickMultiImage(
        imageQuality: ImageUploadPolicy.photoQuality,
        maxWidth: ImageUploadPolicy.photoMaxDimension,
        maxHeight: ImageUploadPolicy.photoMaxDimension,
      );
      if (mounted) setState(() => _photos.addAll(selected));
    } catch (_) {
      if (mounted) setState(() => _error = 'לא ניתן לבחור תמונות');
    }
  }

  Future<void> _saveOwn() async {
    final source = _source;
    final user = Supabase.instance.client.auth.currentUser;
    if (source == null || user == null || user.isAnonymous || _busy) return;
    final priceText = _extraPrice.text.trim();
    final price = priceText.isEmpty ? null : double.tryParse(priceText);
    if (priceText.isNotEmpty && (price == null || price < 0)) {
      setState(() => _error = 'יש להזין סכום תקין לתשלום הנוסף');
      return;
    }
    if (_rating == 0 &&
        _notes.text.trim().isEmpty &&
        _photos.isEmpty &&
        _own == null) {
      setState(() => _error = 'יש להוסיף דירוג, ביקורת או תמונה');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final data = <String, dynamic>{
        'notes': _notes.text.trim(),
        'rating': _rating == 0 ? null : _rating,
        'food': _extraFood.text.trim(),
        'drink': _extraDrink.text.trim(),
        'total_price': price,
      };
      String visitId;
      if (_own == null) {
        // The database trigger links this row to the original outing and date.
        final inserted = await client
            .from('visits')
            .insert({
              ...data,
              'place_id': widget.place['id'],
              'user_id': user.id,
              'source_visit_id': source['id'],
              'visit_date': source['visit_date'],
            })
            .select('id')
            .single();
        visitId = inserted['id'].toString();
      } else {
        visitId = _own!['id'].toString();
        await client
            .from('visits')
            .update(data)
            .eq('id', visitId)
            .eq('user_id', user.id);
      }
      final oldImages = (_own?['visit_images'] as List?)?.length ?? 0;
      final uploaded = <Map<String, dynamic>>[];
      for (var i = 0; i < _photos.length; i++) {
        final bytes = await _photos[i].readAsBytes();
        final extension = _photos[i].name.split('.').last.toLowerCase();
        final path =
            '${user.id}/${DateTime.now().microsecondsSinceEpoch}_$i.$extension';
        await client.storage.from('visit-images').uploadBinary(
              path,
              Uint8List.fromList(bytes),
              fileOptions: FileOptions(contentType: 'image/$extension'),
            );
        uploaded.add({
          'visit_id': visitId,
          'user_id': user.id,
          'image_url': client.storage.from('visit-images').getPublicUrl(path),
          'sort_order': oldImages + i,
        });
      }
      if (uploaded.isNotEmpty) {
        await client.from('visit_images').insert(uploaded);
        if (_own == null) {
          await client
              .from('visits')
              .update({'image_url': uploaded.first['image_url']})
              .eq('id', visitId)
              .eq('user_id', user.id);
        }
      }
      _photos.clear();
      await _load();
      if (mounted) setState(() => _editing = false);
    } catch (_) {
      // A photo upload can fail after the visit itself was saved. Refresh so
      // retrying edits the existing review instead of inserting a duplicate.
      await _load();
      if (mounted) {
        setState(() => _error = 'לא ניתן לשמור את הביקורת. נסה שוב.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteOwn() async {
    final own = _own;
    final user = Supabase.instance.client.auth.currentUser;
    if (own == null || user == null || _busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('מחיקת הביקורת שלי'),
        content: const Text('רק הביקורת שלך תימחק. החוויה המשותפת תישאר.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('ביטול')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('מחיקה')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client
          .from('visits')
          .delete()
          .eq('id', own['id'])
          .eq('user_id', user.id);
      await _load();
      if (mounted) setState(() => _editing = false);
    } catch (_) {
      if (mounted) setState(() => _error = 'לא ניתן למחוק את הביקורת');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final tag = _tag;
    if (tag == null || _busy) return;
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('הסרת התיוג שלי'),
              content: const Text(
                  'התיוג יוסר מהביקור. ביקורת אישית שכבר כתבת לא תימחק.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('ביטול')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('הסרת התיוג')),
              ],
            ));
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _service.removeOwnTag(tag['id'].toString());
      widget.onTagRemoved();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('התיוג לא הוסר. אפשר לנסות שוב.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _personalForm() => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.champagne.withValues(alpha: 0.045),
          border: Border.all(color: AppColors.champagne.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('הביקורת שלי על הביקור המשותף',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
              'האוכל, השתייה והמחיר של הביקור נשארים בחוויה המקורית. כאן מוסיפים רק את הדעה והתוספות שלך.',
              textAlign: TextAlign.right,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 12),
          const Text('הדירוג שלי', textAlign: TextAlign.right),
          Align(
            alignment: Alignment.centerRight,
            child: HalfStarRating(
              key: const ValueKey('shared-half-star-rating'),
              value: _rating,
              size: 34,
              spacing: 5,
              keyPrefix: 'shared-rating',
              onChanged:
                  _busy ? null : (value) => setState(() => _rating = value),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _rating == 0
                  ? 'בחרו דירוג בחצאי כוכבים'
                  : '${_rating.toStringAsFixed(1)} מתוך 5',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
              ),
            ),
          ),
          TextField(
            controller: _notes,
            maxLines: 3,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'הביקורת שלי',
              hintText: 'מה אהבת? אפשר להוסיף גם #האשטאג',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
              controller: _extraFood,
              textAlign: TextAlign.right,
              decoration:
                  const InputDecoration(labelText: 'אכלתי בנוסף (לא חובה)')),
          const SizedBox(height: 8),
          TextField(
              controller: _extraDrink,
              textAlign: TextAlign.right,
              decoration:
                  const InputDecoration(labelText: 'שתיתי בנוסף (לא חובה)')),
          const SizedBox(height: 8),
          TextField(
              controller: _extraPrice,
              textAlign: TextAlign.right,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'שילמתי בנוסף ₪ (לא חובה)')),
          const SizedBox(height: 10),
          Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _pickPhotos,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('הוספת תמונות שלי'),
              )),
          if (_photos.isNotEmpty)
            Wrap(spacing: 6, children: [
              for (final photo in _photos)
                InputChip(
                    label: Text(photo.name),
                    onDeleted: _busy
                        ? null
                        : () => setState(() => _photos.remove(photo)))
            ]),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 8, alignment: WrapAlignment.end, children: [
            TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _editing = false;
                          _error = null;
                        }),
                child: const Text('ביטול')),
            FilledButton(
                onPressed: _busy ? null : _saveOwn,
                child: Text(
                    _own == null ? 'שמירת הביקורת שלי' : 'שמירת השינויים')),
          ]),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
          padding: EdgeInsets.all(12), child: LinearProgressIndicator());
    }
    if (_error != null && !_editing) {
      return TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_error!));
    }
    if (_source == null || (_tag == null && _visits.length < 2)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (_tag != null) ...[
          const Text('תויגת בחוויה הזו',
              style: TextStyle(color: AppColors.champagne)),
          const SizedBox(height: 8),
        ],
        if (!_editing &&
            (_tag != null || _own != null) &&
            _own?['id'] != widget.visitId)
          OutlinedButton.icon(
              onPressed: _busy ? null : _openOwn,
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(_own == null
                  ? 'הוספת הדירוג והביקורת שלי'
                  : 'הדירוג והביקורת שלי')),
        if (_editing) _personalForm(),
        if (_own != null && _own?['id'] != widget.visitId && !_editing)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _busy ? null : _deleteOwn,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('מחיקת הביקורת שלי'),
            ),
          ),
        if (_tag != null)
          TextButton(
              onPressed: _busy ? null : _remove,
              child: const Text('הסרת התיוג שלי')),
        if (_visits.length > 1) ...[
          const SizedBox(height: 12),
          const Text('הביקור המשותף',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const Text('ביקור אחד · דירוג וביקורת נפרדים לכל משתתף',
              style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 10),
          for (final visit in _visits.where((v) => v['id'] != widget.visitId))
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VisitCard(
                    visit: visit,
                    place: widget.place,
                    groupedReview: true,
                    openOnTap: visit['user_id'] !=
                        Supabase.instance.client.auth.currentUser?.id,
                    onChanged: _load)),
        ],
      ]),
    );
  }
}
