import 'dart:typed_data';

import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/repositories/api_repository_utils.dart';
import 'package:schooldesk1/core/utils/result.dart';
import 'package:schooldesk1/modules/attendance/domain/repositories/kiosk_attendance_repository.dart';

/// API-backed kiosk capability boundary.
///
/// Kiosk QR display and logs are online-required because the token, expiry,
/// and scan state are authoritative server decisions. The widget does not
/// access [BackendApiClient] directly.
class ApiKioskAttendanceRepository implements KioskAttendanceRepository {
  ApiKioskAttendanceRepository(this._api);

  final BackendApiClient _api;

  @override
  Future<Result<StaffQrTokenModel>> getToken({String? nonce}) {
    return guardApi(() => _api.getStaffQrToken(nonce: nonce));
  }

  @override
  Future<Result<List<StaffAttendanceModel>>> getRecentScans({String? date}) {
    return guardApi(() => _api.getStaffAttendanceForDate(date: date));
  }

  @override
  Future<Result<Uint8List>> exportLogs({String? date}) {
    return guardApi(() => _api.exportStaffQrLogsCsv(date: date));
  }
}
