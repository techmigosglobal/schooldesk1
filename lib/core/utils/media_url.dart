/// Returns a Supabase Storage image transformation URL for public images.
/// Supabase automatically negotiates WebP for transformed image responses;
/// unsupported/legacy URLs are returned unchanged for compatibility.
String optimizedImageUrl(
  String value, {
  int width = 900,
  int height = 900,
  int quality = 72,
}) {
  final raw = value.trim();
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme) return value;
  if (!uri.path.contains('/storage/v1/object/public/')) return value;
  final sourcePath = uri.path.toLowerCase().split('?').first;
  final isImage = <String>[
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.gif',
    '.heic',
  ].any(sourcePath.endsWith);
  if (!isImage) return value;

  final path = uri.path.replaceFirst(
    '/storage/v1/object/public/',
    '/storage/v1/render/image/public/',
  );
  final params = <String, String>{...uri.queryParameters};
  params.putIfAbsent('width', () => width.clamp(1, 2500).toString());
  params.putIfAbsent('height', () => height.clamp(1, 2500).toString());
  params.putIfAbsent('quality', () => quality.clamp(20, 100).toString());
  params.putIfAbsent('resize', () => 'contain');
  return uri.replace(path: path, queryParameters: params).toString();
}
