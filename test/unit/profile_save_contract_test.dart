import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:schooldesk1/features/shared/data/models/backend_models.dart';

void main() {
  test('profile model accepts nullable role profile fields for every role', () {
    final profile = UserResponse.fromJson({
      'id': null,
      'username': null,
      'name': null,
      'email': null,
      'phone': null,
      'avatar': null,
      'school_id': null,
      'role_id': null,
      'role_name': null,
      'linked_type': null,
      'linked_id': null,
      'is_active': null,
      'is_verified': null,
    });

    expect(profile.id, '');
    expect(profile.email, '');
    expect(profile.phone, '');
    expect(profile.schoolId, '');
    expect(profile.roleName, '');
    expect(profile.isActive, isTrue);
    expect(profile.isVerified, isFalse);
  });

  test('profile API normalizes PATCH profile envelopes from Supabase', () {
    final authApi = File(
      'lib/core/network/api_modules/auth_api.dart',
    ).readAsStringSync();
    final authHandler = File(
      'supabase/functions/api/handlers/auth.ts',
    ).readAsStringSync();

    expect(authApi, contains('_profilePayloadFromEnvelope('));
    expect(authApi, contains("payload['profile']"));
    expect(authHandler, contains('function normalizeProfileResponse'));
    expect(authHandler, contains('return ok(normalizeProfileResponse'));
  });
}
