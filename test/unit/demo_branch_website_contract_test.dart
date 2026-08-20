import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('demo access is local-sandbox only and credentials are one-time', () {
    final handler = File(
      'supabase/functions/api/handlers/demo.ts',
    ).readAsStringSync();
    final storage = File(
      'lib/core/services/demo_sandbox_service.dart',
    ).readAsStringSync();
    expect(handler, contains('mode: "local_sandbox"'));
    expect(handler, contains('DEMO_CREDENTIAL_WRAP_KEY'));
    expect(handler, contains('password_revealed_at'));
    expect(handler, contains('.is("password_revealed_at", null)'));
    expect(
      handler,
      contains('if (consumeError) return fail(consumeError.message)'),
    );
    expect(
      handler,
      contains(
        'if (!consumed) return fail("no unrevealed temporary password is available", 410)',
      ),
    );
    expect(handler, contains('roles: ["principal", "teacher", "parent"]'));
    expect(handler, contains('Demo@'));
    expect(handler, contains('nextDemoUsername'));
    expect(storage, contains('flutter_secure_storage'));
    expect(storage, contains('schooldesk_demo_snapshot'));
    expect(storage, contains('saveLogin'));
    expect(storage, contains('clearSelectedRole'));

    final login = File(
      'lib/features/auth/presentation/screens/auth_login_screen/auth_login_screen.dart',
    ).readAsStringSync();
    final selector = File(
      'lib/features/auth/presentation/screens/demo_role_selector_screen.dart',
    ).readAsStringSync();
    final localApi = File(
      'lib/core/services/demo_local_api_service.dart',
    ).readAsStringSync();
    final main = File('lib/main.dart').readAsStringSync();
    expect(login, contains("RegExp(r'^demo\\d+\$'"));
    expect(login, isNot(contains('Explore local demo')));
    expect(selector, contains("'principal'"));
    expect(selector, contains("'teacher'"));
    expect(selector, contains("'parent'"));
    expect(selector, contains('beginLocalDemoSession'));
    expect(localApi, contains('never over the network'));
    expect(localApi, contains('local_mutations'));
    expect(localApi, contains('awaitRoleSelection'));
    expect(main, contains('_restoreLocalDemoSessionIfNeeded'));
    expect(main, contains('isAwaitingRoleSelection'));

    final generatedApi = File(
      'lib/core/network/schooldesk_api.dart',
    ).readAsStringSync();
    expect(generatedApi, contains('_SchoolDeskDemoInterceptor'));
    expect(generatedApi, contains('demo.responseFor(options)'));

    final logout = File(
      'lib/core/services/logout_service.dart',
    ).readAsStringSync();
    expect(logout, contains('DemoLocalApiService.instance.isActive'));
    expect(logout, contains('AppRoutes.demoRoleSelector'));
  });

  test('web proxy persists and forwards only validated branch context', () {
    final proxy = File(
      'schooldesk-web/app/api/backend/[...path]/route.ts',
    ).readAsStringSync();
    final branch = File(
      'schooldesk-web/app/api/branch/route.ts',
    ).readAsStringSync();
    expect(proxy, contains('x-schooldesk-branch-id'));
    expect(proxy, contains('cookieNames.branch'));
    expect(branch, contains('const uuid'));
    expect(branch, contains('valid branch is required'));
  });

  test('preschool essentials include safe public enquiry capture', () {
    final website = File(
      'supabase/functions/api/handlers/website.ts',
    ).readAsStringSync();
    final publicSite = File(
      'schooldesk-web/components/preschool-essentials.tsx',
    ).readAsStringSync();
    expect(website, contains('handleWebsiteEnquiry'));
    expect(website, contains('svc.from("admission_inquiries").insert'));
    expect(website, contains('const programs ='));
    expect(publicSite, contains('Explore programs'));
    expect(publicSite, contains('A safe campus, every day.'));
    expect(publicSite, contains('Submit enquiry'));
    expect(publicSite, contains('3000'));
    expect(publicSite, contains('prefers-reduced-motion'));
  });
}
