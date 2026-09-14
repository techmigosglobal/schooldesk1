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
      final teacher = File(
        'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
      ).readAsStringSync();
      final parent = File(
        'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
      ).readAsStringSync();

      expect(api, contains('getHomeFeedEventPostsPage'));
      expect(api, contains('getTeacherSchoolFeedPage'));
      expect(api, contains("payload['data'] ?? payload['items']"));
      expect(handler, contains('path === "/event-posts/teacher-feed"'));
      expect(handler, contains('TEACHERS_HOME'));
      expect(teacher, contains('getTeacherSchoolFeedPage'));
      expect(parent, contains('getHomeFeedEventPostsPage'));
      expect(teacher, isNot(contains('getHomeFeedEventPosts().catchError')));
      expect(parent, isNot(contains('getHomeFeedEventPosts().catchError')));
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
