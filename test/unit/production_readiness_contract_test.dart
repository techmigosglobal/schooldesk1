import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'teacher attendance is driven by staff timetable slots and enrollments',
    () {
      final source = File(
        'lib/presentation/teacher_attendance_screen/teacher_attendance_screen.dart',
      ).readAsStringSync();
      final api = File(
        'lib/services/backend_api_client.dart',
      ).readAsStringSync();

      expect(source, contains('RoleAccessService.initialize()'));
      expect(source, contains('RoleAccessService.teacherStaffId'));
      expect(source, contains('getTimetableSlots('));
      expect(source, contains('staffId: staffId'));
      expect(source, contains('dayOfWeek: DateTime.now().weekday'));
      expect(source, contains('getStudentEnrollments(s.id)'));
      expect(source, contains("'enrollment_missing': enrollmentId.isEmpty"));
      expect(source, contains("throw Exception('Enrollment record missing"));
      expect(source, contains('getAttendanceSessions('));
      expect(source, contains('timetableSlotId: slotId'));
      expect(source, contains('periodNumber: periodNumber'));
      expect(source, contains('markAttendance(sessionId, attendances)'));
      expect(source, isNot(contains('Request Correction')));
      expect(source, isNot(contains("String _selectedClass =")));
      expect(source, isNot(contains('getProfile()')));
      expect(api, contains('final String timetableSlotId;'));
      expect(api, contains("'timetable_slot_id': timetableSlotId"));
    },
  );

  test(
    'teacher communication is chat-first and scoped to real conversations',
    () {
      final source = File(
        'lib/presentation/teacher_communication_screen/teacher_communication_screen.dart',
      ).readAsStringSync();

      expect(source, contains("Tab(text: 'Chats')"));
      expect(source, contains("Tab(text: 'School Notices')"));
      expect(source, contains("getRawList('/message-conversations')"));
      expect(source, contains("getRawList('/messages')"));
      expect(source, contains('RoleAccessService.teacherStaffId'));
      expect(source, contains("createRaw('/messages'"));
      expect(source, contains("updateRaw('/messages/\$id'"));
      expect(source, contains("'conversation_id': conversationId"));
      expect(source, contains("'sender_role': 'Teacher'"));
      expect(source, contains("IconButton.filled("));
      expect(source, contains("tooltip: 'Send message'"));
      expect(source, isNot(contains('Send Notice')));
      expect(source, isNot(contains('Compose Notice')));
    },
  );

  test(
    'admin communication filters backend notices without local-only templates',
    () {
      final source = File(
        'lib/presentation/admin_communication_screen/admin_communication_screen.dart',
      ).readAsStringSync();

      expect(source, contains('getAnnouncements()'));
      expect(source, contains('_filteredNotices'));
      expect(source, contains("labelText: 'Search notices'"));
      expect(source, contains("labelText: 'Audience'"));
      expect(source, contains("labelText: 'Status'"));
      expect(source, contains("'Parents'"));
      expect(source, contains("'Teachers'"));
      expect(source, contains("'Principal'"));
      expect(source, contains("createAnnouncement("));
      expect(source, contains("deleteRaw('/notices/\$id'"));
      expect(source, contains('constraints.maxWidth >= 680'));
      expect(source, isNot(contains("String _selectedAudience = 'All'")));
      expect(source, isNot(contains("'Class 5A'")));
    },
  );

  test(
    'push notifications are queued for all roles and sent by isolated worker',
    () {
      final main = File('school-backend/main.go').readAsStringSync();
      final notifications = File(
        'school-backend/internal/handlers/communication_notifications.go',
      ).readAsStringSync();
      final worker = File(
        'school-backend/internal/worker/notifications.go',
      ).readAsStringSync();
      final compose = File(
        'docker-compose.hostinger-traefik.yml',
      ).readAsStringSync();
      final env = File(
        'deploy/hostinger-traefik.env.example',
      ).readAsStringSync();

      expect(main, contains('cfg.EnableFCMPush && cfg.AppMode == "worker"'));
      expect(main, contains('notifications.POST("/device-tokens"'));
      expect(main, contains('notifications.DELETE("/device-tokens"'));
      expect(main, contains('notificationsCompat.POST("/device-tokens"'));
      expect(notifications, contains('createNotificationLogsForRolesTx('));
      expect(notifications, contains('LOWER(users.role) IN ?'));
      expect(notifications, isNot(contains('users.role_slug')));
      expect(notifications, contains('notifyMessageCreated'));
      expect(notifications, contains('"/teacher-communication-screen"'));
      expect(notifications, contains('"/approval-center-screen"'));
      expect(
        worker,
        contains(
          'strings.EqualFold(strings.TrimSpace(notification.PushStatus), "sent")',
        ),
      );
      expect(compose, contains('notification-worker:'));
      expect(compose, contains('profiles:'));
      expect(compose, contains('push'));
      expect(
        compose,
        contains('/run/secrets/firebase-service-account.json:ro'),
      );
      expect(env, contains('ENABLE_FCM_PUSH=false'));
      expect(env, contains('FIREBASE_SERVICE_ACCOUNT_FILE='));
    },
  );

  test(
    'profile avatars, student approvals, and exports have production storage guards',
    () {
      final auth = File(
        'school-backend/internal/handlers/auth.go',
      ).readAsStringSync();
      final student = File(
        'school-backend/internal/handlers/student.go',
      ).readAsStringSync();
      final studentApproval = File(
        'school-backend/internal/handlers/student_approval.go',
      ).readAsStringSync();
      final reportExport = File(
        'school-backend/internal/handlers/report_export.go',
      ).readAsStringSync();
      final dockerfile = File('school-backend/Dockerfile').readAsStringSync();
      final compose = File(
        'docker-compose.hostinger-traefik.yml',
      ).readAsStringSync();

      expect(auth, contains('os.MkdirAll("uploads/avatars"'));
      expect(auth, contains('profile avatar upload save failed'));
      expect(auth, contains('profile avatar database update failed'));
      expect(dockerfile, contains('/app/uploads/avatars'));
      expect(dockerfile, contains('/app/uploads/exports'));
      expect(compose, contains('uploads_data:/app/uploads'));
      expect(student, contains('STU-%d'));
      expect(student, contains('admissionNumber = studentCode'));
      expect(student, contains('admission_number'));
      expect(student, contains('already exists'));
      expect(studentApproval, contains('type approvalApplyError struct'));
      expect(studentApproval, contains('statusForApprovalApplyError(err)'));
      expect(reportExport, contains('os.MkdirAll(dir, 0o755)'));
      expect(
        reportExport,
        contains('report export storage preparation failed'),
      );
    },
  );
}
