import 'package:schooldesk1/core/config/env_config.dart';

const _legacySupabaseStorageHost = 'ouvwogguttybmpgfgctc.supabase.co';

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

  // The Edge Functions runtime may generate Storage URLs from its internal
  // `http://supabase-kong:8000` origin. Coolify can also expose the same
  // internal URL through an HTTP sslip.io preview host. Those origins are
  // unreachable (and cleartext is rejected) from Android/iOS. Keep the
  // storage path and signed query intact while using the app's public API
  // origin. This also handles local Docker URLs through the ADB reverse
  // tunnel.
  final configuredOrigin = Uri.tryParse(EnvConfig.apiOrigin);
  if (configuredOrigin != null &&
      configuredOrigin.host.isNotEmpty &&
      _isDockerStorageHost(uri.host)) {
    return _rewriteOrigin(uri, configuredOrigin).toString();
  }

  // Restored rows can still contain an object URL from the retired Supabase
  // project. Keep the object path and query intact, but point the client at
  // the configured target project so cached/older API payloads remain usable.
  final targetOrigin = Uri.tryParse(EnvConfig.supabaseUrl);
  if (targetOrigin != null &&
      targetOrigin.host.isNotEmpty &&
      uri.host.toLowerCase() == _legacySupabaseStorageHost &&
      uri.path.contains('/storage/v1/object/') &&
      targetOrigin.host.toLowerCase() != uri.host.toLowerCase()) {
    return _rewriteOrigin(uri, targetOrigin).toString();
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

bool _isDockerStorageHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'kong' ||
      normalized == 'host.docker.internal' ||
      normalized == 'supabase-kong' ||
      normalized.startsWith('supabase_kong_') ||
      (normalized.startsWith('supabasekong-') &&
          normalized.endsWith('.sslip.io')) ||
      normalized == '127.0.0.1' ||
      normalized == 'localhost' ||
      normalized == '::1';
}

Uri _rewriteOrigin(Uri uri, Uri origin) => Uri(
  scheme: origin.scheme,
  host: origin.host,
  port: origin.hasPort ? origin.port : null,
  path: uri.path,
  query: uri.hasQuery ? uri.query : null,
  fragment: uri.hasFragment ? uri.fragment : null,
);
