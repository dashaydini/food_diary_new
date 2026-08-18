import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/coffee_cart.dart';
import '../../repositories/firebase_coffee_cart_repository.dart';
import '../../services/location_service.dart';
import '../../widgets/coffee_cart_card.dart';

import '../add_cart_screen.dart';
import 'coffee_cart_details_screen.dart';
import '../map_screen.dart';

class CoffeeCartsScreen extends StatefulWidget {
  const CoffeeCartsScreen({
    super.key,
  });

  @override
  State<CoffeeCartsScreen> createState() => _CoffeeCartsScreenState();
}

class _CoffeeCartsScreenState extends State<CoffeeCartsScreen> {
  final FirebaseCoffeeCartRepository repository =
      FirebaseCoffeeCartRepository();

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

  List<CoffeeCart> filterCarts(List<CoffeeCart> carts) {
    final text = search.trim().toLowerCase();

    final result = carts.where((cart) {
      if (text.isNotEmpty) {
        final searchable = <String>[
          cart.name,
          cart.location,
        ];

        for (final visit in cart.visits) {
          searchable.add(visit.dish);
          searchable.add(visit.notes);
          searchable.addAll(visit.tags);
        }

        final matchesSearch = searchable.any(
          (item) => item.toLowerCase().contains(text),
        );

        if (!matchesSearch) {
          return false;
        }
      }

      if (favoritesOnly && !cart.favorite) {
        return false;
      }

      if (myContentOnly) {
        final uid = FirebaseAuth.instance.currentUser?.uid;

        if (uid == null || cart.ownerId != uid) {
          return false;
        }
      }

      return true;
    }).toList();

    if (sort == 'score') {
      result.sort(
        (a, b) => b.score.compareTo(a.score),
      );
    }

    if (sort == 'visits') {
      result.sort(
        (a, b) => b.visitsCount.compareTo(a.visitsCount),
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

          return distanceA.compareTo(distanceB);
        },
      );
    }

    return result;
  }

  Future<void> addCart() async {
    if (FirebaseAuth.instance.currentUser?.isAnonymous == true) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddCartScreen(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = FirebaseAuth.instance.currentUser?.isAnonymous == true;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F1),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF7F5F1),
          elevation: 0,
          title: const Text(
            'עגלות קפה',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'מפה',
              icon: const Icon(Icons.map_outlined),
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
              tooltip: favoritesOnly ? 'הצג את כולן' : 'הצג מועדפות',
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
              tooltip: myContentOnly ? 'הצג את כולן' : 'הצג רק שלי',
              icon: Icon(
                myContentOnly ? Icons.person : Icons.groups,
              ),
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
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'none',
                  child: Text('ללא מיון'),
                ),
                PopupMenuItem(
                  value: 'score',
                  child: Text('לפי ציון'),
                ),
                PopupMenuItem(
                  value: 'visits',
                  child: Text('לפי ביקורים'),
                ),
                PopupMenuItem(
                  value: 'distance',
                  child: Text('לפי מרחק'),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: isGuest
            ? null
            : FloatingActionButton.extended(
                onPressed: addCart,
                icon: const Icon(Icons.add),
                label: const Text('עגלה'),
              ),
        body: StreamBuilder<List<CoffeeCart>>(
          stream: repository.getCoffeeCarts(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'שגיאה בטעינת עגלות הקפה:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final carts = filterCarts(
              snapshot.data ?? <CoffeeCart>[],
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    8,
                    12,
                    6,
                  ),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'חיפוש עגלת קפה',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: search.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
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
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                  ),
                  child: Text(
                    'נמצאו ${carts.length} עגלות קפה',
                  ),
                ),
                Expanded(
                  child: carts.isEmpty
                      ? const Center(
                          child: Text(
                            'אין עגלות קפה עדיין',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            bottom: 100,
                          ),
                          itemCount: carts.length,
                          itemBuilder: (context, index) {
                            final cart = carts[index];

                            return CoffeeCartCard(
                              cart: cart,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CoffeeCartDetailsScreen(
                                      cart: cart,
                                      myContentOnly: myContentOnly,
                                    ),
                                  ),
                                );

                                if (mounted) {
                                  setState(() {});
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
