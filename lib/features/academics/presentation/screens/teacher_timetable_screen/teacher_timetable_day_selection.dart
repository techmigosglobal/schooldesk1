const List<int> defaultTeacherWorkingDays = [1, 2, 3, 4, 5, 6];

List<int> normalizeTeacherWorkingDays(Iterable<int> days) {
  final normalized =
      days
          .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
          .toSet()
          .toList()
        ..sort();
  return normalized.isEmpty
      ? List<int>.from(defaultTeacherWorkingDays)
      : normalized;
}

int selectInitialTeacherTimetableDay({
  required Iterable<int> workingDays,
  DateTime? now,
}) {
  final normalized = normalizeTeacherWorkingDays(workingDays);
  final today = (now ?? DateTime.now()).weekday;
  return normalized.contains(today) ? today : normalized.first;
}
