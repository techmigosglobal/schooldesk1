/// Student entity — pure domain object, no JSON serialization here.
class Student {
  final String id;
  final String name;
  final String admissionNumber;
  final String rollNumber;
  final String className;
  final String section;
  final String parentName;
  final String parentPhone;
  final String? parentEmail;
  final String? photoUrl;
  final DateTime? dateOfBirth;
  final String? address;
  final String status; // 'Active', 'Inactive', 'Transferred'
  final DateTime createdAt;

  const Student({
    required this.id,
    required this.name,
    required this.admissionNumber,
    required this.rollNumber,
    required this.className,
    required this.section,
    required this.parentName,
    required this.parentPhone,
    this.parentEmail,
    this.photoUrl,
    this.dateOfBirth,
    this.address,
    this.status = 'Active',
    required this.createdAt,
  });

  Student copyWith({
    String? id,
    String? name,
    String? admissionNumber,
    String? rollNumber,
    String? className,
    String? section,
    String? parentName,
    String? parentPhone,
    String? parentEmail,
    String? photoUrl,
    DateTime? dateOfBirth,
    String? address,
    String? status,
    DateTime? createdAt,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      admissionNumber: admissionNumber ?? this.admissionNumber,
      rollNumber: rollNumber ?? this.rollNumber,
      className: className ?? this.className,
      section: section ?? this.section,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      parentEmail: parentEmail ?? this.parentEmail,
      photoUrl: photoUrl ?? this.photoUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      address: address ?? this.address,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) => other is Student && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Student(id: $id, name: $name, class: $className-$section)';
}
