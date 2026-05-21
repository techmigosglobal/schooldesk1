import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('teacher and parent homework use routed screens with real submissions', () {
    final teacherScreen = File(
      'lib/presentation/teacher_homework_screen/teacher_homework_screen.dart',
    ).readAsStringSync();
    final teacherForms = File(
      'lib/presentation/teacher_homework_screen/teacher_homework_form_screens.dart',
    ).readAsStringSync();
    final parentScreen = File(
      'lib/presentation/parent_homework_screen/parent_homework_screen.dart',
    ).readAsStringSync();
    final parentForm = File(
      'lib/presentation/parent_homework_screen/parent_homework_submission_screen.dart',
    ).readAsStringSync();
    final api = File('lib/services/backend_api_client.dart').readAsStringSync();
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();
    final main = File('school-backend/main.go').readAsStringSync();
    final models = File(
      'school-backend/internal/models/hr_comms.go',
    ).readAsStringSync();
    final handler = File(
      'school-backend/internal/handlers/homework_submission.go',
    ).readAsStringSync();

    expect(teacherScreen, contains('AppRoutes.teacherHomeworkForm'));
    expect(teacherScreen, contains('AppRoutes.teacherHomeworkSubmissions'));
    expect(teacherScreen, contains('getHomework('));
    expect(teacherScreen, contains('getHomeworkSubmissions('));
    expect(teacherScreen, isNot(contains('showModalBottomSheet(')));
    expect(teacherScreen, isNot(contains('showDialog(')));
    expect(teacherScreen, isNot(contains('_showAddHomeworkSheet')));
    expect(teacherScreen, isNot(contains('_showEditHomework')));
    expect(teacherScreen, isNot(contains('_showSubmissions')));

    expect(teacherForms, contains('TeacherHomeworkFormScreen'));
    expect(teacherForms, contains('TeacherHomeworkSubmissionsScreen'));
    expect(teacherForms, contains('createHomework('));
    expect(teacherForms, contains('updateHomework('));
    expect(teacherForms, contains('getHomeworkSubmissions('));
    expect(teacherForms, contains('reviewHomeworkSubmission('));
    expect(teacherForms, isNot(contains('showModalBottomSheet(')));
    expect(teacherForms, isNot(contains('showDialog(')));

    expect(parentScreen, contains('AppRoutes.parentHomeworkSubmit'));
    expect(parentScreen, contains('getHomeworkSubmissions('));
    expect(parentScreen, contains('getHomework('));
    expect(parentForm, contains('ParentHomeworkSubmissionScreen'));
    expect(parentForm, contains('submitHomework('));
    expect(parentForm, isNot(contains('showModalBottomSheet(')));
    expect(parentForm, isNot(contains('showDialog(')));

    expect(api, contains('Future<List<Map<String, dynamic>>> getHomework'));
    expect(api, contains('Future<Map<String, dynamic>> createHomework'));
    expect(api, contains('Future<Map<String, dynamic>> updateHomework'));
    expect(
      api,
      contains('Future<Map<String, dynamic>> getHomeworkSubmissions'),
    );
    expect(api, contains('Future<Map<String, dynamic>> submitHomework'));
    expect(
      api,
      contains('Future<Map<String, dynamic>> reviewHomeworkSubmission'),
    );

    expect(routes, contains('teacherHomeworkForm'));
    expect(routes, contains('TeacherHomeworkFormScreen'));
    expect(routes, contains('teacherHomeworkSubmissions'));
    expect(routes, contains('TeacherHomeworkSubmissionsScreen'));
    expect(routes, contains('parentHomeworkSubmit'));
    expect(routes, contains('ParentHomeworkSubmissionScreen'));
    expect(guard, contains('AppRoutes.teacherHomeworkForm: {\'teacher\'}'));
    expect(
      guard,
      contains('AppRoutes.teacherHomeworkSubmissions: {\'teacher\'}'),
    );
    expect(guard, contains('AppRoutes.parentHomeworkSubmit: {\'parent\'}'));
    expect(registry, contains('/teacher-homework-screen/form'));
    expect(registry, contains('/teacher-homework-screen/submissions'));
    expect(registry, contains('/parent-homework-screen/submit'));

    expect(models, contains('type HomeworkSubmission struct'));
    expect(handler, contains('func (h *HomeworkSubmissionHandler) Submit'));
    expect(handler, contains('func (h *HomeworkSubmissionHandler) Review'));
    expect(main, contains('NewHomeworkSubmissionHandler()'));
    expect(main, contains('homework.GET("/:id/submissions"'));
    expect(main, contains('homework.POST("/:id/submissions"'));
    expect(
      main,
      contains('homework.PUT("/:id/submissions/:submission_id/review"'),
    );
  });
}
