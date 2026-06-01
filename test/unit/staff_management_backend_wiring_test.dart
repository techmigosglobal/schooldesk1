import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staff management actions are wired to backend mutations', () {
    final source = File(
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Read-only mode: staff data')));
    expect(source, isNot(contains('onPressed: _showReadOnlyMessage')));
    expect(source, isNot(contains('showModalBottomSheet')));
    expect(source, isNot(contains('Navigator.pushNamed')));
    expect(source, contains('All Staff Directory'));
    expect(source, contains('class _StaffProfileFormPage'));
    expect(source, contains('BackendApiClient.instance.createStaff'));
    expect(source, contains('BackendApiClient.instance.updateStaff'));
    expect(source, contains('BackendApiClient.instance.deleteStaff'));
    expect(source, contains('uploadStaffPhoto'));
    expect(source, contains('uploadStaffDocument'));
    expect(source, contains("createRaw('/staff-subjects'"));
    expect(source, contains("deleteRaw('/staff-subjects/"));
    expect(source, contains("payload['section_id'] = assignment.sectionId"));
    expect(source, contains('staffSubjectKey'));
    expect(source, contains('Login Username'));
    expect(source, contains('username: input.username'));
    expect(source, contains('Designation'));
    expect(source, isNot(contains('Department')));
    expect(source, isNot(contains('departmentId: input.department')));
    expect(source, contains('withData: kIsWeb'));
    expect(source, contains('fileBytes: document.fileBytes'));
    expect(source, isNot(contains('_generateEmployeeId')));
    expect(source, isNot(contains('Login username:')));
  });

  test('staff profile form keeps form fields responsive on phone widths', () {
    final source = File(
      'lib/features/people/presentation/screens/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();

    expect(source, contains('class _ResponsiveFieldRow'));
    expect(source, contains('constraints.maxWidth < 330'));
    expect(source, contains('class _LabeledField'));
    expect(source, contains('Add Staff Profile'));
    expect(source, contains('isExpanded: true'));
    expect(source, contains('overflow: TextOverflow.ellipsis'));
  });

  test('staff create and update payloads use designation only', () {
    final apiSource = File(
      'lib/core/network/api_modules/staff_api.dart',
    ).readAsStringSync();
    final formSource = File(
      'lib/features/people/presentation/screens/staff_management_screen/staff_form_screen.dart',
    ).readAsStringSync();
    final dtoSource = File('school-backend/internal/models/dto.go')
        .readAsStringSync()
        .split('type CreateStaffRequest struct')
        .last
        .split('type CreateStudentRequest struct')
        .first;

    expect(apiSource, contains("'designation': designation ?? ''"));
    expect(apiSource, isNot(contains("'department_id'")));
    expect(apiSource, isNot(contains("'department_name'")));
    expect(formSource, contains("_buildDesignationField()"));
    expect(formSource, isNot(contains("_buildDepartmentField()")));
    expect(dtoSource, contains('Designation'));
    expect(dtoSource, isNot(contains('DepartmentID')));
    expect(dtoSource, isNot(contains('DepartmentName')));
  });
}
