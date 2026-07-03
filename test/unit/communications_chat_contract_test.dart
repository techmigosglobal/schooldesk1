import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'legacy homework messaging route forwards into the unified chat screens',
    () {
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();

      expect(routes, contains("case 'parent':"));
      expect(routes, contains('return const ParentTeacherChatScreen();'));
      expect(routes, contains("case 'principal':"));
      expect(
        routes,
        contains('return const PrincipalChatCommunicationsScreen();'),
      );
      expect(routes, contains('return const TeacherCommunicationScreen();'));
    },
  );

  test(
    'chat handler protects conversation access and notifies principals in direct chats',
    () {
      final handler = File(
        'supabase/functions/api/handlers/communications.ts',
      ).readAsStringSync();

      expect(handler, contains('function canReadChatConversation'));
      expect(handler, contains('function canSendChatMessage'));
      expect(handler, contains('return fail("forbidden", 403);'));
      expect(handler, contains('resolveChatNotificationTarget'));
      expect(handler, contains('const createdBy = text(conversation.created_by);'));
      expect(handler, contains('async function principalUserIdForSchool'));
      expect(handler, contains('if (type === "principal_parent")'));
      expect(handler, contains('if (type === "principal_teacher")'));
      expect(handler, contains('if (createdBy && createdBy !== user.id)'));
    },
  );

  test(
    'parent chat keeps teacher conversations distinct per child and exposes mobile back navigation',
    () {
      final parentScreen = File(
        'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
      ).readAsStringSync();
      final teacherScreen = File(
        'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
      ).readAsStringSync();
      final principalScreen = File(
        'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
      ).readAsStringSync();

      expect(parentScreen, contains('String _teacherThreadKey('));
      expect(parentScreen, contains("'\$teacherId::\$studentId'"));
      expect(parentScreen, contains("conversationType: 'principal_parent'"));
      expect(
        parentScreen,
        contains('School leadership - tap to start direct chat'),
      );
      expect(parentScreen, contains("tooltip: 'Back to chats'"));
      expect(teacherScreen, contains("tooltip: 'Back to chats'"));
      expect(principalScreen, contains("tooltip: 'Back to chats'"));
    },
  );

  test(
    'principal chat direct tab hydrates teacher and parent contacts even before threads exist',
    () {
      final principalScreen = File(
        'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
      ).readAsStringSync();

      expect(principalScreen, contains('_mergeDirectConversationsWithContacts('));
      expect(principalScreen, contains("api.getStaff(page: 1, pageSize: 200)"));
      expect(principalScreen, contains("api.getUsers(\n        role: 'Parent',"));
      expect(principalScreen, contains("'id': 'contact-teacher-\$id'"));
      expect(principalScreen, contains("'id': 'contact-parent-\$id'"));
      expect(
        principalScreen,
        contains('Teacher contact - tap to start direct chat'),
      );
      expect(
        principalScreen,
        contains('Parent contact - tap to start direct chat'),
      );
    },
  );

  test(
    'teacher chat hydrates parent and principal contacts even before direct threads exist',
    () {
      final teacherScreen = File(
        'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
      ).readAsStringSync();

      expect(teacherScreen, contains('_mergeConversationsWithContacts('));
      expect(teacherScreen, contains('api.getUsers(page: 1, pageSize: 200)'));
      expect(teacherScreen, contains("'id': 'contact-parent-\$parentId'"));
      expect(
        teacherScreen,
        contains("'id': 'contact-principal-\$principalId'"),
      );
      expect(
        teacherScreen,
        contains('Parent contact - tap to start direct chat'),
      );
      expect(
        teacherScreen,
        contains('School leadership - tap to start direct chat'),
      );
    },
  );
}
