import 'experience_hashtags.dart';

class HashtagTasteStat {
  final String hashtag;
  final int places;
  final int positive;
  final int negative;
  const HashtagTasteStat(
      this.hashtag, this.places, this.positive, this.negative);

  // Shrink sparse evidence toward neutral, rather than treating one mention as certainty.
  double get weight => (positive - negative) / (places + 2);
}

class HashtagTasteProfile {
  final List<HashtagTasteStat> stats;
  const HashtagTasteProfile(this.stats);

  factory HashtagTasteProfile.fromVisits(
    Iterable<Map<String, dynamic>> ownVisits,
    Map<String, int> feedback,
  ) {
    final mentions = <String, Map<String, List<double>>>{};
    for (final visit in ownVisits) {
      final placeId = visit['place_id']?.toString();
      if (placeId == null) continue;
      for (final tag in ExperienceHashtags.extract(visit['notes'] as String?)) {
        final ratings =
            mentions.putIfAbsent(tag, () => {}).putIfAbsent(placeId, () => []);
        final rating = (visit['rating'] as num?)?.toDouble();
        if (rating != null && rating > 0 && rating <= 5) ratings.add(rating);
      }
    }
    final stats = <HashtagTasteStat>[];
    for (final tag in mentions.entries) {
      var positive = 0;
      var negative = 0;
      for (final place in tag.value.entries) {
        final explicit = feedback[place.key];
        if (explicit == 1) {
          positive++;
        } else if (explicit == -1) {
          negative++;
        } else if (place.value.isNotEmpty) {
          final average =
              place.value.reduce((a, b) => a + b) / place.value.length;
          if (average >= 4) positive++;
          if (average <= 2.5) negative++;
        }
      }
      stats
          .add(HashtagTasteStat(tag.key, tag.value.length, positive, negative));
    }
    stats.sort((a, b) {
      final count = b.places.compareTo(a.places);
      return count != 0 ? count : a.hashtag.compareTo(b.hashtag);
    });
    return HashtagTasteProfile(stats);
  }

  double scoreFor(Iterable<String> candidateTags) {
    final tags = candidateTags.map(ExperienceHashtags.normalize).toSet();
    final matched = stats
        .where((s) => tags.contains(ExperienceHashtags.normalize(s.hashtag)))
        .toList();
    if (matched.isEmpty) return 0;
    // A secondary ranking signal only, not a probability of liking a dish/place.
    return matched.fold<double>(0, (sum, s) => sum + s.weight) /
        matched.length *
        1.5;
  }

  List<String> positiveMatches(Iterable<String> candidateTags) {
    final tags = candidateTags.map(ExperienceHashtags.normalize).toSet();
    final matched = stats
        .where((s) =>
            s.weight > 0 &&
            tags.contains(ExperienceHashtags.normalize(s.hashtag)))
        .toList()
      ..sort((a, b) => b.weight.compareTo(a.weight));
    return matched.map((s) => s.hashtag).toList();
  }
}
