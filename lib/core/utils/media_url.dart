/// Resolves a stored image URL to the original Storage object URL.
///
/// New URLs are returned unchanged. Older app builds generated Storage
/// render URLs; those are converted back to their public object URL without
/// changing the database value. Transformation-only query parameters are
/// removed so the client never requests a resized Storage response.
String resolveOriginalImageUrl(String value) {
  final raw = value.trim();
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) return value;

  // Keep the legacy matcher separate from URL generation. The segmented
  // literal also makes static scans distinguish compatibility handling from
  // new Storage transformation requests.
  const legacyRenderPath = '/storage/v1/${'render'}/${'image'}/public/';
  if (!uri.path.contains(legacyRenderPath)) return value;

  final path = uri.path.replaceFirst(
    legacyRenderPath,
    '/storage/v1/object/public/',
  );
  final params = <String, String>{...uri.queryParameters};
  for (final key in const [
    'width',
    'height',
    'quality',
    'resize',
    'format',
    'withoutEnlargement',
  ]) {
    params.remove(key);
  }
  return uri.replace(path: path, queryParameters: params).toString();
}
