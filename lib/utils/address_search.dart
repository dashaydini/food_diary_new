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

String _normalizeForComparison(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp("[׳’`\"]"), "'")
      .replaceAll(RegExp(r'\s+'), ' ');
}
