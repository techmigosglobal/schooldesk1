import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import 'schooldesk_api_models.dart';

part 'schooldesk_api_client.g.dart';

@RestApi()
abstract class SchoolDeskApiClient {
  factory SchoolDeskApiClient(Dio dio, {String baseUrl}) = _SchoolDeskApiClient;

  @POST('/auth/login')
  Future<ApiEnvelope> login(@Body() LoginRequestDto request);

  @POST('/auth/refresh')
  Future<ApiEnvelope> refresh(@Body() Map<String, dynamic> payload);

  @POST('/auth/logout')
  Future<ApiEnvelope> logout(@Body() Map<String, dynamic> payload);

  @GET('/auth/profile')
  Future<ApiEnvelope> profile();

  @PATCH('/auth/profile')
  Future<ApiEnvelope> updateProfile(@Body() Map<String, dynamic> payload);

  @GET('/dashboard/{role}')
  Future<ApiEnvelope> dashboard(@Path('role') String role);

  @GET('/{resource}')
  Future<PaginatedEnvelope> listTablesMdRoot(
    @Path('resource') String resource,
    @Queries() Map<String, dynamic>? query,
  );

  @GET('/{resource}/{id}')
  Future<ApiEnvelope> getTablesMdRoot(
    @Path('resource') String resource,
    @Path('id') String id,
  );

  @POST('/{resource}')
  Future<ApiEnvelope> createTablesMdRoot(
    @Path('resource') String resource,
    @Body() Map<String, dynamic> payload,
  );

  @PUT('/{resource}/{id}')
  Future<ApiEnvelope> updateTablesMdRoot(
    @Path('resource') String resource,
    @Path('id') String id,
    @Body() Map<String, dynamic> payload,
  );

  @DELETE('/{resource}/{id}')
  Future<ApiEnvelope> deleteTablesMdRoot(
    @Path('resource') String resource,
    @Path('id') String id,
  );

  @GET('/classes')
  Future<PaginatedEnvelope> classes(@Queries() Map<String, dynamic>? query);

  @POST('/classes')
  Future<ApiEnvelope> createClass(@Body() TablesMdClassDto payload);

  @PUT('/classes/{id}')
  Future<ApiEnvelope> updateClass(
    @Path('id') String id,
    @Body() TablesMdClassDto payload,
  );

  @DELETE('/classes/{id}')
  Future<ApiEnvelope> deleteClass(@Path('id') String id);

  @GET('/attendance')
  Future<PaginatedEnvelope> attendance(@Queries() Map<String, dynamic>? query);

  @GET('/attendance/sessions')
  Future<ApiEnvelope> attendanceSessions(
    @Queries() Map<String, dynamic>? query,
  );

  @POST('/attendance/sessions')
  Future<ApiEnvelope> createAttendanceSession(
    @Body() Map<String, dynamic> payload,
  );

  @POST('/attendance/sessions/{session_id}/mark')
  Future<ApiEnvelope> markAttendance(
    @Path('session_id') String sessionId,
    @Body() Map<String, dynamic> payload,
  );

  @GET('/fees')
  Future<PaginatedEnvelope> fees(@Queries() Map<String, dynamic>? query);

  @GET('/fees/invoices')
  Future<ApiEnvelope> feeInvoices(@Queries() Map<String, dynamic>? query);

  @POST('/fees/invoices')
  Future<ApiEnvelope> createFeeInvoice(@Body() Map<String, dynamic> payload);

  @POST('/fees/payments')
  Future<ApiEnvelope> recordPayment(@Body() Map<String, dynamic> payload);

  @GET('/fees/payment-requests')
  Future<ApiEnvelope> paymentRequests(@Queries() Map<String, dynamic>? query);

  @POST('/fees/payment-requests')
  Future<ApiEnvelope> createPaymentRequest(
    @Body() Map<String, dynamic> payload,
  );

  @GET('/exams')
  Future<ApiEnvelope> exams(@Queries() Map<String, dynamic>? query);

  @POST('/exams')
  Future<ApiEnvelope> createExam(@Body() ExamDto payload);

  @PUT('/exams/{id}')
  Future<ApiEnvelope> updateExam(
    @Path('id') String id,
    @Body() ExamDto payload,
  );

  @PATCH('/exams/{id}/publish')
  Future<ApiEnvelope> publishExam(
    @Path('id') String id,
    @Body() Map<String, dynamic> payload,
  );

  @GET('/exams/types')
  Future<ApiEnvelope> examTypes();

  @POST('/exams/schedules')
  Future<ApiEnvelope> createExamSchedule(@Body() ExamScheduleDto payload);

  @GET('/exams/schedules/{schedule_id}/marks')
  Future<ApiEnvelope> scheduleMarks(@Path('schedule_id') String scheduleId);

  @POST('/exams/schedules/{schedule_id}/marks')
  Future<ApiEnvelope> enterMarks(
    @Path('schedule_id') String scheduleId,
    @Body() Map<String, dynamic> payload,
  );

  @GET('/exams/report-cards')
  Future<ApiEnvelope> reportCards(@Queries() Map<String, dynamic>? query);

  @GET('/homework')
  Future<PaginatedEnvelope> homework(@Queries() Map<String, dynamic>? query);

  @POST('/homework')
  Future<ApiEnvelope> createHomework(@Body() HomeworkDto payload);

  @PUT('/homework/{id}')
  Future<ApiEnvelope> updateHomework(
    @Path('id') String id,
    @Body() HomeworkDto payload,
  );

  @DELETE('/homework/{id}')
  Future<ApiEnvelope> deleteHomework(@Path('id') String id);

  @GET('/homework/{id}/submissions')
  Future<ApiEnvelope> homeworkSubmissions(
    @Path('id') String id,
    @Queries() Map<String, dynamic>? query,
  );

  @POST('/homework/{id}/submissions')
  Future<ApiEnvelope> submitHomework(
    @Path('id') String id,
    @Body() Map<String, dynamic> payload,
  );

  @PUT('/homework/{id}/submissions/{submission_id}/review')
  Future<ApiEnvelope> reviewHomeworkSubmission(
    @Path('id') String id,
    @Path('submission_id') String submissionId,
    @Body() Map<String, dynamic> payload,
  );

  @GET('/leaves')
  Future<PaginatedEnvelope> leaves(@Queries() Map<String, dynamic>? query);

  @GET('/notifications')
  Future<ApiEnvelope> notifications();

  @POST('/notifications')
  Future<ApiEnvelope> createNotification(@Body() NotificationDto payload);

  @PUT('/notifications/{id}/read')
  Future<ApiEnvelope> markNotificationRead(@Path('id') String id);

  @POST('/notifications/device-tokens')
  Future<ApiEnvelope> registerDeviceToken(@Body() Map<String, dynamic> payload);

  @DELETE('/notifications/device-tokens')
  Future<ApiEnvelope> revokeDeviceToken(@Body() Map<String, dynamic> payload);

  @GET('/holidays')
  Future<PaginatedEnvelope> holidays(@Queries() Map<String, dynamic>? query);

  @GET('/events')
  Future<PaginatedEnvelope> events(@Queries() Map<String, dynamic>? query);

  @POST('/events')
  Future<ApiEnvelope> createEvent(@Body() EventDto payload);

  @PUT('/events/{id}')
  Future<ApiEnvelope> updateEvent(
    @Path('id') String id,
    @Body() EventDto payload,
  );

  @DELETE('/events/{id}')
  Future<ApiEnvelope> deleteEvent(@Path('id') String id);

  @GET('/approval-requests')
  Future<PaginatedEnvelope> approvalRequests(
    @Queries() Map<String, dynamic>? query,
  );

  @GET('/communications')
  Future<PaginatedEnvelope> communications(
    @Queries() Map<String, dynamic>? query,
  );

  @GET('/principal-reports')
  Future<PaginatedEnvelope> principalReports(
    @Queries() Map<String, dynamic>? query,
  );

  @GET('/students')
  Future<ApiEnvelope> students(@Queries() Map<String, dynamic>? query);

  @GET('/staff')
  Future<ApiEnvelope> staff(@Queries() Map<String, dynamic>? query);

  @GET('/grades')
  Future<ApiEnvelope> grades(@Queries() Map<String, dynamic>? query);

  @GET('/sections')
  Future<ApiEnvelope> sections(@Queries() Map<String, dynamic>? query);

  @GET('/subjects')
  Future<ApiEnvelope> subjects(@Queries() Map<String, dynamic>? query);

  @GET('/message-conversations')
  Future<ApiEnvelope> messageConversations(
    @Queries() Map<String, dynamic>? query,
  );

  @GET('/messages')
  Future<ApiEnvelope> messages(@Queries() Map<String, dynamic>? query);

  @POST('/messages')
  Future<ApiEnvelope> createMessage(@Body() MessageDto payload);
}
