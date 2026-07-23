import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('organization branches are additive and grant principals access', () {
    final migration = File(
      'supabase/migrations/20260722161041_organization_branch_context.sql',
    ).readAsStringSync();
    expect(
      migration,
      contains('create table if not exists public.organizations'),
    );
    expect(
      migration,
      contains('create table if not exists public.branch_memberships'),
    );
    expect(migration, contains('sync_branch_principals'));
    expect(migration, contains('sync_principal_branch_memberships'));
    expect(migration, contains('must_change_password'));
  });

  test('API validates an active branch before adapting legacy handlers', () {
    final index = File('supabase/functions/api/index.ts').readAsStringSync();
    final branches = File(
      'supabase/functions/api/handlers/branches.ts',
    ).readAsStringSync();
    expect(index, contains('x-schooldesk-branch-id'));
    expect(
      index,
      contains('home.organization_id === requested.organization_id'),
    );
    expect(index, contains('branch_memberships'));
    expect(index, contains('handleBranches'));
    expect(branches, contains('currentRole !== "super_admin"'));
    expect(branches, contains('path === "/branches" && method === "POST"'));
    expect(branches, contains('path === "/branches/overview"'));
    expect(branches, contains('["PATCH", "DELETE"].includes(method)'));
    expect(branches, contains('if (method === "PATCH")'));
    expect(branches, contains(r'DELETE ${text(branch.name)}'));
    expect(
      branches,
      contains('the only branch in an organization cannot be deleted'),
    );
    expect(
      branches,
      contains('.in("role_name", ["principal", "super_admin"])'),
    );
  });

  test(
    'branch management has rename and double-confirmed destructive delete',
    () {
      final switcher = File(
        'lib/core/widgets/branch_switcher.dart',
      ).readAsStringSync();
      final api = File(
        'lib/core/network/api_modules/branches_api.dart',
      ).readAsStringSync();

      expect(switcher, contains('Rename branch'));
      expect(switcher, contains('Delete branch and all its data?'));
      expect(switcher, contains('Final branch deletion confirmation'));
      expect(switcher, contains(r'DELETE $branchName'));
      expect(api, contains('Future<Map<String, dynamic>> updateBranch'));
      expect(api, contains('Future<Map<String, dynamic>> deleteBranch'));
      expect(switcher, contains('_disposeDialogControllers'));
      expect(switcher, contains('Duration(milliseconds: 350)'));
    },
  );

  test('super admins can provision an immediately active principal account', () {
    final form = File(
      'lib/features/people/presentation/screens/admin_user_access_screen/account_access_form_screen.dart',
    ).readAsStringSync();
    expect(form, contains('isSuperAdminOwner'));
    expect(form, contains("['Principal', 'Coordinator', 'Teacher', 'Parent']"));
    expect(form, contains('canActivateAccounts'));
    expect(
      form,
      contains('requestPrincipalApproval: !widget.args.canActivateAccounts'),
    );
  });

  test('audit activity is presented as readable school actions', () {
    final activity = File(
      'supabase/functions/api/handlers/activity.ts',
    ).readAsStringSync();
    final screen = File(
      'lib/features/monitoring/presentation/screens/principal_audit_logs_screen.dart',
    ).readAsStringSync();
    expect(activity, contains('activityTarget'));
    expect(activity, contains('activityDescription'));
    expect(activity, contains('actorName: actor'));
    expect(activity, contains('url.searchParams.get("actor")'));
    expect(
      activity,
      contains('query = query.neq("actor_role", "super_admin")'),
    );
    expect(screen, contains('_AuditLogPresentation'));
    expect(screen, contains('Staff member or username'));
    expect(screen, contains('performed\\s+(GET|POST|PATCH|PUT|DELETE)'));
  });

  test('credential resets are one-time and never retrieve old passwords', () {
    final users = File(
      'supabase/functions/api/handlers/users.ts',
    ).readAsStringSync();
    final screen = File(
      'lib/features/people/presentation/screens/admin_user_access_screen/admin_user_access_screen.dart',
    ).readAsStringSync();
    expect(users, contains('temporary_password'));
    expect(users, contains('must_change_password: true'));
    expect(users, contains('credentials.reset'));
    expect(screen, contains('I have shared it securely'));
    final auth = File(
      'supabase/functions/api/handlers/auth.ts',
    ).readAsStringSync();
    expect(auth, contains('must_change_password: false'));
  });

  test('settings relies on the shared theme tokens in every theme mode', () {
    final settings = File(
      'lib/features/profile/presentation/screens/settings_screen/settings_screen.dart',
    ).readAsStringSync();
    expect(settings, contains('Theme.of(context).schoolDesk'));
    expect(settings, isNot(contains('Color(0xFF151C26)')));
  });

  test('profile email changes synchronize Auth and the public profile', () {
    final auth = File(
      'supabase/functions/api/handlers/auth.ts',
    ).readAsStringSync();
    expect(auth, contains('"email"'));
    expect(auth, contains('auth.admin.updateUserById(user.id'));
    expect(auth, contains('email_confirm: true'));
  });
}
