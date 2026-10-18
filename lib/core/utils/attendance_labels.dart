/// The dashboard tile describes the selected child's school-day register.
String attendanceTodayLabel(Map<String, dynamic> child) {
  final today = child['attendance_today'];
  if (today is! Map) return 'Not marked';
  if (today['is_finalized'] != true && today['status'] != null) {
    return 'Not submitted';
  }
  return switch ('${today['status'] ?? ''}'.toLowerCase()) {
    'present' || 'p' => 'Present',
    'absent' || 'a' => 'Absent',
    'late' || 'l' => 'Late',
    'leave' => 'Leave',
    'excused' || 'e' => 'Excused',
    _ => 'Not marked',
  };
}
