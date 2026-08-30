import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

void main() {
  test('production has no public school provisioning route or client seam', () {
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final guard = File('lib/routes/route_access_guard.dart').readAsStringSync();
    final registry = File(
      'lib/routes/schooldesk_screen_registry.dart',
    ).readAsStringSync();
    final authBarrel = File('lib/features/auth/auth.dart').readAsStringSync();
    final models = File(
      'lib/features/shared/data/models/backend_models.dart',
    ).readAsStringSync();
    final handler = File(
      'supabase/functions/api/handlers/schools.ts',
    ).readAsStringSync();
    final client = readBackendApiSources();

    expect(routes, isNot(contains('onboarding')));
    expect(guard, isNot(contains('onboarding')));
    expect(registry, isNot(contains('onboarding')));
    expect(authBarrel, isNot(contains('onboarding_screen')));
    expect(
      File(
        'lib/features/auth/presentation/screens/onboarding_screen/onboarding_screen.dart',
      ).existsSync(),
      isFalse,
    );

    expect(models, isNot(contains('SchoolSetupRequest')));
    expect(client, isNot(contains('/schools/setup')));
    expect(client, isNot(contains('setupSchool(')));

    expect(handler, contains('if (path === "/schools/setup")'));
    expect(handler, contains('return fail("not found", 404)'));
    expect(handler, isNot(contains('auth.admin.createUser')));
    expect(handler, isNot(contains('signInWithPassword')));
  });
}
