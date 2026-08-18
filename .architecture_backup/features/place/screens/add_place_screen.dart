import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/place.dart';
import '../repositories/firebase_place_repository.dart';

class AddPlaceScreen extends StatefulWidget {
  final String category;
  final String itemName;

  const AddPlaceScreen({
    super.key,
    required this.category,
    required this.itemName,
  });

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final nameController = TextEditingController();
  final locationController = TextEditingController();

  final picker = ImagePicker();
  final repository = FirebasePlaceRepository();

  String imageBase64 = '';

  double latitude = 0;
  double longitude = 0;

  bool favorite = false;
  bool loadingLocation = false;
  bool saving = false;

  Future<void> pickImage() async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();

    setState(() {
      imageBase64 = base64Encode(bytes);
    });
  }

  Future<void> getLocation() async {
    setState(() {
      loadingLocation = true;
    });

    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      setState(() {
        loadingLocation = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        loadingLocation = false;
      });
      return;
    }

    final position = await Geolocator.getCurrentPosition();

    if (!mounted) {
      return;
    }

    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
      loadingLocation = false;
    });
  }

  Future<void> getCoordinatesFromAddress() async {
    final address = locationController.text.trim();

    if (address.isEmpty) {
      return;
    }

    try {
      final encoded = Uri.encodeComponent(
        '$address, Israel',
      );

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=$encoded&format=json&limit=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'FoodDiaryApp',
        },
      );

      if (response.statusCode != 200) {
        return;
      }

      final data = jsonDecode(response.body);

      if (data is List && data.isNotEmpty && mounted) {
        setState(() {
          latitude = double.tryParse(
                data[0]['lat'].toString(),
              ) ??
              0;

          longitude = double.tryParse(
                data[0]['lon'].toString(),
              ) ??
              0;
        });
      }
    } catch (e) {
      debugPrint(
        'Geocode error: $e',
      );
    }
  }

  Future<void> save() async {
    if (saving) {
      return;
    }

    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'צריך שם למקום',
          ),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    if (latitude == 0 || longitude == 0) {
      await getCoordinatesFromAddress();
    }

    final user = FirebaseAuth.instance.currentUser;

    final place = Place(
      name: name,
      location: locationController.text.trim(),
      visits: [],
      imageBase64: imageBase64,
      favorite: favorite,
      latitude: latitude,
      longitude: longitude,
      ownerName: user?.displayName ?? '',
      ownerId: user?.uid ?? '',
      createdAt: DateTime.now(),
      category: widget.category,
    );

    try {
      final result = await repository.addPlace(place);

      if (!mounted) {
        return;
      }

      setState(() {
        saving = false;
      });

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'לא ניתן היה לשמור את המקום',
            ),
          ),
        );
        return;
      }

      if (result.firebaseId != place.firebaseId) {
        final open = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text(
                'המקום כבר קיים',
              ),
              content: Text(
                '${result.name}\n\n'
                'המקום כבר נמצא במערכת. רוצה להיכנס אליו?',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      false,
                    );
                  },
                  child: const Text(
                    'ביטול',
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      true,
                    );
                  },
                  child: const Text(
                    'כניסה למקום',
                  ),
                ),
              ],
            );
          },
        );

        if (open == true && mounted) {
          Navigator.pop(
            context,
            result,
          );
        }

        return;
      }

      Navigator.pop(
        context,
        result,
      );
    } catch (e) {
      debugPrint(
        'SAVE PLACE ERROR: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'שגיאה בשמירת המקום: $e',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'הוספת ${widget.itemName}',
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: pickImage,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: imageBase64.isEmpty
                    ? const Icon(
                        Icons.add_a_photo,
                        size: 60,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(
                          base64Decode(imageBase64),
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'שם המקום',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: 'מיקום',
                hintText: 'לדוגמה: באר טוביה',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: loadingLocation ? null : getLocation,
              icon: const Icon(
                Icons.my_location,
              ),
              label: const Text(
                'קבל מיקום נוכחי',
              ),
            ),
            if (latitude != 0 && longitude != 0)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'GPS:\n$latitude\n$longitude',
                ),
              ),
            SwitchListTile(
              title: const Text(
                'מועדף ⭐',
              ),
              value: favorite,
              onChanged: (value) {
                setState(() {
                  favorite = value;
                });
              },
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: saving ? null : save,
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'שמור',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
