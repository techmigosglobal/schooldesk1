import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../core/config/env_config.dart';
import '../core/errors/exceptions.dart';
import 'generated/schooldesk_api.dart';
import 'generated/schooldesk_api_models.dart';
import 'token_storage_service.dart';

/// Backend API client for school-desk backend
/// Handles all HTTP communication with the Go backend
class BackendApiClient {
  static BackendApiClient? _instance;
  late final Dio _dio;
  Completer<bool>? _refreshCompleter;

  BackendApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBaseUrl,
        connectTimeout: Duration(seconds: EnvConfig.apiTimeoutSeconds),
        receiveTimeout: Duration(seconds: EnvConfig.apiTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(this),
      _LoggingInterceptor(),
      _ErrorInterceptor(this),
    ]);
  }

  static BackendApiClient get instance {
    _instance ??= BackendApiClient._();
    return _instance!;
  }

  static Future<void> initialize() async {
    final client = instance;
    final access = await TokenStorageService.getAccessToken();
    if (access != null && access.isNotEmpty) {
      client.setAuthToken(access);
      client.setCurrentRole(await TokenStorageService.getRoleName());
      await client.restoreStoredSession();
    }
  }

  Dio get dio => _dio;

  String? _authToken;
  String? _currentRoleName;

  String? get currentRoleName => _currentRoleName;

  void setAuthToken(String token) {
    _authToken = token;
  }

  void setCurrentRole(String? roleName) {
    final normalized = roleName?.trim();
    _currentRoleName = normalized == null || normalized.isEmpty
        ? null
        : normalized;
  }

  void clearAuthToken() {
    _authToken = null;
    _currentRoleName = null;
  }

  bool get isAuthenticated => _authToken != null;

  // ─── Authentication ────────────────────────────────────────────────────────

  Future<LoginResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post('/auth/login', data: request.toJson());
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final loginData = data['data'] as Map<String, dynamic>;
        final resp = LoginResponse.fromJson(loginData);
        setAuthToken(resp.token);
        setCurrentRole(resp.user.roleName);
        await TokenStorageService.saveTokens(
          accessToken: resp.token,
          refreshToken: resp.refreshToken,
          roleName: resp.user.roleName,
        );
        return resp;
      }
      throw ServerException(message: data['error'] ?? 'Login failed');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    final refresh = await TokenStorageService.getRefreshToken();
    if (_authToken != null) {
      try {
        await _dio.post('/auth/logout', data: {'refresh_token': refresh ?? ''});
      } catch (_) {
        // Ignore logout network failures; client-side token clear is mandatory.
      }
    }
    clearAuthToken();
    await TokenStorageService.clear();
  }

  Future<Map<String, dynamic>> getDashboard(String role) async {
    final safeRole = role.trim().toLowerCase();
    try {
      final response = await _dio.get('/dashboard/$safeRole');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load dashboard',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPrincipalClassesOverview() async {
    try {
      final response = await _dio.get('/principal/classes');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load class command center',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPrincipalClass({
    required String academicYearId,
    required String sectionName,
    required int capacity,
    String gradeId = '',
    String gradeName = '',
    int? gradeNumber,
    String classTeacherId = '',
  }) async {
    try {
      final response = await _dio.post(
        '/principal/classes',
        data: {
          'grade_id': gradeId.trim(),
          'grade_name': gradeName.trim(),
          if (gradeNumber != null) 'grade_number': gradeNumber,
          'academic_year_id': academicYearId.trim(),
          'section_name': sectionName.trim(),
          'capacity': capacity,
          'class_teacher_id': classTeacherId.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create principal class',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPrincipalClassInstruction({
    required String sectionId,
    required String message,
    String title = '',
    String type = 'instruction',
    String priority = 'normal',
    bool sendNotice = false,
  }) async {
    try {
      final response = await _dio.post(
        '/principal/classes/$sectionId/instructions',
        data: {
          'title': title.trim(),
          'message': message.trim(),
          'type': type.trim().isEmpty ? 'instruction' : type.trim(),
          'priority': priority.trim().isEmpty ? 'normal' : priority.trim(),
          'send_notice': sendNotice,
          'target_route': '/principal-classes-screen',
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to save class instruction',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAssistantCatalog() async {
    try {
      final response = await _dio.get('/assistant/workflows');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load assistant workflows',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> detectAssistantIntent(String command) async {
    try {
      final response = await _dio.post(
        '/assistant/intent',
        data: {'command': command},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to parse assistant command',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getAssistantSessions({
    String? status,
    bool all = false,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (status != null && status.trim().isNotEmpty) {
        query['status'] = status.trim();
      }
      if (all) query['all'] = true;
      final response = await _dio.get(
        '/assistant/sessions',
        queryParameters: query.isEmpty ? null : query,
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load assistant sessions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createAssistantSession({
    required String workflowType,
    String title = '',
    String command = '',
    Map<String, dynamic> initialData = const {},
  }) async {
    try {
      final response = await _dio.post(
        '/assistant/sessions',
        data: {
          'workflow_type': workflowType,
          'title': title,
          'command': command,
          'initial_data': initialData,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create assistant session',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> saveAssistantStep({
    required String sessionId,
    required String stepId,
    Map<String, dynamic> draftData = const {},
    Map<String, dynamic> stepData = const {},
    bool completed = false,
    String currentStepId = '',
  }) async {
    try {
      final response = await _dio.put(
        '/assistant/sessions/$sessionId/steps/$stepId',
        data: {
          'draft_data': draftData,
          'step_data': stepData,
          'completed': completed,
          'current_step_id': currentStepId,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to save assistant step',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> validateAssistantSession(
    String sessionId,
  ) async {
    try {
      final response = await _dio.post(
        '/assistant/sessions/$sessionId/validate',
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to validate assistant workflow',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> executeAssistantSession(String sessionId) async {
    try {
      final response = await _dio.post(
        '/assistant/sessions/$sessionId/execute',
        data: {'confirm': true},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to execute assistant workflow',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> cancelAssistantSession(String sessionId) async {
    try {
      final response = await _dio.delete('/assistant/sessions/$sessionId');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to cancel assistant workflow',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getAssistantTemplate(String workflowType) async {
    try {
      final response = await _dio.get('/assistant/templates/$workflowType');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load assistant template',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> importAssistantPreview({
    required String sessionId,
    required String format,
    required String content,
  }) async {
    try {
      final response = await _dio.post(
        '/assistant/sessions/$sessionId/import-preview',
        data: {'format': format, 'content': content},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to import assistant data',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPrincipalSubjectsOverview() async {
    try {
      final response = await _dio.get('/principal/subjects');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load subject command center',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPrincipalSubjectAction({
    required String subjectId,
    required String actionType,
    required String message,
    String title = '',
    String priority = 'normal',
    String teacherId = '',
    String gradeId = '',
    String dueDate = '',
  }) async {
    try {
      final response = await _dio.post(
        '/principal/subjects/$subjectId/actions',
        data: {
          'action_type': actionType.trim(),
          'title': title.trim(),
          'message': message.trim(),
          'priority': priority.trim().isEmpty ? 'normal' : priority.trim(),
          'teacher_id': teacherId.trim(),
          'grade_id': gradeId.trim(),
          'due_date': dueDate.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to save subject action',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> savePrincipalSubjectMapping({
    required String subjectId,
    required String gradeId,
    required int periodsPerWeek,
    int maxMarks = 100,
    int passMarks = 35,
    bool isMandatory = true,
    String sectionId = '',
    String teacherId = '',
    bool isPrimary = true,
    String assignmentId = '',
  }) async {
    try {
      final response = await _dio.post(
        '/principal/subjects/${subjectId.trim()}/mappings',
        data: {
          'grade_id': gradeId.trim(),
          'section_id': sectionId.trim(),
          'teacher_id': teacherId.trim(),
          'assignment_id': assignmentId.trim(),
          'periods_per_week': periodsPerWeek,
          'max_marks': maxMarks,
          'pass_marks': passMarks,
          'is_mandatory': isMandatory,
          'is_primary': isPrimary,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to save subject mapping',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPrincipalTimetableOverview() async {
    try {
      final response = await _dio.get('/principal/timetable');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load timetable command center',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPrincipalTimetableAction({
    required String actionType,
    required String message,
    String title = '',
    String priority = 'normal',
    String slotId = '',
    String dueDate = '',
  }) async {
    try {
      final response = await _dio.post(
        '/principal/timetable/actions',
        data: {
          'action_type': actionType.trim(),
          'title': title.trim(),
          'message': message.trim(),
          'priority': priority.trim().isEmpty ? 'normal' : priority.trim(),
          'slot_id': slotId.trim(),
          'due_date': dueDate.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to save timetable action',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPrincipalExamsOverview() async {
    try {
      final response = await _dio.get('/principal/exams');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load exam command center',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPrincipalExamAction({
    required String actionType,
    required String message,
    String title = '',
    String priority = 'normal',
    String examId = '',
    String dueDate = '',
  }) async {
    try {
      final response = await _dio.post(
        '/principal/exams/actions',
        data: {
          'action_type': actionType.trim(),
          'title': title.trim(),
          'message': message.trim(),
          'priority': priority.trim().isEmpty ? 'normal' : priority.trim(),
          'exam_id': examId.trim(),
          'entity_id': examId.trim(),
          'due_date': dueDate.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to save exam action',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getPrincipalResultsOverview() async {
    try {
      final response = await _dio.get('/principal/results');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load results command center',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createPrincipalResultAction({
    required String actionType,
    required String message,
    String title = '',
    String priority = 'normal',
    String examId = '',
    String dueDate = '',
  }) async {
    try {
      final response = await _dio.post(
        '/principal/results/actions',
        data: {
          'action_type': actionType.trim(),
          'title': title.trim(),
          'message': message.trim(),
          'priority': priority.trim().isEmpty ? 'normal' : priority.trim(),
          'exam_id': examId.trim(),
          'entity_id': examId.trim(),
          'due_date': dueDate.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to save result action',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Password update failed',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> refreshSession() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final refresh = await TokenStorageService.getRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      return false;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        if (!completer.isCompleted) completer.complete(false);
        return false;
      }
      final payload = data['data'] as Map<String, dynamic>;
      final token = payload['token'] as String?;
      final nextRefresh =
          (payload['refresh_token'] as String?) ?? (token ?? '');
      if (token == null || token.isEmpty) {
        if (!completer.isCompleted) completer.complete(false);
        return false;
      }
      setAuthToken(token);
      await TokenStorageService.saveTokens(
        accessToken: token,
        refreshToken: nextRefresh,
      );
      if (!completer.isCompleted) completer.complete(true);
      return true;
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<bool> restoreStoredSession() async {
    if (_authToken == null || _authToken!.isEmpty) {
      return false;
    }

    try {
      final profile = await getProfile();
      setCurrentRole(profile.roleName);
      await TokenStorageService.saveRoleName(profile.roleName);
      return true;
    } on AuthException {
      final refreshed = await refreshSession();
      if (!refreshed) {
        await TokenStorageService.clear();
        clearAuthToken();
        return false;
      }
      try {
        final profile = await getProfile();
        setCurrentRole(profile.roleName);
        await TokenStorageService.saveRoleName(profile.roleName);
        return true;
      } catch (_) {
        return currentRoleName != null;
      }
    } catch (_) {
      return currentRoleName != null;
    }
  }

  Future<UserResponse> getProfile() async {
    try {
      final response = await _dio.get('/auth/profile');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return UserResponse.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(message: data['error'] ?? 'Failed to get profile');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserResponse> updateProfile(Map<String, dynamic> payload) async {
    try {
      final response = await _dio.patch('/auth/profile', data: payload);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return UserResponse.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update profile',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadProfileAvatar(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post('/auth/profile/avatar', data: formData);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['avatar'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload profile avatar',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Schools ───────────────────────────────────────────────────────────────

  Future<List<SchoolModel>> getSchools() async {
    try {
      final response = await _dio.get('/schools');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => SchoolModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: data['error'] ?? 'Failed to get schools');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getCurrentSchool() async {
    try {
      final response = await _dio.get('/schools/current');
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(message: data['error'] ?? 'Failed to get school');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateCurrentSchool(
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await _dio.patch('/schools/current', data: payload);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update school',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadCurrentSchoolLogo(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'logo': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post('/schools/current/logo', data: formData);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        final payload = Map<String, dynamic>.from(data['data'] as Map? ?? {});
        return '${payload['logo_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload school logo',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Academic Years ─────────────────────────────────────────────────────────

  Future<List<AcademicYearModel>> getAcademicYears({String? schoolId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (schoolId != null) queryParams['school_id'] = schoolId;

      final response = await _dio.get(
        '/academic-years',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => AcademicYearModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get academic years',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AcademicYearModel> createAcademicYear({
    required String yearLabel,
    required String startDate,
    required String endDate,
    bool isCurrent = true,
  }) async {
    try {
      final response = await _dio.post(
        '/academic-years',
        data: {
          'year_label': yearLabel,
          'start_date': startDate,
          'end_date': endDate,
          'is_current': isCurrent,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return AcademicYearModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create academic year',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AcademicYearModel> updateAcademicYear(
    String id, {
    required String yearLabel,
    required String startDate,
    required String endDate,
    bool isCurrent = false,
  }) async {
    try {
      final response = await _dio.put(
        '/academic-years/$id',
        data: {
          'year_label': yearLabel,
          'start_date': startDate,
          'end_date': endDate,
          'is_current': isCurrent,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return AcademicYearModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update academic year',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Grades ─────────────────────────────────────────────────────────────────

  Future<List<GradeModel>> getGrades({String? schoolId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (schoolId != null) queryParams['school_id'] = schoolId;

      final response = await _dio.get('/grades', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => GradeModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: data['error'] ?? 'Failed to get grades');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Sections ───────────────────────────────────────────────────────────────

  Future<List<SectionModel>> getSections({
    String? gradeId,
    String? yearId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (gradeId != null) queryParams['grade_id'] = gradeId;
      if (yearId != null) queryParams['academic_year_id'] = yearId;

      final response = await _dio.get(
        '/sections',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => SectionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: data['error'] ?? 'Failed to get sections');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Staff ──────────────────────────────────────────────────────────────────

  Future<PaginatedList<StaffModel>> getStaff({
    String? schoolId,
    String? departmentId,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (schoolId != null) queryParams['school_id'] = schoolId;
      if (departmentId != null) queryParams['department_id'] = departmentId;
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get('/staff', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return PaginatedList<StaffModel>(
          data: (data['data'] as List)
              .map((e) => StaffModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          total: data['total'] as int,
          page: data['page'] as int,
          pageSize: data['page_size'] as int,
        );
      }
      throw ServerException(message: data['error'] ?? 'Failed to get staff');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StaffModel> getStaffMember(String id) async {
    try {
      final response = await _dio.get('/staff/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StaffModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get staff member',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StaffModel> createStaff({
    required String firstName,
    required String lastName,
    String? staffCode,
    String? username,
    String? email,
    String? phone,
    String? designation,
    String? departmentId,
    String? password,
    String accountRole = 'Teacher',
    String gender = 'unspecified',
    String employmentType = 'full_time',
    String joinDate = '2026-01-01',
    String dateOfBirth = '1990-01-01',
    double basicSalary = 0,
    bool requestPrincipalApproval = false,
  }) async {
    try {
      final response = await _dio.post(
        '/staff',
        data: {
          if (staffCode != null && staffCode.trim().isNotEmpty)
            'staff_code': staffCode.trim(),
          if (username != null && username.trim().isNotEmpty)
            'username': username.trim(),
          'first_name': firstName,
          'last_name': lastName,
          'email': email ?? '',
          'phone': phone ?? '',
          'designation': designation ?? '',
          'department_id': departmentId ?? '',
          'department_name': departmentId ?? '',
          if (password != null && password.trim().isNotEmpty)
            'password': password.trim(),
          'account_role': accountRole,
          'request_principal_approval': requestPrincipalApproval,
          'gender': gender,
          'employment_type': employmentType,
          'join_date': joinDate,
          'date_of_birth': dateOfBirth,
          'basic_salary': basicSalary,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StaffModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(message: data['error'] ?? 'Failed to create staff');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadStaffPhoto({
    required String staffId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'photo': await _multipartStudentFile(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
        ),
      });
      final response = await _dio.post('/staff/$staffId/photo', data: formData);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['photo'] ?? payload['photo_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload staff photo',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadStaffDocument({
    required String staffId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    required String documentType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'doc_type': documentType.trim().isEmpty
            ? 'staff_document'
            : documentType.trim(),
        'document': await _multipartStudentFile(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
        ),
      });
      final response = await _dio.post(
        '/staff/$staffId/documents',
        data: formData,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['file_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload staff document',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateStaff(
    String id, {
    required String firstName,
    required String lastName,
    String? staffCode,
    String? username,
    String? email,
    String? phone,
    String? designation,
    String? departmentId,
    String? password,
    String accountRole = 'Teacher',
    String gender = 'unspecified',
    String employmentType = 'full_time',
    String joinDate = '2026-01-01',
    String dateOfBirth = '1990-01-01',
    double basicSalary = 0,
  }) async {
    try {
      final response = await _dio.put(
        '/staff/$id',
        data: {
          if (staffCode != null && staffCode.trim().isNotEmpty)
            'staff_code': staffCode.trim(),
          if (username != null && username.trim().isNotEmpty)
            'username': username.trim(),
          'first_name': firstName,
          'last_name': lastName,
          'email': email ?? '',
          'phone': phone ?? '',
          'designation': designation ?? '',
          'department_id': departmentId ?? '',
          'department_name': departmentId ?? '',
          if (password != null && password.trim().isNotEmpty)
            'password': password.trim(),
          'account_role': accountRole,
          'gender': gender,
          'employment_type': employmentType,
          'join_date': joinDate,
          'date_of_birth': dateOfBirth,
          'basic_salary': basicSalary,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to update staff',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteStaff(String id) async {
    try {
      final response = await _dio.delete('/staff/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to delete staff',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Students ───────────────────────────────────────────────────────────────

  Future<PaginatedList<StudentModel>> getStudents({
    String? schoolId,
    String? sectionId,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (schoolId != null) queryParams['school_id'] = schoolId;
      if (sectionId != null) queryParams['section_id'] = sectionId;
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get(
        '/students',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return PaginatedList<StudentModel>(
          data: (data['data'] as List)
              .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          total: data['total'] as int,
          page: data['page'] as int,
          pageSize: data['page_size'] as int,
        );
      }
      throw ServerException(message: data['error'] ?? 'Failed to get students');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getMyStudents() async {
    try {
      final response = await _dio.get('/me/students');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        if (payload is List) {
          return payload.whereType<Map>().map((e) {
            final row = Map<String, dynamic>.from(e);
            final firstName = row['first_name']?.toString().trim() ?? '';
            final lastName = row['last_name']?.toString().trim() ?? '';
            final fullName = [
              firstName,
              lastName,
            ].where((part) => part.isNotEmpty).join(' ');
            row['name'] = row['name'] ?? row['full_name'] ?? fullName;
            row['class'] = row['class'] ?? row['grade_name'];
            row['section'] = row['section'] ?? row['section_name'];
            row['rollNo'] =
                row['rollNo'] ??
                row['roll_number'] ??
                row['admission_number'] ??
                row['student_code'];
            row['attendance'] = row['attendance'] ?? 'N/A';
            row['homeworkDue'] = row['homeworkDue'] ?? 0;
            row['classTeacher'] = row['classTeacher'] ?? 'Not assigned';
            return row;
          }).toList();
        }
        return <Map<String, dynamic>>[];
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get linked students',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<PaginatedList<UserAccountModel>> getUsers({
    String? role,
    String? status,
    int page = 1,
    int pageSize = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (role != null && role.trim().isNotEmpty) {
        queryParams['role'] = role.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }

      final response = await _dio.get('/users', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return PaginatedList<UserAccountModel>(
          data: (data['data'] as List)
              .map((e) => UserAccountModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          total: data['total'] as int,
          page: data['page'] as int,
          pageSize: data['page_size'] as int,
        );
      }
      throw ServerException(message: data['error'] ?? 'Failed to get users');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserAccountModel> createUser({
    required String username,
    required String password,
    required String role,
    String fullName = '',
    String email = '',
    String phone = '',
    bool isActive = true,
    bool requestPrincipalApproval = false,
  }) async {
    try {
      final cleanUsername = username.trim();
      final cleanEmail = email.trim();
      final response = await _dio.post(
        '/users',
        data: {
          'name': fullName.trim(),
          'username': cleanUsername,
          'password': password,
          'role': role,
          if (cleanEmail.isNotEmpty) 'email': cleanEmail,
          'phone': phone,
          'is_active': isActive,
          'request_principal_approval': requestPrincipalApproval,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return UserAccountModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(message: data['error'] ?? 'Failed to create user');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserAccountModel> updateUser(
    String id, {
    String? username,
    String? password,
    String? role,
    String? fullName,
    String? email,
    String? phone,
    bool? isActive,
  }) async {
    try {
      final payload = <String, dynamic>{};
      if (username != null && username.trim().isNotEmpty) {
        payload['username'] = username.trim();
      }
      if (password != null && password.isNotEmpty) {
        payload['password'] = password;
      }
      if (role != null) payload['role'] = role;
      if (fullName != null) payload['name'] = fullName;
      if (email != null) payload['email'] = email;
      if (phone != null) payload['phone'] = phone;
      if (isActive != null) payload['is_active'] = isActive;
      final response = await _dio.patch('/users/$id', data: payload);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return UserAccountModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(message: data['error'] ?? 'Failed to update user');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadUserAvatar({
    required String userId,
    required String filePath,
  }) async {
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });
      final response = await _dio.post('/users/$userId/avatar', data: formData);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['avatar'] ?? payload['avatar_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload user avatar',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteUser(String id, {bool permanent = false}) async {
    try {
      final response = await _dio.delete(
        '/users/$id',
        queryParameters: permanent ? {'permanent': true} : null,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) return;
      throw ServerException(message: data['error'] ?? 'Failed to delete user');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> assignParentStudents({
    required String parentUserId,
    required List<String> admissionNumbers,
    List<String> studentIds = const [],
  }) async {
    try {
      final cleaned = admissionNumbers
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final cleanedStudentIds = studentIds
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final response = await _dio.post(
        '/parents/$parentUserId/students',
        data: {'admission_numbers': cleaned, 'student_ids': cleanedStudentIds},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to assign students',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getParentStudents({
    required String parentUserId,
  }) async {
    try {
      final response = await _dio.get('/parents/$parentUserId/students');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        if (payload is Map) {
          return _asListMap(payload['students']);
        }
        return _asListMap(payload);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get parent students',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> setStudentParent({
    required String studentId,
    String? parentUserId,
  }) async {
    try {
      final response = await _dio.put(
        '/students/$studentId/parent',
        data: {'parent_user_id': parentUserId?.trim() ?? ''},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to update student parent',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StudentModel> getStudent(String id) async {
    try {
      final response = await _dio.get('/students/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StudentModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(message: data['error'] ?? 'Failed to get student');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getStudentEnrollments(
    String studentId,
  ) async {
    try {
      final response = await _dio.get('/students/$studentId/enrollments');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get student enrollments',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StudentModel> createStudent({
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String gender,
    String? admissionNumber,
    String? studentCode,
    String? currentSectionId,
    String admissionDate = '2026-01-01',
    String status = 'active',
  }) async {
    try {
      final response = await _dio.post(
        '/students',
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'date_of_birth': dateOfBirth,
          'gender': gender,
          'admission_number': admissionNumber ?? '',
          'student_code': studentCode ?? '',
          'current_section_id': currentSectionId ?? '',
          'admission_date': admissionDate,
          'status': status,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StudentModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create student',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadStudentPhoto({
    required String studentId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'photo': await _multipartStudentFile(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
        ),
      });
      final response = await _dio.post(
        '/students/$studentId/photo',
        data: formData,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['photo'] ?? payload['photo_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload student photo',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> uploadStudentDocument({
    required String studentId,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
    required String docType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'doc_type': docType.trim().isEmpty
            ? 'admission_document'
            : docType.trim(),
        'document': await _multipartStudentFile(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
        ),
      });
      final response = await _dio.post(
        '/students/$studentId/documents',
        data: formData,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return '${payload['file_url'] ?? ''}';
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to upload student document',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateStudent(
    String id, {
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String gender,
    String? admissionNumber,
    String? studentCode,
    String? currentSectionId,
    String? admissionDate,
    String status = 'active',
  }) async {
    try {
      final payload = <String, dynamic>{
        'first_name': firstName,
        'last_name': lastName,
        'date_of_birth': dateOfBirth,
        'gender': gender,
        'admission_number': admissionNumber ?? '',
        'student_code': studentCode ?? '',
        'current_section_id': currentSectionId ?? '',
        'status': status,
      };
      if ((admissionDate ?? '').trim().isNotEmpty) {
        payload['admission_date'] = admissionDate!.trim();
      }
      final response = await _dio.put('/students/$id', data: payload);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to update student',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<MultipartFile> _multipartStudentFile({
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    if (fileBytes != null && fileBytes.isNotEmpty) {
      return MultipartFile.fromBytes(
        fileBytes,
        filename: (fileName ?? '').trim().isEmpty
            ? 'schooldesk-upload'
            : fileName!.trim(),
      );
    }
    final cleanPath = (filePath ?? '').trim();
    if (cleanPath.isEmpty) {
      throw const ServerException(message: 'Upload file is required');
    }
    return MultipartFile.fromFile(
      cleanPath,
      filename: (fileName ?? '').trim().isEmpty ? null : fileName!.trim(),
    );
  }

  Future<void> deleteStudent(String id) async {
    try {
      final response = await _dio.delete('/students/$id');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to delete student',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Attendance ─────────────────────────────────────────────────────────────

  Future<List<AttendanceSessionModel>> getAttendanceSessions({
    String? sectionId,
    String? date,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (sectionId != null) queryParams['section_id'] = sectionId;
      if (date != null) queryParams['date'] = date;

      final response = await _dio.get(
        '/attendance/sessions',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map(
              (e) => AttendanceSessionModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get attendance sessions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AttendanceSessionModel> createAttendanceSession({
    required String sectionId,
    required String subjectId,
    required String staffId,
    required String date,
    int? periodNumber,
    String? timetableSlotId,
  }) async {
    try {
      final data = {
        'section_id': sectionId,
        'subject_id': subjectId,
        'staff_id': staffId,
        'date': date,
        if (periodNumber != null) 'period_number': periodNumber,
        if (timetableSlotId != null) 'timetable_slot_id': timetableSlotId,
      };

      final response = await _dio.post('/attendance/sessions', data: data);
      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        return AttendanceSessionModel.fromJson(
          responseData['data'] as Map<String, dynamic>,
        );
      }
      throw ServerException(
        message: responseData['error'] ?? 'Failed to create attendance session',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markAttendance(
    String sessionId,
    List<Map<String, dynamic>> attendances,
  ) async {
    try {
      final response = await _dio.post(
        '/attendance/sessions/$sessionId/mark',
        data: {'attendances': attendances},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to mark attendance',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getStudentAttendanceSummary({
    required String studentId,
    String? academicYearId,
    String? termId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'student_id': studentId};
      if (academicYearId != null && academicYearId.isNotEmpty) {
        queryParams['academic_year_id'] = academicYearId;
      }
      if (termId != null && termId.isNotEmpty) {
        queryParams['term_id'] = termId;
      }

      final response = await _dio.get(
        '/attendance/summary',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        if (payload is Map) return Map<String, dynamic>.from(payload);
        return <String, dynamic>{};
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get attendance summary',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getStudentAttendanceRecords(
    String studentId, {
    int? month,
    int? year,
  }) {
    final queryParams = <String, dynamic>{};
    if (month != null) queryParams['month'] = month.toString().padLeft(2, '0');
    if (year != null) queryParams['year'] = '$year';
    return getRawList(
      '/students/$studentId/attendance',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  Future<StaffQrTokenModel> getStaffQrToken() async {
    try {
      final response = await _dio.get('/attendance/staff/qr-token');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StaffQrTokenModel.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to create staff QR code',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StaffAttendanceModel> scanStaffQr(String token) async {
    try {
      final response = await _dio.post(
        '/attendance/staff/qr-scan',
        data: {'token': token},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return StaffAttendanceModel.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to record staff attendance',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<StaffAttendanceModel?> getMyStaffAttendanceToday() async {
    try {
      final response = await _dio.get('/attendance/staff/me/today');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        if (payload is Map) {
          final attendance = payload['attendance'];
          if (attendance is Map) {
            return StaffAttendanceModel.fromJson(
              Map<String, dynamic>.from(attendance),
            );
          }
        }
        return null;
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load staff attendance',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<StaffAttendanceModel>> getStaffAttendanceForDate({
    String? date,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null && date.isNotEmpty) queryParams['date'] = date;

      final response = await _dio.get(
        '/attendance/staff',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final payload = data['data'];
        final rows = payload is Map ? payload['attendances'] : payload;
        if (rows is List) {
          return rows
              .whereType<Map>()
              .map(
                (item) => StaffAttendanceModel.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList();
        }
        return const [];
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load staff attendance',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Exams ──────────────────────────────────────────────────────────────────

  Future<List<ExamModel>> getExams({
    String? schoolId,
    String? yearId,
    String? termId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (schoolId != null) queryParams['school_id'] = schoolId;
      if (yearId != null) queryParams['academic_year_id'] = yearId;
      if (termId != null) queryParams['term_id'] = termId;

      final response = await SchoolDeskApi.instance.client.exams(
        queryParams.isEmpty ? null : queryParams,
      );
      if (response.success == true) {
        return _asListMap(
          response.data,
        ).map((e) => ExamModel.fromJson(e)).toList();
      }
      throw ServerException(message: response.error ?? 'Failed to get exams');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getExamTypes() async {
    try {
      final response = await _dio.get('/exams/types');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get exam types',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTerms(String academicYearId) async {
    try {
      final response = await _dio.get('/academic-years/$academicYearId/terms');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(message: data['error'] ?? 'Failed to get terms');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Fees ───────────────────────────────────────────────────────────────────

  Future<List<FeeInvoiceModel>> getStudentFees(String studentId) async {
    try {
      final response = await _dio.get('/students/$studentId/fees');
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => FeeInvoiceModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(message: data['error'] ?? 'Failed to get fees');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> recordPayment(PaymentRequest request) async {
    try {
      final response = await _dio.post(
        '/fees/payments',
        data: request.toJson(),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to record payment',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitParentPaymentRequest(
    PaymentRequest request, {
    String? remarks,
  }) async {
    try {
      final payload = request.toParentPaymentRequestJson();
      if (remarks != null && remarks.trim().isNotEmpty) {
        payload['remarks'] = remarks.trim();
      }
      final response = await _dio.post('/fees/payment-requests', data: payload);
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to submit payment request',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getParentPaymentRequests({
    String? studentId,
    String? invoiceId,
    String? status,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (studentId != null && studentId.trim().isNotEmpty) {
        queryParams['student_id'] = studentId.trim();
      }
      if (invoiceId != null && invoiceId.trim().isNotEmpty) {
        queryParams['invoice_id'] = invoiceId.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }
      final response = await _dio.get(
        '/fees/payment-requests',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load payment requests',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> decideParentPaymentRequest(
    String id, {
    required String status,
    String adminRemarks = '',
  }) async {
    try {
      final response = await _dio.put(
        '/fees/payment-requests/$id/decision',
        data: {
          'status': status,
          if (adminRemarks.trim().isNotEmpty)
            'admin_remarks': adminRemarks.trim(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update payment request',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getStudentLeaveApplications({
    String? studentId,
    String? status,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (studentId != null && studentId.trim().isNotEmpty) {
        queryParams['student_id'] = studentId.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }
      final response = await _dio.get(
        '/student-leave/applications',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to load student leave applications',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitStudentLeaveApplication({
    required String studentId,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String reason,
    bool halfDay = false,
  }) async {
    try {
      final response = await _dio.post(
        '/student-leave/applications',
        data: {
          'student_id': studentId,
          'leave_type': leaveType,
          'from_date': fromDate,
          'to_date': toDate,
          'half_day': halfDay,
          'reason': reason,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to submit student leave application',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> decideStudentLeaveApplication(
    String id, {
    required String status,
    String rejectionReason = '',
  }) async {
    try {
      final response = await _dio.put(
        '/student-leave/applications/$id/decision',
        data: {
          'status': status,
          if (rejectionReason.trim().isNotEmpty)
            'rejection_reason': rejectionReason.trim(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to update student leave application',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Leave ──────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLeaveTypes() {
    return getRawList('/leave/types');
  }

  Future<List<Map<String, dynamic>>> getLeaveBalances({
    String? staffId,
    String? academicYearId,
  }) {
    final queryParams = <String, dynamic>{};
    if (staffId != null && staffId.trim().isNotEmpty) {
      queryParams['staff_id'] = staffId.trim();
    }
    if (academicYearId != null && academicYearId.trim().isNotEmpty) {
      queryParams['academic_year_id'] = academicYearId.trim();
    }
    return getRawList(
      '/leave/balances',
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  Future<List<LeaveApplicationModel>> getLeaveApplications({
    String? staffId,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (staffId != null) queryParams['staff_id'] = staffId;
      if (status != null) queryParams['status'] = status;

      final response = await _dio.get(
        '/leave/applications',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map(
              (e) => LeaveApplicationModel.fromJson(e as Map<String, dynamic>),
            )
            .toList();
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get leave applications',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> submitLeaveApplication(LeaveApplicationRequest request) async {
    try {
      final response = await _dio.post(
        '/leave/applications',
        data: request.toJson(),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to submit leave application',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> decideLeaveApplication(
    String id, {
    required String status,
    String reason = '',
  }) async {
    try {
      final response = await _dio.put(
        '/leave/applications/$id/approve',
        data: {'status': status, 'reason': reason},
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to update leave application',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Announcements ──────────────────────────────────────────────────────────

  Future<List<AnnouncementModel>> getAnnouncements({String? schoolId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (schoolId != null) queryParams['school_id'] = schoolId;

      final response = await _dio.get(
        '/announcements',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return (data['data'] as List)
            .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get announcements',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> createAnnouncement({
    required String title,
    required String content,
    String targetAudience = 'all',
    bool isUrgent = false,
  }) async {
    try {
      final response = await _dio.post(
        '/announcements',
        data: {
          'title': title,
          'content': content,
          'target_audience': targetAudience,
          'is_urgent': isUrgent,
        },
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to create announcement',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> createEvent({
    required String academicYearId,
    required String title,
    required String eventType,
    required DateTime start,
    required DateTime end,
    String location = '',
    String description = '',
    bool isHoliday = false,
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.createEvent(
        EventDto(
          academicYearId: academicYearId,
          eventName: title,
          eventType: eventType,
          description: description,
          startDate: start.toUtc().toIso8601String().split('T').first,
          endDate: end.toUtc().toIso8601String().split('T').first,
          startTime: start.toUtc().toIso8601String().split('T').last,
          endTime: end.toUtc().toIso8601String().split('T').last,
          venue: location,
          isHoliday: isHoliday,
          status: 'scheduled',
        ),
      );
      if (response.success != true) {
        throw ServerException(
          message: response.error ?? 'Failed to create event',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> createExam({
    required String academicYearId,
    required String termId,
    required String examTypeId,
    required String examName,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.createExam(
        ExamDto(
          academicYearId: academicYearId,
          termId: termId,
          examTypeId: examTypeId,
          examName: examName,
          startDate: startDate,
          endDate: endDate,
        ),
      );
      if (response.success != true) {
        throw ServerException(
          message: response.error ?? 'Failed to create exam',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateExam(
    String id, {
    required String academicYearId,
    required String termId,
    required String examTypeId,
    required String examName,
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.updateExam(
        id,
        ExamDto(
          academicYearId: academicYearId,
          termId: termId,
          examTypeId: examTypeId,
          examName: examName,
          startDate: startDate,
          endDate: endDate,
        ),
      );
      if (response.success != true) {
        throw ServerException(
          message: response.error ?? 'Failed to update exam',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> setExamPublished(String id, bool isPublished) async {
    try {
      final response = await SchoolDeskApi.instance.client.publishExam(id, {
        'is_published': isPublished,
      });
      if (response.success != true) {
        throw ServerException(
          message: response.error ?? 'Failed to update exam publish status',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getEvents({String? academicYearId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }
      final response = await SchoolDeskApi.instance.client.events(
        queryParams.isEmpty ? null : queryParams,
      );
      if (response.success == true) {
        return _asListMap(response.data).map((event) {
          final normalized = Map<String, dynamic>.from(event);
          normalized['id'] ??= normalized['event_id'];
          normalized['event_title'] ??= normalized['event_name'];
          normalized['location'] ??= normalized['venue'];
          normalized['start_datetime'] ??=
              '${normalized['start_date'] ?? ''}T${normalized['start_time'] ?? '00:00:00'}';
          normalized['end_datetime'] ??=
              '${normalized['end_date'] ?? normalized['start_date'] ?? ''}T${normalized['end_time'] ?? '23:59:59'}';
          return normalized;
        }).toList();
      }
      throw ServerException(message: 'Failed to get events');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    try {
      final response = await SchoolDeskApi.instance.client.notifications();
      if (response.success == true) {
        return _asListMap(response.data).map((notification) {
          final normalized = Map<String, dynamic>.from(notification);
          normalized['id'] ??= normalized['notification_id'];
          normalized['body'] ??= normalized['message'];
          normalized['type'] ??= normalized['notification_type'];
          normalized['user_id'] ??= normalized['target_user_id'];
          return normalized;
        }).toList();
      }
      throw ServerException(
        message: response.error ?? 'Failed to get notifications',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    try {
      final response = await SchoolDeskApi.instance.client.markNotificationRead(
        notificationId,
      );
      if (response.success != true) {
        throw ServerException(
          message: response.error ?? 'Failed to mark notification as read',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> registerNotificationDeviceToken({
    required String token,
    required String platform,
    String deviceId = '',
    String appVersion = '',
  }) async {
    try {
      final response = await _dio.post(
        '/notifications/device-tokens',
        data: {
          'token': token,
          'platform': platform,
          if (deviceId.trim().isNotEmpty) 'device_id': deviceId.trim(),
          if (appVersion.trim().isNotEmpty) 'app_version': appVersion.trim(),
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to register notification device',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> revokeNotificationDeviceToken({required String token}) async {
    try {
      final response = await _dio.delete(
        '/notifications/device-tokens',
        data: {'token': token},
      );
      final data = _asMap(response.data);
      if (data['success'] != true) {
        throw ServerException(
          message: data['error'] ?? 'Failed to revoke notification device',
        );
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getFeeStructures({
    String? academicYearId,
    String? gradeId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }
      if (gradeId != null) {
        queryParams['grade_id'] = gradeId;
      }
      final response = await _dio.get(
        '/fees/structures',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get fee structures',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getInvoices({
    String? studentId,
    String? status,
    int page = 1,
    int pageSize = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
      };
      if (studentId != null) queryParams['student_id'] = studentId;
      if (status != null) queryParams['status'] = status;
      final response = await _dio.get(
        '/fees/invoices',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(message: data['error'] ?? 'Failed to get invoices');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getTimetableSlots({
    String? sectionId,
    String? academicYearId,
    int? dayOfWeek,
    String? staffId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (sectionId != null) {
        queryParams['section_id'] = sectionId;
      }
      if (academicYearId != null) {
        queryParams['academic_year_id'] = academicYearId;
      }
      if (dayOfWeek != null) {
        queryParams['day_of_week'] = dayOfWeek;
      }
      if (staffId != null) {
        queryParams['staff_id'] = staffId;
      }
      final response = await _dio.get(
        '/timetable/slots',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get timetable slots',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<TimetableSuggestionResult> suggestTimetableSlots({
    required String sectionId,
    required String academicYearId,
    required String termId,
    required int dayOfWeek,
    int periodCount = 7,
    String startTime = '09:00',
    int periodDurationMinutes = 40,
    int gapMinutes = 5,
  }) async {
    try {
      final response = await _dio.post(
        '/timetable/suggestions',
        data: {
          'section_id': sectionId,
          'academic_year_id': academicYearId,
          'term_id': termId,
          'day_of_week': dayOfWeek,
          'period_count': periodCount,
          'start_time': startTime,
          'period_duration_minutes': periodDurationMinutes,
          'gap_minutes': gapMinutes,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return TimetableSuggestionResult.fromJson(_asMap(data['data']));
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to generate timetable suggestions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<TimetableGenerationResult> generateTimetableSlots({
    required String sectionId,
    required String academicYearId,
    required String termId,
    required int dayOfWeek,
    int periodCount = 7,
    String startTime = '09:00',
    int periodDurationMinutes = 40,
    int gapMinutes = 5,
  }) async {
    try {
      final response = await _dio.post(
        '/timetable/slots/generate',
        data: {
          'section_id': sectionId,
          'academic_year_id': academicYearId,
          'term_id': termId,
          'day_of_week': dayOfWeek,
          'period_count': periodCount,
          'start_time': startTime,
          'period_duration_minutes': periodDurationMinutes,
          'gap_minutes': gapMinutes,
        },
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return TimetableGenerationResult.fromJson(_asMap(data['data']));
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to apply timetable suggestions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getSubstitutions({
    String? date,
    String? originalStaffId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null) {
        queryParams['date'] = date;
      }
      if (originalStaffId != null) {
        queryParams['original_staff_id'] = originalStaffId;
      }
      final response = await _dio.get(
        '/timetable/substitutions',
        queryParameters: queryParams,
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to get substitutions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Homework ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHomework({
    String? studentId,
    String? sectionId,
    String? teacherId,
    String? status,
  }) async {
    final queryParams = <String, dynamic>{};
    if (studentId != null && studentId.trim().isNotEmpty) {
      queryParams['student_id'] = studentId.trim();
    }
    if (sectionId != null && sectionId.trim().isNotEmpty) {
      queryParams['section_id'] = sectionId.trim();
    }
    if (teacherId != null && teacherId.trim().isNotEmpty) {
      queryParams['staff_id'] = teacherId.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      queryParams['status'] = status.trim();
    }
    try {
      final response = await SchoolDeskApi.instance.client.homework(
        queryParams.isEmpty ? null : queryParams,
      );
      if (response.success == true) {
        return _asListMap(response.data);
      }
      throw ServerException(message: 'Failed to load homework');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createHomework({
    required String title,
    required String subject,
    required String className,
    required String sectionId,
    required String teacherId,
    required String description,
    required String dueDate,
    String studentId = '',
    String status = 'pending',
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.createHomework(
        HomeworkDto(
          title: title,
          subjectId: subject,
          classId: className,
          sectionId: sectionId,
          staffId: teacherId,
          studentId: studentId,
          description: description,
          submissionDate: dueDate,
          status: status,
        ),
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to create homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateHomework(
    String id, {
    required String title,
    required String subject,
    required String className,
    required String sectionId,
    required String teacherId,
    required String description,
    required String dueDate,
    String studentId = '',
    String status = 'pending',
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.updateHomework(
        id,
        HomeworkDto(
          title: title,
          subjectId: subject,
          classId: className,
          sectionId: sectionId,
          staffId: teacherId,
          studentId: studentId,
          description: description,
          submissionDate: dueDate,
          status: status,
        ),
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to update homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteHomework(String id) async {
    try {
      final response = await SchoolDeskApi.instance.client.deleteHomework(id);
      if (response.success == true) return;
      throw ServerException(
        message: response.error ?? 'Failed to delete homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getHomeworkSubmissions(
    String homeworkId, {
    String? studentId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (studentId != null && studentId.trim().isNotEmpty) {
      queryParams['student_id'] = studentId.trim();
    }
    try {
      final response = await SchoolDeskApi.instance.client.homeworkSubmissions(
        homeworkId,
        queryParams.isEmpty ? null : queryParams,
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to load homework submissions',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> submitHomework(
    String homeworkId, {
    required String studentId,
    required String answerText,
    String attachmentUrl = '',
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client
          .submitHomework(homeworkId, {
            'student_id': studentId,
            'answer_text': answerText,
            'attachment_url': attachmentUrl,
          });
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to submit homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> reviewHomeworkSubmission(
    String homeworkId,
    String submissionId, {
    required String status,
    String grade = '',
    String remarks = '',
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client
          .reviewHomeworkSubmission(homeworkId, submissionId, {
            'status': status,
            'grade': grade,
            'remarks': remarks,
          });
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to review homework',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ─── Report Exports ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createReportExport(
    String path, {
    required String reportTitle,
    required String format,
    String reportType = '',
    String scope = '',
    Map<String, dynamic> parameters = const {},
  }) {
    final payload = <String, dynamic>{
      'report_title': reportTitle,
      'report': reportTitle,
      'format': format.toLowerCase(),
      if (reportType.trim().isNotEmpty) 'report_type': reportType.trim(),
      if (scope.trim().isNotEmpty) 'scope': scope.trim(),
      if (parameters.isNotEmpty) 'parameters': parameters,
      ...parameters,
    };
    return createRaw(path, payload);
  }

  Future<List<Map<String, dynamic>>> getReportExports(
    String path, {
    String? status,
  }) {
    final queryParams = <String, dynamic>{};
    if (status != null && status.trim().isNotEmpty) {
      queryParams['status'] = status.trim();
    }
    return getRawList(
      path,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  // ─── Tables.md ERP Resource Helpers ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTablesMDRows(
    String resource, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await SchoolDeskApi.instance.client.listTablesMdRoot(
        _tablesMDPath(resource),
        queryParameters,
      );
      if (response.success == true) return _asListMap(response.data);
      throw ServerException(
        message: 'Failed to load ${_tablesMDPath(resource)}',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getTablesMDRow(
    String resource,
    String id,
  ) async {
    try {
      final response = await SchoolDeskApi.instance.client.getTablesMdRoot(
        _tablesMDPath(resource),
        id,
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to load $resource',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createTablesMDRow(
    String resource,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await SchoolDeskApi.instance.client.createTablesMdRoot(
        _tablesMDPath(resource),
        payload,
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to create $resource',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateTablesMDRow(
    String resource,
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await SchoolDeskApi.instance.client.updateTablesMdRoot(
        _tablesMDPath(resource),
        id,
        payload,
      );
      if (response.success == true) return _asMap(response.data);
      throw ServerException(
        message: response.error ?? 'Failed to update $resource',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteTablesMDRow(String resource, String id) async {
    try {
      final response = await SchoolDeskApi.instance.client.deleteTablesMdRoot(
        _tablesMDPath(resource),
        id,
      );
      if (response.success == true) return;
      throw ServerException(
        message: response.error ?? 'Failed to delete $resource',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _tablesMDPath(String resource) {
    switch (resource.trim()) {
      case 'approval_requests':
        return 'approval-requests';
      case 'principal_reports':
        return 'principal-reports';
      default:
        return resource.trim().replaceAll('_', '-');
    }
  }

  // ─── Raw CRUD Helpers ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRawList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final root = _tablesMDRootListPath(path);
      if (root != null) {
        final response = await SchoolDeskApi.instance.client.listTablesMdRoot(
          root,
          queryParameters,
        );
        if (response.success == true) return _asListMap(response.data);
        throw ServerException(message: 'Failed to load $path');
      }
      final response = await _dio.get(path, queryParameters: queryParameters);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asListMap(data['data']);
      }
      throw ServerException(message: data['error'] ?? 'Failed to load $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getRawMap(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return _asMap(data['data']);
      }
      throw ServerException(message: data['error'] ?? 'Failed to load $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createRaw(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final root = _tablesMDRootListPath(path);
      if (root != null) {
        final response = await SchoolDeskApi.instance.client.createTablesMdRoot(
          root,
          payload,
        );
        if (response.success == true) return _asMap(response.data);
        throw ServerException(
          message: response.error ?? 'Failed to create $path',
        );
      }
      final response = await _dio.post(path, data: payload);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(message: data['error'] ?? 'Failed to create $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> updateRaw(
    String path,
    Map<String, dynamic> payload,
  ) async {
    try {
      final item = _tablesMDRootItemPath(path);
      if (item != null) {
        final response = await SchoolDeskApi.instance.client.updateTablesMdRoot(
          item.root,
          item.id,
          payload,
        );
        if (response.success == true) return _asMap(response.data);
        throw ServerException(
          message: response.error ?? 'Failed to update $path',
        );
      }
      final response = await _dio.put(path, data: payload);
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(message: data['error'] ?? 'Failed to update $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> bookParentTeacherMeeting(
    String id, {
    String notes = 'Booked by parent',
  }) async {
    try {
      final response = await _dio.put(
        '/parent-teacher-meetings/$id/book',
        data: {'notes': notes},
      );
      final data = _asMap(response.data);
      if (data['success'] == true) {
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw ServerException(
        message: data['error'] ?? 'Failed to book PTM slot',
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteRaw(String path) async {
    try {
      final item = _tablesMDRootItemPath(path);
      if (item != null) {
        final response = await SchoolDeskApi.instance.client.deleteTablesMdRoot(
          item.root,
          item.id,
        );
        if (response.success == true) return;
        throw ServerException(
          message: response.error ?? 'Failed to delete $path',
        );
      }
      final response = await _dio.delete(path);
      final data = _asMap(response.data);
      if (data['success'] == true) return;
      throw ServerException(message: data['error'] ?? 'Failed to delete $path');
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  List<Map<String, dynamic>> _asListMap(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  String? _tablesMDRootListPath(String path) {
    final segments = _pathSegments(path);
    if (segments.length != 1) return null;
    return _tablesMDRoots.contains(segments.first) ? segments.first : null;
  }

  ({String root, String id})? _tablesMDRootItemPath(String path) {
    final segments = _pathSegments(path);
    if (segments.length != 2 || !_tablesMDRoots.contains(segments.first)) {
      return null;
    }
    return (root: segments.first, id: segments.last);
  }

  List<String> _pathSegments(String path) {
    return path
        .split('?')
        .first
        .split('/')
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
  }

  static const Set<String> _tablesMDRoots = {
    'classes',
    'attendance',
    'fees',
    'exams',
    'homework',
    'leaves',
    'notifications',
    'holidays',
    'events',
    'approval-requests',
    'communications',
    'principal-reports',
  };

  // ─── Error Handling ─────────────────────────────────────────────────────────

  Exception _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return const NetworkException(
        message: 'Unable to connect to server. Please check your connection.',
      );
    }
    if (e.response != null) {
      final statusCode = e.response!.statusCode ?? 0;
      final data = e.response!.data;
      final message =
          (data is Map<String, dynamic>
              ? (data['error'] as String? ?? data['message'] as String?)
              : null) ??
          'Server error occurred.';
      if (statusCode == 401) return AuthException(message: message);
      if (statusCode == 404) return NotFoundException(message: message);
      return ServerException(message: message, statusCode: statusCode);
    }
    return NetworkException(message: e.message ?? 'Network error occurred.');
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    return <String, dynamic>{};
  }
}

// ─── Auth Interceptor ─────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  final BackendApiClient _client;

  _AuthInterceptor(this._client);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_client._authToken != null) {
      options.headers['Authorization'] = 'Bearer ${_client._authToken}';
    }
    handler.next(options);
  }
}

// ─── Logging Interceptor ──────────────────────────────────────────────────────

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (EnvConfig.enableLogging) {
      developer.log(
        '[API] ${options.method} ${options.path}',
        name: 'BackendApiClient',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (EnvConfig.enableLogging) {
      developer.log(
        '[API] ${response.statusCode} ${response.requestOptions.path}',
        name: 'BackendApiClient',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (EnvConfig.enableLogging) {
      developer.log(
        '[API ERROR] ${err.response?.statusCode} ${err.message}',
        name: 'BackendApiClient',
      );
    }
    handler.next(err);
  }
}

// ─── Error Interceptor ────────────────────────────────────────────────────────

class _ErrorInterceptor extends Interceptor {
  final BackendApiClient _client;

  _ErrorInterceptor(this._client);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode ?? 0;
    final requestPath = err.requestOptions.path;
    final alreadyRetriedAfterRefresh =
        err.requestOptions.extra['retriedAfterRefresh'] == true;
    final isAuthRoute =
        requestPath.contains('/auth/login') ||
        requestPath.contains('/auth/refresh') ||
        requestPath.contains('/auth/logout') ||
        requestPath.contains('/auth/password');

    if (statusCode == 401 && !isAuthRoute) {
      if (alreadyRetriedAfterRefresh) {
        TokenStorageService.clear().then((_) {
          _client.clearAuthToken();
          handler.next(err);
        });
        return;
      }

      _client
          .refreshSession()
          .then((ok) async {
            if (!ok) {
              await TokenStorageService.clear();
              _client.clearAuthToken();
              handler.next(err);
              return;
            }
            try {
              final cloned = await _retry(
                err.requestOptions,
                _client._authToken!,
              );
              handler.resolve(cloned);
            } on DioException catch (retryErr) {
              if (retryErr.response?.statusCode == 401) {
                await TokenStorageService.clear();
                _client.clearAuthToken();
              }
              handler.next(retryErr);
            }
          })
          .catchError((_) {
            handler.next(err);
          });
      return;
    }
    handler.next(err);
  }

  Future<Response<dynamic>> _retry(
    RequestOptions requestOptions,
    String token,
  ) {
    final options = Options(
      method: requestOptions.method,
      headers: Map<String, dynamic>.from(requestOptions.headers)
        ..['Authorization'] = 'Bearer $token',
      responseType: requestOptions.responseType,
      contentType: requestOptions.contentType,
      validateStatus: requestOptions.validateStatus,
      receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      followRedirects: requestOptions.followRedirects,
      extra: {...requestOptions.extra, 'retriedAfterRefresh': true},
    );
    return _client.dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      options: options,
    );
  }
}

// ─── Request/Response Models ──────────────────────────────────────────────────

class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() {
    final identity = username.trim();
    final fallbackEmail = _fallbackEmail(identity);
    return {
      'username': identity,
      if (fallbackEmail.isNotEmpty) 'email': fallbackEmail,
      'password': password,
    };
  }

  static String _fallbackEmail(String value) {
    final identity = value.trim();
    final lower = identity.toLowerCase();
    if (lower == 'princ' || lower == 'principal') {
      return 'principal@schooldesk.local';
    }
    if (lower == 'principal@schooldesk.com') {
      return 'principal@schooldesk.local';
    }
    if (_looksLikeEmail(identity)) {
      return identity;
    }
    return '';
  }

  static bool _looksLikeEmail(String value) {
    return value.contains('@') && value.contains('.');
  }
}

class LoginResponse {
  final String token;
  final String refreshToken;
  final int expiresAt;
  final UserResponse user;

  const LoginResponse({
    required this.token,
    required this.refreshToken,
    required this.expiresAt,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
    token: json['token'] as String,
    refreshToken: json['refresh_token'] as String? ?? '',
    expiresAt: json['expires_at'] as int,
    user: UserResponse.fromJson(json['user'] as Map<String, dynamic>),
  );
}

class UserResponse {
  final String id;
  final String username;
  final String name;
  final String email;
  final String phone;
  final String avatar;
  final String schoolId;
  final String roleId;
  final String roleName;
  final String linkedType;
  final String linkedId;
  final bool isActive;
  final bool isVerified;

  const UserResponse({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatar,
    required this.schoolId,
    required this.roleId,
    required this.roleName,
    required this.linkedType,
    required this.linkedId,
    required this.isActive,
    required this.isVerified,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) => UserResponse(
    id: json['id'] as String,
    username: json['username'] as String? ?? '',
    name: json['name'] as String? ?? '',
    email: json['email'] as String,
    phone: json['phone'] as String? ?? '',
    avatar: json['avatar'] as String? ?? '',
    schoolId: json['school_id'] as String,
    roleId: json['role_id'] as String,
    roleName: json['role_name'] as String,
    linkedType: json['linked_type'] as String? ?? '',
    linkedId: json['linked_id'] as String? ?? '',
    isActive: json['is_active'] as bool? ?? true,
    isVerified: json['is_verified'] as bool? ?? false,
  );
}

class UserAccountModel {
  final String id;
  final String name;
  final String username;
  final String email;
  final String phone;
  final String avatar;
  final String schoolId;
  final String roleId;
  final String roleName;
  final String linkedType;
  final String linkedId;
  final bool isActive;
  final bool isVerified;
  final DateTime? lastLogin;
  final DateTime? createdAt;

  const UserAccountModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.avatar,
    required this.schoolId,
    required this.roleId,
    required this.roleName,
    required this.linkedType,
    required this.linkedId,
    required this.isActive,
    required this.isVerified,
    this.lastLogin,
    this.createdAt,
  });

  factory UserAccountModel.fromJson(Map<String, dynamic> json) =>
      UserAccountModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '',
        schoolId: json['school_id'] as String? ?? '',
        roleId: json['role_id'] as String? ?? '',
        roleName: json['role_name'] as String? ?? '',
        linkedType: json['linked_type'] as String? ?? '',
        linkedId: json['linked_id'] == null ? '' : json['linked_id'].toString(),
        isActive: json['is_active'] as bool? ?? true,
        isVerified: json['is_verified'] as bool? ?? false,
        lastLogin: json['last_login'] == null
            ? null
            : DateTime.tryParse(json['last_login'].toString()),
        createdAt: json['created_at'] == null
            ? null
            : DateTime.tryParse(json['created_at'].toString()),
      );
}

class PaginatedList<T> {
  final List<T> data;
  final int total;
  final int page;
  final int pageSize;

  const PaginatedList({
    required this.data,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  bool get hasMore => page * pageSize < total;
}

// ─── School Models ─────────────────────────────────────────────────────────────

class SchoolModel {
  final String id;
  final String name;
  final String schoolType;
  final String? affiliationBoard;
  final String? email;
  final String? phone;
  final String? city;
  final String? state;

  const SchoolModel({
    required this.id,
    required this.name,
    required this.schoolType,
    this.affiliationBoard,
    this.email,
    this.phone,
    this.city,
    this.state,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) => SchoolModel(
    id: json['id'] as String,
    name: json['name'] as String,
    schoolType: json['school_type'] as String,
    affiliationBoard: json['affiliation_board'] as String?,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    city: json['city'] as String?,
    state: json['state'] as String?,
  );
}

class AcademicYearModel {
  final String id;
  final String schoolId;
  final String yearLabel;
  final String startDate;
  final String endDate;
  final bool isCurrent;
  final String status;

  const AcademicYearModel({
    required this.id,
    required this.schoolId,
    required this.yearLabel,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.status,
  });

  factory AcademicYearModel.fromJson(Map<String, dynamic> json) =>
      AcademicYearModel(
        id: json['id'] as String,
        schoolId: json['school_id'] as String,
        yearLabel: json['year_label'] as String,
        startDate: json['start_date'] as String,
        endDate: json['end_date'] as String,
        isCurrent: json['is_current'] as bool? ?? false,
        status: json['status'] as String? ?? 'upcoming',
      );
}

class GradeModel {
  final String id;
  final String schoolId;
  final int gradeNumber;
  final String gradeName;

  const GradeModel({
    required this.id,
    required this.schoolId,
    required this.gradeNumber,
    required this.gradeName,
  });

  factory GradeModel.fromJson(Map<String, dynamic> json) => GradeModel(
    id: json['id'] as String,
    schoolId: json['school_id'] as String,
    gradeNumber: json['grade_number'] as int,
    gradeName: json['grade_name'] as String,
  );
}

class SectionModel {
  final String id;
  final String gradeId;
  final String gradeName;
  final String academicYearId;
  final String sectionName;
  final String classTeacherId;
  final String classTeacherName;
  final int capacity;

  const SectionModel({
    required this.id,
    required this.gradeId,
    required this.gradeName,
    required this.academicYearId,
    required this.sectionName,
    required this.classTeacherId,
    required this.classTeacherName,
    required this.capacity,
  });

  factory SectionModel.fromJson(Map<String, dynamic> json) => SectionModel(
    id: _stringValue(json['id']),
    gradeId: _stringValue(json['grade_id']),
    gradeName: _gradeName(json['grade']),
    academicYearId: _stringValue(json['academic_year_id']),
    sectionName: _stringValue(json['section_name']),
    classTeacherId: _stringValue(json['class_teacher_id']),
    classTeacherName: _staffName(json['class_teacher']),
    capacity: (json['capacity'] as num?)?.toInt() ?? 0,
  );

  static String _stringValue(Object? value) => value?.toString() ?? '';

  static String _gradeName(Object? value) {
    if (value is! Map) return '';
    return _stringValue(value['grade_name'] ?? value['name'] ?? value['id']);
  }

  static String _staffName(Object? value) {
    if (value is! Map) return '';
    final direct = _stringValue(value['name']).trim();
    if (direct.isNotEmpty) return direct;
    final first = _stringValue(value['first_name']).trim();
    final last = _stringValue(value['last_name']).trim();
    final fullName = '$first $last'.trim();
    if (fullName.isNotEmpty) return fullName;
    return _stringValue(value['email'] ?? value['id']);
  }
}

// ─── Staff Models ─────────────────────────────────────────────────────────────

class StaffModel {
  final String id;
  final String schoolId;
  final String staffCode;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? designation;
  final String? employmentType;
  final String? departmentId;
  final String? departmentName;
  final String status;
  final String? dateOfBirth;
  final String? gender;
  final String? joinDate;
  final String photoUrl;
  final List<Map<String, dynamic>> documents;
  final int documentCount;

  const StaffModel({
    required this.id,
    required this.schoolId,
    required this.staffCode,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.designation,
    this.employmentType,
    this.departmentId,
    this.departmentName,
    required this.status,
    this.dateOfBirth,
    this.gender,
    this.joinDate,
    required this.photoUrl,
    this.documents = const [],
    this.documentCount = 0,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    final documents = _listMapValue(json['documents']);
    return StaffModel(
      id: json['id'] as String,
      schoolId: json['school_id'] as String,
      staffCode: json['staff_code'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      gender: json['gender'] as String?,
      designation: json['designation'] as String?,
      employmentType: json['employment_type'] as String?,
      departmentId: json['department_id'] as String?,
      departmentName:
          json['department_name'] as String? ??
          (json['department'] as Map<String, dynamic>?)?['department_name']
              as String?,
      joinDate: json['join_date'] as String?,
      status: json['status'] as String? ?? 'active',
      photoUrl: _photoUrlFromJson(json),
      documents: documents,
      documentCount: documents.length,
    );
  }

  static List<Map<String, dynamic>> _listMapValue(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static String _photoUrlFromJson(Map<String, dynamic> json) {
    final direct = (json['photo_url'] ?? json['photo'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final documents = json['documents'];
    if (documents is List) {
      for (final item in documents) {
        if (item is! Map) continue;
        final type = (item['doc_type'] ?? item['type'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        if (type != 'profile_photo' && type != 'staff_photo') continue;
        final url = (item['file_url'] ?? item['url'] ?? '').toString().trim();
        if (url.isNotEmpty) return url;
      }
    }
    return '';
  }
}

// ─── Student Models ───────────────────────────────────────────────────────────

class StudentModel {
  final String id;
  final String schoolId;
  final String studentCode;
  final String admissionNumber;
  final String firstName;
  final String lastName;
  final String? dateOfBirth;
  final String? admissionDate;
  final String? gender;
  final String? currentSectionId;
  final String status;
  final String photoUrl;
  final List<Map<String, dynamic>> guardians;
  final List<Map<String, dynamic>> documents;
  final List<Map<String, dynamic>> parentAccounts;
  final Map<String, dynamic> primaryGuardian;
  final Map<String, dynamic> medicalRecord;
  final Map<String, dynamic> currentSection;
  final Map<String, dynamic> attendanceSummary;
  final Map<String, dynamic> feeSummary;
  final Map<String, dynamic> performanceSummary;

  const StudentModel({
    required this.id,
    required this.schoolId,
    required this.studentCode,
    required this.admissionNumber,
    required this.firstName,
    required this.lastName,
    this.dateOfBirth,
    this.admissionDate,
    this.gender,
    this.currentSectionId,
    required this.status,
    required this.photoUrl,
    this.guardians = const [],
    this.documents = const [],
    this.parentAccounts = const [],
    this.primaryGuardian = const {},
    this.medicalRecord = const {},
    this.currentSection = const {},
    this.attendanceSummary = const {},
    this.feeSummary = const {},
    this.performanceSummary = const {},
  });

  String get fullName => '$firstName $lastName'.trim();
  double get attendancePercent => _doubleFromJson(
    attendanceSummary['percent'] ?? attendanceSummary['attendance_percent'],
  );
  String get attendanceStatusLabel =>
      (attendanceSummary['status_label'] ?? '').toString().trim();
  String get feeStatus => (feeSummary['status'] ?? 'clear').toString().trim();
  double get feeBalance => _doubleFromJson(feeSummary['balance']);
  int get pendingInvoices => _intFromJson(feeSummary['pending_invoices']);
  double get performanceScore =>
      _doubleFromJson(performanceSummary['average_percent']);
  String get performanceGrade =>
      (performanceSummary['grade'] ?? 'N/A').toString().trim();
  int get documentCount => documents.length;
  String get primaryGuardianName {
    final name = (primaryGuardian['full_name'] ?? primaryGuardian['name'] ?? '')
        .toString()
        .trim();
    if (name.isNotEmpty) return name;
    if (parentAccounts.isNotEmpty) {
      final parent = parentAccounts.first;
      final parentName = (parent['name'] ?? parent['username'] ?? '')
          .toString()
          .trim();
      if (parentName.isNotEmpty) return parentName;
    }
    return '';
  }

  String get primaryGuardianPhone {
    final phone = (primaryGuardian['phone'] ?? '').toString().trim();
    if (phone.isNotEmpty) return phone;
    if (parentAccounts.isNotEmpty) {
      return (parentAccounts.first['phone'] ?? '').toString().trim();
    }
    return '';
  }

  factory StudentModel.fromJson(Map<String, dynamic> json) => StudentModel(
    id: json['id'] as String,
    schoolId: json['school_id'] as String? ?? '',
    studentCode: json['student_code'] as String? ?? '',
    admissionNumber: json['admission_number'] as String? ?? '',
    firstName: json['first_name'] as String? ?? '',
    lastName: json['last_name'] as String? ?? '',
    dateOfBirth: json['date_of_birth'] as String?,
    admissionDate: json['admission_date'] as String?,
    gender: json['gender'] as String?,
    currentSectionId: json['current_section_id'] as String?,
    status: json['status'] as String? ?? 'active',
    photoUrl: _photoUrlFromJson(json),
    guardians: _asListMap(json['guardians']),
    documents: _asListMap(json['documents']),
    parentAccounts: _asListMap(json['parent_accounts']),
    primaryGuardian: _asMap(json['primary_guardian']),
    medicalRecord: _asMap(json['medical_record']),
    currentSection: _asMap(json['current_section']),
    attendanceSummary: _asMap(json['attendance_summary']),
    feeSummary: _asMap(json['fee_summary']),
    performanceSummary: _asMap(json['performance_summary']),
  );

  static List<Map<String, dynamic>> _asListMap(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static double _doubleFromJson(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}') ?? 0;
  }

  static int _intFromJson(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? 0;
  }

  static String _photoUrlFromJson(Map<String, dynamic> json) {
    final direct = (json['photo_url'] ?? json['photo'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;

    final documents = json['documents'];
    if (documents is List) {
      for (final item in documents) {
        if (item is! Map) continue;
        final type = (item['doc_type'] ?? item['type'] ?? '')
            .toString()
            .toLowerCase()
            .trim();
        if (type != 'profile_photo' && type != 'student_photo') continue;
        final url = (item['file_url'] ?? item['url'] ?? '').toString().trim();
        if (url.isNotEmpty) return url;
      }
    }
    return '';
  }
}

// ─── Attendance Models ────────────────────────────────────────────────────────

class AttendanceSessionModel {
  final String id;
  final String sectionId;
  final String timetableSlotId;
  final String subjectId;
  final String staffId;
  final String date;
  final int periodNumber;
  final int totalStudents;
  final int presentCount;

  const AttendanceSessionModel({
    required this.id,
    required this.sectionId,
    required this.timetableSlotId,
    required this.subjectId,
    required this.staffId,
    required this.date,
    required this.periodNumber,
    required this.totalStudents,
    required this.presentCount,
  });

  factory AttendanceSessionModel.fromJson(Map<String, dynamic> json) =>
      AttendanceSessionModel(
        id: json['id'] as String,
        sectionId: json['section_id'] as String,
        timetableSlotId: json['timetable_slot_id'] as String? ?? '',
        subjectId: json['subject_id'] as String,
        staffId: json['staff_id'] as String,
        date: json['date'] as String,
        periodNumber: json['period_number'] as int? ?? 0,
        totalStudents: json['total_students'] as int? ?? 0,
        presentCount: json['present_count'] as int? ?? 0,
      );
}

class StaffQrTokenModel {
  final String token;
  final String schoolDate;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final DateTime? serverTime;
  final int refreshAfterSeconds;

  const StaffQrTokenModel({
    required this.token,
    required this.schoolDate,
    required this.issuedAt,
    required this.expiresAt,
    required this.serverTime,
    required this.refreshAfterSeconds,
  });

  bool get isExpired =>
      expiresAt != null && !DateTime.now().toUtc().isBefore(expiresAt!);

  int get secondsRemaining {
    final expiry = expiresAt;
    if (expiry == null) return refreshAfterSeconds;
    final remaining = expiry.difference(DateTime.now().toUtc()).inSeconds;
    return remaining < 0 ? 0 : remaining;
  }

  factory StaffQrTokenModel.fromJson(Map<String, dynamic> json) =>
      StaffQrTokenModel(
        token: '${json['token'] ?? ''}',
        schoolDate: '${json['school_date'] ?? ''}',
        issuedAt: _parseDateTime(json['issued_at']),
        expiresAt: _parseDateTime(json['expires_at']),
        serverTime: _parseDateTime(json['server_time']),
        refreshAfterSeconds: _intValue(json['refresh_after_seconds'], 60),
      );

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toUtc();
  }

  static int _intValue(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}') ?? fallback;
  }
}

class StaffAttendanceModel {
  final String id;
  final String staffId;
  final DateTime? date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String status;
  final String source;
  final String biometricId;
  final String markedBy;
  final StaffModel? staff;

  const StaffAttendanceModel({
    required this.id,
    required this.staffId,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    required this.source,
    required this.biometricId,
    required this.markedBy,
    required this.staff,
  });

  bool get checkedIn => checkIn != null;

  String get staffName {
    final name = staff?.fullName.trim() ?? '';
    if (name.isNotEmpty) return name;
    return staffId;
  }

  String get checkInTimeLabel => _clockLabel(checkIn);

  String get checkOutTimeLabel => _clockLabel(checkOut);

  factory StaffAttendanceModel.fromJson(Map<String, dynamic> json) {
    final staffJson = json['staff'];
    return StaffAttendanceModel(
      id: '${json['id'] ?? ''}',
      staffId: '${json['staff_id'] ?? ''}',
      date: _parseDateTime(json['date']),
      checkIn: _parseDateTime(json['check_in']),
      checkOut: _parseDateTime(json['check_out']),
      status: '${json['status'] ?? ''}',
      source: '${json['source'] ?? 'manual'}',
      biometricId: '${json['biometric_id'] ?? ''}',
      markedBy: '${json['marked_by'] ?? ''}',
      staff: staffJson is Map
          ? StaffModel.fromJson(Map<String, dynamic>.from(staffJson))
          : null,
    );
  }

  static DateTime? _parseDateTime(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static String _clockLabel(DateTime? value) {
    if (value == null) return '--:--';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class TimetableSuggestionModel {
  final String sectionId;
  final String academicYearId;
  final String termId;
  final int dayOfWeek;
  final int periodNumber;
  final String subjectId;
  final String subjectName;
  final String staffId;
  final String staffName;
  final String startTime;
  final String endTime;
  final int confidence;
  final List<String> warnings;
  final bool blocking;

  const TimetableSuggestionModel({
    required this.sectionId,
    required this.academicYearId,
    required this.termId,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.subjectId,
    required this.subjectName,
    required this.staffId,
    required this.staffName,
    required this.startTime,
    required this.endTime,
    required this.confidence,
    required this.warnings,
    required this.blocking,
  });

  factory TimetableSuggestionModel.fromJson(Map<String, dynamic> json) {
    final warnings = json['warnings'] is List
        ? (json['warnings'] as List).map((value) => '$value').toList()
        : <String>[];
    return TimetableSuggestionModel(
      sectionId: '${json['section_id'] ?? ''}',
      academicYearId: '${json['academic_year_id'] ?? ''}',
      termId: '${json['term_id'] ?? ''}',
      dayOfWeek: _intFromJson(json['day_of_week']),
      periodNumber: _intFromJson(json['period_number']),
      subjectId: '${json['subject_id'] ?? ''}',
      subjectName: '${json['subject_name'] ?? json['subject_id'] ?? ''}',
      staffId: '${json['staff_id'] ?? ''}',
      staffName: '${json['staff_name'] ?? json['staff_id'] ?? ''}',
      startTime: '${json['start_time'] ?? ''}',
      endTime: '${json['end_time'] ?? ''}',
      confidence: _intFromJson(json['confidence']),
      warnings: warnings,
      blocking: json['blocking'] == true,
    );
  }

  Map<String, dynamic> toSlotPayload() => {
    'section_id': sectionId,
    'academic_year_id': academicYearId,
    'term_id': termId,
    'day_of_week': dayOfWeek,
    'period_number': periodNumber,
    'subject_id': subjectId,
    'staff_id': staffId,
    'start_time': startTime,
    'end_time': endTime,
  };

  static int _intFromJson(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

class TimetableSuggestionResult {
  final String sectionId;
  final String academicYearId;
  final String termId;
  final int dayOfWeek;
  final List<TimetableSuggestionModel> suggestions;
  final int requestedPeriods;
  final int suggestedPeriods;
  final int creatablePeriods;
  final int blockedPeriods;

  const TimetableSuggestionResult({
    required this.sectionId,
    required this.academicYearId,
    required this.termId,
    required this.dayOfWeek,
    required this.suggestions,
    required this.requestedPeriods,
    required this.suggestedPeriods,
    required this.creatablePeriods,
    required this.blockedPeriods,
  });

  factory TimetableSuggestionResult.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : <String, dynamic>{};
    final suggestions = json['suggestions'] is List
        ? (json['suggestions'] as List)
              .whereType<Map>()
              .map(
                (row) => TimetableSuggestionModel.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList()
        : <TimetableSuggestionModel>[];
    return TimetableSuggestionResult(
      sectionId: '${json['section_id'] ?? ''}',
      academicYearId: '${json['academic_year_id'] ?? ''}',
      termId: '${json['term_id'] ?? ''}',
      dayOfWeek: TimetableSuggestionModel._intFromJson(json['day_of_week']),
      suggestions: suggestions,
      requestedPeriods: TimetableSuggestionModel._intFromJson(
        summary['requested_periods'],
      ),
      suggestedPeriods: TimetableSuggestionModel._intFromJson(
        summary['suggested_periods'],
      ),
      creatablePeriods: TimetableSuggestionModel._intFromJson(
        summary['creatable_periods'],
      ),
      blockedPeriods: TimetableSuggestionModel._intFromJson(
        summary['blocked_periods'],
      ),
    );
  }

  Map<String, dynamic> toSummaryPayload() => {
    'requested_periods': requestedPeriods,
    'suggested_periods': suggestedPeriods,
    'creatable_periods': creatablePeriods,
    'blocked_periods': blockedPeriods,
  };
}

class TimetableGenerationResult {
  final int created;
  final int skipped;
  final List<TimetableSuggestionModel> skippedSuggestions;

  const TimetableGenerationResult({
    required this.created,
    required this.skipped,
    required this.skippedSuggestions,
  });

  factory TimetableGenerationResult.fromJson(Map<String, dynamic> json) {
    final skippedSuggestions = json['skipped_suggestions'] is List
        ? (json['skipped_suggestions'] as List)
              .whereType<Map>()
              .map(
                (row) => TimetableSuggestionModel.fromJson(
                  Map<String, dynamic>.from(row),
                ),
              )
              .toList()
        : <TimetableSuggestionModel>[];
    return TimetableGenerationResult(
      created: TimetableSuggestionModel._intFromJson(json['created']),
      skipped: TimetableSuggestionModel._intFromJson(json['skipped']),
      skippedSuggestions: skippedSuggestions,
    );
  }
}

// ─── Exam Models ──────────────────────────────────────────────────────────────

class ExamModel {
  final String id;
  final String schoolId;
  final String academicYearId;
  final String termId;
  final String examTypeId;
  final String examName;
  final String startDate;
  final String endDate;
  final bool isPublished;

  const ExamModel({
    required this.id,
    required this.schoolId,
    required this.academicYearId,
    required this.termId,
    required this.examTypeId,
    required this.examName,
    required this.startDate,
    required this.endDate,
    required this.isPublished,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) => ExamModel(
    id: '${json['id'] ?? json['exam_id'] ?? ''}',
    schoolId: '${json['school_id'] ?? ''}',
    academicYearId: '${json['academic_year_id'] ?? ''}',
    termId: '${json['term_id'] ?? ''}',
    examTypeId: '${json['exam_type_id'] ?? json['exam_type'] ?? ''}',
    examName: '${json['exam_name'] ?? ''}',
    startDate: '${json['start_date'] ?? json['exam_date'] ?? ''}',
    endDate: '${json['end_date'] ?? json['exam_date'] ?? ''}',
    isPublished:
        json['is_published'] as bool? ??
        '${json['status'] ?? ''}'.toLowerCase() == 'published',
  );
}

// ─── Fee Models ───────────────────────────────────────────────────────────────

class FeeInvoiceModel {
  final String id;
  final String studentId;
  final String invoiceNumber;
  final String invoiceDate;
  final String dueDate;
  final double totalAmount;
  final double discountAmount;
  final double netAmount;
  final double paidAmount;
  final double balance;
  final String status;

  const FeeInvoiceModel({
    required this.id,
    required this.studentId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.totalAmount,
    required this.discountAmount,
    required this.netAmount,
    required this.paidAmount,
    required this.balance,
    required this.status,
  });

  factory FeeInvoiceModel.fromJson(Map<String, dynamic> json) =>
      FeeInvoiceModel(
        id: json['id'] as String,
        studentId: json['student_id'] as String,
        invoiceNumber: json['invoice_number'] as String,
        invoiceDate: json['invoice_date'] as String,
        dueDate: json['due_date'] as String,
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
        netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0,
        paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'pending',
      );
}

class PaymentRequest {
  final String invoiceId;
  final String receiptNumber;
  final double amountPaid;
  final String paymentDate;
  final String paymentMode;
  final String? transactionId;

  const PaymentRequest({
    required this.invoiceId,
    required this.receiptNumber,
    required this.amountPaid,
    required this.paymentDate,
    required this.paymentMode,
    this.transactionId,
  });

  Map<String, dynamic> toJson() => {
    'invoice_id': invoiceId,
    'receipt_number': receiptNumber,
    'amount_paid': amountPaid,
    'payment_date': paymentDate,
    'payment_mode': paymentMode,
    if (transactionId != null) 'transaction_id': transactionId,
  };

  Map<String, dynamic> toParentPaymentRequestJson() => {
    'invoice_id': invoiceId,
    'request_reference': receiptNumber,
    'amount': amountPaid,
    'payment_date': paymentDate,
    'payment_mode': paymentMode,
    if (transactionId != null) 'transaction_id': transactionId,
  };
}

// ─── Leave Models ─────────────────────────────────────────────────────────────

class LeaveApplicationModel {
  final String id;
  final String staffId;
  final String leaveTypeId;
  final String fromDate;
  final String toDate;
  final bool halfDay;
  final double totalDays;
  final String? reason;
  final String status;
  final String? rejectionReason;

  const LeaveApplicationModel({
    required this.id,
    required this.staffId,
    required this.leaveTypeId,
    required this.fromDate,
    required this.toDate,
    required this.halfDay,
    required this.totalDays,
    this.reason,
    required this.status,
    this.rejectionReason,
  });

  factory LeaveApplicationModel.fromJson(Map<String, dynamic> json) =>
      LeaveApplicationModel(
        id: json['id'] as String,
        staffId: json['staff_id'] as String,
        leaveTypeId: json['leave_type_id'] as String,
        fromDate: json['from_date'] as String,
        toDate: json['to_date'] as String,
        halfDay: json['half_day'] as bool? ?? false,
        totalDays: (json['total_days'] as num?)?.toDouble() ?? 0,
        reason: json['reason'] as String?,
        status: json['status'] as String? ?? 'pending',
        rejectionReason: json['rejection_reason'] as String?,
      );
}

class LeaveApplicationRequest {
  final String staffId;
  final String leaveTypeId;
  final String fromDate;
  final String toDate;
  final bool halfDay;
  final String? reason;

  const LeaveApplicationRequest({
    required this.staffId,
    required this.leaveTypeId,
    required this.fromDate,
    required this.toDate,
    this.halfDay = false,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
    'staff_id': staffId,
    'leave_type_id': leaveTypeId,
    'from_date': fromDate,
    'to_date': toDate,
    'half_day': halfDay,
    if (reason != null) 'reason': reason,
  };
}

// ─── Announcement Models ──────────────────────────────────────────────────────

class AnnouncementModel {
  final String id;
  final String schoolId;
  final String title;
  final String content;
  final String targetAudience;
  final bool isUrgent;
  final String createdBy;
  final String publishedAt;
  final String? attachmentUrl;

  const AnnouncementModel({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.content,
    required this.targetAudience,
    required this.isUrgent,
    required this.createdBy,
    required this.publishedAt,
    this.attachmentUrl,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      AnnouncementModel(
        id: json['id'] as String,
        schoolId: json['school_id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        targetAudience: json['target_audience'] as String? ?? 'all',
        isUrgent: json['is_urgent'] as bool? ?? false,
        createdBy: json['created_by'] as String,
        publishedAt: json['published_at'] as String,
        attachmentUrl: json['attachment_url'] as String?,
      );
}
