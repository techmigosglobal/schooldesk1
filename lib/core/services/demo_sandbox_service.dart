import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps only fictional demo snapshots on-device. It never stores a demo
/// password and no sandbox edit is sent to SchoolDesk APIs.
class DemoSandboxService {
  DemoSandboxService._();
  static final instance = DemoSandboxService._();
  static const _storage = FlutterSecureStorage();
  static const _snapshotKey = 'schooldesk_demo_snapshot';
  static const _roleKey = 'schooldesk_demo_role';

  Future<void> save(Map<String, dynamic> payload, String role) async {
    await _storage.write(key: _snapshotKey, value: jsonEncode(payload));
    await _storage.write(key: _roleKey, value: role);
  }

  Future<Map<String, dynamic>?> snapshot() async {
    final raw = await _storage.read(key: _snapshotKey);
    if (raw == null || raw.isEmpty) return null;
    final value = jsonDecode(raw);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  /// Updates the fictional snapshot only in encrypted device storage.
  /// This deliberately has no API client dependency.
  Future<void> saveSnapshot(Map<String, dynamic> value) =>
      _storage.write(key: _snapshotKey, value: jsonEncode(value));

  Future<void> clear() => _storage.deleteAll(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
  );
}
