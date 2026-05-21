import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/shared/domain/entities/student.dart';

void main() {
  group('Student Entity', () {
    final testStudent = Student(
      id: 'stu_001',
      name: 'Arjun Sharma',
      admissionNumber: 'ADM2025001',
      rollNumber: '01',
      className: 'Class 10',
      section: 'A',
      parentName: 'Rajesh Sharma',
      parentPhone: '9876543210',
      parentEmail: 'rajesh@example.com',
      status: 'Active',
      createdAt: DateTime(2025, 1, 15),
    );

    test('creates student with required fields', () {
      expect(testStudent.id, 'stu_001');
      expect(testStudent.name, 'Arjun Sharma');
      expect(testStudent.className, 'Class 10');
      expect(testStudent.section, 'A');
    });

    test('has default status of Active', () {
      final student = Student(
        id: 'stu_002',
        name: 'Test',
        admissionNumber: 'ADM001',
        rollNumber: '01',
        className: 'Class 1',
        section: 'A',
        parentName: 'Parent',
        parentPhone: '9876543210',
        createdAt: DateTime.now(),
      );
      expect(student.status, 'Active');
    });

    group('copyWith()', () {
      test('creates copy with updated name', () {
        final updated = testStudent.copyWith(name: 'Arjun Kumar');
        expect(updated.name, 'Arjun Kumar');
        expect(updated.id, testStudent.id); // unchanged
        expect(updated.className, testStudent.className); // unchanged
      });

      test('creates copy with updated class', () {
        final promoted = testStudent.copyWith(
          className: 'Class 11',
          section: 'B',
        );
        expect(promoted.className, 'Class 11');
        expect(promoted.section, 'B');
        expect(promoted.name, testStudent.name); // unchanged
      });

      test('creates copy with updated status', () {
        final inactive = testStudent.copyWith(status: 'Inactive');
        expect(inactive.status, 'Inactive');
      });
    });

    group('equality', () {
      test('two students with same id are equal', () {
        final student2 = testStudent.copyWith(name: 'Different Name');
        expect(testStudent, equals(student2));
      });

      test('two students with different ids are not equal', () {
        final student2 = testStudent.copyWith(id: 'stu_999');
        expect(testStudent, isNot(equals(student2)));
      });
    });

    group('hashCode', () {
      test('same id produces same hashCode', () {
        final student2 = testStudent.copyWith(name: 'Other');
        expect(testStudent.hashCode, student2.hashCode);
      });
    });

    group('toString()', () {
      test('includes id, name, and class info', () {
        final str = testStudent.toString();
        expect(str, contains('stu_001'));
        expect(str, contains('Arjun Sharma'));
      });
    });
  });
}
