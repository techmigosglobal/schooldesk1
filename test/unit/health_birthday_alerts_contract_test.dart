import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('health reminder and birthday alert contracts', () {
    test('Supabase schema stores parent health reminders separately', () {
      final migration = File(
        'supabase/migrations/0020_health_reminders_birthday_alerts.sql',
      ).readAsStringSync();

      expect(
        migration,
        contains('create table if not exists public.health_reminders'),
      );
      expect(migration, contains('created_by_parent_user_id uuid not null'));
      expect(migration, contains('reminder_date date not null'));
      expect(migration, contains('condition text'));
      expect(migration, contains('medication text'));
      expect(migration, contains('idx_health_reminders_student_date'));
      expect(migration, contains('uniq_notification_logs_entity_recipient'));
      expect(migration, contains('add column if not exists route text'));
      expect(migration, contains('add column if not exists priority text'));
    });

    test('backend exposes parent health reminder history and fan-out', () {
      final index = File('supabase/functions/api/index.ts').readAsStringSync();
      final handler = File(
        'supabase/functions/api/handlers/health_reminders.ts',
      ).readAsStringSync();

      expect(index, contains('handleHealthReminders'));
      expect(index, contains('path.startsWith("/health-reminders")'));
      expect(handler, contains('path !== "/health-reminders"'));
      expect(handler, contains('method === "GET"'));
      expect(handler, contains('method === "POST"'));
      expect(handler, contains('parentCanAccessStudent'));
      expect(handler, contains('resolveStudentRecipients'));
      expect(handler, contains('class_teacher_id'));
      expect(handler, contains('co_teacher_id'));
      expect(handler, contains('role_name", "principal"'));
      expect(handler, contains('svc.from("health_reminders").insert'));
      expect(handler, contains('entity_type: "health_reminder"'));
      expect(handler, contains('route: "/notification-center-screen"'));
    });

    test('backend birthday job creates idempotent role notifications', () {
      final index = File('supabase/functions/api/index.ts').readAsStringSync();
      final handler = File(
        'supabase/functions/api/handlers/birthday_alerts.ts',
      ).readAsStringSync();

      expect(index, contains('handleBirthdayAlerts'));
      expect(index, contains('path.startsWith("/jobs/birthday-alerts")'));
      expect(handler, contains('path === "/jobs/birthday-alerts/run"'));
      expect(handler, contains('method === "POST"'));
      expect(handler, contains('BIRTHDAY_ALERT_JOB_SECRET'));
      expect(handler, contains('x-school-id'));
      expect(handler, contains('date_of_birth'));
      expect(handler, contains('birthday_wish'));
      expect(handler, contains('parent_student_links'));
      expect(handler, contains('class_teacher_id'));
      expect(handler, contains('co_teacher_id'));
      expect(handler, contains('role_name", "principal"'));
      expect(handler, contains('upsert('));
      expect(handler, contains('onConflict: "user_id,entity_type,entity_id"'));
    });

    test('parent health screen uses day-specific reminders and history', () {
      final source = File(
        'lib/features/health/presentation/screens/parent_health_update_screen/parent_health_update_screen.dart',
      ).readAsStringSync();

      expect(source, contains('dio.get('));
      expect(source, contains('dio.post('));
      expect(source, contains("'/health-reminders'"));
      expect(source, contains("'reminder_date'"));
      expect(source, contains('Reminder Date'));
      expect(source, contains('Reminder History'));
      expect(source, isNot(contains('triggerHealthReminderAlert')));
      expect(
        source,
        isNot(
          contains("dio.post(\n                            '/medical-records'"),
        ),
      );
    });

    test('dashboard highlights recognize backend health and birthday rows', () {
      final highlights = File(
        'lib/features/dashboard/presentation/widgets/todays_highlights_card.dart',
      ).readAsStringSync();
      final notifications = File(
        'lib/core/services/notification_service.dart',
      ).readAsStringSync();

      expect(highlights, contains("n.category == NotificationCategory.health"));
      expect(
        highlights,
        contains("n.referenceType.contains('health_reminder')"),
      );
      expect(highlights, contains('api.triggerBirthdayAlerts()'));
      expect(highlights, contains('_BirthdayAlertSection'));
      expect(highlights, contains('_BirthdayAlertTile'));
      expect(
        notifications,
        isNot(contains('Future<void> _loadBirthdayAlerts()')),
      );
      expect(notifications, isNot(contains('await _loadBirthdayAlerts();')));
    });
  });
}
