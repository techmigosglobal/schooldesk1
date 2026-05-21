class StudentModel {
  const StudentModel({
    this.id,
    required this.firstName,
    required this.lastName,
    this.rollNumber,
    this.classId,
    this.parentId,
    this.dateOfBirth,
    this.address,
  });

  final String? id;
  final String firstName;
  final String lastName;
  final String? rollNumber;
  final String? classId;
  final String? parentId;
  final String? dateOfBirth;
  final String? address;

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id']?.toString(),
      firstName: (json['first_name'] ?? json['firstName'] ?? '').toString(),
      lastName: (json['last_name'] ?? json['lastName'] ?? '').toString(),
      rollNumber: (json['roll_number'] ?? json['rollNumber'])?.toString(),
      classId: (json['class_id'] ?? json['current_section_id'])?.toString(),
      parentId: json['parent_id']?.toString(),
      dateOfBirth: (json['dob'] ?? json['date_of_birth'])?.toString(),
      address: json['address']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'first_name': firstName,
    'last_name': lastName,
    if (rollNumber != null) 'roll_number': rollNumber,
    if (classId != null) 'class_id': classId,
    if (parentId != null) 'parent_id': parentId,
    if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
    if (address != null) 'address': address,
  };
}
