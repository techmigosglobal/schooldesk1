import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/communication/data/chat_models.dart';

void main() {
  test(
    'normalizes class and student context without discarding API fields',
    () {
      final row = <String, dynamic>{
        'id': 'contact-parent-1-student-1',
        'role': 'parent',
        'student_id': 'student-1',
        'student_name': 'Aarav Sharma',
        'section_id': 'section-1',
        'class_label': 'Grade 4 - A',
        'custom_field': 'preserved',
      };

      final normalized = normalizeChatContextMap(row);
      final context = ChatContext.fromMap(normalized);

      expect(context.displayLabel, 'Grade 4 - A - Aarav Sharma');
      expect(context.shortLabel, 'Grade 4 - A');
      expect(normalized['custom_field'], 'preserved');
      expect(
        chatConversationKey({
          'type': 'principal_parent',
          'parent_id': 'parent-1',
          'student_id': 'student-1',
          'leader_id': 'leader-1',
        }),
        'principal_parent||parent-1|student-1|leader-1',
      );
    },
  );

  test(
    'falls back to nested student labels when top-level metadata is absent',
    () {
      final context = ChatContext.fromMap({
        'student': {'id': 'student-2', 'name': 'Diya Sharma'},
        'class_label': 'Grade 2 - B',
      });

      expect(context.studentName, 'Diya Sharma');
      expect(context.displayLabel, 'Grade 2 - B - Diya Sharma');
    },
  );
}
