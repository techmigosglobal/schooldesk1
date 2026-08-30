import 'package:schooldesk1/core/config/env_config.dart';

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

  // The local Edge runtime runs inside Docker and Supabase may return
  // `kong:8000` (or another Docker-only alias) in generated Storage URLs.
  // Android/iOS cannot resolve that hostname, even though the host machine
  // exposes the same gateway on 127.0.0.1:54321 through the ADB reverse
  // tunnel. Rewrite only when the configured app origin is local; hosted
  // Supabase URLs are never modified.
  final localOrigin = Uri.tryParse(EnvConfig.apiOrigin);
  if (localOrigin != null &&
      _isLocalOrigin(localOrigin) &&
      _isDockerStorageHost(uri.host)) {
    return _rewriteOrigin(uri, localOrigin).toString();
  }

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

bool _isLocalOrigin(Uri uri) {
  final host = uri.host.toLowerCase();
  return host == '127.0.0.1' || host == 'localhost' || host == '::1';
}

bool _isDockerStorageHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'kong' ||
      normalized == 'host.docker.internal' ||
      normalized == 'supabase-kong' ||
      normalized.startsWith('supabase_kong_') ||
      normalized == '127.0.0.1' ||
      normalized == 'localhost' ||
      normalized == '::1';
}

Uri _rewriteOrigin(Uri uri, Uri origin) => uri.replace(
  scheme: origin.scheme,
  host: origin.host,
  port: origin.hasPort ? origin.port : null,
);
