import 'dart:convert';

List<String> parseEventPostMediaUrls(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) {
    return raw
        .map((e) => e.toString().trim())
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
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {
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
