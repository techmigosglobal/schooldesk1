/// Attendance record entity.
class AttendanceRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String className;
  final String section;
  final DateTime date;
  final String status; // 'Present', 'Absent', 'Late', 'Half-Day', 'Leave'
  final String? remarks;
  final String? markedBy;
  final DateTime? markedAt;

  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.section,
    required this.date,
    required this.status,
    this.remarks,
    this.markedBy,
    this.markedAt,
  });

  AttendanceRecord copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? className,
    String? section,
    DateTime? date,
    String? status,
    String? remarks,
    String? markedBy,
    DateTime? markedAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      className: className ?? this.className,
      section: section ?? this.section,
      date: date ?? this.date,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      markedBy: markedBy ?? this.markedBy,
      markedAt: markedAt ?? this.markedAt,
    );
  }

  @override
  bool operator ==(Object other) => other is AttendanceRecord && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
