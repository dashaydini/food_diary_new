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
      });

      String? resolvedAddress;
      if (!kIsWeb) {
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
              if ((place.country ?? '').trim().isNotEmpty)
                place.country!.trim(),
            ];

            if (parts.isNotEmpty) {
              resolvedAddress = parts.join(', ');
            }
          }
        } catch (_) {
          // Fall back to the web-compatible reverse geocoder below.
        }
      }

      resolvedAddress ??= await _reverseGeocodeWithNominatim(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _loadingLocation = false;
        if (resolvedAddress?.isNotEmpty == true) {
          _addressController.text = resolvedAddress!;
        } else {
          _error = 'המיקום נבחר, אך לא נמצאה כתובת. אפשר להזין אותה ידנית.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingLocation = false;
        _usingCurrentLocation = false;
        _error = 'לא ניתן לקבל את המיקום הנוכחי';
      });
    }
  }

  Future<String?> _reverseGeocodeWithNominatim(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.https(
        'nominatim.openstreetmap.org',
        '/reverse',
        {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'format': 'jsonv2',
          'addressdetails': '1',
          'accept-language': 'he',
          'zoom': '18',
        },
      );
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'FoodDiary/1.0'},
      );
      if (response.statusCode != 200) return null;

      final result = jsonDecode(response.body) as Map<String, dynamic>;
      final address = result['address'];
      if (address is Map) {
        final road = (address['road'] ??
                address['pedestrian'] ??
                address['footway'] ??
                address['neighbourhood'])
            ?.toString()
            .trim();
        final houseNumber = address['house_number']?.toString().trim();
        final city = (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['municipality'])
            ?.toString()
            .trim();
        final locality =
            (address['suburb'] ?? address['quarter'])?.toString().trim();
        final parts = <String>[
          if (road?.isNotEmpty == true)
            [road, if (houseNumber?.isNotEmpty == true) houseNumber]
                .whereType<String>()
                .join(' '),
          if (locality?.isNotEmpty == true && locality != city) locality!,
          if (city?.isNotEmpty == true) city!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }

      final displayName = result['display_name']?.toString().trim();
      return displayName?.isNotEmpty == true ? displayName : null;
    } catch (_) {
      return null;
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
    final theme = Theme.of(context);

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
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            widget.isEditing ? 'עריכת מקום' : 'הוספת מקום',
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w400,
            ),
          ),
          leading: IconButton(
            tooltip: 'חזרה',
            onPressed: _handleBack,
            icon: const Icon(
              Icons.arrow_forward_rounded,
              textDirection: TextDirection.ltr,
              color: AppColors.champagne,
            ),
          ),
          actions: const [
            HomeButton(),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mobile = constraints.maxWidth < 700;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        mobile ? 16 : 28,
                        mobile ? 14 : 20,
                        mobile ? 16 : 28,
                        32,
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            widget.categoryTitle,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _placeField(
                          controller: _nameController,
                          label: 'שם המקום',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'יש להזין שם מקום';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        _buildImagePickerCard(),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'מיקום',
                            textAlign: TextAlign.right,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed:
                                _loadingLocation ? null : _useCurrentLocation,
                            icon: _loadingLocation
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.6,
                                    ),
                                  )
                                : const Icon(
                                    Icons.my_location_outlined,
                                    size: 18,
                                  ),
                            label: Text(
                              _usingCurrentLocation
                                  ? 'המיקום הנוכחי נבחר'
                                  : 'שימוש במיקום הנוכחי',
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _placeField(
                          controller: _addressController,
                          label: 'חיפוש לפי כתובת',
                          hintText: 'לדוגמה: הרצל 10, תל אביב',
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
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 46,
                          child: OutlinedButton.icon(
                            onPressed: _loadingLocation ? null : _searchAddress,
                            icon: _loadingLocation
                                ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.6,
                                    ),
                                  )
                                : const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                  ),
                            label: const Text('חיפוש כתובת'),
                          ),
                        ),
                        if (_latitude != null && _longitude != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color:
                                    AppColors.champagne.withValues(alpha: 0.14),
                                width: 0.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.champagne
                                      .withValues(alpha: 0.03),
                                  blurRadius: 24,
                                  spreadRadius: -6,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: _buildLocationMap(),
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.right,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.danger.withValues(alpha: 0.88),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 26),
                        SizedBox(
                          height: 50,
                          child: FilledButton(
                            onPressed: _saving ? null : _savePlace,
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                    ),
                                  )
                                : const Text(
                                    'שמירת מקום',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _placeField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: TextInputAction.next,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: AppColors.background,
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
    );
  }

  Widget _buildImagePickerCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _chooseImage,
      child: Center(
        child: SizedBox(
          width: 280,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.champagne.withValues(alpha: 0.15),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.champagne.withValues(alpha: 0.035),
                    blurRadius: 28,
                    spreadRadius: -6,
                  ),
                ],
              ),
              child: _selectedImage == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 34,
                          color: AppColors.champagne.withValues(alpha: 0.62),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'הוסף תמונה',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'מצלמה או גלריה',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Container(
                        alignment: Alignment.center,
                        color: AppColors.background,
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
    );
  }
}
