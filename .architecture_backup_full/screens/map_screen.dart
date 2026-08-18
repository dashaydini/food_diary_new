import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../repositories/firebase_coffee_cart_repository.dart';
import '../services/location_service.dart';

import '../models/place.dart';
import '../models/coffee_cart.dart';
import 'coffee_cart/coffee_cart_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController mapController = MapController();

  final FirebaseCoffeeCartRepository firebaseRepository =
      FirebaseCoffeeCartRepository();

  LatLng? currentLocation;

  bool loadingLocation = false;

  Future<void> getCurrentLocation() async {
    setState(() {
      loadingLocation = true;
    });

    final position = await LocationService.getCurrentLocation();

    if (position == null) {
      setState(() {
        loadingLocation = false;
      });

      return;
    }

    final point = LatLng(
      position.latitude,
      position.longitude,
    );

    setState(() {
      currentLocation = point;

      loadingLocation = false;
    });

    mapController.move(
      point,
      15,
    );
  }

  Future<void> openNavigation(Place cart) async {
    if (cart.latitude == 0 || cart.longitude == 0) {
      return;
    }

    final url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=${cart.latitude},${cart.longitude}",
    );

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  void openCartDetails(CoffeeCart cart) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CoffeeCartDetailsScreen(
          cart: cart,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "מפת עגלות",
        ),
        actions: [
          IconButton(
            icon: loadingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.my_location,
                  ),
            tooltip: "המיקום שלי",
            onPressed: loadingLocation ? null : getCurrentLocation,
          ),
        ],
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: firebaseRepository.getCoffeeCarts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final carts = (snapshot.data ?? [])
              .where(
                (cart) => cart.latitude != 0 && cart.longitude != 0,
              )
              .toList();

          if (carts.isEmpty) {
            return const Center(
              child: Text(
                "אין עגלות עם מיקום",
              ),
            );
          }

          return FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentLocation ??
                  LatLng(
                    carts.first.latitude,
                    carts.first.longitude,
                  ),
              initialZoom: 12,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.food_diary",
              ),
              MarkerLayer(
                markers: [
                  ...carts.map(
                    (cart) => Marker(
                      point: LatLng(
                        cart.latitude,
                        cart.longitude,
                      ),
                      width: 70,
                      height: 70,
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (_) => Directionality(
                              textDirection: TextDirection.rtl,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      cart.name,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "⭐ ${cart.score.toStringAsFixed(1)}",
                                    ),
                                    Text(
                                      "ביקורים: ${cart.visitsCount}",
                                    ),
                                    const SizedBox(
                                      height: 20,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.pop(context);

                                            openCartDetails(
                                              cart,
                                            );
                                          },
                                          child: const Text(
                                            "פתח עגלה",
                                          ),
                                        ),
                                        FilledButton.icon(
                                          onPressed: () {
                                            openNavigation(
                                              cart,
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.navigation,
                                          ),
                                          label: const Text(
                                            "נווט",
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Icon(
                          Icons.local_cafe,
                          size: 45,
                        ),
                      ),
                    ),
                  ),
                  if (currentLocation != null)
                    Marker(
                      point: currentLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.person_pin_circle,
                        size: 45,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
