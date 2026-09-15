import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../theme/colors.dart';
import '../core/services/notification_dispatch_service.dart';
import '../utils/image_upload_policy.dart';
import '../utils/supabase_image_url.dart';
import '../utils/permissions.dart';
import '../widgets/home_button.dart';

class _PendingMenuFile {
  final Uint8List bytes;
  final String name;
  final String type;

  const _PendingMenuFile({
    required this.bytes,
    required this.name,
    required this.type,
  });
}

class PlaceMenuManagerScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  const PlaceMenuManagerScreen({super.key, required this.place});

  @override
  State<PlaceMenuManagerScreen> createState() => _PlaceMenuManagerScreenState();
}

class _PlaceMenuManagerScreenState extends State<PlaceMenuManagerScreen> {
  final _note = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _files = [];
  final List<_PendingMenuFile> _pendingFiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await Supabase.instance.client
          .from('place_menus')
          .select('content,files,file_url,file_name,file_type')
          .eq('place_id', widget.place['id'])
          .maybeSingle();
      _note.text = row?['content']?.toString() ?? '';
      final savedFiles = row?['files'];
      if (savedFiles is List) {
        _files = [
          for (final item in savedFiles)
            if (item is Map) Map<String, dynamic>.from(item)
        ];
      } else if (row?['file_url']?.toString().trim().isNotEmpty == true) {
        _files = [
          {
            'url': row!['file_url'],
            'name': row['file_name'],
            'type': row['file_type'],
          }
        ];
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final images = source == ImageSource.camera
          ? [
              if (await _imagePicker.pickImage(
                      source: source,
                      imageQuality: ImageUploadPolicy.menuQuality,
                      maxWidth: ImageUploadPolicy.menuMaxDimension,
                      maxHeight: ImageUploadPolicy.menuMaxDimension)
                  case final image?)
                image
            ]
          : await _imagePicker.pickMultiImage(
              imageQuality: ImageUploadPolicy.menuQuality,
              maxWidth: ImageUploadPolicy.menuMaxDimension,
              maxHeight: ImageUploadPolicy.menuMaxDimension,
            );
      if (images.isEmpty) return;
      final pending = <_PendingMenuFile>[];
      for (final image in images) {
        pending.add(_PendingMenuFile(
          bytes: await image.readAsBytes(),
          name: image.name,
          type: 'image',
        ));
      }
      if (!mounted) return;
      setState(() => _pendingFiles.addAll(pending));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא ניתן לפתוח את בחירת התמונות')),
        );
      }
    }
  }

  Future<void> _pickPdf() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      if (files.isEmpty) return;
      final pending = <_PendingMenuFile>[];
      for (final file in files) {
        pending.add(_PendingMenuFile(
          bytes: await file.readAsBytes(),
          name: file.name,
          type: 'pdf',
        ));
      }
      if (!mounted) return;
      setState(() => _pendingFiles.addAll(pending));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא ניתן לפתוח את בחירת קובצי ה־PDF')),
        );
      }
    }
  }

  Future<void> _showFileOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('בחירת תמונה מהגלריה'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pickImage(ImageSource.gallery);
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('צילום תפריט'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('בחירת קובץ PDF'),
            onTap: () {
              Navigator.pop(sheetContext);
              _pickPdf();
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final nextFiles = [
        for (final file in _files) {...file}
      ];
      for (final file in _pendingFiles) {
        final extension = file.name.split('.').last.toLowerCase();
        final path =
            '${widget.place['id']}/${Supabase.instance.client.auth.currentUser!.id}/${const Uuid().v4()}.$extension';
        await Supabase.instance.client.storage
            .from('place-menu-files')
            .uploadBinary(path, file.bytes,
                fileOptions: FileOptions(
                    upsert: false,
                    contentType: extension == 'pdf'
                        ? 'application/pdf'
                        : 'image/${extension == 'jpg' ? 'jpeg' : extension}'));
        final url = Supabase.instance.client.storage
            .from('place-menu-files')
            .getPublicUrl(path);
        nextFiles.add({
          'url': url,
          'path': path,
          'name': file.name,
          'type': file.type,
        });
      }
      await Supabase.instance.client.from('place_menus').upsert({
        'place_id': widget.place['id'],
        'content': _note.text.trim(),
        'files': nextFiles,
        'file_url': null,
        'file_name': null,
        'file_type': null,
        'updated_by': Supabase.instance.client.auth.currentUser!.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      _files = nextFiles;
      _pendingFiles.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('התפריט נשמר ופורסם')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('לא ניתן לשמור את התפריט')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _storagePath(Map<String, dynamic> file) {
    final saved = file['path']?.toString().trim();
    if (saved?.isNotEmpty == true) return saved;
    final url = file['url']?.toString() ?? '';
    const marker = '/place-menu-files/';
    final markerIndex = url.indexOf(marker);
    return markerIndex < 0 ? null : url.substring(markerIndex + marker.length);
  }

  Future<void> _removeFile(Map<String, dynamic> file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('מחיקת קובץ מהתפריט'),
        content: Text('למחוק את ${file['name'] ?? 'הקובץ'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ביטול'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('מחיקה'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      final nextFiles = _files.where((item) => !identical(item, file)).toList();
      final path = _storagePath(file);
      if (path != null) {
        await Supabase.instance.client.storage
            .from('place-menu-files')
            .remove([path]);
      }
      await Supabase.instance.client.from('place_menus').update({
        'files': nextFiles,
        'updated_by': Supabase.instance.client.auth.currentUser!.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('place_id', widget.place['id']);
      if (!mounted) return;
      setState(() => _files = nextFiles);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('לא ניתן למחוק את הקובץ כרגע')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPdf(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('לא ניתן לפתוח את קובץ ה־PDF')),
      );
    }
  }

  void _openImage(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Image.network(
                  optimizedSupabaseImageUrl(
                    url,
                    width: 1600,
                    quality: 80,
                    resize: 'contain',
                  ),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          SafeArea(
            child: IconButton.filled(
              onPressed: () => Navigator.pop(dialogContext),
              icon: const Icon(Icons.close),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _existingFileTile(Map<String, dynamic> file) {
    final url = file['url']?.toString() ?? '';
    final isImage = file['type']?.toString() == 'image';
    return Card(
      child: ListTile(
        leading: isImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                    optimizedSupabaseImageUrl(url, width: 180, height: 180),
                    width: 58,
                    height: 58,
                    fit: BoxFit.cover),
              )
            : const Icon(Icons.picture_as_pdf_outlined, size: 34),
        title: Text(file['name']?.toString() ??
            (isImage ? 'תמונת תפריט' : 'תפריט PDF')),
        subtitle: Text(isImage ? 'לחיצה לפתיחת התמונה' : 'לחיצה לפתיחת PDF'),
        onTap: () => isImage ? _openImage(url) : _openPdf(url),
        trailing: IconButton(
          tooltip: 'מחיקה',
          onPressed: _saving ? null : () => _removeFile(file),
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
        ),
      ),
    );
  }

  Widget _pendingFileTile(int index, _PendingMenuFile file) => ListTile(
        leading: Icon(file.type == 'pdf'
            ? Icons.picture_as_pdf_outlined
            : Icons.image_outlined),
        title: Text(file.name),
        subtitle: const Text('יצורף לתפריט לאחר שמירה'),
        trailing: IconButton(
          tooltip: 'הסרה',
          onPressed: _saving
              ? null
              : () => setState(() => _pendingFiles.removeAt(index)),
          icon: const Icon(Icons.close),
        ),
      );

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: Text('תפריט · ${widget.place['name']}'),
            actions: const [HomeButton()]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(padding: const EdgeInsets.all(18), children: [
                    if (_files.isEmpty && _pendingFiles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text('עדיין לא נוספו קובצי תפריט'),
                      ),
                    for (final file in _files) _existingFileTile(file),
                    for (var index = 0; index < _pendingFiles.length; index++)
                      _pendingFileTile(index, _pendingFiles[index]),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _showFileOptions,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('הוספת תמונות או קובצי PDF'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                          labelText: 'הערה קצרה לתפריט (רשות)'),
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

class PlaceOpeningHoursManagerScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  const PlaceOpeningHoursManagerScreen({super.key, required this.place});

  @override
  State<PlaceOpeningHoursManagerScreen> createState() =>
      _PlaceOpeningHoursManagerScreenState();
}

class _PlaceOpeningHoursManagerScreenState
    extends State<PlaceOpeningHoursManagerScreen> {
  static const _days = [
    'ראשון',
    'שני',
    'שלישי',
    'רביעי',
    'חמישי',
    'שישי',
    'שבת'
  ];
  late List<Map<String, dynamic>> _schedule;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _schedule = [
      for (var i = 0; i < _days.length; i++)
        {
          'day': i,
          'label': _days[i],
          'open': false,
          'from': '08:00',
          'to': i == 5 ? '14:00' : '20:00'
        }
    ];
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await Supabase.instance.client
          .from('place_opening_hours')
          .select('schedule')
          .eq('place_id', widget.place['id'])
          .maybeSingle();
      final saved = row?['schedule'];
      if (saved is List && saved.length == 7) {
        _schedule = [
          for (final item in saved) Map<String, dynamic>.from(item as Map)
        ];
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickTime(int index, String key) async {
    final parts = (_schedule[index][key] as String).split(':');
    final value = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (value != null && mounted) {
      setState(() => _schedule[index][key] =
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.from('place_opening_hours').upsert({
        'place_id': widget.place['id'],
        'content': '',
        'schedule': _schedule,
        'updated_by': Supabase.instance.client.auth.currentUser!.id,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('שעות הפתיחה נשמרו ופורסמו')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('לא ניתן לשמור את שעות הפתיחה')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
            title: Text('שעות פתיחה · ${widget.place['name']}'),
            actions: const [HomeButton()]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView(
                      padding: const EdgeInsets.all(18),
                      children: [
                        for (var i = 0; i < _schedule.length; i++)
                          Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(children: [
                                    SwitchListTile(
                                      value: _schedule[i]['open'] == true,
                                      title: Text('יום ${_days[i]}'),
                                      subtitle: Text(
                                          _schedule[i]['open'] == true
                                              ? 'פתוח'
                                              : 'סגור'),
                                      onChanged: (value) => setState(
                                          () => _schedule[i]['open'] = value),
                                    ),
                                    if (_schedule[i]['open'] == true)
                                      Row(children: [
                                        Expanded(
                                            child: OutlinedButton(
                                                onPressed: () =>
                                                    _pickTime(i, 'from'),
                                                child: Text(
                                                    'משעה ${_schedule[i]['from']}'))),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: OutlinedButton(
                                                onPressed: () =>
                                                    _pickTime(i, 'to'),
                                                child: Text(
                                                    'עד ${_schedule[i]['to']}'))),
                                      ]),
                                  ]))),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_saving ? 'שומר...' : 'שמירה ופרסום')),
                      ],
                    )),
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
                    source: source,
                    imageQuality: ImageUploadPolicy.photoQuality,
                    maxWidth: ImageUploadPolicy.photoMaxDimension,
                    maxHeight: ImageUploadPolicy.photoMaxDimension)
                case final image?)
              image
          ]
        : await _picker.pickMultiImage(
            imageQuality: ImageUploadPolicy.photoQuality,
            maxWidth: ImageUploadPolicy.photoMaxDimension,
            maxHeight: ImageUploadPolicy.photoMaxDimension,
          );
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
                          child: Image.network(
                              optimizedSupabaseImageUrl(
                                  image['image_url'].toString(),
                                  width: 480,
                                  height: 480),
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
          .select('id,visit_id,body,created_by')
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

  Future<void> _deleteReply(Map<String, dynamic> reply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('מחיקת התגובה הרשמית'),
        content: const Text('התגובה שלך תימחק מהחוויה. להמשיך?'),
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
    await Supabase.instance.client
        .from('place_official_replies')
        .delete()
        .eq('id', reply['id']);
    await _load();
  }

  Future<void> _reportVisit(Map<String, dynamic> visit) async {
    final controller = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('דיווח על חוויה לא הולמת'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'מה לא תקין בחוויה?',
            hintText: 'הסבר קצר שיעזור למנהל לבדוק את הדיווח',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('שליחת דיווח')),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (send != true || reason.length < 2) return;
    try {
      final report = await Supabase.instance.client
          .from('visit_reports')
          .insert({
            'visit_id': visit['id'],
            'reporter_id': Supabase.instance.client.auth.currentUser!.id,
            'reason': reason,
          })
          .select('id')
          .single();
      await NotificationDispatchService.send(
        eventType: 'visit_report',
        resourceId: report['id'].toString(),
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('הדיווח נשלח והחוויה הוסתרה עד לבדיקת מנהל'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('החוויה כבר דווחה או שלא ניתן לשלוח את הדיווח'),
        ));
      }
    }
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
                  final ownsReply = reply?['created_by']?.toString() ==
                      Supabase.instance.client.auth.currentUser?.id;
                  return Card(
                      child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            (visit['notes']?.toString().trim().isNotEmpty ??
                                    false)
                                ? visit['notes'].toString()
                                : 'חוויה ללא מלל',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 7),
                          Text(reply == null
                              ? 'אין תגובה רשמית'
                              : 'תגובת העסק: ${reply['body']}'),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            OutlinedButton.icon(
                              onPressed: () => _editReply(visit),
                              icon: const Icon(Icons.reply_rounded),
                              label:
                                  Text(reply == null ? 'תגובה' : 'עריכת תגובה'),
                            ),
                            if (reply != null &&
                                (ownsReply || Permissions.canManageContent))
                              OutlinedButton.icon(
                                onPressed: () => _deleteReply(reply),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('מחיקת התגובה'),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => _reportVisit(visit),
                              icon: const Icon(Icons.flag_outlined),
                              label: const Text('דיווח על החוויה'),
                            ),
                          ]),
                        ]),
                  ));
                },
              ),
      );
}
