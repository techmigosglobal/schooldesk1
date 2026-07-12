import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests that verify the backend leave handler and Flutter API layer
/// cover the full teacher leave lifecycle:
///   apply → principal approve/reject → teacher recall → notifications
void main() {
  group('Backend leave handler contracts', () {
    late String source;

    setUpAll(() {
      source = File(
        'supabase/functions/api/handlers/leave.ts',
      ).readAsStringSync();
    });

    test('POST /leave/applications inserts with status=pending', () {
      expect(source, contains('status: "pending"'));
      expect(
        source,
        contains(
          'const { data, error } = await svc.from("leave_applications").insert(payload)',
        ),
      );
    });

    test('staff_id is required for leave submission', () {
      expect(
        source,
        contains('if (!staffId) return fail("staff_id required", 400)'),
      );
    });

    test('recall endpoint updates status to recalled', () {
      expect(source, contains('status: "recalled"'));
      expect(source, contains('/leave\\/applications\\/([^/]+)\\/recall'));
    });

    test('approve endpoint supports both POST and PUT', () {
      // POST /approve
      expect(
        source,
        contains('/leave\\/applications\\/([^/]+)\\/(approve|reject)'),
      );
      // PUT /approve (alias)
      expect(source, contains('/leave\\/applications\\/([^/]+)\\/approve'));
    });

    test('approve handler creates notification_events for teacher', () {
      expect(source, contains('notification_events'));
      expect(source, contains('leave_approved'));
      expect(source, contains('leave_rejected'));
    });

    test('recall handler creates notification_events for principal', () {
      expect(source, contains('leave_recalled'));
      expect(source, contains('resolvePrincipalUserId'));
      expect(source, contains('target_role: "principal"'));
      // Verify notification_events insert exists within the recall block
      final recallIdx = source.indexOf('recallMatch && method === "POST"');
      final recallEnd = source.indexOf('return ok(data);', recallIdx);
      final recallBlock = source.substring(recallIdx, recallEnd);
      expect(recallBlock, contains('notification_events'));
      expect(recallBlock, contains('notification_logs'));
    });

    test('recall notification includes teacher name and date range', () {
      expect(source, contains('staffName'));
      expect(source, contains('fromDate'));
      expect(source, contains('toDate'));
      expect(source, contains('dateRange'));
    });

    test(
      'resolvePrincipalUserId queries users table with linked_type=principal',
      () {
        expect(source, contains('linked_type\", \"principal\"'));
      },
    );

    test('resolvePrincipalUserId has fallback to role_name ilike', () {
      expect(source, contains('ilike'));
      expect(source, contains('role_name'));
    });

    test('approve handler creates notification_logs for in-app center', () {
      expect(source, contains('notification_logs'));
      expect(source, contains('is_read: false'));
    });

    test('recall handler creates notification_logs for in-app center', () {
      // Verify recall block also inserts notification_logs
      final recallSection = source.substring(
        source.indexOf('recallMatch && method === "POST"'),
      );
      expect(recallSection, contains('notification_logs'));
      expect(recallSection, contains('target_role: "principal"'));
    });

    test('approve handler triggers push processing', () {
      expect(source, contains('triggerPushProcessing'));
    });

    test('recall handler triggers push processing', () {
      final recallSection = source.substring(
        source.indexOf('recallMatch && method === "POST"'),
      );
      expect(recallSection, contains('triggerPushProcessing'));
    });

    test('leave notifications are wrapped in try/catch for resilience', () {
      // Approve notification block
      expect(source, contains('Failed to create leave notification'));
      // Recall notification block
      expect(source, contains('Failed to create recall notification'));
    });
  });

  group('Flutter LeaveApplicationModel contracts', () {
    late String modelSource;

    setUpAll(() {
      modelSource = File(
        'lib/features/shared/data/models/backend_models.dart',
      ).readAsStringSync();
    });

    test('LeaveApplicationModel has staffName field', () {
      expect(modelSource, contains('final String staffName'));
    });

    test('LeaveApplicationModel has fromDate and toDate fields', () {
      expect(modelSource, contains('final String fromDate'));
      expect(modelSource, contains('final String toDate'));
    });

    test('LeaveApplicationModel has status field', () {
      expect(modelSource, contains('final String status'));
    });

    test('LeaveApplicationModel has reason field', () {
      expect(modelSource, contains('this.reason'));
    });

    test('fromJson maps from_date or start_date to fromDate', () {
      expect(
        modelSource,
        contains("json['from_date'] ?? json['start_date'] ?? ''"),
      );
    });

    test('fromJson maps to_date or end_date to toDate', () {
      expect(
        modelSource,
        contains("json['to_date'] ?? json['end_date'] ?? ''"),
      );
    });

    test('fromJson resolves staff name from joined staff record', () {
      expect(modelSource, contains("staff['first_name']"));
      expect(modelSource, contains("staff['last_name']"));
    });

    test('LeaveApplicationRequest sends start_date and end_date', () {
      expect(modelSource, contains("'start_date': fromDate"));
      expect(modelSource, contains("'end_date': toDate"));
    });
  });

  group('Flutter leave API module contracts', () {
    late String apiSource;

    setUpAll(() {
      apiSource = File(
        'lib/core/network/api_modules/leave_api.dart',
      ).readAsStringSync();
    });

    test('submitLeaveApplication sends POST to /leave/applications', () {
      expect(apiSource, contains("'/leave/applications'"));
      expect(apiSource, contains('_dio.post'));
    });

    test(
      'recallLeaveApplication sends POST to /leave/applications/:id/recall',
      () {
        expect(apiSource, contains("'/leave/applications/\$id/recall'"));
      },
    );

    test(
      'decideLeaveApplication sends PUT to /leave/applications/:id/approve',
      () {
        expect(apiSource, contains("'/leave/applications/\$id/approve'"));
        expect(apiSource, contains('_dio.put'));
      },
    );

    test('getLeaveApplications fetches GET /leave/applications', () {
      expect(apiSource, contains("'/leave/applications'"));
    });

    test('getLeaveTypes fetches GET /leave/types', () {
      expect(apiSource, contains("'/leave/types'"));
    });

    test('getLeaveBalances fetches GET /leave/balances', () {
      expect(apiSource, contains("'/leave/balances'"));
    });

    test('submitLeaveApplication has half_day fallback retry', () {
      expect(apiSource, contains("payload.remove('half_day')"));
    });
  });

  group('Leave entity contracts', () {
    late String entitySource;

    setUpAll(() {
      entitySource = File(
        'lib/features/shared/domain/entities/leave_request.dart',
      ).readAsStringSync();
    });

    test('LeaveRequest has status field defaulting to Pending', () {
      expect(entitySource, contains("this.status = 'Pending'"));
    });

    test('LeaveRequest has durationDays computed property', () {
      expect(entitySource, contains('int get durationDays'));
    });

    test('LeaveRequest has copyWith method', () {
      expect(entitySource, contains('LeaveRequest copyWith('));
    });

    test('LeaveRequest equality is based on id', () {
      expect(entitySource, contains('other.id == id'));
    });
  });

  group('AdminTeachersScreen leave data contracts', () {
    late String screenSource;

    setUpAll(() {
      screenSource = File(
        'lib/features/people/presentation/screens/admin_teachers_screen/admin_teachers_screen.dart',
      ).readAsStringSync();
    });

    test(
      'leave records use staffName instead of staffId for teacher display',
      () {
        expect(screenSource, contains("l.staffName"));
      },
    );

    test('leave records populate from/to/reason keys', () {
      expect(screenSource, contains("'from': l.fromDate"));
      expect(screenSource, contains("'to': l.toDate"));
      expect(screenSource, contains("'reason': l.reason"));
    });

    test('status comparison uses lowercase pending', () {
      expect(screenSource, contains("== 'pending'"));
    });

    test('_titleCase helper exists for status display', () {
      expect(screenSource, contains('static String _titleCase'));
    });

    test('teacher card includes dept from departmentName', () {
      expect(screenSource, contains("'dept': s.departmentName"));
    });
  });
}
