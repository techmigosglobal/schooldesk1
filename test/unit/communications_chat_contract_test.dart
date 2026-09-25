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
    'chat handler protects conversation access and preserves direct-leader ownership',
    () {
      final handler = File(
        'supabase/functions/api/handlers/communications.ts',
      ).readAsStringSync();

      expect(handler, contains('function canReadChatConversation'));
      expect(handler, contains('function canSendChatMessage'));
      expect(handler, contains('return fail("forbidden", 403);'));
      expect(handler, contains('resolveChatNotificationTarget'));
      expect(
        handler,
        contains(
          'const createdBy = text(conversation.leader_id ?? conversation.created_by);',
        ),
      );
      expect(handler, contains('async function principalUserIdForSchool'));
      expect(handler, contains('if (type === "principal_parent")'));
      expect(handler, contains('if (type === "principal_teacher")'));
      expect(handler, contains('if (createdBy && createdBy !== user.id)'));
    },
  );

  test(
    'chat handler exposes scoped contacts and validates conversation participants',
    () {
      final handler = File(
        'supabase/functions/api/handlers/communications.ts',
      ).readAsStringSync();

      expect(handler, contains('if (path === "/chat/contacts"'));
      expect(handler, contains('async function parentChatContacts'));
      expect(handler, contains('async function teacherChatContacts'));
      expect(handler, contains('async function principalChatContacts'));
      expect(handler, contains('async function validateChatConversationScope'));
      expect(
        handler,
        contains('parent_teacher scope requires a linked student'),
      );
      expect(
        handler,
        contains('teacher is not assigned to this class section'),
      );
      expect(
        handler,
        contains('principal_parent scope requires a parent and linked student'),
      );
      expect(
        handler,
        contains('principal_teacher scope requires a teacher participant'),
      );
    },
  );

  test(
    'chat realtime migration publishes conversation and message changes',
    () {
      final migration = File(
        'supabase/migrations/20260706180000_chat_realtime_scope.sql',
      ).readAsStringSync();

      expect(migration, contains('supabase_realtime'));
      expect(migration, contains('public.message_conversations'));
      expect(migration, contains('public.messages'));
      expect(
        migration,
        contains(
          'alter table public.message_conversations replica identity full',
        ),
      );
      expect(
        migration,
        contains('alter table public.messages replica identity full'),
      );
    },
  );

  test('Flutter chat screens subscribe to Supabase realtime refresh events', () {
    final service = File(
      'lib/core/services/chat_realtime_service.dart',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/communications_api.dart',
    ).readAsStringSync();
    final parentScreen = File(
      'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
    ).readAsStringSync();
    final parentRepository = File(
      'lib/roles/parent/data/api_parent_communication_repository.dart',
    ).readAsStringSync();
    final teacherScreen = File(
      'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
    ).readAsStringSync();
    final teacherRepository = File(
      'lib/roles/teacher/data/api_teacher_communication_repository.dart',
    ).readAsStringSync();
    final principalScreen = File(
      'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
    ).readAsStringSync();

    expect(service, contains('final client = Supabase.instance.client;'));
    expect(
      service,
      contains('await Supabase.instance.client.realtime.setAuth(token.trim())'),
    );
    expect(service, contains('Future<bool> refreshAuth()'));
    expect(service, contains('if (!await refreshAuth()) return null;'));
    expect(service, contains('onPostgresChanges'));
    expect(service, contains("table: 'messages'"));
    expect(service, contains("table: 'message_conversations'"));
    expect(
      api,
      contains('Future<List<Map<String, dynamic>>> getUnifiedChatContacts'),
    );
    expect(parentScreen, contains('ChatRealtimeService.instance.subscribe'));
    expect(teacherScreen, contains('ChatRealtimeService.instance.subscribe'));
    expect(principalScreen, contains('ChatRealtimeService.instance.subscribe'));
    expect(parentScreen, contains('_repository.loadContacts('));
    expect(parentRepository, contains("role: 'parent'"));
    expect(teacherScreen, contains('_repository.loadContacts()'));
    expect(
      teacherRepository,
      contains("getUnifiedChatContacts(role: 'teacher'"),
    );
    expect(
      principalScreen,
      contains('_repository.loadContacts(role: _leadershipRole)'),
    );
  });

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
        contains('tap to start direct chat'),
      );
      expect(parentScreen, contains('leaderId: leaderId'));
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

      expect(
        principalScreen,
        contains('_mergeDirectConversationsWithContacts('),
      );
      expect(principalScreen, contains('_safeChatRows('));
      expect(
        principalScreen,
        contains('_repository.loadContacts(role: _leadershipRole)'),
      );
      expect(
        principalScreen,
        isNot(contains("api.getStaff(page: 1, pageSize: 200)")),
      );
      expect(
        principalScreen,
        isNot(contains("api.getUsers(role: 'Parent'")),
      );
      expect(principalScreen, contains("'id': 'contact-teacher-\$id'"));
      expect(
        principalScreen,
        contains("'id': 'contact-parent-\$id-\$studentId'"),
      );
      expect(
        principalScreen,
        contains('_directContactHint(row, \'Teacher contact\')'),
      );
      expect(
        principalScreen,
        contains('_directContactHint(row, \'Parent contact\')'),
      );
      expect(principalScreen, contains('directTeacher.where(_canSendIn)'));
      expect(principalScreen, contains('directParent.where(_canSendIn)'));
    },
  );

  test('principal chat keeps monitor and direct selection isolated', () {
    final principalScreen = File(
      'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
    ).readAsStringSync();

    expect(principalScreen, contains('_selectedMonitorConversation'));
    expect(principalScreen, contains('_selectedDirectConversation'));
    expect(principalScreen, contains('_monitorMessages'));
    expect(principalScreen, contains('_directMessages'));
    expect(principalScreen, contains('_selectRetainedConversation('));
    expect(principalScreen, contains('_clearMessagesFor('));
    expect(principalScreen, isNot(contains('orElse: () => source.first')));
  });

  test('chat screens deduplicate overlapping realtime message batches', () {
    final principalScreen = File(
      'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
    ).readAsStringSync();
    final parentScreen = File(
      'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
    ).readAsStringSync();
    final teacherScreen = File(
      'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
    ).readAsStringSync();

    expect(
      principalScreen,
      contains('mergeChatMessagesByIdentity(current, newMessages)'),
    );
    expect(
      parentScreen,
      contains('mergeChatMessagesByIdentity(_messages, newMessages)'),
    );
    expect(
      teacherScreen,
      contains('mergeChatMessagesByIdentity(_messages, newMessages)'),
    );
  });

  test(
    'principal communication screen labels participant roles and clears unread state on open',
    () {
      final principalScreen = File(
        'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
      ).readAsStringSync();
      final bubble = File(
        'lib/features/communication/presentation/widgets/chat_shared_widgets.dart',
      ).readAsStringSync();

      expect(principalScreen, contains('_directRoleLabel('));
      expect(principalScreen, contains('_messageRole('));
      expect(principalScreen, contains('_messageSenderName('));
      expect(principalScreen, contains('_markConversationRead('));
      expect(principalScreen, contains('_zeroUnreadFor('));
      expect(principalScreen, contains("'unread_count': 0"));
      expect(principalScreen, contains(r'Chatting with ${_directRoleLabel'));
      expect(bubble, contains('final String senderLabel;'));
      expect(bubble, contains('final String senderRoleLabel;'));
    },
  );

  test(
    'chat notifications target recipients and principal monitor inboxes with route metadata',
    () {
      final handler = File(
        'supabase/functions/api/handlers/communications.ts',
      ).readAsStringSync();

      expect(handler, contains('async function principalUserIdsForSchool'));
      expect(handler, contains('target_role: targetRole'));
      expect(handler, contains('chatRouteForRole(target.role)'));
      expect(handler, contains('priority: "medium"'));
      expect(handler, contains('if (type == "parent_teacher" &&'));
      expect(handler, contains('"Parent-teacher chat updated"'));
      expect(handler, contains('async function chatNotificationTargets'));
      expect(handler, contains('School leader replied'));
      expect(handler, contains('event_type: "message"'));
      expect(handler, contains('student_id: text(context.student_id)'));
    },
  );

  test('principal monitor filters stay readable in narrow side panels', () {
    final principalScreen = File(
      'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
    ).readAsStringSync();

    expect(principalScreen, contains('scrollDirection: Axis.horizontal'));
    expect(principalScreen, contains('ConstrainedBox('));
    expect(principalScreen, contains("label: 'Teacher'"));
    expect(principalScreen, contains("label: 'Parent'"));
    expect(principalScreen, contains("label: 'Student'"));
    expect(principalScreen, contains("label: const Text('Unread')"));
    expect(
      principalScreen,
      contains('backgroundColor: context.appTheme.surface'),
    );
    expect(
      principalScreen,
      contains('side: BorderSide(color: context.appTheme.outlineVariant)'),
    );
    expect(
      principalScreen,
      contains('selectedColor: context.appTheme.primaryContainer'),
    );
    expect(
      principalScreen,
      contains('checkmarkColor: context.appTheme.primary'),
    );
    expect(principalScreen, contains('color: context.appTheme.onSurface'));
  });

  test(
    'principal direct-contact filters retain readable contrast and class context',
    () {
      final principalScreen = File(
        'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
      ).readAsStringSync();

      expect(principalScreen, contains('Widget _directFilters()'));
      expect(principalScreen, contains('SingleChildScrollView('));
      expect(principalScreen, contains("label: 'Teachers (\$teacherCount)'"));
      expect(principalScreen, contains("label: 'Parents (\$parentCount)'"));
      expect(
        principalScreen,
        contains('selectedColor: theme.primaryContainer'),
      );
      expect(
        principalScreen,
        contains('color: selected ? theme.primary : theme.onSurface'),
      );
      expect(principalScreen, contains('List<String> _classSectionsFor'));
      expect(principalScreen, contains('String _directContactHint'));
    },
  );

  test(
    'teacher chat hydrates parent and principal contacts even before direct threads exist',
    () {
      final teacherScreen = File(
        'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
      ).readAsStringSync();
      final teacherRepository = File(
        'lib/roles/teacher/data/api_teacher_communication_repository.dart',
      ).readAsStringSync();

      expect(teacherScreen, contains('_mergeConversationsWithContacts('));
      expect(teacherScreen, contains('_repository.loadContacts()'));
      expect(
        teacherRepository,
        contains("getUnifiedChatContacts(role: 'teacher'"),
      );
      expect(
        teacherScreen,
        isNot(contains('api.getUsers(page: 1, pageSize: 200)')),
      );
      expect(
        teacherScreen,
        contains("'id': 'contact-parent-\$parentId-\$studentId'"),
      );
      expect(teacherScreen, contains("'student_id': studentId"));
      expect(
        teacherScreen,
        contains("studentId: _text(conversation['student_id'])"),
      );
      expect(teacherScreen, contains("'id': 'contact-leader-\$leaderId'"));
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

  test(
    'chat contacts expose the expected teacher parent and parent teacher co-teacher workflow',
    () {
      final handler = File(
        'supabase/functions/api/handlers/communications.ts',
      ).readAsStringSync();
      final parentScreen = File(
        'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
      ).readAsStringSync();

      expect(handler, contains('contact_role: "class_teacher"'));
      expect(handler, contains('contact_role: "co_teacher"'));
      expect(handler, contains('student_name: [text(student?.first_name)'));
      expect(handler, contains('...context'));
      expect(handler, contains('type: "principal_parent"'));
      expect(handler, contains('type: "principal_teacher"'));
      expect(handler, isNot(contains('type: "teacher_teacher"')));
      expect(parentScreen, contains("_contactSubtitle(c)"));
      expect(parentScreen, contains("contactRole == 'co_teacher'"));
      expect(parentScreen, contains(": 'Teacher'"));
      expect(parentScreen, contains('_selectRetainedThread('));
      expect(parentScreen, contains('_clearMessages()'));
      expect(parentScreen, isNot(contains('orElse: () => threads.first')));
    },
  );

  test(
    'teacher communication lists available chats without auto-opening the first thread',
    () {
      final teacherScreen = File(
        'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
      ).readAsStringSync();
      final teacherNav = File(
        'lib/core/widgets/teacher_navigation.dart',
      ).readAsStringSync();

      expect(teacherScreen, contains("title: 'Communication'"));
      expect(teacherScreen, contains('Parent and principal chats'));
      expect(teacherNav, contains("label: 'Communication'"));
      expect(teacherScreen, contains('_selectRetainedConversation('));
      expect(teacherScreen, contains('_clearMessages()'));
      expect(teacherScreen, contains("type: 'parent_teacher'"));
      expect(teacherScreen, contains("type: 'principal_teacher'"));
      expect(
        teacherScreen,
        isNot(contains('orElse: () => conversations.first')),
      );
    },
  );

  test(
    'chat scope migration removes broad policies and preserves branch access',
    () {
      final migration = File(
        'supabase/migrations/20260804120000_chat_scope_and_realtime_rls.sql',
      ).readAsStringSync();

      expect(
        migration,
        contains('drop policy if exists "message_conversations_school_select"'),
      );
      expect(migration, contains('chat_can_access_conversation'));
      expect(migration, contains('branch_memberships'));
      expect(migration, contains('chat_messages_participant_select'));
      expect(migration, contains('alter publication supabase_realtime'));
      expect(migration, contains('replica identity full'));
    },
  );

  test('leaders can reply inside monitored parent-teacher conversations', () {
    final handler = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();
    final principalScreen = File(
      'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
    ).readAsStringSync();

    expect(
      handler,
      contains(
        'return await canReadChatConversation(svc, school, conversation, user);',
      ),
    );
    expect(handler, contains('if (canManageSchoolContent(user))'));
    expect(
      principalScreen,
      contains(
        "if (_text(conversation['type']) == 'parent_teacher') return true;",
      ),
    );
    expect(principalScreen, contains('replies stay in this thread'));
  });

  test('chat reads and notifications retain participant and student scope', () {
    final handler = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();
    final processor = File(
      'supabase/functions/notification-processor/index.ts',
    ).readAsStringSync();
    final realtime = File(
      'lib/core/services/chat_realtime_service.dart',
    ).readAsStringSync();

    expect(handler, contains('async function parentIsLinkedToStudent'));
    expect(handler, contains('async function teacherIsAssignedToStudent'));
    expect(handler, contains('lessonPlannerAssignedSectionIds'));
    expect(
      handler,
      contains(
        'if (!conversationId) return fail("conversation_id is required", 400);',
      ),
    );
    expect(handler, contains('async function chatNotificationTargets'));
    expect(handler, contains('event_type: "message"'));
    expect(processor, contains('case "message":'));
    expect(
      processor,
      contains('student_id: String(eventData.student_id || "")'),
    );
    expect(realtime, contains("column: 'conversation_id'"));
    expect(
      realtime,
      isNot(matches(RegExp(r"table: 'messages',\s*callback"))),
    );
  });

  test(
    'coordinator uses the same leadership chat route with branch context',
    () {
      final routes = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final apiIndex = File(
        'supabase/functions/api/index.ts',
      ).readAsStringSync();

      expect(
        routes,
        contains("AppRoutes.principalChatCommunications: {'principal'}"),
      );
      expect(routes, contains("return {...configured, 'coordinator'};"));
      expect(apiIndex, contains('x-schooldesk-branch-id'));
      expect(apiIndex, contains('currentRole === "coordinator"'));
      expect(apiIndex, contains('branch_memberships'));
    },
  );
}
