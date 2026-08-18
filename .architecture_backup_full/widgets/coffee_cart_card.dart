import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/coffee_cart.dart';
import '../services/location_service.dart';

class CoffeeCartCard extends StatefulWidget {
  final CoffeeCart cart;
  final VoidCallback onTap;
  final VoidCallback? onAddVisit;
  final VoidCallback? onNavigate;
  final VoidCallback? onFavorite;

  const CoffeeCartCard({
    super.key,
    required this.cart,
    required this.onTap,
    this.onAddVisit,
    this.onNavigate,
    this.onFavorite,
  });

  @override
  State<CoffeeCartCard> createState() => _CoffeeCartCardState();
}

class _CoffeeCartCardState extends State<CoffeeCartCard> {
  Position? currentPosition;

  static const champagne = Color(0xFFE7D6B5);
  static const champagneSoft = Color(0xFFCDBB9A);
  static const roseGold = Color(0xFFB8897B);
  static const roseGoldDark = Color(0xFF76544C);
  static const surface = Color(0xFF12100F);
  static const surfaceTop = Color(0xFF181412);

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

  String getDistance() {
    if (currentPosition == null) {
      return '';
    }

    if (widget.cart.latitude == 0 || widget.cart.longitude == 0) {
      return '';
    }

    final meters = Geolocator.distanceBetween(
      currentPosition!.latitude,
      currentPosition!.longitude,
      widget.cart.latitude,
      widget.cart.longitude,
    );

    if (meters < 1000) {
      return "${meters.round()} מטר ממך";
    }

    return "${(meters / 1000).toStringAsFixed(1)} ק\"מ ממך";
  }

  List<String> getTags() {
    final Set<String> tags = {};

    for (final visit in widget.cart.visits) {
      tags.addAll(visit.tags);
    }

    return tags.take(3).toList();
  }

  String getLastVisit() {
    if (widget.cart.visits.isEmpty) {
      return '';
    }

    final visits = [...widget.cart.visits];

    visits.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return visits.first.dish;
  }

  String getLastVisitDate() {
    if (widget.cart.visits.isEmpty) {
      return '';
    }

    final visits = [...widget.cart.visits];

    visits.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    final date = visits.first.date;
    final now = DateTime.now();
    final days = now.difference(date).inDays;

    if (days == 0) {
      return "היום";
    }

    if (days == 1) {
      return "אתמול";
    }

    return "לפני $days ימים";
  }

  String getPriceRating() {
    final ratings = widget.cart.visits
        .map((visit) => visit.priceRating)
        .where((rating) => rating >= 1 && rating <= 3)
        .toList();

    if (ratings.isEmpty) {
      return '';
    }

    final average = ratings.reduce((a, b) => a + b) / ratings.length;
    final rounded = average.round();

    return '₪' * rounded;
  }

  Widget infoRow({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: roseGold,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: champagneSoft,
                fontWeight: FontWeight.w300,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = getTags();
    final distance = getDistance();
    final lastDish = getLastVisit();
    final lastDate = getLastVisitDate();
    final priceRating = getPriceRating();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            surfaceTop,
            surface,
            Color(0xFF0D0B0A),
          ],
        ),
        border: Border.all(
          color: roseGold,
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: roseGold.withValues(alpha: 0.08),
          highlightColor: roseGold.withValues(alpha: 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.cart.imageBase64.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                  child: Image.memory(
                    base64Decode(widget.cart.imageBase64),
                    height: 185,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  15,
                  16,
                  13,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // NAME + FAVORITE
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.cart.name,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w500,
                              color: champagne,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (priceRating.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              right: 8,
                            ),
                            child: Text(
                              priceRating,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: champagne,
                              ),
                            ),
                          ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            widget.cart.favorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 21,
                            color:
                                widget.cart.favorite ? roseGold : champagneSoft,
                          ),
                          onPressed: widget.onFavorite,
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    // SCORE
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 18,
                          color: champagne,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          widget.cart.score.toStringAsFixed(1),
                          style: const TextStyle(
                            color: champagne,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 18),
                        Text(
                          "${widget.cart.visitsCount} ביקורים",
                          style: const TextStyle(
                            color: champagneSoft,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),

                    infoRow(
                      icon: Icons.location_on_outlined,
                      text: widget.cart.location,
                    ),

                    if (widget.cart.ownerName.isNotEmpty)
                      infoRow(
                        icon: Icons.person_outline,
                        text: "נוצר על ידי: ${widget.cart.ownerName}",
                      ),

                    if (widget.cart.createdAt != null)
                      infoRow(
                        icon: Icons.calendar_today_outlined,
                        text:
                            "בתאריך: ${widget.cart.createdAt!.day}/${widget.cart.createdAt!.month}/${widget.cart.createdAt!.year}",
                      ),

                    if (distance.isNotEmpty)
                      infoRow(
                        icon: Icons.near_me_outlined,
                        text: distance,
                      ),

                    if (lastDish.isNotEmpty)
                      infoRow(
                        icon: Icons.restaurant_outlined,
                        text: "אחרון: $lastDish",
                      ),

                    if (lastDate.isNotEmpty)
                      infoRow(
                        icon: Icons.history,
                        text: "ביקור $lastDate",
                      ),

                    if (tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 11),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: tags
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: roseGoldDark,
                                      width: 0.7,
                                    ),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: champagneSoft,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),

                    const SizedBox(height: 10),

                    // ACTIONS
                    Container(
                      height: 0.7,
                      color: roseGoldDark,
                    ),

                    const SizedBox(height: 5),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: widget.onAddVisit,
                          style: TextButton.styleFrom(
                            foregroundColor: champagne,
                          ),
                          icon: const Icon(
                            Icons.add,
                            size: 18,
                          ),
                          label: const Text("ביקור"),
                        ),
                        TextButton.icon(
                          onPressed: widget.onNavigate,
                          style: TextButton.styleFrom(
                            foregroundColor: champagne,
                          ),
                          icon: const Icon(
                            Icons.navigation_outlined,
                            size: 18,
                          ),
                          label: const Text("ניווט"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
