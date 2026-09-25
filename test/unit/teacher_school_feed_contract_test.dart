import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('teacher dashboard reads the staff school feed', () {
    final screen = File(
      'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/roles/teacher/data/api_teacher_dashboard_repository.dart',
    ).readAsStringSync();
    final desktop = File(
      'lib/features/dashboard/presentation/widgets/teacher_dashboard_desktop_shell.dart',
    ).readAsStringSync();

    expect(repository, contains('_api.getTeacherSchoolFeedPage'));
    expect(screen, contains('List<Map<String, dynamic>> _eventPosts'));
    expect(screen, contains('showParentVisibility: true'));
    expect(screen, contains("audienceLabel: 'Staff & school updates'"));
    expect(screen, contains('SchoolFeedPreview('));
    expect(desktop, contains('final List<Map<String, dynamic>> eventPosts'));
    expect(desktop, contains('SchoolFeedPreview('));
  });

  test(
    'teacher feed remains backed by authorized staff and school destinations',
    () {
      final handler = File(
        'supabase/functions/api/handlers/uploads.ts',
      ).readAsStringSync();

      expect(handler, contains('path === "/event-posts/teacher-feed"'));
      expect(handler, contains('.in("status", ["approved", "published"])'));
      expect(handler, contains('TEACHERS_HOME'));
    },
  );

  test('feed cards use bounded media space instead of viewport height', () {
    final parent = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();

    expect(parent, contains('final cardWidth = size.width * 0.92'));
    expect(parent, contains('cardWidth * 0.9'));
    expect(parent, contains('final mediaHeight = constraints.maxHeight'));
    expect(parent, contains('Positioned.fill('));
    expect(parent, isNot(contains('height: 240,')));
  });

  test('SchoolPost uploads are private until approval promotion', () {
    final screen = File(
      'lib/features/communication/presentation/screens/event_post_screen.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/modules/communication/data/api_event_post_repository.dart',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/uploads.ts',
    ).readAsStringSync();

    expect(screen, contains('_repository.uploadMedia('));
    expect(repository, contains("private: true"));
    expect(repository, contains("folder: 'event-posts'"));
    expect(handler, contains('promoteEventPostMedia'));
    expect(handler, contains('copyR2File'));
    expect(handler, contains('R2 media promotion verification failed'));
  });
}
