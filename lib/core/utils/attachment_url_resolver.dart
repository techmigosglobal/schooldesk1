import 'package:schooldesk1/core/network/backend_api_client.dart';

Uri? resolveAttachmentUrl(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (uri.hasScheme) return uri;

  final base = Uri.tryParse(BackendApiClient.instance.baseUrl);
  if (base == null) return null;

  final origin = Uri(
    scheme: base.scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
  );
  final path = raw.startsWith('/') ? raw.substring(1) : raw;
  return origin.resolve(path);
}
