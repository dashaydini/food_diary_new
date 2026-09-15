String buildAddressSearchQuery({
  required String address,
  String? placeName,
}) {
  var query = address.trim().replaceAll(RegExp(r'\s+'), ' ');
  final normalizedPlaceName = _normalizeForComparison(placeName ?? '');

  if (normalizedPlaceName.isNotEmpty &&
      _normalizeForComparison(query).startsWith(normalizedPlaceName) &&
      query.length >= (placeName?.trim().length ?? 0)) {
    query = query.substring(placeName!.trim().length).trim();
  }

  query = query
      .replaceFirst(RegExp(r'^[\s,;:–—-]+'), '')
      .replaceFirst(RegExp(r'^(?:במושב|מושב|בקיבוץ|קיבוץ)\s+'), '')
      .trim();

  if (query.isEmpty) {
    query = address.trim();
  }

  if (!RegExp(r'(?:ישראל|israel)', caseSensitive: false).hasMatch(query)) {
    query = '$query, ישראל';
  }

  return query;
}

Map<String, dynamic>? selectBestAddressSearchResult(
  List<dynamic> results, {
  required String query,
}) {
  if (results.isEmpty) return null;

  final wanted = _normalizeForComparison(query.split(',').first);
  const settlementTypes = {
    'village',
    'hamlet',
    'town',
    'city',
    'municipality',
  };

  Map<String, dynamic>? best;
  var bestScore = -1000;

  for (final raw in results) {
    if (raw is! Map) continue;
    final result = Map<String, dynamic>.from(raw);
    final address = result['address'] is Map
        ? Map<String, dynamic>.from(result['address'] as Map)
        : const <String, dynamic>{};
    final name = _normalizeForComparison(result['name']?.toString() ?? '');
    final type = result['type']?.toString().toLowerCase() ?? '';
    final addressType = result['addresstype']?.toString().toLowerCase() ?? '';

    final addressNames = <String>{
      for (final key in const [
        'village',
        'hamlet',
        'town',
        'city',
        'municipality',
      ])
        if (address[key] != null)
          _normalizeForComparison(address[key].toString()),
    };

    var score = 0;
    if (name == wanted) score += 40;
    if (addressNames.contains(wanted)) score += 40;
    if (settlementTypes.contains(addressType) ||
        settlementTypes.contains(type)) {
      score += 15;
    }
    // A mapped settlement node is usually a better pin than the centroid of
    // a large administrative polygon with the same name.
    if (result['osm_type']?.toString() == 'node') score += 5;
    if (result['category']?.toString() == 'boundary') score -= 25;

    if (score > bestScore) {
      bestScore = score;
      best = result;
    }
  }

  return best;
}

String _normalizeForComparison(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp("[׳’`\"]"), "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}
