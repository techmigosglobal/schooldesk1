import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/core/services/demo_fixture_store.dart';

void main() {
  test('Day Care plans are child-only hourly monthly plans', () {
    final childMonthlyMigration = File(
      'supabase/migrations/20260729140412_daycare_child_monthly_plans.sql',
    ).readAsStringSync();
    final hourlyMigration = File(
      'supabase/migrations/20260818090712_daycare_hourly_per_child_plans.sql',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();
    final home = File(
      'lib/features/finance/presentation/screens/fee_home_screen/fee_home_screen.dart',
    ).readAsStringSync();

    expect(
      childMonthlyMigration,
      contains('alter column fee_structure_id drop not null'),
    );
    expect(childMonthlyMigration, contains('monthly_amount'));
    expect(childMonthlyMigration, contains('daycare_plan_id'));
    expect(
      childMonthlyMigration,
      contains('fee_invoices_daycare_plan_period_unique'),
    );
    expect(hourlyMigration, contains('hourly_rate numeric(12,2)'));
    expect(
      hourlyMigration,
      contains('contracted_hours_per_month numeric(10,2)'),
    );
    expect(hourlyMigration, contains("'formula'"));
    expect(
      handler,
      contains(
        'hourly_rate and contracted_hours_per_month must be greater than zero',
      ),
    );
    expect(
      handler,
      contains('.eq("is_active", true).lte("effective_from", today)'),
    );
    expect(handler, contains('daycare_plan_id'));
    expect(home, contains("'hourly_rate': rate"));
    expect(home, contains("'contracted_hours_per_month': hours"));
    expect(home, isNot(contains('Create a Daycare fee structure')));
    expect(home, contains('Contracted hours per month'));
  });

  test('Day Care eligibility is enforced before plan creation and billing', () {
    final handler = File(
      'supabase/functions/api/handlers/fees.ts',
    ).readAsStringSync();
    final expandedEligibilityMigration = File(
      'supabase/migrations/20260730011750_expand_daycare_class_eligibility.sql',
    ).readAsStringSync();
    final home = File(
      'lib/features/finance/presentation/screens/fee_home_screen/fee_home_screen.dart',
    ).readAsStringSync();

    expect(handler, contains('/daycare-eligible-students'));
    expect(handler, contains('filter(isDaycareStudent)'));
    expect(handler, contains('student_id_number, status, current_section'));
    expect(handler, contains('enrichDaycareStudents'));
    expect(
      handler,
      contains('Student must be enrolled in an active Day Care section'),
    );
    expect(handler, contains('startsWith(\n    "daycare",'));
    expect(
      expandedEligibilityMigration,
      contains("regexp_replace(lower(coalesce(grade.grade_name"),
    );
    expect(expandedEligibilityMigration, contains("like 'daycare%'"));
    expect(home, contains("'/fees/daycare-eligible-students'"));
    expect(home, contains('Needs attention'));
  });

  test('ledger is the sole principal invoice surface', () {
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final home = File(
      'lib/features/finance/presentation/screens/fee_home_screen/fee_home_screen.dart',
    ).readAsStringSync();
    final ledger = File(
      'lib/features/finance/presentation/screens/fee_ledger_screen/fee_ledger_screen.dart',
    ).readAsStringSync();

    expect(routes, isNot(contains('/fee-reports-screen')));
    expect(routes, isNot(contains('/principal/fee-reports')));
    expect(routes, isNot(contains('/principal/invoice-generate')));
    expect(home, isNot(contains('Reports & Exports')));
    expect(home, isNot(contains('Active Structure')));
    expect(ledger, contains('Invoice PDF'));
    expect(ledger, contains("tooltip: 'Receipt PDF'"));
    expect(ledger, contains('Record payment'));
    expect(ledger, contains('FeeDocumentKind.feeInvoice'));
    expect(ledger, contains('FeeDocumentKind.paymentReceipt'));
  });

  test('complete fee reports include a Day Care finance section', () {
    final uploads = File(
      'supabase/functions/api/handlers/uploads.ts',
    ).readAsStringSync();
    final feeModels = File(
      'lib/features/finance/presentation/screens/fee_shared/fee_models.dart',
    ).readAsStringSync();

    expect(uploads, contains('title: "Day Care Finance"'));
    expect(uploads, contains('"Hourly rate"'));
    expect(uploads, contains('"Hours"'));
    expect(uploads, contains('daycarePlansById'));
    expect(feeModels, contains('isDaycareFeeStructure'));
  });

  test('lesson plans complete automatically after the week ends', () {
    final handler = File(
      'supabase/functions/api/handlers/communications.ts',
    ).readAsStringSync();
    final teacher = File(
      'lib/features/academics/presentation/screens/lesson_planner_screen.dart',
    ).readAsStringSync();
    final principal = File(
      'lib/features/academics/presentation/screens/principal_lesson_planner_screen.dart',
    ).readAsStringSync();

    expect(handler, contains('autoCompleteEndedLessonPlanners'));
    expect(handler, contains('completed_at'));
    expect(teacher, isNot(contains("label: const Text('Complete')")));
    expect(teacher, contains("label: 'Current week'"));
    expect(principal, contains("label: Text('Current plans')"));
  });

  test('demo fixtures cover the calendar and local finance supplements', () {
    final store = DemoFixtureStore.pristine();
    for (final path in [
      '/academic-years/year-1',
      '/holidays',
      '/fees/reminders',
      '/fees/daycare-plans',
      '/fees/daycare-eligible-students',
      '/fees/payment-config',
    ]) {
      expect(
        store.respond(path: path, method: 'GET', role: 'parent')['success'],
        true,
      );
    }
    expect(
      store.respond(
        path: '/fees/daycare-plans',
        method: 'POST',
        role: 'principal',
        body: {
          'student_id': 'student-daycare-1',
          'hourly_rate': 70,
          'contracted_hours_per_month': 60,
          'due_day': 10,
        },
      )['success'],
      true,
    );
    expect(
      store.respond(
        path: '/fees/daycare-plans',
        method: 'GET',
        role: 'principal',
      )['data'],
      isNotEmpty,
    );
  });
}
