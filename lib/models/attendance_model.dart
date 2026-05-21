class AttendanceModel {
  const AttendanceModel({
    required this.id,
    required this.studentId,
    required this.status,
    this.date,
    this.classId,
  });

  final String id;
  final String studentId;
  final String status;
  final String? date;
  final String? classId;

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    final session = json['session'] is Map
        ? Map<String, dynamic>.from(json['session'] as Map)
        : null;
    return AttendanceModel(
      id: (json['id'] ?? '').toString(),
      studentId: (json['student_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      date: (json['date'] ?? json['marked_at'] ?? session?['date'])?.toString(),
      classId: (json['class_id'] ?? session?['section_id'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'status': status,
    if (date != null) 'date': date,
    if (classId != null) 'class_id': classId,
  };
}
