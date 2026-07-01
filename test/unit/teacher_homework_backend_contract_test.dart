import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

import 'backend_route_sources.dart';

void main() {
  test(
    'homework lifecycle keeps parent submissions and teacher review routes wired',
    () {
      final parentScreen = File(
        'lib/features/homework/presentation/screens/parent_homework_screen/parent_homework_screen.dart',
      ).readAsStringSync();
      final parentForm = File(
        'lib/features/homework/presentation/screens/parent_homework_screen/parent_homework_submission_screen.dart',
      ).readAsStringSync();
      final api = readBackendApiSources();
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final registry = File(
        'lib/routes/schooldesk_screen_registry.dart',
      ).readAsStringSync();
      final homeworkBarrel = File(
        'lib/features/homework/homework.dart',
      ).readAsStringSync();
      final main = readBackendRouteSources();
      final models = File(
        'school-backend/internal/models/hr_comms.go',
      ).readAsStringSync();
      final handler = File(
        'school-backend/internal/handlers/homework_submission.go',
      ).readAsStringSync();

      expect(routes, contains('teacherHomework'));
      expect(routes, contains('teacherHomeworkForm'));
      expect(routes, contains('teacherHomeworkSubmissions'));
      expect(guard, contains('AppRoutes.teacherHomework: {\'teacher\'}'));
      expect(registry, contains('/teacher-homework-screen'));
      expect(homeworkBarrel, contains('teacher_homework_screen'));

      expect(parentScreen, contains('AppRoutes.parentHomeworkSubmit'));
      expect(parentScreen, contains('getHomeworkSubmissions('));
      expect(parentScreen, contains('getHomework('));
      expect(parentScreen, contains('_homeworkId(row)'));
      expect(parentScreen, contains("'homework_id': h['homework_id']"));
      expect(parentScreen, contains("'submission_attachment_urls'"));
      expect(parentForm, contains('ParentHomeworkSubmissionScreen'));
      expect(parentForm, contains('_homeworkId'));
      expect(parentForm, contains('_pickAttachments'));
      expect(parentForm, contains('submitHomework('));
      expect(parentForm, contains('attachmentUrls: _attachmentUrls'));
      expect(parentForm, isNot(contains('showModalBottomSheet(')));
      expect(parentForm, isNot(contains('showDialog(')));

      expect(api, contains('Future<List<Map<String, dynamic>>> getHomework'));
      expect(api, contains('Future<Map<String, dynamic>> createHomework'));
      expect(api, contains('Future<Map<String, dynamic>> updateHomework'));
      expect(api, contains('String attachmentUrl ='));
      expect(api, contains('attachmentUrl: attachmentUrl'));
      expect(
        api,
        contains('Future<Map<String, dynamic>> getHomeworkSubmissions'),
      );
      expect(api, contains('Future<Map<String, dynamic>> submitHomework'));
      expect(api, contains('List<String> attachmentUrls = const []'));
      expect(api, contains("'attachment_urls': attachmentUrls"));
      expect(
        api,
        contains('Future<Map<String, dynamic>> reviewHomeworkSubmission'),
      );

      expect(routes, contains('parentHomeworkSubmit'));
      expect(routes, contains('ParentHomeworkSubmissionScreen'));
      expect(guard, contains('AppRoutes.parentHomeworkSubmit: {\'parent\'}'));
      expect(registry, contains('/parent-homework-screen/submit'));

      expect(models, contains('type HomeworkSubmission struct'));
      expect(handler, contains('func (h *HomeworkSubmissionHandler) Submit'));
      expect(handler, contains('func (h *HomeworkSubmissionHandler) Review'));
      expect(
        handler,
        contains('notifyHomeworkSubmittedForReview(homework, row)'),
      );
      expect(main, contains('NewHomeworkSubmissionHandler()'));
      expect(main, contains('homework.GET("/:id/submissions"'));
      expect(main, contains('homework.POST("/:id/submissions"'));
      expect(
        main,
        contains('homework.PUT("/:id/submissions/:submission_id/review"'),
      );
    },
  );

  test('homework edit uses canonical record id and refreshed display fields', () {
    final teacherScreen = File(
      'lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_screen.dart',
    ).readAsStringSync();
    final teacherForms = File(
      'lib/features/homework/presentation/screens/teacher_homework_screen/teacher_homework_form_screens.dart',
    ).readAsStringSync();
    final homeworkApi = File(
      'lib/core/network/api_modules/homework_api.dart',
    ).readAsStringSync();
    final backendCrud = File(
      'school-backend/internal/handlers/tables_md_crud.go',
    ).readAsStringSync();

    expect(teacherScreen, contains('_homeworkId(row)'));
    expect(teacherScreen, contains('await _loadHomework(forceRefresh: true)'));
    expect(teacherForms, contains('_homeworkRecordId'));
    expect(teacherForms, contains("homework?['homework_id']"));
    expect(teacherForms, contains("homework?['id']"));
    expect(teacherForms, contains('updateHomework('));
    expect(teacherForms, contains('_homeworkId'));
    expect(teacherForms, contains("_review(submission, 'reviewed')"));
    expect(teacherForms, contains("_review(submission, 'needs_revision')"));
    expect(teacherForms, contains('_submissionAttachmentUrls'));
    expect(teacherForms, contains('openEventPostMediaPreview'));
    expect(homeworkApi, contains('submissionDate: dueDate'));
    expect(homeworkApi, contains('attachmentUrl: attachmentUrl'));
    expect(backendCrud, contains('homework_id'));
    expect(backendCrud, contains('recordIDQuery'));
    expect(backendCrud, contains('OR "+'));
  });

  test('class diary removes duplicate green save affordance', () {
    final teacherDiary = File(
      'lib/features/academics/presentation/screens/teacher_diary_screen/teacher_diary_screen.dart',
    ).readAsStringSync();

    expect(teacherDiary, contains("label: 'Past Entries'"));
    expect(teacherDiary, contains('Colors.indigo'));
    expect(teacherDiary, isNot(contains("label: 'Archived'")));
    expect(
      teacherDiary,
      isNot(
        contains(
          "label: 'Save Diary',\n                icon: Icons.save_rounded",
        ),
      ),
    );
    expect(teacherDiary, contains('FloatingActionButton.extended'));
    expect(teacherDiary, contains('_buildQuickEntry'));
  });
}
