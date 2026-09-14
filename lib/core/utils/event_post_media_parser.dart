import 'dart:convert';

enum EventPostMediaKind { image, video, pdf, document, media }

class EventPostMediaItem {
  final String url;
  final String name;
  final String mimeType;
  final EventPostMediaKind kind;
  final int? size;
  final String storageRef;
  final String thumbnailUrl;

  const EventPostMediaItem({
    required this.url,
    this.name = '',
    this.mimeType = '',
    this.kind = EventPostMediaKind.media,
    this.size,
    this.storageRef = '',
    this.thumbnailUrl = '',
  });

  bool get isImage => kind == EventPostMediaKind.image;
  bool get isVideo => kind == EventPostMediaKind.video;
  bool get isPdf => kind == EventPostMediaKind.pdf;

  String get displayName {
    if (name.trim().isNotEmpty) return name.trim();
    final uri = Uri.tryParse(url);
    final segments = uri?.pathSegments ?? const <String>[];
    return segments.isEmpty ? url : segments.last;
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    if (name.trim().isNotEmpty) 'name': name.trim(),
    if (mimeType.trim().isNotEmpty) 'mime_type': mimeType.trim(),
    'kind': kind.name,
    if (size != null) 'size': size,
    if (storageRef.trim().isNotEmpty) 'storage_ref': storageRef.trim(),
    if (thumbnailUrl.trim().isNotEmpty) 'thumbnail_url': thumbnailUrl.trim(),
  };

  static List<EventPostMediaItem> parseList(dynamic raw) {
    if (raw == null) return const [];
    if (raw is Map) {
      final item = _fromDynamic(raw);
      return item.url.trim().isEmpty ? const [] : [item];
    }
    if (raw is List) {
      return raw
          .map(_fromDynamic)
          .where((item) => item.url.trim().isNotEmpty)
          .toList();
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return const [];
    if (text.startsWith('[')) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is List) {
          return parseList(decoded);
        }
      } on Object catch (_) {
        // Fall through to legacy parsing.
      }
    }
    return parseEventPostMediaUrls(text).map(fromUrl).toList();
  }

  static EventPostMediaItem _fromDynamic(dynamic value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final url = _text(map['url'] ?? map['media_url'] ?? map['mediaUrl']);
      final name = _text(map['name'] ?? map['filename'] ?? map['file_name']);
      final mimeType = _text(
        map['mime_type'] ??
            map['mimeType'] ??
            map['media_type'] ??
            map['mediaType'] ??
            map['content_type'],
      );
      final explicitKind = _text(
        map['kind'] ?? map['type'] ?? map['media_kind'],
      ).toLowerCase();
      final size = map['size'];
      final storageRef = _text(map['storage_ref'] ?? map['storageRef']);
      final thumbnailUrl = _text(
        map['thumbnail_url'] ?? map['thumbnailUrl'] ?? map['poster_url'],
      );
      return EventPostMediaItem(
        url: url,
        name: name,
        mimeType: mimeType,
        kind: _kindFor(url, mimeType, explicitKind),
        size: size is int ? size : int.tryParse(_text(size)),
        storageRef: storageRef,
        thumbnailUrl: thumbnailUrl,
      );
    }
    return fromUrl(_text(value));
  }

  static EventPostMediaItem fromUrl(
    String url, {
    String name = '',
    String mimeType = '',
    int? size,
    String thumbnailUrl = '',
  }) {
    final normalizedUrl = url.trim();
    return EventPostMediaItem(
      url: normalizedUrl,
      name: name,
      mimeType: mimeType,
      kind: _kindFor(normalizedUrl, mimeType, ''),
      size: size,
      thumbnailUrl: thumbnailUrl,
    );
  }

  static EventPostMediaKind _kindFor(
    String url,
    String mimeType,
    String explicitKind,
  ) {
    final kind = explicitKind.toLowerCase();
    final mime = mimeType.toLowerCase();
    final path = (Uri.tryParse(url)?.path ?? url).toLowerCase();
    if (kind.contains('video') ||
        mime.startsWith('video/') ||
        _hasExtension(path, const ['mp4', 'mov', 'm4v', 'webm'])) {
      return EventPostMediaKind.video;
    }
    if (kind.contains('image') ||
        kind.contains('photo') ||
        mime.startsWith('image/') ||
        _hasExtension(path, const [
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'heic',
        ])) {
      return EventPostMediaKind.image;
    }
    if (kind.contains('pdf') ||
        mime == 'application/pdf' ||
        path.endsWith('.pdf')) {
      return EventPostMediaKind.pdf;
    }
    if (_hasExtension(path, const ['doc', 'docx'])) {
      return EventPostMediaKind.document;
    }
    return EventPostMediaKind.media;
  }

  static bool _hasExtension(String path, List<String> extensions) {
    return extensions.any((ext) => path.endsWith('.$ext'));
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';
}

List<String> parseEventPostMediaUrls(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw
        .map((e) {
          if (e is Map) {
            return (e['url'] ?? e['media_url'] ?? e['mediaUrl'] ?? '')
                .toString()
                .trim();
          }
          return e.toString().trim();
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }

  final text = raw.toString().trim();
  if (text.isEmpty) return const [];

  if (text.startsWith('[')) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map((e) {
              if (e is Map) {
                return (e['url'] ?? e['media_url'] ?? e['mediaUrl'] ?? '')
                    .toString()
                    .trim();
              }
              return e.toString().trim();
            })
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } on Object catch (_) {
      // Fallback parsing below.
    }
  }

  final splitByDelimiter = text
      .split(RegExp(r',(?:\s)*(?=(?:https?:\/\/|\/))'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  if (splitByDelimiter.length > 1) {
    return splitByDelimiter;
  }

  return [text];
}

String firstEventPostMediaUrl(dynamic raw) {
  final media = parseEventPostMediaUrls(raw);
  return media.isEmpty ? '' : media.first;
}
