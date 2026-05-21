/// Homework assignment entity.
class HomeworkAssignment {
  final String id;
  final String title;
  final String description;
  final String subject;
  final String className;
  final String section;
  final String assignedBy;
  final DateTime assignedDate;
  final DateTime dueDate;
  final List<String> submittedBy;
  final String status; // 'Active', 'Closed', 'Graded'

  const HomeworkAssignment({
    required this.id,
    required this.title,
    required this.description,
    required this.subject,
    required this.className,
    required this.section,
    required this.assignedBy,
    required this.assignedDate,
    required this.dueDate,
    this.submittedBy = const [],
    this.status = 'Active',
  });

  bool get isOverdue => dueDate.isBefore(DateTime.now()) && status == 'Active';
  int get submissionCount => submittedBy.length;

  HomeworkAssignment copyWith({
    String? id,
    String? title,
    String? description,
    String? subject,
    String? className,
    String? section,
    String? assignedBy,
    DateTime? assignedDate,
    DateTime? dueDate,
    List<String>? submittedBy,
    String? status,
  }) {
    return HomeworkAssignment(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      className: className ?? this.className,
      section: section ?? this.section,
      assignedBy: assignedBy ?? this.assignedBy,
      assignedDate: assignedDate ?? this.assignedDate,
      dueDate: dueDate ?? this.dueDate,
      submittedBy: submittedBy ?? this.submittedBy,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HomeworkAssignment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
