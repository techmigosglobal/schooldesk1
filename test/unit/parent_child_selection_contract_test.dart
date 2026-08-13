import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/role_access_service.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('parent child selection persistence helper is wired to parent screens', () {
    final helper = read(
      'lib/core/services/parent_child_selection_service.dart',
    );
    expect(helper, contains('StorageKeys.parentSelectedChild'));
    expect(helper, contains('SharedPreferences.getInstance'));
    expect(helper, contains('Future<int> indexFor'));
    expect(helper, contains('Future<void> saveIndex'));
    expect(helper, contains('Future<void> saveStudentId'));

    for (final path in const [
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
      'lib/features/attendance/presentation/screens/parent_attendance_screen/parent_attendance_screen.dart',
      'lib/features/homework/presentation/screens/parent_homework_screen/parent_homework_screen.dart',
      'lib/features/academics/presentation/screens/parent_timetable_screen/parent_timetable_screen.dart',
      'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
      'lib/features/documents/presentation/screens/parent_documents_screen/parent_documents_screen.dart',
      'lib/features/finance/presentation/screens/parent_hub/parent_fee_hub.dart',
      'lib/features/leave/presentation/screens/parent_leave_screen/parent_leave_screen.dart',
    ]) {
      final source = read(path);
      expect(
        source,
        contains('ParentChildSelectionService.indexFor'),
        reason: '$path must restore the selected child',
      );
      expect(
        source,
        contains('ParentChildSelectionService.saveIndex'),
        reason: '$path must persist child selector changes',
      );
    }
  });

  test(
    'RoleAccessService.childAt fails loudly for invalid parent child index',
    () {
      RoleAccessService.clear();

      expect(() => RoleAccessService.childAt(0), returnsNormally);

      final source = read('lib/core/services/role_access_service.dart');
      expect(source, contains('RangeError.index'));
      expect(source, isNot(contains('return _parentChildren.first;')));
    },
  );
}
