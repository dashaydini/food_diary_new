// ignore_for_file: use_build_context_synchronously
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../../place/models/place.dart';
import '../../place/repositories/firebase_place_repository.dart';

import '../../place/screens/place_details_screen.dart';

class AddCoffeeCartScreen extends StatefulWidget {
  final String category;

  const AddCoffeeCartScreen({
    super.key,
    this.category = 'עגלות קפה',
  });

  @override
  State<AddCoffeeCartScreen> createState() => _AddCoffeeCartScreenState();
}

class _AddCoffeeCartScreenState extends State<AddCoffeeCartScreen> {
  final nameController = TextEditingController();

  final locationController = TextEditingController();

  final picker = ImagePicker();

  String imageBase64 = '';

  double latitude = 0;

  double longitude = 0;

  bool favorite = false;

  bool loadingLocation = false;

  bool saving = false;

  Future<void> pickImage() async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
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
        "$address, Israel",
      );

      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/search?"
        "q=$encoded&format=json&limit=1",
      );

      final response = await http.get(
        url,
        headers: {
          "User-Agent": "CoffeeDiaryApp",
        },
      );

      if (response.statusCode != 200) {
        return;
      }

      final data = jsonDecode(response.body);

      if (data is List && data.isNotEmpty) {
        setState(() {
          latitude = double.parse(
            data[0]["lat"],
          );

          longitude = double.parse(
            data[0]["lon"],
          );
        });
      }
    } catch (e) {
      debugPrint(
        "Geocode error: $e",
      );
    }
  }

  Future<void> save() async {
    if (saving) {
      return;
    }

    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "צריך שם לעגלה",
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

    final cart = Place(
      name: nameController.text.trim(),
      location: locationController.text.trim(),
      visits: [],
      imageBase64: imageBase64,
      favorite: favorite,
      latitude: latitude,
      longitude: longitude,
      ownerName: FirebaseAuth.instance.currentUser?.uid ==
              'gGKgCYdaWHgV45wePSbouhv5hLq2'
          ? 'Shay Dini'
          : FirebaseAuth.instance.currentUser?.uid ==
                  'tAK3wd1LFbMMNZv8uG5daE4EW2j2'
              ? 'Daria'
              : '',
      ownerId: FirebaseAuth.instance.currentUser?.uid ?? '',
      createdAt: DateTime.now(),
      category: widget.category,
    );

    final result = await FirebasePlaceRepository().addPlace(cart);

    if (!mounted) {
      return;
    }

    if (result != null && result.firebaseId != cart.firebaseId) {
      setState(() {
        saving = false;
      });

      final open = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              "העגלה כבר קיימת ☕",
            ),
            content: Text(
              "${result.name}\n\n"
              "העגלה כבר נמצאת במערכת. "
              "רוצה להיכנס אליה?",
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
                  "ביטול",
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
                  "כניסה לעגלה",
                ),
              ),
            ],
          );
        },
      );

      if (open == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PlaceDetailsScreen(
              place: result,
            ),
          ),
        );
      }

      return;
    }

    Navigator.pop(
      context,
      result,
    );
  }

  @override
  void dispose() {
    nameController.dispose();

    locationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "הוספת עגלת קפה",
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
                        base64Decode(
                          imageBase64,
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "שם העגלה",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: locationController,
            decoration: const InputDecoration(
              labelText: "מיקום",
              hintText: "לדוגמה: באר טוביה",
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
              "קבל מיקום נוכחי",
            ),
          ),
          if (latitude != 0 && longitude != 0)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                "GPS:\n$latitude\n$longitude",
              ),
            ),
          SwitchListTile(
            title: const Text(
              "מועדפת ⭐",
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
                ? const CircularProgressIndicator()
                : const Text(
                    "שמירה",
                  ),
          ),
        ],
      ),
    );
  }
}
