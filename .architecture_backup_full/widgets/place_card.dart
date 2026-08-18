import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/place.dart';

class PlaceCard extends StatelessWidget {
  final Place place;
  final VoidCallback onTap;
  final VoidCallback? onAddVisit;
  final VoidCallback? onNavigate;
  final VoidCallback? onFavorite;

  const PlaceCard({
    super.key,
    required this.place,
    required this.onTap,
    this.onAddVisit,
    this.onNavigate,
    this.onFavorite,
  });

  static const champagne = Color(0xFFE7D6B5);
  static const champagneSoft = Color(0xFFCDBB9A);
  static const roseGold = Color(0xFFB8897B);
  static const surface = Color(0xFF12100F);
  static const surfaceTop = Color(0xFF181412);

  @override
  Widget build(BuildContext context) {
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (place.imageBase64.isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                  child: Image.memory(
                    base64Decode(place.imageBase64),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place.name,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: champagne,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onFavorite,
                          icon: Icon(
                            place.favorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 21,
                            color: place.favorite ? roseGold : champagneSoft,
                          ),
                        ),
                      ],
                    ),
                    if (place.location.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 17,
                            color: roseGold,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              place.location,
                              style: const TextStyle(
                                fontSize: 13,
                                color: champagneSoft,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (onAddVisit != null)
                          TextButton.icon(
                            onPressed: onAddVisit,
                            style: TextButton.styleFrom(
                              foregroundColor: champagne,
                            ),
                            icon: const Icon(
                              Icons.add,
                              size: 18,
                            ),
                            label: const Text('ביקור'),
                          ),
                        if (onNavigate != null)
                          TextButton.icon(
                            onPressed: onNavigate,
                            style: TextButton.styleFrom(
                              foregroundColor: champagne,
                            ),
                            icon: const Icon(
                              Icons.navigation_outlined,
                              size: 18,
                            ),
                            label: const Text('ניווט'),
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
