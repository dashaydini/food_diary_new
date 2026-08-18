import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/coffee_cart.dart';
import '../../models/coffee_visit.dart';
import '../../repositories/firebase_coffee_cart_repository.dart';
import '../../services/location_service.dart';
import 'add_coffee_visit_screen.dart';
import 'edit_coffee_cart_screen.dart';

class CoffeeCartDetailsScreen extends StatefulWidget {
  final CoffeeCart cart;
  final bool myContentOnly;

  const CoffeeCartDetailsScreen({
    super.key,
    required this.cart,
    this.myContentOnly = false,
  });

  @override
  State<CoffeeCartDetailsScreen> createState() =>
      _CoffeeCartDetailsScreenState();
}

class _CoffeeCartDetailsScreenState extends State<CoffeeCartDetailsScreen> {
  final FirebaseCoffeeCartRepository repository =
      FirebaseCoffeeCartRepository();

  String? defaultNavigation;
  Position? currentPosition;

  static const background = Color(0xFFF7F5F1);
  static const textPrimary = Color(0xFF2B2522);
  static const textSecondary = Color(0xFF625A55);
  static const roseGold = Color(0xFFB8897B);
  static const border = Color(0xFFE6DDD5);
  static const card = Colors.white;

  @override
  void initState() {
    super.initState();
    loadNavigation();
    loadLocation();
  }

  Future<void> loadNavigation() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      defaultNavigation = prefs.getString('default_navigation');
    });
  }

  Future<void> loadLocation() async {
    final position = await LocationService.getCurrentLocation();

    if (position != null && mounted) {
      setState(() {
        currentPosition = position;
      });
    }
  }

  bool hasLocation() {
    return widget.cart.latitude != 0 && widget.cart.longitude != 0;
  }

  String getDistance() {
    if (currentPosition == null || !hasLocation()) {
      return '';
    }

    final meters = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      widget.cart.latitude,
      widget.cart.longitude,
    );

    if (meters < 1000) {
      return '${meters.round()} מטר ממך';
    }

    return '${(meters / 1000).toStringAsFixed(1)} ק״מ ממך';
  }

  Future<void> navigate(String type) async {
    final lat = widget.cart.latitude;
    final lng = widget.cart.longitude;

    late final Uri url;

    if (type == 'waze') {
      url = Uri.parse(
        'https://waze.com/ul?ll=$lat,$lng&navigate=yes',
      );
    } else if (type == 'apple') {
      url = Uri.parse(
        'https://maps.apple.com/?daddr=$lat,$lng',
      );
    } else {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
      );
    }

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> chooseNavigation() async {
    if (!hasLocation()) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('אין מיקום GPS לעגלה הזו'),
        ),
      );

      return;
    }

    if (defaultNavigation != null) {
      await navigate(defaultNavigation!);
      return;
    }

    String selected = 'google';
    bool remember = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('בחר ניווט'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioGroup<String>(
                    groupValue: selected,
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selected = value;
                      });
                    },
                    child: const Column(
                      children: [
                        RadioListTile<String>(
                          value: 'google',
                          title: Text('Google Maps'),
                        ),
                        RadioListTile<String>(
                          value: 'waze',
                          title: Text('Waze'),
                        ),
                        RadioListTile<String>(
                          value: 'apple',
                          title: Text('Apple Maps'),
                        ),
                      ],
                    ),
                  ),
                  CheckboxListTile(
                    value: remember,
                    title: const Text('זכור בחירה'),
                    onChanged: (value) {
                      setDialogState(() {
                        remember = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ביטול'),
                ),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    if (remember) {
                      final prefs = await SharedPreferences.getInstance();

                      await prefs.setString(
                        'default_navigation',
                        selected,
                      );

                      defaultNavigation = selected;
                    }

                    await navigate(selected);
                  },
                  child: const Text('פתח'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> addVisit() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.isAnonymous) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCoffeeVisitScreen(
          cart: widget.cart,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> editCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditCoffeeCartScreen(
          cart: widget.cart,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  bool isVisitOwner(CoffeeVisit visit) {
    final user = FirebaseAuth.instance.currentUser;

    return user != null && !user.isAnonymous && visit.userId == user.uid;
  }

  Future<void> deleteVisit(CoffeeVisit visit) async {
    if (!isVisitOwner(visit)) {
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('מחיקת ביקור'),
          content: const Text('האם למחוק את הביקור?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ביטול'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('מחיקה'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      widget.cart.visits.remove(visit);
    });

    try {
      if (widget.cart.isInBox) {
        await widget.cart.save();
      }

      if (widget.cart.firebaseId.isNotEmpty) {
        await repository.updateCoffeeCart(widget.cart);
      }
    } catch (e) {
      debugPrint('DELETE COFFEE VISIT ERROR: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('מחיקת הביקור נכשלה: $e'),
          ),
        );
      }
    }
  }

  Future<void> openVisit(CoffeeVisit visit) async {
    final owner = isVisitOwner(visit);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddCoffeeVisitScreen(
          cart: widget.cart,
          existingVisit: visit,
          viewOnly: !owner,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  List<CoffeeVisit> get visits {
    final allVisits = List<CoffeeVisit>.from(widget.cart.visits);

    if (!widget.myContentOnly) {
      return allVisits;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;

    return allVisits.where((visit) => visit.userId == uid).toList();
  }

  Widget visitCard(CoffeeVisit visit) {
    final owner = isVisitOwner(visit);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: border,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        title: Text(
          visit.dish.isEmpty ? 'ביקור' : visit.dish,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        subtitle: visit.notes.trim().isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  visit.notes,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: textSecondary,
                  ),
                ),
              ),
        trailing: owner
            ? PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: Color(0xFF8F817A),
                ),
                onSelected: (value) async {
                  if (value == 'edit') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddCoffeeVisitScreen(
                          cart: widget.cart,
                          existingVisit: visit,
                          viewOnly: false,
                        ),
                      ),
                    );

                    if (mounted) {
                      setState(() {});
                    }
                  }

                  if (value == 'delete') {
                    await deleteVisit(visit);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('עריכה'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('מחיקה'),
                  ),
                ],
              )
            : null,
        onTap: () => openVisit(visit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    final cartVisits = visits;
    final distance = getDistance();
    final isGuest = FirebaseAuth.instance.currentUser?.isAnonymous == true;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          title: Text(
            cart.name,
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            if (hasLocation())
              IconButton(
                tooltip: 'ניווט',
                icon: const Icon(
                  Icons.navigation_outlined,
                ),
                onPressed: chooseNavigation,
              ),
            IconButton(
              tooltip: 'עריכה',
              icon: const Icon(
                Icons.edit_outlined,
              ),
              onPressed: editCart,
            ),
          ],
        ),
        floatingActionButton: isGuest
            ? null
            : FloatingActionButton.extended(
                backgroundColor: roseGold,
                foregroundColor: Colors.white,
                onPressed: addVisit,
                icon: const Icon(Icons.add),
                label: const Text('ביקור'),
              ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            8,
            16,
            100,
          ),
          children: [
            if (cart.imageBase64.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.memory(
                  base64Decode(cart.imageBase64),
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              cart.name,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            if (cart.location.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: roseGold,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cart.location,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 15,
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (distance.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  const Icon(
                    Icons.near_me_outlined,
                    size: 17,
                    color: roseGold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    distance,
                    style: const TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            if (hasLocation()) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: chooseNavigation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: roseGold,
                    side: const BorderSide(
                      color: roseGold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    Icons.navigation_outlined,
                  ),
                  label: const Text('נווט לעגלה'),
                ),
              ),
            ],
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'ביקורים',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                if (!isGuest)
                  TextButton.icon(
                    onPressed: addVisit,
                    style: TextButton.styleFrom(
                      foregroundColor: roseGold,
                    ),
                    icon: const Icon(
                      Icons.add,
                      size: 19,
                    ),
                    label: const Text('הוסף ביקור'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (cartVisits.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: border,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_cafe_outlined,
                      size: 40,
                      color: roseGold,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'עדיין אין ביקורים',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      isGuest
                          ? 'התחבר כדי להוסיף ביקור'
                          : 'הוסף את הביקור הראשון שלך',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...cartVisits.map(visitCard),
          ],
        ),
      ),
    );
  }
}
