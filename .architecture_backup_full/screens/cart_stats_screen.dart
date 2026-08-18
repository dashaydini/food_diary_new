import 'package:flutter/material.dart';

import '../models/coffee_cart.dart';
import '../theme/colors.dart';

class CartStatsScreen extends StatelessWidget {
  final CoffeeCart cart;

  const CartStatsScreen({
    super.key,
    required this.cart,
  });

  double average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }

    return values.reduce(
          (a, b) => a + b,
        ) /
        values.length;
  }

  Map<String, int> getTags() {
    final Map<String, int> result = {};

    for (final visit in cart.visits) {
      for (final tag in visit.tags) {
        result[tag] = (result[tag] ?? 0) + 1;
      }
    }

    return result;
  }

  String bestDish() {
    if (cart.visits.isEmpty) {
      return "-";
    }

    final sorted = [...cart.visits];

    sorted.sort(
      (a, b) => b.score.compareTo(
        a.score,
      ),
    );

    return sorted.first.dish.isEmpty ? "-" : sorted.first.dish;
  }

  Widget stars(double score) {
    final stars = <Widget>[];

    final value = score / 2;

    for (int i = 1; i <= 5; i++) {
      if (value >= i) {
        stars.add(
          const Icon(
            Icons.star,
            color: AppColors.star,
            size: 25,
          ),
        );
      } else if (value >= i - 0.5) {
        stars.add(
          const Icon(
            Icons.star_half,
            color: AppColors.star,
            size: 25,
          ),
        );
      } else {
        stars.add(
          const Icon(
            Icons.star_border,
            color: AppColors.star,
            size: 25,
          ),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: stars,
    );
  }

  Widget ratingRow(
    String title,
    double value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              title,
            ),
          ),
          stars(value),
          const SizedBox(
            width: 8,
          ),
          Text(
            value.toStringAsFixed(1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visits = cart.visits;

    final tags = getTags();

    final sortedTags = tags.entries.toList()
      ..sort(
        (a, b) => b.value.compareTo(
          a.value,
        ),
      );

    final atmosphere = average(
      visits
          .map(
            (e) => e.atmosphere,
          )
          .toList(),
    );

    final cleanliness = average(
      visits
          .map(
            (e) => e.cleanliness,
          )
          .toList(),
    );

    final service = average(
      visits
          .map(
            (e) => e.service,
          )
          .toList(),
    );

    final food = average(
      visits
          .map(
            (e) => e.foodQuality,
          )
          .toList(),
    );

    final variety = average(
      visits
          .map(
            (e) => e.variety,
          )
          .toList(),
    );

    final value = average(
      visits
          .map(
            (e) => e.value,
          )
          .toList(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "סטטיסטיקה - ${cart.name}",
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    cart.name,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  stars(
                    cart.score,
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  Text(
                    cart.score.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "${cart.visitsCount} ביקורים",
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "📊 דירוגים",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  ratingRow(
                    "אוכל",
                    food,
                  ),
                  ratingRow(
                    "אווירה",
                    atmosphere,
                  ),
                  ratingRow(
                    "שירות",
                    service,
                  ),
                  ratingRow(
                    "ניקיון",
                    cleanliness,
                  ),
                  ratingRow(
                    "מגוון",
                    variety,
                  ),
                  ratingRow(
                    "תמורה",
                    value,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.emoji_events,
              ),
              title: const Text(
                "המנה המובילה",
              ),
              subtitle: Text(
                bestDish(),
              ),
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          if (sortedTags.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "🏷 תגיות נפוצות",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    ...sortedTags.take(5).map(
                          (tag) => Text(
                            "${tag.key} (${tag.value})",
                          ),
                        ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
