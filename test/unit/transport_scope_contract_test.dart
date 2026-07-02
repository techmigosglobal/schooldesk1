import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transport and stop directory stay retired from current API surface', () {
    final appRoutes = File('lib/routes/app_routes.dart').readAsStringSync();
    final backendRoutes = File(
      'school-backend/internal/routes/routes.go',
    ).readAsStringSync();
    final supabaseIndex = File('supabase/functions/api/index.ts')
        .readAsStringSync();
    final prd = File('docs/PRD.md').readAsStringSync();

    expect(appRoutes, isNot(contains('/transport-')));
    expect(appRoutes, isNot(contains('/stop-')));
    expect(backendRoutes, isNot(contains('api.Group("/transport")')));
    expect(backendRoutes, isNot(contains('api.Group("/stops")')));
    expect(supabaseIndex, isNot(contains('path.startsWith("/transport")')));
    expect(supabaseIndex, isNot(contains('path.startsWith("/stops")')));
    expect(prd, contains('No transport or library route exposure'));
  });
}
