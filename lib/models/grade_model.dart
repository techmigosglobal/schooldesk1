class GradeModel {
  const GradeModel({
    required this.id,
    required this.studentId,
    required this.marks,
    this.subjectId,
    this.examType,
    this.maxMarks,
  });

  final String id;
  final String studentId;
  final double marks;
  final String? subjectId;
  final String? examType;
  final double? maxMarks;

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    final schedule = json['exam_schedule'] is Map
        ? Map<String, dynamic>.from(json['exam_schedule'] as Map)
        : null;
    return GradeModel(
      id: (json['id'] ?? '').toString(),
      studentId: (json['student_id'] ?? '').toString(),
      marks: ((json['marks'] ?? json['marks_obtained'] ?? 0) as num).toDouble(),
      subjectId: (json['subject_id'] ?? schedule?['subject_id'])?.toString(),
      examType: json['exam_type']?.toString(),
      maxMarks: json['max_marks'] is num
          ? (json['max_marks'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'student_id': studentId,
    'marks': marks,
    if (subjectId != null) 'subject_id': subjectId,
    if (examType != null) 'exam_type': examType,
    if (maxMarks != null) 'max_marks': maxMarks,
  };
}
