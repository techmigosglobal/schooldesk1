import 'dart:typed_data';

import 'package:schooldesk1/core/network/models/backend_models.dart';
import 'package:schooldesk1/core/utils/result.dart';

/// Online-only contract for the staff QR attendance surface.
///
/// QR tokens, scan logs, and exports are server-authoritative. They are not
/// replayable offline mutations and therefore expose explicit Result states.
abstract class KioskAttendanceRepository {
  Future<Result<StaffQrTokenModel>> getToken({String? nonce});

  Future<Result<List<StaffAttendanceModel>>> getRecentScans({String? date});

  Future<Result<Uint8List>> exportLogs({String? date});
}
