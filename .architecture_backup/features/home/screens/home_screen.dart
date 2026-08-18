import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../place/repositories/firebase_place_repository.dart';

import '../../../core/services/location_service.dart';

import '../../place/widgets/place_card.dart';

import '../../place/screens/add_place_screen.dart';
import '../../visit/screens/add_visit_screen.dart';
import '../../place/screens/place_details_screen.dart';
import '../../map/screens/map_screen.dart';
import '../../place/models/place.dart';

class HomeScreen extends StatefulWidget {
  final String categoryTitle;
  final String itemName;

  const HomeScreen({
    super.key,
    this.categoryTitle = "עגלות קפה",
    this.itemName = "עגלה",
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebasePlaceRepository placeRepository = FirebasePlaceRepository();

  final TextEditingController searchController = TextEditingController();

  String search = '';

  bool favoritesOnly = false;

  bool myContentOnly = false;

  String sort = 'none';

  Position? currentPosition;

  @override
  void initState() {
    super.initState();

    loadLocation();
  }

  Future<void> loadLocation() async {
    final position = await LocationService.getCurrentLocation();

    if (position != null && mounted) {
      setState(() {
        currentPosition = position;
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();

    super.dispose();
  }

  String _categoryId(String title) {
    switch (title) {
      case 'בתי קפה':
        return 'coffee';
      case 'עגלות קפה':
        return 'coffee_cart';
      case 'מסעדות':
        return 'restaurant';
      case 'פוד טראק':
        return 'food_truck';
      case 'פאבים':
        return 'pub';
      case 'מאפיות':
        return 'bakery';
      case 'ברים':
        return 'cocktail_bar';
      case 'אוכל רחוב':
        return 'street_food';
      default:
        return 'other';
    }
  }

  List filterCarts(List carts) {
    final result = carts.where((cart) {
      final text = search.trim().toLowerCase();

      bool matchSearch = text.isEmpty;

      if (!matchSearch) {
        final searchable = <String>[
          cart.name,
          cart.location,
        ];

        for (final visit in cart.visits) {
          searchable.add(
            visit.dish,
          );

          searchable.add(
            visit.notes,
          );

          searchable.addAll(
            visit.tags,
          );
        }

        matchSearch = searchable.any(
          (item) => item.toLowerCase().contains(text),
        );
      }

      final matchFavorite = !favoritesOnly || cart.favorite;

      final matchOwner = !myContentOnly ||
          cart.ownerId == FirebaseAuth.instance.currentUser?.uid;

      final matchCategory = cart.category == _categoryId(widget.categoryTitle);

      return matchSearch && matchFavorite && matchOwner && matchCategory;
    }).toList();

    if (sort == 'score') {
      result.sort(
        (a, b) => b.score.compareTo(
          a.score,
        ),
      );
    }

    if (sort == 'visits') {
      result.sort(
        (a, b) => b.visitsCount.compareTo(
          a.visitsCount,
        ),
      );
    }

    if (sort == 'distance' && currentPosition != null) {
      result.sort(
        (a, b) {
          final distanceA = Geolocator.distanceBetween(
            currentPosition!.latitude,
            currentPosition!.longitude,
            a.latitude,
            a.longitude,
          );

          final distanceB = Geolocator.distanceBetween(
            currentPosition!.latitude,
            currentPosition!.longitude,
            b.latitude,
            b.longitude,
          );

          return distanceA.compareTo(
            distanceB,
          );
        },
      );
    }

    return result;
  }

  Future<void> refresh() async {
    if (mounted) {
      setState(() {});
    }
  }

  Future openNavigation(Place place) async {
    if (place.latitude == 0 || place.longitude == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "אין מיקום GPS למקום",
          ),
        ),
      );

      return;
    }

    final url = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=${place.latitude},${place.longitude}",
    );

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  Future addVisit(Place place) async {
    if (FirebaseAuth.instance.currentUser?.isAnonymous == true) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddVisitScreen(
          cart: place,
        ),
      ),
    );

    await refresh();
  }

  Future toggleFavorite(Place place) async {
    setState(() {
      place.favorite = !place.favorite;
    });

    await placeRepository.updatePlace(
      place,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'HOME SCREEN ACTIVE: category=${widget.categoryTitle} item=${widget.itemName}',
    );

    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final user = FirebaseAuth.instance.currentUser;

            final greeting = user?.isAnonymous == true
                ? "שלום אורח"
                : "שלום, ${user?.displayName?.trim().isNotEmpty == true ? user!.displayName!.trim() : "משתמש"}";

            return Text(greeting);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.map,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MapScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              favoritesOnly ? Icons.star : Icons.star_border,
            ),
            onPressed: () {
              setState(() {
                favoritesOnly = !favoritesOnly;
              });
            },
          ),
          IconButton(
            icon: Icon(
              myContentOnly ? Icons.person : Icons.groups,
              color:
                  myContentOnly ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: myContentOnly ? 'הצג את כולם' : 'הצג רק שלי',
            onPressed: () {
              setState(() {
                myContentOnly = !myContentOnly;
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                sort = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'none',
                child: Text(
                  "ללא מיון",
                ),
              ),
              const PopupMenuItem(
                value: 'score',
                child: Text(
                  "לפי ציון",
                ),
              ),
              const PopupMenuItem(
                value: 'visits',
                child: Text(
                  "לפי ביקורים",
                ),
              ),
              const PopupMenuItem(
                value: 'distance',
                child: Text(
                  "לפי מרחק",
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton:
          FirebaseAuth.instance.currentUser?.isAnonymous == true
              ? null
              : FloatingActionButton.extended(
                  icon: const Icon(
                    Icons.add,
                  ),
                  label: Text(
                    widget.itemName,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddPlaceScreen(
                          category: _categoryId(widget.categoryTitle),
                          itemName: widget.itemName,
                        ),
                      ),
                    );

                    await refresh();
                  },
                ),
      body: StreamBuilder<List<dynamic>>(
        stream: placeRepository.getPlaces(
          category: _categoryId(widget.categoryTitle),
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("======================================");
            debugPrint("HOME STREAM ERROR");
            debugPrint("${snapshot.error}");
            debugPrint("${snapshot.stackTrace}");
            debugPrint("======================================");

            return Center(
              child: Text(
                "שגיאה בטעינת העגלות:\n${snapshot.error}",
                textDirection: TextDirection.rtl,
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final allCarts = snapshot.data ?? [];

          final carts = filterCarts(
            allCarts,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: "חיפוש ${widget.itemName}",
                    prefixIcon: const Icon(
                      Icons.search,
                    ),
                    suffixIcon: search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                            ),
                            onPressed: () {
                              searchController.clear();

                              setState(() {
                                search = '';
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      search = value;
                    });
                  },
                ),
              ),
              Text(
                "נמצאו ${carts.length} ${widget.itemName}",
              ),
              Expanded(
                child: carts.isEmpty
                    ? Center(
                        child: Text(
                          "אין ${widget.itemName} עדיין",
                        ),
                      )
                    : ListView.builder(
                        itemCount: carts.length,
                        itemBuilder: (context, index) {
                          final cart = carts[index];

                          return PlaceCard(
                            place: cart,
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlaceDetailsScreen(
                                    place: cart,
                                    myContentOnly: myContentOnly,
                                  ),
                                ),
                              );

                              await refresh();
                            },
                            onAddVisit: FirebaseAuth
                                        .instance.currentUser?.isAnonymous ==
                                    true
                                ? null
                                : () async {
                                    await addVisit(
                                      cart,
                                    );
                                  },
                            onNavigate: () async {
                              await openNavigation(
                                cart,
                              );
                            },
                            onFavorite: () async {
                              await toggleFavorite(
                                cart,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
