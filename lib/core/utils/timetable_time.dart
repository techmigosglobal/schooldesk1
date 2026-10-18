/// Canonical 24-hour school timetable clock; no AM/PM inference.
String? normalizeTimetableTime(Object? input) {
  var text = '${input ?? ''}'.trim();
  if (RegExp(r'^\d{3,4}$').hasMatch(text)) {
    text = text.padLeft(4, '0');
    text = '${text.substring(0, 2)}:${text.substring(2)}';
  }
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?$',
  ).firstMatch(text);
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  final second = int.tryParse(match[3] ?? '0')!;
  if (hour > 23 || minute > 59 || second > 59) return null;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
