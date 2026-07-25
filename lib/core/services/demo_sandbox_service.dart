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
  static const _activeKey = 'schooldesk_demo_active';

  Future<void> saveLogin(Map<String, dynamic> payload) async {
    await _storage.write(key: _snapshotKey, value: jsonEncode(payload));
    await _storage.write(key: _activeKey, value: 'true');
    await _storage.delete(key: _roleKey);
  }

  Future<void> selectRole(String role) =>
      _storage.write(key: _roleKey, value: role.trim().toLowerCase());

  Future<String?> selectedRole() => _storage.read(key: _roleKey);

  Future<bool> isActive() async =>
      (await _storage.read(key: _activeKey)) == 'true';

  /// Keeps the verified local snapshot but sends the user back to role choice.
  Future<void> clearSelectedRole() => _storage.delete(key: _roleKey);

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

  Future<void> end() async {
    await _storage.delete(key: _snapshotKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _activeKey);
  }
}
