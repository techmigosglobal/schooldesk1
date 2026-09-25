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

    test('backend saves parent reminders and delivers them at 4 PM', () {
      final index = File('supabase/functions/api/index.ts').readAsStringSync();
      final handler = File(
        'supabase/functions/api/handlers/health_reminders.ts',
      ).readAsStringSync();

      expect(index, contains('handleHealthReminders'));
      expect(index, contains('path.startsWith("/health-reminders")'));
      expect(index, contains('path.startsWith("/jobs/health-reminders")'));
      expect(handler, contains('path !== "/health-reminders"'));
      expect(handler, contains('path === "/jobs/health-reminders/run"'));
      expect(handler, contains('HEALTH_REMINDER_JOB_SECRET'));
      expect(handler, contains('Asia/Kolkata'));
      expect(handler, contains('isAfterFourPmIndia'));
      expect(handler, contains('deliverHealthReminders'));
      expect(handler, contains('method === "GET"'));
      expect(handler, contains('method === "POST"'));
      expect(handler, contains('method === "PATCH"'));
      expect(handler, contains('method === "DELETE"'));
      expect(handler, contains('parentCanAccessStudent'));
      expect(handler, contains('resolveStudentRecipients'));
      expect(handler, contains('class_teacher_id'));
      expect(handler, contains('co_teacher_id'));
      expect(handler, contains('svc.from("health_reminders").insert'));
      expect(handler, contains('entity_type: "health_reminder"'));
      expect(handler, contains('route: "/notification-center-screen"'));
      expect(handler, contains('notification_logs").insert'));
      expect(handler, contains('notification_events").insert'));
      expect(handler, isNot(contains('notification_logs").upsert')));
      expect(handler, isNot(contains('notification_events").upsert')));
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
      expect(handler, contains('whole-school celebration'));
      expect(handler, contains('schoolRecipients'));
      expect(handler, contains('targetRole !== "parent"'));
      expect(handler, contains('existingLogKeys'));
      expect(handler, contains('existingDedupeKeys'));
      expect(handler, contains('dedupe_key: `birthday:'));
      expect(handler, contains('delivery_window'));
    });

    test('push queue claims events and schedules two daily windows', () {
      final processor = File(
        'supabase/functions/notification-processor/index.ts',
      ).readAsStringSync();
      final migration = File(
        'supabase/migrations/20260712191838_limit_birthday_health_push_delivery.sql',
      ).readAsStringSync();

      expect(processor, contains('async function claimEvent'));
      expect(processor, contains('.eq("processed", false)'));
      expect(processor, contains('reason: "already_claimed"'));
      expect(migration, contains('uniq_notification_events_dedupe_key'));
      expect(migration, contains("'daily-birthday-alerts-morning'"));
      expect(migration, contains("'daily-birthday-alerts-afternoon'"));
      expect(migration, contains("'30 3 * * *'"));
      expect(migration, contains("'30 9 * * *'"));
    });

    test('parent health screen uses day-specific reminders and history', () {
      final source = File(
        'lib/features/health/presentation/screens/parent_health_update_screen/parent_health_update_screen.dart',
      ).readAsStringSync();
      final repository = File(
        'lib/roles/parent/data/api_parent_health_repository.dart',
      ).readAsStringSync();

      expect(source, contains('_repository.loadReminders'));
      expect(repository, contains("'/health-reminders'"));
      expect(repository, contains("'/health-reminders/\$reminderId'"));
      expect(source, contains("'reminder_date'"));
      expect(source, contains('Reminder Date'));
      expect(source, contains('Reminder History'));
      expect(source, contains('Edit Health Reminder'));
      expect(source, contains('Delete health reminder?'));
      expect(source, contains('4:00 PM on the selected date'));
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
      expect(highlights, isNot(contains('api.triggerBirthdayAlerts()')));
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
