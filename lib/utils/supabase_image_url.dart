/// Returns a directly loadable image URL.
///
/// Supabase's `/render/image/` transformation endpoint is not available on
/// every project/plan. Using it unconditionally makes otherwise public images
/// fail with HTTP 403. Keep public Storage images on the original object URL
/// and also recover legacy transformed URLs that may already be present in
/// cached data.
String optimizedSupabaseImageUrl(
  String source, {
  required int width,
  int? height,
  int quality = 72,
  String resize = 'cover',
}) {
  final uri = Uri.tryParse(source);
  if (uri == null || !uri.host.endsWith('.supabase.co')) {
    return source;
  }

  const renderedPrefix = '/storage/v1/render/image/public/';
  if (!uri.path.contains(renderedPrefix)) {
    return source;
  }

  final query = Map<String, String>.from(uri.queryParameters)
    ..remove('width')
    ..remove('height')
    ..remove('quality')
    ..remove('resize');

  return uri
      .replace(
        path: uri.path.replaceFirst(
          renderedPrefix,
          '/storage/v1/object/public/',
        ),
        queryParameters: query.isEmpty ? null : query,
      )
      .toString();
}
