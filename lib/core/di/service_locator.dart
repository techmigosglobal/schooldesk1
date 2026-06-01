import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:schooldesk1/features/auth/presentation/controllers/auth_controller.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_attendance_repository.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_fee_repository.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_leave_repository.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_notice_repository.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_student_repository.dart';
import 'package:schooldesk1/features/shared/data/repositories/api_teacher_repository.dart';
import 'package:schooldesk1/features/shared/domain/repositories/attendance_repository.dart';
import 'package:schooldesk1/features/shared/domain/repositories/fee_repository.dart';
import 'package:schooldesk1/features/shared/domain/repositories/leave_repository.dart';
import 'package:schooldesk1/features/shared/domain/repositories/notice_repository.dart';
import 'package:schooldesk1/features/shared/domain/repositories/student_repository.dart';
import 'package:schooldesk1/features/shared/domain/repositories/teacher_repository.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';

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

  static Future<void> initialize() async {
    _apiClient = BackendApiClient.instance;
    _storage ??= await BackendDataService.getInstance();
    _studentRepository ??= ApiStudentRepository(apiClient);
    _teacherRepository ??= ApiTeacherRepository(apiClient);
    _feeRepository ??= ApiFeeRepository(apiClient);
    _attendanceRepository ??= ApiAttendanceRepository(apiClient);
    _leaveRepository ??= ApiLeaveRepository(apiClient);
    _noticeRepository ??= ApiNoticeRepository(apiClient);
    _authController ??= AuthController();
  }

  static BackendApiClient get apiClient {
    assert(
      _apiClient != null,
      'ServiceLocator.initialize() must be called first.',
    );
    return _apiClient!;
  }

  static BackendDataService get storage {
    assert(
      _storage != null,
      'ServiceLocator.initialize() must be called first.',
    );
    return _storage!;
  }

  static StudentRepository get studentRepository {
    assert(
      _studentRepository != null,
      'ServiceLocator.initialize() must be called first.',
    );
    return _studentRepository!;
  }

  static TeacherRepository get teacherRepository {
    assert(
      _teacherRepository != null,
      'ServiceLocator.initialize() must be called first.',
    );
    return _teacherRepository!;
  }

  static FeeRepository get feeRepository {
    assert(
      _feeRepository != null,
      'ServiceLocator.initialize() must be called first.',
    );
    return _feeRepository!;
  }

  static AttendanceRepository get attendanceRepository {
    assert(
      _attendanceRepository != null,
      'ServiceLocator.initialize() must be called first.',
    );
    return _attendanceRepository!;
  }

  static LeaveRepository get leaveRepository {
    assert(
      _leaveRepository != null,
      'ServiceLocator.initialize() must be called first.',
    );
    return _leaveRepository!;
  }

  static NoticeRepository get noticeRepository {
    assert(
      _noticeRepository != null,
      'ServiceLocator.initialize() must be called first.',
    );
    return _noticeRepository!;
  }

  static AuthController get authController {
    assert(
      _authController != null,
      'ServiceLocator.initialize() must be called first.',
    );
    return _authController!;
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
      ],
      child: child,
    );
  }
}
