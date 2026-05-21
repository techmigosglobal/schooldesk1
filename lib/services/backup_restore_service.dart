import 'dart:convert';

import 'backend_api_client.dart';

class BackupRestoreService {
  static BackupRestoreService? _instance;

  Map<String, dynamic>? _backupMeta;

  static Future<BackupRestoreService> getInstance() async {
    _instance ??= BackupRestoreService._();
    return _instance!;
  }

  BackupRestoreService._();

  Future<String> exportBackup() async {
    final api = BackendApiClient.instance;
    final payload = {
      'version': '1.0',
      'timestamp': DateTime.now().toIso8601String(),
      'appName': 'SchoolDesk',
      'data': {
        'students': (await api.getStudents(page: 1, pageSize: 100)).data.length,
        'staff': (await api.getStaff(page: 1, pageSize: 100)).data.length,
        'fees': await api.getInvoices(),
        'announcements': (await api.getAnnouncements()).length,
        'audit_logs': await api.getRawList('/audit-logs'),
      },
    };
    return jsonEncode(payload);
  }

  Future<bool> restoreBackup(String jsonString) async {
    final decoded = jsonDecode(jsonString);
    return decoded is Map && decoded['appName'] == 'SchoolDesk';
  }

  Map<String, dynamic>? getBackupMeta() => _backupMeta;

  Future<void> saveBackupMeta(String timestamp, int sizeBytes) async {
    _backupMeta = {'lastBackup': timestamp, 'sizeBytes': sizeBytes};
  }

  Future<int> getDataSizeBytes() async => (await exportBackup()).length;
}
