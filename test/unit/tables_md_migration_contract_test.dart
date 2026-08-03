import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

import 'backend_route_sources.dart';

void main() {
  test('Tables.md roots are bridged through the generated Retrofit client', () {
    final backendApi = readBackendApiSources();
    final generatedApi = File(
      'lib/core/network/generated/schooldesk_api_client.dart',
    ).readAsStringSync();
    final envConfig = File(
      'lib/core/config/env_config.dart',
    ).readAsStringSync();

    expect(
      backendApi,
      contains(
        "import 'package:schooldesk1/core/network/schooldesk_api.dart';",
      ),
    );
    expect(backendApi, contains('SchoolDeskApi.instance.client.homework('));
    expect(backendApi, contains("part 'api_modules/notifications_api.dart';"));
    expect(
      backendApi,
      contains('Future<NotificationPage> getNotificationsPage'),
    );
    expect(backendApi, contains('SchoolDeskApi.instance.client.events('));
    expect(backendApi, isNot(contains('SchoolDeskApi.instance.client.exams(')));
    expect(backendApi, contains('listTablesMdRoot('));
    expect(backendApi, contains('createTablesMdRoot('));
    expect(backendApi, contains('updateTablesMdRoot('));
    expect(backendApi, contains('deleteTablesMdRoot('));
    expect(generatedApi, contains("part 'schooldesk_api_client.g.dart';"));
    expect(
      generatedApi,
      contains("Future<PaginatedEnvelope> listTablesMdRoot"),
    );
    expect(envConfig, contains('v1BaseUrlFrom(_configuredApiBaseUrl)'));
  });

  test('migrated event and lesson planner UI avoids direct Dio calls', () {
    final migratedUiFiles = [
      File(
        'lib/features/academics/presentation/screens/lesson_planner_screen.dart',
      ),
      File(
        'lib/features/academics/presentation/screens/parent_lesson_planner_screen/parent_lesson_planner_screen.dart',
      ),
      File(
        'lib/features/academics/presentation/screens/principal_lesson_planner_screen.dart',
      ),
      File(
        'lib/features/communication/presentation/screens/principal_event_approval_screen.dart',
      ),
      File(
        'lib/features/communication/presentation/screens/event_post_screen.dart',
      ),
      File(
        'lib/features/dashboard/presentation/screens/parent_dashboard_screen/parent_dashboard_screen.dart',
      ),
      File(
        'lib/features/shared/presentation/screens/school_gallery_screen.dart',
      ),
    ];

    for (final file in migratedUiFiles) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains("package:dio/dio.dart")),
        reason:
            '${file.path} must use BackendApiClient facade methods, not Dio.',
      );
      expect(
        source,
        isNot(contains('.dio.')),
        reason:
            '${file.path} must use BackendApiClient facade methods, not Dio.',
      );
    }
  });

  test(
    'lesson planner remains active while transport and library stay retired',
    () {
      final appRoutes = File('lib/routes/app_routes.dart').readAsStringSync();
      final teacherNavigation = File(
        'lib/core/widgets/teacher_navigation.dart',
      ).readAsStringSync();
      final main = readBackendRouteSources();

      expect(appRoutes, contains('/teacher-lesson-planner-screen'));
      expect(appRoutes, contains('/principal-lesson-planner-screen'));
      expect(appRoutes, isNot(contains('/teacher-resources-screen')));
      expect(teacherNavigation, contains('AppRoutes.teacherLessonPlanner'));
      expect(teacherNavigation, isNot(contains('/teacher-resources-screen')));
      expect(main, contains('path === "/lesson-planners/principal"'));
      expect(main, contains('path === "/lesson-planners/teacher"'));
      expect(main, isNot(contains('api.Group("/transport")')));
      expect(main, isNot(contains('api.Group("/library")')));
    },
  );

  test('backend data service walks paginated directories', () {
    final backendDataService = File(
      'lib/core/services/backend_data_service.dart',
    ).readAsStringSync();
    final backendApi = readBackendApiSources();

    expect(backendDataService, contains('Future<List<T>> _fetchAll<T>('));
    expect(backendDataService, contains('result.hasMore'));
    expect(backendDataService, isNot(contains('pageSize: 100')));
    expect(
      backendDataService,
      isNot(contains('getStudents(page: 1, pageSize: 100)')),
    );
    expect(
      backendApi,
      contains('Future<PaginatedList<Map<String, dynamic>>> getInvoicesPage'),
    );
    expect(backendDataService, contains('while (true)'));
    expect(backendDataService, contains('result.hasMore'));
  });
}
