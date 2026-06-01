import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:schooldesk1/features/auth/presentation/controllers/auth_controller.dart';
import 'package:schooldesk1/features/shared/domain/repositories/attendance_repository.dart';
import 'package:schooldesk1/features/shared/domain/repositories/fee_repository.dart';
import 'package:schooldesk1/features/shared/domain/repositories/leave_repository.dart';
import 'package:schooldesk1/features/shared/domain/repositories/notice_repository.dart';
import 'package:schooldesk1/features/shared/domain/repositories/student_repository.dart';
import 'package:schooldesk1/features/shared/domain/repositories/teacher_repository.dart';
import 'package:schooldesk1/core/network/backend_api_client.dart';
import 'package:schooldesk1/core/services/backend_data_service.dart';
import 'package:schooldesk1/core/di/service_locator.dart';

final backendApiClientProvider = Provider<BackendApiClient>(
  (ref) => ServiceLocator.apiClient,
);

final backendDataServiceProvider = Provider<BackendDataService>(
  (ref) => ServiceLocator.storage,
);

final studentRepositoryProvider = Provider<StudentRepository>(
  (ref) => ServiceLocator.studentRepository,
);

final teacherRepositoryProvider = Provider<TeacherRepository>(
  (ref) => ServiceLocator.teacherRepository,
);

final feeRepositoryProvider = Provider<FeeRepository>(
  (ref) => ServiceLocator.feeRepository,
);

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => ServiceLocator.attendanceRepository,
);

final leaveRepositoryProvider = Provider<LeaveRepository>(
  (ref) => ServiceLocator.leaveRepository,
);

final noticeRepositoryProvider = Provider<NoticeRepository>(
  (ref) => ServiceLocator.noticeRepository,
);

final authControllerProvider = Provider<AuthController>(
  (ref) => ServiceLocator.authController,
);
