/// Returns a resized Supabase Storage image URL when [source] points at a
/// public image in this project's Storage. Other URLs (assets, blobs and PDFs)
/// are returned unchanged.
String optimizedSupabaseImageUrl(
  String source, {
  required int width,
  int? height,
  int quality = 72,
  String resize = 'cover',
}) {
  final uri = Uri.tryParse(source);
  if (uri == null ||
      !uri.host.endsWith('.supabase.co') ||
      !uri.path.contains('/storage/v1/object/public/')) {
    return source;
  }

  final extension = uri.pathSegments.isEmpty
      ? ''
      : uri.pathSegments.last.split('.').last.toLowerCase();
  if (!const {'jpg', 'jpeg', 'png', 'webp', 'avif'}.contains(extension)) {
    return source;
  }

  final query = <String, String>{
    ...uri.queryParameters,
    'width': width.clamp(1, 2500).toString(),
    'quality': quality.clamp(20, 100).toString(),
    'resize': resize,
    if (height != null) 'height': height.clamp(1, 2500).toString(),
  };

  return uri
      .replace(
        path: uri.path.replaceFirst(
          '/storage/v1/object/public/',
          '/storage/v1/render/image/public/',
        ),
        queryParameters: query,
      )
      .toString();
}
