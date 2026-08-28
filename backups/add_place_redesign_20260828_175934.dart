import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../widgets/home_button.dart';
import '../utils/permissions.dart';
import 'place_details_screen.dart';

class AddPlaceScreen extends StatefulWidget {
  final String categoryId;
  final String categoryTitle;
  final Map<String, dynamic>? place;

  // ignore: prefer_const_constructors_in_immutables
  AddPlaceScreen({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    this.place,
  });

  bool get isEditing => place != null;

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  XFile? _selectedImage;

  double? _latitude;
  double? _longitude;

  bool _usingCurrentLocation = false;
  bool _saving = false;
  bool _loadingLocation = false;

  String? _error;

  bool _hasUnsavedChanges() {
    return _nameController.text.trim().isNotEmpty ||
        _addressController.text.trim().isNotEmpty ||
        _selectedImage != null ||
        _latitude != null ||
        _longitude != null ||
        _usingCurrentLocation;
  }

  Future<void> _handleBack() async {
    if (!_hasUnsavedChanges()) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('שינויים שלא נשמרו'),
          content: Text('יש שינויים שלא נשמרו. מה תרצה לעשות?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop('cancel');
              },
              child: Text('ביטול'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop('discard');
              },
              child: Text('יציאה ללא שמירה'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop('save');
              },
              child: Text('שמירת שינויים'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (result == 'discard') {
      Navigator.of(context).pop();
      return;
    }

    if (result == 'save') {
      await _savePlace();
    }
  }

  @override
  void initState() {
    super.initState();

    final place = widget.place;

    if (place != null) {
      _nameController.text = place['name']?.toString() ?? '';
      _addressController.text = place['address']?.toString() ?? '';

      _latitude = (place['latitude'] as num?)?.toDouble();
      _longitude = (place['longitude'] as num?)?.toDouble();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _chooseImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt_outlined),
                title: Text('צילום במצלמה'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined),
                title: Text('בחירה מהגלריה'),
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
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (!mounted || image == null) return;

      setState(() {
        _selectedImage = image;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'לא ניתן לבחור תמונה';
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _loadingLocation = true;
      _error = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception('שירותי המיקום כבויים');
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('אין הרשאה למיקום');
      }

      final position = await Geolocator.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _usingCurrentLocation = true;
        _loadingLocation = false;
      });

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;

          final parts = <String>[
            if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
            if ((place.locality ?? '').trim().isNotEmpty)
              place.locality!.trim(),
            if ((place.country ?? '').trim().isNotEmpty) place.country!.trim(),
          ];

          if (parts.isNotEmpty) {
            _addressController.text = parts.join(', ');
          }
        }
      } catch (_) {
        // המיקום נשמר גם אם לא הצלחנו להפיק כתובת.
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingLocation = false;
        _usingCurrentLocation = false;
        _error = 'לא ניתן לקבל את המיקום הנוכחי';
      });
    }
  }

  Future<void> _searchAddress() async {
    final address = _addressController.text.trim();

    if (address.isEmpty) {
      setState(() {
        _error = 'יש להזין כתובת לחיפוש';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loadingLocation = true;
      _error = null;
      _usingCurrentLocation = false;
    });

    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': address,
          'format': 'jsonv2',
          'limit': '1',
          'addressdetails': '1',
          'accept-language': 'he',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'FoodDiary/1.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('שגיאת חיפוש (${response.statusCode})');
      }

      final results = jsonDecode(response.body) as List<dynamic>;

      if (results.isEmpty) {
        throw Exception('לא נמצאה כתובת');
      }

      final result = results.first as Map<String, dynamic>;

      final latitude = double.tryParse(result['lat']?.toString() ?? '');
      final longitude = double.tryParse(result['lon']?.toString() ?? '');

      if (latitude == null || longitude == null) {
        throw Exception('לא התקבל מיקום תקין');
      }

      if (!mounted) return;

      setState(() {
        _latitude = latitude;
        _longitude = longitude;
        _loadingLocation = false;
        _addressController.text = result['display_name']?.toString() ?? address;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingLocation = false;
        _latitude = null;
        _longitude = null;
        _error = 'לא נמצאה כתובת. נסה להזין כתובת מלאה יותר.';
      });
    }
  }

  Widget _buildLocationMap() {
    if (_latitude == null || _longitude == null) {
      return SizedBox.shrink();
    }

    final point = LatLng(_latitude!, _longitude!);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 260,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 16,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fooddiary.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 50,
                  height: 50,
                  child: Icon(
                    Icons.location_pin,
                    size: 50,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _checkForExistingPlace(
    String name,
    String categoryId,
  ) async {
    final normalizedName = name.trim().toLowerCase();

    final rows = await Supabase.instance.client
        .from('places')
        .select()
        .eq('category_id', categoryId);

    for (final row in (rows as List)) {
      final existingName = (row['name'] as String?)?.trim().toLowerCase();

      if (existingName == normalizedName) {
        return Map<String, dynamic>.from(row);
      }
    }

    return null;
  }

  Future<void> _savePlace() async {
    if (!_formKey.currentState!.validate()) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null || user.isAnonymous) {
      setState(() {
        _error = 'יש להתחבר עם חשבון כדי לשמור את המקום';
      });
      return;
    }

    final existingPlace = widget.place;

    if (existingPlace != null &&
        !Permissions.canEditPlace(
          existingPlace['user_id']?.toString(),
        )) {
      setState(() {
        _error = 'אין לך הרשאה לערוך את המקום הזה';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;

      final currentSession = client.auth.currentSession;
      final currentUser = client.auth.currentUser;

      if (currentSession == null || currentUser == null) {
        throw Exception('אין Session פעיל');
      }

      if (currentUser.isAnonymous) {
        throw Exception('המשתמש מחובר כאורח');
      }

      final isEditing = existingPlace != null;
      final placeId = isEditing ? existingPlace['id'].toString() : Uuid().v4();

      String? imageUrl = existingPlace?['image_url']?.toString();

      if (_selectedImage != null) {
        final extension = _selectedImage!.name.split('.').last.toLowerCase();

        final filePath = '${user.id}/$placeId.$extension';

        if (kIsWeb) {
          await client.storage.from('place-images').uploadBinary(
                filePath,
                await _selectedImage!.readAsBytes(),
                fileOptions: FileOptions(
                  upsert: true,
                ),
              );
        } else {
          await client.storage.from('place-images').upload(
                filePath,
                File(_selectedImage!.path),
                fileOptions: FileOptions(
                  upsert: true,
                ),
              );
        }

        imageUrl =
            '${client.storage.from('place-images').getPublicUrl(filePath)}?v=${DateTime.now().millisecondsSinceEpoch}';
      }

      if (!isEditing) {
        final duplicate = await _checkForExistingPlace(
          _nameController.text.trim(),
          widget.categoryId,
        );

        if (duplicate != null) {
          await _showDuplicatePlaceDialog(duplicate);

          if (mounted) {
            setState(() {
              _saving = false;
            });
          }

          return;
        }
      }

      final data = {
        'category_id': widget.categoryId,
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'image_url': imageUrl,
      };

      if (isEditing) {
        await client.from('places').update(data).eq('id', placeId);
      } else {
        await client.from('places').insert({
          'id': placeId,
          'user_id': user.id,
          ...data,
        });
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      String message;

      if (e is StorageException) {
        message = 'שגיאת Storage (${e.statusCode}): ${e.message}';
      } else if (e is PostgrestException) {
        message = 'שגיאת מסד נתונים: ${e.message}';
      } else {
        message = e.toString();
      }

      if (message.length > 500) {
        message = message.substring(0, 500);
      }

      setState(() {
        _saving = false;
        _error = message;
      });
    }
  }

  Future<void> _showDuplicatePlaceDialog(
    Map<String, dynamic> existingPlace,
  ) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          title: Text(
            'המקום כבר קיים',
            textAlign: TextAlign.right,
          ),
          content: Text(
            'המקום "${existingPlace['name'] ?? ''}" כבר קיים בקטגוריה הזו.',
            textAlign: TextAlign.right,
          ),
          actionsAlignment: MainAxisAlignment.end,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('ביטול'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PlaceDetailsScreen(
                      place: existingPlace,
                    ),
                  ),
                );
              },
              child: Text('מעבר למקום'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          actions: [
            HomeButton(),
          ],
          title: Text(
            widget.isEditing ? 'עריכת מקום' : 'הוספת מקום',
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(24),
              children: [
                Text(
                  widget.categoryTitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.muted.withValues(alpha: 0.54),
                  ),
                ),
                SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'שם המקום',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'יש להזין שם מקום';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _chooseImage,
                  child: Center(
                    child: SizedBox(
                      width: 260,
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: _selectedImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 42,
                                      color: AppColors.muted
                                          .withValues(alpha: 0.45),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'הוסף תמונה',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppColors.muted
                                            .withValues(alpha: 0.54),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'מצלמה או גלריה',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.muted
                                            .withValues(alpha: 0.38),
                                      ),
                                    ),
                                  ],
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    alignment: Alignment.center,
                                    color: AppColors.card,
                                    child: kIsWeb
                                        ? Image.network(
                                            _selectedImage!.path,
                                            fit: BoxFit.contain,
                                          )
                                        : Image.file(
                                            File(_selectedImage!.path),
                                            fit: BoxFit.contain,
                                          ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'מיקום',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _loadingLocation ? null : _useCurrentLocation,
                  icon: _loadingLocation
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.my_location),
                  label: Text(
                    _usingCurrentLocation
                        ? 'המיקום הנוכחי נבחר'
                        : 'שימוש במיקום הנוכחי',
                  ),
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _addressController,
                  onChanged: (_) {
                    if (_usingCurrentLocation ||
                        _latitude != null ||
                        _longitude != null) {
                      setState(() {
                        _usingCurrentLocation = false;
                        _latitude = null;
                        _longitude = null;
                      });
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'חיפוש לפי כתובת',
                    hintText: 'לדוגמה: הרצל 10, תל אביב',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _loadingLocation ? null : _searchAddress,
                  icon: _loadingLocation
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.search),
                  label: Text('חיפוש כתובת'),
                ),
                SizedBox(height: 16),
                _buildLocationMap(),
                if (_error != null) ...[
                  SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ],
                SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _savePlace,
                    child: _saving
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(),
                          )
                        : Text(
                            'שמירת מקום',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
