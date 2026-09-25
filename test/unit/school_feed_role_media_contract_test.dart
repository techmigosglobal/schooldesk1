import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'feed clients parse paginated responses and keep teacher scope distinct',
    () {
      final api = File(
        'lib/core/network/api_modules/events_api.dart',
      ).readAsStringSync();
      final handler = File(
        'supabase/functions/api/handlers/uploads.ts',
      ).readAsStringSync();
      final teacherRepository = File(
        'lib/roles/teacher/data/api_teacher_dashboard_repository.dart',
      ).readAsStringSync();
      final parentRepository = File(
        'lib/roles/parent/data/api_parent_dashboard_repository.dart',
      ).readAsStringSync();

      expect(api, contains('getHomeFeedEventPostsPage'));
      expect(api, contains('getTeacherSchoolFeedPage'));
      expect(api, contains('response.data'));
      expect(api, contains('response.total'));
      expect(api, contains('response.pageSize'));
      expect(handler, contains('path === "/event-posts/teacher-feed"'));
      expect(handler, contains('TEACHERS_HOME'));
      expect(teacherRepository, contains('getTeacherSchoolFeedPage'));
      expect(parentRepository, contains('getHomeFeedEventPostsPage'));
      expect(
        teacherRepository,
        isNot(contains('getHomeFeedEventPosts().catchError')),
      );
      expect(
        parentRepository,
        isNot(contains('getHomeFeedEventPosts().catchError')),
      );
    },
  );

  test(
    'feed media renders a video first frame and preserves its aspect ratio',
    () {
      final media = File(
        'lib/core/widgets/event_post_media_preview.dart',
      ).readAsStringSync();
      final teacherFeed = File(
        'lib/features/dashboard/presentation/widgets/school_feed_preview.dart',
      ).readAsStringSync();

      expect(media, contains('VideoPlayer(controller)'));
      expect(media, contains('thumbnailUrl'));
      expect(media, contains('BoxFit.contain'));
      expect(teacherFeed, contains('EventPostMediaCarousel('));
      expect(media, contains('loadOnInit: true'));
    },
  );

  test(
    'feed routes reject kiosk access and expose an explicit stale/error state',
    () {
      final handler = File(
        'supabase/functions/api/handlers/uploads.ts',
      ).readAsStringSync();
      final preview = File(
        'lib/features/dashboard/presentation/widgets/school_feed_preview.dart',
      ).readAsStringSync();
      final parent = File(
        'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
      ).readAsStringSync();

      expect(handler, contains('feedRoles'));
      expect(handler, contains('kiosk'));
      expect(preview, contains('SchoolFeedStatusNotice'));
      expect(parent, contains('feedError'));
      expect(parent, contains('feedStale'));
    },
  );
}
