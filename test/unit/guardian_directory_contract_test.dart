import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

import 'backend_route_sources.dart';

void main() {
  test(
    'guardian dashboard card opens dedicated directory instead of user access',
    () {
      final dashboard = File(
        'lib/features/dashboard/presentation/screens/principal_dashboard_screen/principal_dashboard_screen.dart',
      ).readAsStringSync();
      final routes = File('lib/routes/app_routes.dart').readAsStringSync();
      final guard = File(
        'lib/routes/route_access_guard.dart',
      ).readAsStringSync();
      final registry = File(
        'lib/routes/schooldesk_screen_registry.dart',
      ).readAsStringSync();

      expect(dashboard, contains("label: 'Guardians'"));
      expect(dashboard, contains('route: AppRoutes.guardianDirectory'));
      expect(
        dashboard,
        isNot(
          contains(
            "label: 'Guardians',\n                    route: AppRoutes.principalUserManagement",
          ),
        ),
      );
      expect(
        routes,
        contains("guardianDirectory = '/guardian-directory-screen'"),
      );
      expect(routes, contains('GuardianDirectoryScreen(ownerRole:'));
      expect(guard, contains('AppRoutes.guardianDirectory: {\'principal\'}'));
      expect(registry, contains("route: '/guardian-directory-screen'"));
    },
  );

  test(
    'guardian directory uses parent accounts, child links, and guardian records',
    () {
      final source = File(
        'lib/features/people/presentation/screens/guardian_directory_screen/guardian_directory_screen.dart',
      ).readAsStringSync();

      expect(source, contains('All Parents & Guardians Directory'));
      expect(source, contains('class _GuardianProfileFormPage'));
      expect(source, contains("getUsers(\n        role: 'Parent'"));
      expect(source, contains('getParentStudents('));
      expect(source, contains('assignParentStudents('));
      expect(source, contains('studentIds: input.linkedStudents'));
      expect(source, contains('Upload Photo'));
      expect(source, contains('Crop Guardian Photo'));
      expect(source, contains('uploadUserAvatar('));
      expect(source, contains('photoUrl: _mediaUrl(parent.avatar)'));
      expect(source, contains('student.studentCode.toLowerCase().trim()'));
      expect(source, contains("createRaw('/guardians'"));
      expect(source, contains("updateRaw(\n          '/guardians/"));
      expect(source, contains("deleteRaw('/guardians/"));
      expect(source, contains('deleteUser(guardian.id, permanent: true)'));
      expect(source, contains('Add Guardian Profile'));
      expect(source, contains('Edit Guardian Profile'));
      expect(source, contains('class _ResponsiveFieldRow'));
      expect(source, contains('constraints.maxWidth < 330'));
    },
  );

  test(
    'guardian parent-student assignment resolves by id and student code',
    () {
      final client = readBackendApiSources();
      final userBackend = File(
        'school-backend/internal/handlers/user.go',
      ).readAsStringSync();
      final main = readBackendRouteSources();
      final backend = File(
        'school-backend/internal/handlers/parent_link.go',
      ).readAsStringSync();

      expect(client, contains('Future<String> uploadUserAvatar('));
      expect(client, contains("'/users/\$userId/avatar'"));
      expect(client, contains('final String avatar;'));
      expect(userBackend, contains('func (h *UserHandler) UploadUserAvatar'));
      expect(main, contains('users.POST("/:id/avatar"'));
      expect(client, contains('List<String> studentIds = const []'));
      expect(client, contains("'student_ids': cleanedStudentIds"));
      expect(
        backend,
        contains('StudentIDs       []string `json:"student_ids"`'),
      );
      expect(backend, contains('LOWER(admission_number) IN ?'));
      expect(backend, contains('LOWER(student_code) IN ?'));
      expect(
        backend,
        contains('firstNonEmpty(s.AdmissionNumber, s.StudentCode)'),
      );
    },
  );
}
