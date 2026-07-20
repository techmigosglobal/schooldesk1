import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guided Help content covers every supported portal role', () {
    final migration = File(
      'supabase/migrations/20260720031143_role_guided_help_workflows.sql',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/help.ts',
    ).readAsStringSync();
    final screen = File(
      'lib/features/shared/presentation/screens/help_screen/help_screen.dart',
    ).readAsStringSync();

    for (final role in ['principal', 'coordinator', 'teacher', 'parent']) {
      expect(migration, contains("('$role'"));
      expect(handler, contains('"$role"'));
      expect(screen, contains("'$role'"));
    }
    expect(migration, contains('How do I mark daily student attendance'));
    expect(migration, contains('How do I submit a payment request'));
    expect(migration, contains('How do I access school-wide audit logs'));
    expect(migration, contains('What can I do as a Coordinator?'));
    expect(migration, isNot(contains("('coordinator', 'Finance")));
  });

  test('help guides preserve structured steps and safe route actions', () {
    final handler = File(
      'supabase/functions/api/handlers/help.ts',
    ).readAsStringSync();
    final screen = File(
      'lib/features/shared/presentation/screens/help_screen/help_screen.dart',
    ).readAsStringSync();

    expect(handler, contains('function workflowSteps'));
    expect(handler, contains('workflow_steps: workflowSteps'));
    expect(handler, contains('action_route: optionalText'));
    expect(screen, contains('List<String> _workflowSteps'));
    expect(screen, contains('Step-by-step workflow'));
    expect(screen, contains('Future<void> _openWorkflow'));
    expect(screen, contains('RouteAccessGuard.isRoleAllowedFor'));
    expect(screen, contains(r'Open ${routeMetadata?.title'));
  });
}
