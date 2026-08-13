import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/utils/media_url.dart';

Uri? resolveAttachmentUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri == null) return null;

  final base = Uri.tryParse(BackendApiClient.instance.baseUrl);
  if (base == null) return null;
  if (uri.hasScheme) {
    if (uri.path.startsWith('/uploads/')) {
      return _apiUploadUri(base, uri.path);
    }
    return Uri.tryParse(resolveOriginalImageUrl(uri.toString())) ?? uri;
  }

  final origin = Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
  );
  if (raw.startsWith('/uploads/') || raw.startsWith('uploads/')) {
    return _apiUploadUri(base, raw);
  }
  final path = raw.startsWith('/') ? raw.substring(1) : raw;
  return Uri.tryParse(
        resolveOriginalImageUrl(origin.resolve(path).toString()),
      ) ??
      origin.resolve(path);
}

Uri _apiUploadUri(Uri base, String uploadPath) {
  final normalizedBase = base.path.contains('/functions/v1/api')
      ? '/api/v1'
      : (base.path.endsWith('/')
            ? base.path.substring(0, base.path.length - 1)
            : base.path);
  final normalizedUploadPath = uploadPath.startsWith('/')
      ? uploadPath
      : '/$uploadPath';
  return base.replace(
    path: '$normalizedBase$normalizedUploadPath',
    query: null,
    fragment: null,
  );
}
