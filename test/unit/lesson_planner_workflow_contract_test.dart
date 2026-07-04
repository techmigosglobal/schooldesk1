import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher lesson planner uses teacher shell without back button', () {
    final screen = File(
      'lib/features/academics/presentation/screens/lesson_planner_screen.dart',
    ).readAsStringSync();
    final teacherFlow = File(
      'lib/core/widgets/teacher_flow_ui.dart',
    ).readAsStringSync();

    expect(screen, contains('TeacherFlowScaffold('));
    expect(screen, contains('selectedIndex: TeacherNav.lessonPlanner'));
    expect(screen, isNot(contains('SchoolDeskModuleScaffold(')));
    expect(teacherFlow, contains('showBackButton: false'));
    expect(teacherFlow, contains('drawer: TeacherDrawer('));
  });

  test('teacher lesson planner posts multiple attachments for one week', () {
    final screen = File(
      'lib/features/academics/presentation/screens/lesson_planner_screen.dart',
    ).readAsStringSync();
    final api = File(
      'lib/core/network/api_modules/events_api.dart',
    ).readAsStringSync();

    expect(screen, contains('List<_LessonPlannerAttachment> _attachments'));
    expect(screen, contains('allowMultiple: true'));
    expect(screen, contains('_attachments.map((item) => item.toJson())'));
    expect(screen, contains('attachments: _attachments.map'));
    expect(screen, contains('At least one lesson plan file is required.'));

    expect(api, contains('List<Map<String, dynamic>> attachments = const []'));
    expect(api, contains("'attachments': attachments"));
    expect(api, contains("'attachment_url': attachmentUrl"));
  });

  test('backend scopes lesson planners by teacher and parent section', () {
    final handler = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();

    expect(handler, contains('lessonPlannerAssignedSectionIds'));
    expect(handler, contains('lessonPlannerParentSectionIds'));
    expect(handler, contains('ensureLessonPlannerTeacherCanPost'));
    expect(handler, contains('class_teacher_id'));
    expect(handler, contains('co_teacher_id'));
    expect(handler, contains('staff_subjects'));
    expect(handler, contains('parent_student_links'));
    expect(handler, contains('current_section_id'));
    expect(handler, contains(r'sectionIds.has(`${row.section_id ?? ""}`)'));
    expect(handler, contains('status !== "draft"'));
  });

  test('lesson planner rows normalize and render multiple attachments', () {
    final handler = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();
    final principal = File(
      'lib/features/academics/presentation/screens/principal_lesson_planner_screen.dart',
    ).readAsStringSync();
    final parent = File(
      'lib/features/academics/presentation/screens/parent_lesson_planner_screen/parent_lesson_planner_screen.dart',
    ).readAsStringSync();

    expect(handler, contains('normalizeLessonPlannerAttachments'));
    expect(handler, contains('attachments: normalizeLessonPlannerAttachments'));
    expect(
      handler,
      contains('attachment_url: firstLessonPlannerAttachmentUrl'),
    );
    expect(principal, contains('_lessonPlannerAttachments(planner)'));
    expect(parent, contains('_lessonPlannerAttachments(planner)'));
    expect(principal, contains('Open attachment'));
    expect(parent, contains('View Attachment'));
  });
}
