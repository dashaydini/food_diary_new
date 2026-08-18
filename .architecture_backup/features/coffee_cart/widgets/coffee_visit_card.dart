import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/coffee_visit.dart';

class CoffeeVisitCard extends StatelessWidget {
  final CoffeeVisit visit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CoffeeVisitCard({
    super.key,
    required this.visit,
    this.onEdit,
    this.onDelete,
  });

  static const champagne = Color(0xFFE7D6B5);
  static const champagneSoft = Color(0xFFCDBB9A);
  static const roseGold = Color(0xFFB8897B);
  static const roseGoldDark = Color(0xFF76544C);
  static const surface = Color(0xFF12100F);
  static const surfaceTop = Color(0xFF181412);

  Widget stars(double score) {
    final List<Widget> widgets = [];
    final value = score / 2;

    for (int i = 1; i <= 5; i++) {
      if (value >= i) {
        widgets.add(
          const Icon(
            Icons.star,
            color: champagne,
            size: 20,
          ),
        );
      } else if (value >= i - 0.5) {
        widgets.add(
          const Icon(
            Icons.star_half,
            color: champagne,
            size: 20,
          ),
        );
      } else {
        widgets.add(
          const Icon(
            Icons.star_border,
            color: roseGoldDark,
            size: 20,
          ),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget scoreLine(
    String title,
    double value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: roseGold,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: champagneSoft,
                fontSize: 13,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(
              color: champagne,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String dateText() {
    return "${visit.date.day.toString().padLeft(2, '0')}/"
        "${visit.date.month.toString().padLeft(2, '0')}/"
        "${visit.date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
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
          onTap: onEdit,
          borderRadius: BorderRadius.circular(8),
          splashColor: roseGold.withValues(alpha: 0.08),
          highlightColor: roseGold.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (visit.imageBase64.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      base64Decode(visit.imageBase64),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),

                if (visit.imageBase64.isNotEmpty) const SizedBox(height: 14),

                // TITLE + DATE
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        visit.dish.isEmpty ? "ללא שם מנה" : visit.dish,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: champagne,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      dateText(),
                      style: const TextStyle(
                        color: champagneSoft,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),

                if (visit.notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    visit.notes,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      color: champagneSoft,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // SCORES
                scoreLine(
                  "אוכל",
                  visit.foodQuality,
                  Icons.restaurant_outlined,
                ),
                scoreLine(
                  "אווירה",
                  visit.atmosphere,
                  Icons.local_cafe_outlined,
                ),
                scoreLine(
                  "שירות",
                  visit.service,
                  Icons.support_agent_outlined,
                ),
                scoreLine(
                  "ניקיון",
                  visit.cleanliness,
                  Icons.cleaning_services_outlined,
                ),
                scoreLine(
                  "מגוון",
                  visit.variety,
                  Icons.menu_book_outlined,
                ),
                scoreLine(
                  "תמורה",
                  visit.value,
                  Icons.payments_outlined,
                ),

                const SizedBox(height: 10),

                Container(
                  height: 0.7,
                  color: roseGoldDark,
                ),

                const SizedBox(height: 10),

                // TOTAL SCORE
                Row(
                  children: [
                    stars(visit.score),
                    const SizedBox(width: 9),
                    Text(
                      visit.score.toStringAsFixed(1),
                      style: const TextStyle(
                        color: champagne,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (onDelete != null)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: roseGold,
                          size: 21,
                        ),
                        onPressed: onDelete,
                      ),
                  ],
                ),

                // TAGS
                if (visit.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: visit.tags
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
                                  color: champagneSoft,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                          .toList(),
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
