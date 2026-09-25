import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:schooldesk1/features/auth/presentation/controllers/auth_controller.dart';
import 'package:schooldesk1/modules/attendance/data/repositories/api_attendance_repository.dart';
import 'package:schooldesk1/modules/finance/data/repositories/api_fee_repository.dart';
import 'package:schooldesk1/modules/leave/data/repositories/api_leave_repository.dart';
import 'package:schooldesk1/modules/communication/data/repositories/api_notice_repository.dart';
import 'package:schooldesk1/modules/people/data/repositories/api_student_repository.dart';
import 'package:schooldesk1/modules/people/data/repositories/api_teacher_repository.dart';
import 'package:schooldesk1/modules/attendance/domain/repositories/attendance_repository.dart';
import 'package:schooldesk1/modules/finance/domain/repositories/fee_repository.dart';
import 'package:schooldesk1/modules/leave/domain/repositories/leave_repository.dart';
import 'package:schooldesk1/modules/communication/domain/repositories/notice_repository.dart';
import 'package:schooldesk1/modules/people/domain/repositories/student_repository.dart';
import 'package:schooldesk1/modules/people/domain/repositories/teacher_repository.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/offline/offline_sync_engine.dart';

/// Service locator — provides singleton instances of all controllers and repositories.
/// Replace with proper DI framework (get_it) when scaling to production.
class ServiceLocator {
  ServiceLocator._();

  static BackendApiClient? _apiClient;
  static BackendDataService? _storage;
  static StudentRepository? _studentRepository;
  static TeacherRepository? _teacherRepository;
  static FeeRepository? _feeRepository;
  static AttendanceRepository? _attendanceRepository;
  static LeaveRepository? _leaveRepository;
  static NoticeRepository? _noticeRepository;
  static AuthController? _authController;
  static OfflineSyncEngine? _offlineSync;

  static Future<void> initialize({OfflineSyncEngine? offlineSync}) async {
    _apiClient = BackendApiClient.instance;
    _offlineSync ??= offlineSync ?? OfflineSyncEngine.instance;
    _storage ??= await BackendDataService.getInstance();
    _studentRepository ??= ApiStudentRepository(apiClient);
    _teacherRepository ??= ApiTeacherRepository(apiClient);
    _feeRepository ??= ApiFeeRepository(apiClient);
    _attendanceRepository ??= ApiAttendanceRepository(apiClient)
      ..attachOfflineDatabase(_offlineSync!.database);
    _leaveRepository ??= ApiLeaveRepository(apiClient);
    _noticeRepository ??= ApiNoticeRepository(apiClient);
    _authController ??= AuthController();
  }

  static BackendApiClient get apiClient {
    if (_apiClient == null) {
      throw StateError('ServiceLocator.initialize() must be called first.');
    }
    return _apiClient!;
  }

  static BackendDataService get storage {
    if (_storage == null) {
      throw StateError('ServiceLocator.initialize() must be called first.');
    }
    return _storage!;
  }

  static StudentRepository get studentRepository {
    if (_studentRepository == null) {
      throw StateError('ServiceLocator.initialize() must be called first.');
    }
    return _studentRepository!;
  }

  static TeacherRepository get teacherRepository {
    if (_teacherRepository == null) {
      throw StateError('ServiceLocator.initialize() must be called first.');
    }
    return _teacherRepository!;
  }

  static FeeRepository get feeRepository {
    if (_feeRepository == null) {
      throw StateError('ServiceLocator.initialize() must be called first.');
    }
    return _feeRepository!;
  }

  static AttendanceRepository get attendanceRepository {
    if (_attendanceRepository == null) {
      throw StateError('ServiceLocator.initialize() must be called first.');
    }
    return _attendanceRepository!;
  }

  static LeaveRepository get leaveRepository {
    if (_leaveRepository == null) {
      throw StateError('ServiceLocator.initialize() must be called first.');
    }
    return _leaveRepository!;
  }

  static NoticeRepository get noticeRepository {
    if (_noticeRepository == null) {
      throw StateError('ServiceLocator.initialize() must be called first.');
    }
    return _noticeRepository!;
  }

  static AuthController get authController {
    if (_authController == null) {
      throw StateError('ServiceLocator.initialize() must be called first.');
    }
    return _authController!;
  }

  static OfflineSyncEngine get offlineSync {
    if (_offlineSync == null) {
      throw StateError('ServiceLocator.initialize() must be called first.');
    }
    return _offlineSync!;
  }
}

/// Provider widget that makes controllers available to the widget tree.
/// Wraps the app with all necessary ChangeNotifierProviders.
///
/// Dashboard controllers remain screen-local; AuthController is shared globally.
class AppProviders extends StatelessWidget {
  final Widget child;

  const AppProviders({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(
          value: ServiceLocator.authController,
        ),
        ChangeNotifierProvider<OfflineSyncEngine>.value(
          value: ServiceLocator.offlineSync,
        ),
      ],
      child: child,
    );
  }
}
