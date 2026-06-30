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
      isNull,
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
    final mediaPreview = File(
      'lib/core/widgets/event_post_media_preview.dart',
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
    expect(parentDashboard, contains('EventPostMediaItem.parseList'));
    expect(parentDashboard, isNot(contains('mediaUrls.first')));
    expect(parentDashboard, contains('PageView.builder'));
    expect(gallery, contains('EventPostMediaItem.parseList'));
    expect(parentDashboard, contains('EventPostMediaPreview'));
    expect(gallery, contains('EventPostMediaPreview'));
    expect(mediaPreview, contains('VideoPlayerController.networkUrl'));
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
    expect(resolver, contains('_apiUploadUri(base, uri.path)'));
    expect(resolver, contains("_apiUploadUri(base, raw)"));
    expect(principal, contains('resolveAttachmentUrl(attachment)'));
    expect(parent, contains('resolveAttachmentUrl(attachmentUrl)'));
    expect(teacher, contains('resolveAttachmentUrl('));
    expect(principal, contains('Attachment link is not available.'));
  });

  test('lesson planner upload files open through the api route', () {
    final resolver = File(
      'lib/core/utils/attachment_url_resolver.dart',
    ).readAsStringSync();
    final routes = File(
      'school-backend/internal/routes/routes.go',
    ).readAsStringSync();
    final uploadHandler = File(
      'school-backend/internal/handlers/upload.go',
    ).readAsStringSync();
    final database = File(
      'school-backend/internal/database/database.go',
    ).readAsStringSync();
    final uploadModel = File(
      'school-backend/internal/models/uploaded_file.go',
    ).readAsStringSync();

    expect(resolver, contains("uri.path.startsWith('/uploads/')"));
    expect(resolver, contains("raw.startsWith('/uploads/')"));
    expect(resolver, contains("raw.startsWith('uploads/')"));
    expect(
      resolver,
      contains("path: '\$normalizedBase\$normalizedUploadPath'"),
    );
    expect(
      routes,
      contains('api.GET("/uploads/*filepath", uploadHandler.DownloadFile)'),
    );
    expect(uploadHandler, contains('func (h *UploadHandler) DownloadFile'));
    expect(uploadHandler, contains('downloadFromDatabase'));
    expect(uploadHandler, contains('strings.HasPrefix'));
    expect(uploadHandler, contains('models.UploadedFile'));
    expect(database, contains('&models.UploadedFile{}'));
    expect(uploadModel, contains('type UploadedFile struct'));
    expect(uploadModel, contains('Data         []byte'));
  });
}
