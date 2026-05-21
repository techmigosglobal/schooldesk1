/// Teacher / Staff entity — domain object.
class Teacher {
  final String id;
  final String name;
  final String employeeId;
  final String email;
  final String phone;
  final String subject;
  final String designation;
  final String? assignedClass;
  final String? assignedSection;
  final String? photoUrl;
  final String status; // 'Active', 'On Leave', 'Inactive'
  final DateTime joinDate;
  final int leaveBalance;

  const Teacher({
    required this.id,
    required this.name,
    required this.employeeId,
    required this.email,
    required this.phone,
    required this.subject,
    required this.designation,
    this.assignedClass,
    this.assignedSection,
    this.photoUrl,
    this.status = 'Active',
    required this.joinDate,
    this.leaveBalance = 12,
  });

  Teacher copyWith({
    String? id,
    String? name,
    String? employeeId,
    String? email,
    String? phone,
    String? subject,
    String? designation,
    String? assignedClass,
    String? assignedSection,
    String? photoUrl,
    String? status,
    DateTime? joinDate,
    int? leaveBalance,
  }) {
    return Teacher(
      id: id ?? this.id,
      name: name ?? this.name,
      employeeId: employeeId ?? this.employeeId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      subject: subject ?? this.subject,
      designation: designation ?? this.designation,
      assignedClass: assignedClass ?? this.assignedClass,
      assignedSection: assignedSection ?? this.assignedSection,
      photoUrl: photoUrl ?? this.photoUrl,
      status: status ?? this.status,
      joinDate: joinDate ?? this.joinDate,
      leaveBalance: leaveBalance ?? this.leaveBalance,
    );
  }

  @override
  bool operator ==(Object other) => other is Teacher && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
