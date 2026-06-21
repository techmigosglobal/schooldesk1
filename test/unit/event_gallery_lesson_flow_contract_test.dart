import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/routes/app_routes.dart';
import 'package:schooldesk1/routes/route_access_guard.dart';

void main() {
  test('role guard exposes event, gallery, and planner routes safely', () {
    expect(
      RouteAccessGuard.redirectFor(
        routeName: AppRoutes.teacherEventPosts,
        isAuthenticated: true,
        currentRole: 'Teacher',
      ),
      isNull,
    );
    expect(
      RouteAccessGuard.redirectFor(
        routeName: AppRoutes.teacherLessonPlanner,
        isAuthenticated: true,
        currentRole: 'Teacher',
      ),
      isNull,
    );
    expect(
      RouteAccessGuard.redirectFor(
        routeName: AppRoutes.schoolGallery,
        isAuthenticated: true,
        currentRole: 'Parent',
      ),
      isNull,
    );
    expect(
      RouteAccessGuard.redirectFor(
        routeName: AppRoutes.principalEventApprovals,
        isAuthenticated: true,
        currentRole: 'Principal',
      ),
      isNull,
    );
    expect(
      RouteAccessGuard.redirectFor(
        routeName: AppRoutes.principalEventApprovals,
        isAuthenticated: true,
        currentRole: 'Admin',
      ),
      AppRoutes.landingPage,
    );
  });

  test('frontend screens use explicit event and lesson planner endpoints', () {
    final parentDashboard = File(
      'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
    ).readAsStringSync();
    final parentLessonPlanner = File(
      'lib/features/academics/presentation/screens/parent_lesson_planner_screen/parent_lesson_planner_screen.dart',
    ).readAsStringSync();
    final landing = File(
      'lib/features/shell/presentation/screens/landing_page_screen/landing_page_screen.dart',
    ).readAsStringSync();
    final approval = File(
      'lib/features/communication/presentation/screens/principal_event_approval_screen.dart',
    ).readAsStringSync();
    final gallery = File(
      'lib/features/shared/presentation/screens/school_gallery_screen.dart',
    ).readAsStringSync();

    expect(parentDashboard, contains('getHomeFeedEventPosts()'));
    expect(parentLessonPlanner, contains('getParentLessonPlanners()'));
    expect(
      parentDashboard,
      isNot(contains('/api/v1/event-posts?destination=PARENTS_HOME')),
    );
    expect(landing, isNot(contains('/landing/events')));
    expect(
      landing,
      isNot(contains('/api/v1/event-posts?destination=SCHOOL_LANDING')),
    );
    expect(approval, contains('getPendingEventPosts()'));
    expect(gallery, contains('getGalleryEventPosts()'));
    expect(gallery, contains('GridView.builder'));
  });

  test(
    'backend keeps event posts approved-only and landing response public',
    () {
      final handler = File(
        'school-backend/internal/handlers/event_post.go',
      ).readAsStringSync();
      final routes = File(
        'school-backend/internal/routes/routes.go',
      ).readAsStringSync();

      expect(handler, contains('normalizeEventPostDestinations'));
      expect(handler, contains('At least one valid destination is required'));
      expect(handler, contains('publicEventPost'));
      expect(handler, contains('ApprovalStatusApproved'));
      expect(handler, contains('%SCHOOL_GALLERY%'));
      expect(handler, contains('%PARENTS_HOME%'));
      expect(handler, contains('%SCHOOL_LANDING%'));
      expect(
        routes,
        contains(
          'eventPosts.GET("/pending", middleware.RBACMiddleware("Principal")',
        ),
      );
      expect(routes, contains('api.GET("/landing/events"'));
    },
  );

  test('parent lesson planners are scoped through linked students', () {
    final handler = File(
      'school-backend/internal/handlers/lesson_planner.go',
    ).readAsStringSync();

    expect(handler, contains('parent_student_links.parent_user_id'));
    expect(
      handler,
      contains('students.current_section_id = lesson_planners.section_id'),
    );
    expect(
      handler,
      contains('enrollments.section_id = lesson_planners.section_id'),
    );
    expect(handler, isNot(contains('Preload("Class")')));
    expect(handler, contains('Preload("Grade")'));
  });

  test('lesson planner attachment links are normalized before opening', () {
    final principal = File(
      'lib/features/academics/presentation/screens/principal_lesson_planner_screen.dart',
    ).readAsStringSync();
    final parent = File(
      'lib/features/academics/presentation/screens/parent_lesson_planner_screen/parent_lesson_planner_screen.dart',
    ).readAsStringSync();
    final teacher = File(
      'lib/features/academics/presentation/screens/lesson_planner_screen.dart',
    ).readAsStringSync();
    final resolver = File(
      'lib/core/utils/attachment_url_resolver.dart',
    ).readAsStringSync();

    expect(resolver, contains('resolveAttachmentUrl'));
    expect(resolver, contains('BackendApiClient.instance.baseUrl'));
    expect(resolver, contains('uri.hasScheme'));
    expect(principal, contains('resolveAttachmentUrl(attachment)'));
    expect(parent, contains('resolveAttachmentUrl(attachmentUrl)'));
    expect(teacher, contains('resolveAttachmentUrl('));
    expect(principal, contains('Attachment link is not available.'));
  });
}
