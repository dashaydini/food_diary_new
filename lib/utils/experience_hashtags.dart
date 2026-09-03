/// Hashtags are derived from public experience notes, never private journal notes.
class ExperienceHashtags {
  static final _pattern = RegExp(
    r'(^|[^\p{L}\p{M}\p{N}_/#])#([\p{L}\p{N}][\p{L}\p{M}\p{N}_׳]*)',
    unicode: true,
  );

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll(
          RegExp(
              r'[\u0591-\u05BD\u05BF-\u05C7\u200E\u200F\u202A-\u202E\u2066-\u2069]'),
          '')
      .replaceAll(RegExp(r'[_\s]+'), ' ')
      .trim();

  static List<String> extract(String? notes) {
    final tags = <String>{};
    for (final match in _pattern.allMatches(notes ?? '')) {
      final tag = normalize(match.group(2)!).replaceAll(' ', '_');
      if (tag.isNotEmpty) tags.add(tag);
    }
    return tags.toList();
  }

  static List<String> matching(Iterable<String> tags, String query) {
    final trimmed = query.trim();
    final explicit = trimmed.startsWith('#');
    final terms = explicit
        ? extract(trimmed).map(normalize).toSet()
        : <String>{normalize(trimmed)};
    if (terms.isEmpty || terms.contains('')) return [];
    return tags.toSet().where((tag) {
      final normalized = normalize(tag);
      return explicit
          ? terms.contains(normalized)
          : normalized.contains(terms.single);
    }).toList();
  }

  static bool matchesPlace(
    Map<String, dynamic> place,
    Iterable<String> tags,
    String query,
  ) {
    if (query.trim().isEmpty) return true;
    final matched = matching(tags, query);
    if (query.trim().startsWith('#')) {
      final requested = extract(query).map(normalize).toSet();
      return requested.isNotEmpty &&
          requested.every(matched.map(normalize).toSet().contains);
    }
    return matched.isNotEmpty ||
        [place['name'], place['description'], place['address']].any(
          (value) =>
              normalize(value?.toString() ?? '').contains(normalize(query)),
        );
  }

  static Map<String, Set<String>> byPlace(
    Iterable<Map<String, dynamic>> visits,
  ) {
    final result = <String, Set<String>>{};
    for (final visit in visits) {
      final placeId = visit['place_id']?.toString();
      if (placeId == null) continue;
      final tags = extract(visit['notes'] as String?);
      if (tags.isNotEmpty) {
        result.putIfAbsent(placeId, () => <String>{}).addAll(tags);
      }
    }
    return result;
  }
}
