import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'backend_api_sources.dart';

import 'backend_route_sources.dart';

void main() {
  test('onboarding uses real school setup endpoint and no demo credentials', () {
    final routes = File('lib/routes/app_routes.dart').readAsStringSync();
    final screen = File(
      'lib/features/auth/presentation/screens/onboarding_screen/onboarding_screen.dart',
    ).readAsStringSync();
    final client = readBackendApiSources();
    final backend = readBackendRouteSources();

    expect(
      routes,
      contains('onboarding: (context) => const OnboardingScreen()'),
    );
    expect(screen, contains('BackendApiClient.instance.setupSchool'));
    expect(screen, contains('SchoolSetupRequest('));
    expect(screen, contains('Navigator.pushNamedAndRemoveUntil'));
    expect(client, contains("Future<LoginResponse> setupSchool"));
    expect(client, contains("'/schools/setup'"));
    expect(backend, contains('schools.POST("/setup"'));

    for (final source in [routes, screen]) {
      expect(source, isNot(contains('admin123')));
      expect(source, isNot(contains('principal@schooldesk.local')));
    }
  });
}
