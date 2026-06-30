import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('role navigation uses centralized sequential indices', () {
    final navIndices = read('lib/core/navigation/role_nav_indices.dart');

    for (final declaration in const [
      'class ParentNav',
      'static const dashboard = 0;',
      'static const attendance = 1;',
      'static const gallery = 15;',
      'class TeacherNav',
      'static const documents = 15;',
      'class PrincipalNav',
      'static const monitor = 24;',
    ]) {
      expect(navIndices, contains(declaration));
    }

    for (final sourcePath in const [
      'lib/core/widgets/parent_navigation.dart',
      'lib/core/widgets/teacher_navigation.dart',
      'lib/core/widgets/app_navigation.dart',
    ]) {
      final source = read(sourcePath);
      expect(source, contains('role_nav_indices.dart'));
      expect(
        source,
        isNot(contains(RegExp(r'index:\s+(?:1[6-9]|[2-9]\d)'))),
        reason: '$sourcePath must not use sparse legacy drawer indices',
      );
    }
  });

  test('retired role features are not active routes or navigation targets', () {
    final activeSources = [
      read('lib/routes/app_routes.dart'),
      read('lib/routes/route_access_guard.dart'),
      read('lib/routes/schooldesk_screen_registry.dart'),
      read('lib/core/widgets/parent_navigation.dart'),
      read('lib/core/widgets/teacher_navigation.dart'),
      read(
        'lib/features/dashboard/presentation/screens/teacher_dashboard_screen/teacher_dashboard_screen.dart',
      ),
    ].join('\n');

    for (final retired in const [
      'teacherHomework',
      'teacherHomeworkForm',
      'teacherHomeworkSubmissions',
      'teacherDiscipline',
      'parentAcademicInfo',
      'parentHealthUpdate',
      '/teacher-homework-screen',
      '/teacher-discipline-screen',
      '/parent-academic-info-screen',
      '/parent-health-update-screen',
      'Student Discipline',
      'Health Updates',
      'Academic Info',
    ]) {
      expect(activeSources, isNot(contains(retired)));
    }
  });

  test('new audit remediation routes are registered and guarded', () {
    final routeSources = [
      read('lib/routes/app_routes.dart'),
      read('lib/routes/route_access_guard.dart'),
      read('lib/routes/schooldesk_screen_registry.dart'),
      read('lib/core/widgets/app_navigation.dart'),
      read('lib/core/widgets/teacher_navigation.dart'),
    ].join('\n');

    for (final expected in const [
      'principalDocuments',
      'principalAuditLogs',
      'teacherDocuments',
      '/principal-documents-screen',
      '/principal-audit-logs-screen',
      '/teacher-documents-screen',
      'PrincipalNav.documents',
      'PrincipalNav.auditLogs',
      'TeacherNav.documents',
    ]) {
      expect(routeSources, contains(expected));
    }
  });

  test('principal module no longer uses AdminDrawer in active screens', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    final findings = <String>[];
    for (final file in dartFiles) {
      if (file.path.endsWith('admin_navigation.dart')) continue;
      final source = file.readAsStringSync();
      if (source.contains('AdminDrawer(') ||
          source.contains('admin_navigation.dart')) {
        findings.add(file.path);
      }
    }

    expect(findings, isEmpty, reason: findings.join('\n'));
  });

  test('backend retired endpoints are no longer registered', () {
    final backendRoutes = read('school-backend/internal/routes/routes.go');

    for (final retired in const [
      'api.Group("/payroll")',
      'frontendResource("/admissions/applications"',
      'frontendResource("/discipline-incidents"',
      'frontendResource("/helpdesk-tickets"',
      'frontendResource("/documents/access-requests"',
      'frontendResource("/certificates/requests"',
      'frontendResource("/certificates/transfer-requests"',
      'frontendResource("/syllabus"',
      'frontendResource("/complaints", "Principal", "Teacher")',
      'frontendResource("/curriculum", "Principal", "Teacher", "Parent")',
    ]) {
      expect(backendRoutes, isNot(contains(retired)));
    }

    expect(
      backendRoutes,
      contains('frontendResource("/documents/templates", "Principal")'),
    );
    expect(
      backendRoutes,
      contains('frontendResource("/complaints", "Principal")'),
    );
    expect(
      backendRoutes,
      contains('frontendResource("/curriculum", "Principal")'),
    );
  });

  test('chat screens do not perform five-second full reload polling', () {
    for (final path in const [
      'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
      'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
      'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
    ]) {
      final source = read(path);
      expect(source, isNot(contains('Duration(seconds: 5)')));
      expect(source, contains('Duration(seconds: 30)'));
      expect(source, contains('background: true'));
    }
  });
}
