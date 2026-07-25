import 'package:schooldesk1/core/services/demo_fixture_store.dart';
import 'dart:io';
import 'package:test/test.dart';

void main() {
  test('offline fixture store covers the core role records with media', () {
    final store = DemoFixtureStore.pristine();
    const role = 'parent';
    for (final path in [
      '/dashboard/parent',
      '/me/students',
      '/attendance/summary',
      '/fees/invoices',
      '/homework',
      '/lesson-planners/parent',
      '/health-reminders',
      '/chat/contacts',
      '/chat/conversations',
      '/event-posts/home-feed',
      '/documents',
      '/parent-teacher-meetings',
    ]) {
      expect(
        store.respond(path: path, method: 'GET', role: role)['success'],
        true,
        reason: '$path must be locally available',
      );
    }
    final posts =
        store.respond(
              path: '/event-posts/home-feed',
              method: 'GET',
              role: role,
            )['data']
            as List;
    expect(posts, hasLength(5));
    expect(
      posts.every((post) => (post['media_urls'] as List).isNotEmpty),
      isTrue,
    );
  });

  test('local writes update the encrypted-snapshot fixture state only', () {
    final store = DemoFixtureStore.pristine();
    final created = store.respond(
      path: '/homework',
      method: 'POST',
      role: 'teacher',
      body: {'title': 'Shape hunt'},
    );
    expect(created['success'], true);
    final restored = DemoFixtureStore.fromSnapshot(store.toSnapshot());
    final homework =
        restored.respond(
              path: '/homework',
              method: 'GET',
              role: 'teacher',
            )['data']
            as List;
    expect(homework.any((row) => row['title'] == 'Shape hunt'), isTrue);
  });

  test('principal and teacher workflows resolve without a remote fallback', () {
    final store = DemoFixtureStore.pristine();
    for (final role in ['principal', 'teacher']) {
      for (final path in [
        '/dashboard/$role',
        '/students',
        '/staff',
        '/timetable/slots',
        '/attendance/staff/me/today',
        '/approvals',
        '/issues',
        '/notifications/preferences',
        '/event-posts/teacher',
      ]) {
        expect(
          store.respond(path: path, method: 'GET', role: role)['success'],
          true,
          reason: '$role must receive local data for $path',
        );
      }
    }
  });

  test('post-login demo guards prevent direct realtime, push, and telemetry', () {
    for (final path in [
      'lib/features/communication/presentation/screens/teacher_communication_screen/teacher_communication_screen.dart',
      'lib/features/communication/presentation/screens/parent_teacher_chat_screen/parent_teacher_chat_screen.dart',
      'lib/features/communication/presentation/screens/principal_chat_communications_screen/principal_chat_communications_screen.dart',
      'lib/core/services/push_notification_service.dart',
      'lib/core/services/error_reporting_service.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('DemoLocalApiService.instance.isActive'));
    }
  });
}
