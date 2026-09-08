import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';

class PlaceTextManagerScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  final bool openingHours;

  const PlaceTextManagerScreen({
    super.key,
    required this.place,
    required this.openingHours,
  });

  @override
  State<PlaceTextManagerScreen> createState() => _PlaceTextManagerScreenState();
}

class _PlaceTextManagerScreenState extends State<PlaceTextManagerScreen> {
  final _controller = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  String get _table =>
      widget.openingHours ? 'place_opening_hours' : 'place_menus';
  String get _title => widget.openingHours ? 'שעות פתיחה' : 'תפריט';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await Supabase.instance.client
          .from(_table)
          .select('content')
          .eq('place_id', widget.place['id'])
          .maybeSingle();
      _controller.text = row?['content']?.toString() ?? '';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from(_table).upsert({
        'place_id': widget.place['id'],
        'content': _controller.text.trim(),
        'updated_by': Supabase.instance.client.auth.currentUser!.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$_title נשמר')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('לא ניתן לשמור את $_title')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: Text('$_title · ${widget.place['name']}'),
            actions: const [HomeButton()]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(padding: const EdgeInsets.all(18), children: [
                    TextField(
                      controller: _controller,
                      minLines: 10,
                      maxLines: 20,
                      decoration: InputDecoration(
                        labelText: _title,
                        hintText: widget.openingHours
                            ? 'א׳–ה׳ 08:00–20:00\nו׳ 08:00–14:00\nשבת סגור'
                            : 'הקלד כאן את פריטי התפריט, המחירים והערות',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'שומר...' : 'שמירה ופרסום'),
                    ),
                  ]),
                ),
              ),
      );
}

class PlaceGalleryManagerScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  const PlaceGalleryManagerScreen({super.key, required this.place});

  @override
  State<PlaceGalleryManagerScreen> createState() =>
      _PlaceGalleryManagerScreenState();
}

class _PlaceGalleryManagerScreenState extends State<PlaceGalleryManagerScreen> {
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _images = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await Supabase.instance.client
        .from('place_gallery_images')
        .select('id,image_url,created_at')
        .eq('place_id', widget.place['id'])
        .order('created_at', ascending: false);
    if (mounted) {
      setState(() {
        _images = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    }
  }

  Future<void> _pick(ImageSource source) async {
    final picked = source == ImageSource.camera
        ? [
            if (await _picker.pickImage(
                    source: source, imageQuality: 82, maxWidth: 1600)
                case final image?)
              image
          ]
        : await _picker.pickMultiImage(imageQuality: 82, maxWidth: 1600);
    if (picked.isEmpty) return;
    setState(() => _uploading = true);
    try {
      for (final image in picked) {
        final extension = image.name.split('.').last.toLowerCase();
        final path =
            '${Supabase.instance.client.auth.currentUser!.id}/${const Uuid().v4()}.$extension';
        await Supabase.instance.client.storage
            .from('place-images')
            .uploadBinary(
              path,
              await image.readAsBytes(),
              fileOptions: const FileOptions(upsert: false),
            );
        final url = Supabase.instance.client.storage
            .from('place-images')
            .getPublicUrl(path);
        await Supabase.instance.client.from('place_gallery_images').insert({
          'place_id': widget.place['id'],
          'image_url': url,
          'uploaded_by': Supabase.instance.client.auth.currentUser!.id,
        });
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('העלאת התמונות נכשלה')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _remove(String id) async {
    await Supabase.instance.client
        .from('place_gallery_images')
        .delete()
        .eq('id', id);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: Text('גלריה · ${widget.place['name']}'),
            actions: const [HomeButton()]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(18), children: [
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: _uploading
                              ? null
                              : () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('בחירה מהגלריה'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: OutlinedButton.icon(
                          onPressed: _uploading
                              ? null
                              : () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('צילום'))),
                ]),
                if (_uploading)
                  const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator()),
                const SizedBox(height: 18),
                if (_images.isEmpty)
                  const Center(child: Text('עדיין לא נוספו תמונות')),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10),
                  itemCount: _images.length,
                  itemBuilder: (context, index) {
                    final image = _images[index];
                    return Stack(fit: StackFit.expand, children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(image['image_url'].toString(),
                              fit: BoxFit.cover)),
                      Positioned(
                          top: 5,
                          left: 5,
                          child: IconButton.filled(
                              onPressed: () => _remove(image['id'].toString()),
                              icon: const Icon(Icons.delete_outline))),
                    ]);
                  },
                ),
              ]),
      );
}

class PlaceRepliesManagerScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  const PlaceRepliesManagerScreen({super.key, required this.place});

  @override
  State<PlaceRepliesManagerScreen> createState() =>
      _PlaceRepliesManagerScreenState();
}

class _PlaceRepliesManagerScreenState extends State<PlaceRepliesManagerScreen> {
  List<Map<String, dynamic>> _visits = [];
  Map<String, Map<String, dynamic>> _replies = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      Supabase.instance.client
          .from('visits')
          .select('id,notes,rating,visit_date')
          .eq('place_id', widget.place['id'])
          .order('visit_date', ascending: false),
      Supabase.instance.client
          .from('place_official_replies')
          .select('id,visit_id,body')
          .eq('place_id', widget.place['id']),
    ]);
    if (!mounted) return;
    setState(() {
      _visits = List<Map<String, dynamic>>.from(results[0]);
      _replies = {
        for (final row in List<Map<String, dynamic>>.from(results[1]))
          row['visit_id'].toString(): row
      };
      _loading = false;
    });
  }

  Future<void> _editReply(Map<String, dynamic> visit) async {
    final existing = _replies[visit['id'].toString()];
    final controller =
        TextEditingController(text: existing?['body']?.toString());
    final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('תגובה רשמית של בית העסק'),
              content: TextField(
                  controller: controller,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 2000),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('ביטול')),
                FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('פרסום'))
              ],
            ));
    if (save == true && controller.text.trim().length >= 2) {
      await Supabase.instance.client.from('place_official_replies').upsert({
        'place_id': widget.place['id'],
        'visit_id': visit['id'],
        'body': controller.text.trim(),
        'created_by': Supabase.instance.client.auth.currentUser!.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'visit_id');
      await _load();
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: Text('תגובות · ${widget.place['name']}'),
            actions: const [HomeButton()]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: _visits.length,
                itemBuilder: (context, index) {
                  final visit = _visits[index];
                  final reply = _replies[visit['id'].toString()];
                  return Card(
                      child: ListTile(
                    title: Text(
                        (visit['notes']?.toString().trim().isNotEmpty ?? false)
                            ? visit['notes'].toString()
                            : 'חוויה ללא מלל'),
                    subtitle: reply == null
                        ? const Text('אין תגובה רשמית')
                        : Text('תגובת העסק: ${reply['body']}'),
                    trailing: const Icon(Icons.reply_rounded),
                    onTap: () => _editReply(visit),
                  ));
                },
              ),
      );
}
