import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BackendApiClient remains a thin facade over API modules', () {
    final facade = File('lib/core/network/backend_api_client.dart');
    final facadeSource = facade.readAsStringSync();
    final modules = Directory('lib/core/network/api_modules')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    final models = File(
      'lib/features/shared/data/models/backend_models.dart',
    ).readAsStringSync();

    expect(facadeSource.split('\n').length, lessThanOrEqualTo(200));
    expect(
      facadeSource,
      contains(
        "export 'package:schooldesk1/features/shared/data/models/backend_models.dart';",
      ),
    );
    expect(facadeSource, contains("part 'api_modules/auth_api.dart';"));
    expect(facadeSource, contains("part 'api_modules/students_api.dart';"));
    expect(facadeSource, contains("part 'api_modules/fees_api.dart';"));
    expect(facadeSource, isNot(contains('class LoginRequest')));
    expect(models, contains('class LoginRequest'));
    expect(models, contains('class StudentModel'));
    expect(models, contains('class PaymentRequest'));

    expect(modules.length, greaterThanOrEqualTo(10));
    for (final module in modules) {
      expect(
        module.readAsLinesSync().length,
        lessThanOrEqualTo(500),
        reason: '${module.path} should stay small enough to review safely.',
      );
    }
  });

  test('shared repositories are API-backed adapters over BackendApiClient', () {
    final repositoryDir = Directory('lib/features/shared/data/repositories');
    final files = repositoryDir
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .toSet();

    expect(
      files,
      containsAll({
        'api_attendance_repository.dart',
        'api_fee_repository.dart',
        'api_leave_repository.dart',
        'api_notice_repository.dart',
        'api_student_repository.dart',
        'api_teacher_repository.dart',
      }),
    );

    for (final file in repositoryDir.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.startsWith('api_') || name == 'api_repository_utils.dart') {
        continue;
      }

      final source = file.readAsStringSync();
      expect(
        source,
        contains('implements '),
        reason: '$name must implement the existing domain repository contract.',
      );
      expect(
        source,
        contains('BackendApiClient'),
        reason: '$name must reuse the stable backend API facade.',
      );
      expect(
        source,
        contains('guardApi('),
        reason: '$name must translate backend exceptions into Result failures.',
      );
    }
  });

  test('ServiceLocator registers repositories and exposes AuthController', () {
    final source = File('lib/core/di/service_locator.dart').readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    final riverpodProviders = File(
      'lib/app/providers/schooldesk_providers.dart',
    ).readAsStringSync();

    expect(source, contains('ApiStudentRepository(apiClient)'));
    expect(source, contains('ApiTeacherRepository(apiClient)'));
    expect(source, contains('ApiFeeRepository(apiClient)'));
    expect(source, contains('ApiAttendanceRepository(apiClient)'));
    expect(source, contains('ApiLeaveRepository(apiClient)'));
    expect(source, contains('ApiNoticeRepository(apiClient)'));
    expect(source, contains('ChangeNotifierProvider<AuthController>.value'));
    expect(source, contains('ServiceLocator.authController'));

    expect(main, contains('await ServiceLocator.initialize();'));
    expect(main, contains('ProviderScope('));
    expect(main, contains('const AppProviders(child: MyApp())'));
    expect(riverpodProviders, contains('backendApiClientProvider'));
    expect(riverpodProviders, contains('studentRepositoryProvider'));
    expect(riverpodProviders, contains('feeRepositoryProvider'));
  });
}
