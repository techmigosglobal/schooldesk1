/// Shared text utilities used across navigation drawers and screens.
library;

/// Safely extracts a trimmed string from a dynamic value, returning [fallback]
/// if the value is null or empty after trimming.
String safeText(dynamic value, {required String fallback}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

/// Extracts up to 2 initials from a name string.
/// Returns [fallback] if the name is empty or contains no valid parts.
String safeInitials(String name, {required String fallback}) {
  final parts = name
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .take(2)
      .map((part) => part.trim()[0].toUpperCase())
      .join();
  return parts.isEmpty ? fallback : parts;
}

/// Safely converts a dynamic value to a double, returning [fallback] on failure.
double safeNumValue(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? fallback;
}
