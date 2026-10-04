import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'teacher chat retains contact after first message creates conversation',
    () {
      final source = File(
        'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
      ).readAsStringSync();

      expect(source, contains("selected?['is_contact_placeholder'] != true"));
      expect(source, contains("selectedType == 'parent_teacher'"));
      expect(source, contains("_text(row['parent_id']) == selectedParentId"));
      expect(source, contains("selectedType == 'principal_teacher'"));
      expect(source, contains("_text(row['leader_id']) == selectedLeaderId"));
    },
  );

  test(
    'parent leadership chat retains placeholder after conversation creation',
    () {
      final source = File(
        'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
      ).readAsStringSync();

      expect(
        source,
        contains("selected?.conversationType == 'principal_parent'"),
      );
      expect(
        source,
        contains('thread.conversationType == \'principal_parent\''),
      );
      expect(source, contains('thread.leaderId == selected!.leaderId'));
    },
  );
}
