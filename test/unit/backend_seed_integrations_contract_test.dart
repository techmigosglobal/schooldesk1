import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backend seed command provisions kiosk and documents QR push env', () {
    final seed = File('school-backend/cmd/seed/main.go').readAsStringSync();
    final database = File(
      'school-backend/internal/database/database.go',
    ).readAsStringSync();
    final hostingerEnv = File(
      'deploy/hostinger-traefik.env.example',
    ).readAsStringSync();
    final compose = File(
      'docker-compose.hostinger-traefik.yml',
    ).readAsStringSync();

    expect(seed, contains('seedKioskAttendanceUser('));
    expect(seed, contains('Kiosk ready: username=%s password=%s'));
    expect(seed, contains('SCHOOLDESK_KIOSK_PASSWORD'));
    expect(seed, contains('STAFF_QR_SECRET'));

    expect(database, contains('ensureDefaultKioskUser'));
    expect(database, contains('SCHOOLDESK_KIOSK_PASSWORD'));
    expect(database, contains('Kiosk@12345'));
    expect(database, contains('NotificationLog{}'));
    expect(database, contains('NotificationDeviceToken{}'));

    expect(hostingerEnv, contains('SCHOOLDESK_KIOSK_PASSWORD='));
    expect(hostingerEnv, contains('STAFF_QR_SECRET='));
    expect(hostingerEnv, contains('ENABLE_FCM_PUSH=false'));
    expect(hostingerEnv, contains('FIREBASE_PROJECT_ID='));
    expect(hostingerEnv, contains('FIREBASE_SERVICE_ACCOUNT_FILE='));
    expect(compose, contains('notification-worker:'));
    expect(compose, contains('ENABLE_FCM_PUSH:'));
  });
}
