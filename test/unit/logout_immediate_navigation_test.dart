import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('signOut navigates to landing page before any network call', () {
    final source = File(
      'lib/core/services/logout_service.dart',
    ).readAsStringSync();

    // The refresh token must be saved BEFORE clearing auth state.
    final refreshTokenIndex = source.indexOf('getRefreshToken()');
    final clearAuthTokenIndex = source.indexOf('clearAuthToken()');
    final tokenClearIndex = source.indexOf('TokenStorageService.clear()');
    expect(
      refreshTokenIndex,
      greaterThan(0),
      reason: 'Refresh token must be saved before clearing.',
    );
    expect(
      refreshTokenIndex,
      lessThan(clearAuthTokenIndex),
      reason: 'Refresh token saved before auth token cleared.',
    );
    expect(
      refreshTokenIndex,
      lessThan(tokenClearIndex),
      reason: 'Refresh token saved before storage cleared.',
    );

    // Navigation must happen AFTER clearing state but BEFORE background cleanup.
    final navigateIndex = source.indexOf('pushNamedAndRemoveUntil');
    final backgroundCleanupIndex = source.indexOf('_backgroundCleanup');
    expect(
      navigateIndex,
      greaterThan(clearAuthTokenIndex),
      reason: 'Navigation happens after clearing client state.',
    );
    expect(
      navigateIndex,
      lessThan(backgroundCleanupIndex),
      reason: 'Navigation happens before background cleanup starts.',
    );
    expect(
      source,
      contains("AppRoutes.landingPage"),
      reason: 'Navigates to the landing page.',
    );

    // The backend logout in background uses the saved refresh token directly.
    expect(
      source,
      contains('BackendApiClient.instance.dio.post'),
      reason: 'Background cleanup calls logout API directly with saved token.',
    );
    expect(
      source,
      contains("'/auth/logout'"),
      reason: 'Background cleanup hits the /auth/logout endpoint.',
    );
  });

  test('signOut guard flag prevents multiple concurrent sign-outs', () {
    final source = File(
      'lib/core/services/logout_service.dart',
    ).readAsStringSync();

    // Guard flag must exist and be checked at the start of signOut().
    expect(
      source,
      contains('static bool _signingOut = false'),
      reason: 'Guard flag exists as a static field.',
    );
    expect(
      source,
      contains('if (_signingOut) return'),
      reason: 'Guard flag is checked to prevent re-entry.',
    );

    // confirmAndSignOut must also check the guard.
    final confirmIndex = source.indexOf('confirmAndSignOut');
    final guardCheckIndex = source.indexOf('if (_signingOut) return');
    expect(
      confirmIndex,
      lessThan(guardCheckIndex),
      reason: 'Guard checked at the start of confirmAndSignOut.',
    );

    // Guard must be set to true inside signOut.
    expect(
      source,
      contains('_signingOut = true'),
      reason: 'Guard flag is set to true during sign-out.',
    );

    // Guard must be reset after a delay to allow future sign-outs.
    expect(
      source,
      contains('Future.delayed'),
      reason: 'Guard flag is reset after a delay.',
    );
  });

  test('background cleanup runs fire-and-forget without blocking', () {
    final source = File(
      'lib/core/services/logout_service.dart',
    ).readAsStringSync();

    // Background cleanup must use Future() to run async work outside the
    // current microtask queue, ensuring navigation is never blocked.
    expect(
      source,
      contains('static void _backgroundCleanup'),
      reason: 'Cleanup is a void method (not awaited).',
    );
    expect(
      source,
      contains('Future(() async {'),
      reason: 'Cleanup uses Future() to defer async work.',
    );

    // All network calls in background must be wrapped in try/catch.
    expect(
      source,
      contains('revokeCurrentToken()'),
      reason: 'Push token revocation is in background.',
    );
    expect(
      source,
      contains('cleanupTopicsForRole'),
      reason: 'Topic cleanup is in background.',
    );

    // Background cleanup is fire-and-forget — called without await.
    final cleanupCallIndex = source.indexOf('_backgroundCleanup(');
    final cleanupDefIndex = source.indexOf('static void _backgroundCleanup');
    expect(
      cleanupCallIndex,
      greaterThan(0),
      reason: '_backgroundCleanup is called somewhere.',
    );
    expect(
      source.substring(cleanupCallIndex - 4, cleanupCallIndex),
      isNot(contains('await')),
      reason: '_backgroundCleanup is called without await.',
    );
  });
}
