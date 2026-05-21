import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staff management actions are wired to backend mutations', () {
    final source = File(
      'lib/presentation/staff_management_screen/staff_management_screen.dart',
    ).readAsStringSync();
    final form = File(
      'lib/presentation/staff_management_screen/staff_form_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('Read-only mode: staff data')));
    expect(source, isNot(contains('onPressed: _showReadOnlyMessage')));
    expect(source, isNot(contains('showModalBottomSheet')));
    expect(source, contains('Navigator.pushNamed'));
    expect(form, contains('class StaffFormScreen'));
    expect(form, contains('BackendApiClient.instance.createStaff'));
    expect(form, contains('BackendApiClient.instance.updateStaff'));
    expect(source, contains('BackendApiClient.instance.deleteStaff'));
  });

  test('staff form keeps form fields responsive on phone widths', () {
    final source = File(
      'lib/presentation/staff_management_screen/staff_form_screen.dart',
    ).readAsStringSync();

    expect(source, contains('Widget _buildResponsivePair('));
    expect(source, contains('constraints.maxWidth < 620'));
    expect(source, contains('Widget _buildDepartmentField()'));
    expect(source, contains('Widget _buildDesignationField()'));
    expect(source, contains('isExpanded: true'));
    expect(source, contains('overflow: TextOverflow.ellipsis'));
  });
}
