import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/shared/data/models/backend_models.dart';

void main() {
  test('student model accepts live section and parent-link payloads', () {
    final student = StudentModel.fromJson({
      'id': 'student-1',
      'school_id': 'school-1',
      'student_id_number': 'SID-1',
      'admission_number': 'ADM-1',
      'first_name': 'Asha',
      'last_name': 'Rao',
      'status': 'active',
      'current_section_id': 'section-1',
      'section': {
        'id': 'section-1',
        'section_name': 'A',
        'grade': {'grade_name': 'Day Care A'},
      },
      'parent_student_links': [
        {
          'parent_user_id': 'parent-1',
          'parent': {
            'id': 'parent-1',
            'name': 'Priya Rao',
            'phone': '9000000000',
          },
        },
      ],
    });

    expect(student.currentSection['section_name'], 'A');
    expect(student.currentSection['grade']['grade_name'], 'Day Care A');
    expect(student.parentUserId, 'parent-1');
    expect(student.primaryGuardianName, 'Priya Rao');
    expect(student.primaryGuardianPhone, '9000000000');
  });
}
