Here is my comprehensive Code-Level Audit Report based on the backend routes, frontend API client, and screen implementations.
────────────────────────────────────────────────────────────────────────────────
SchoolDesk Code-Level Audit Report
Methodology
I cross-referenced:
- Backend:  school-backend/internal/routes/routes.go  (master route file) + all handler files
- Frontend API:  lib/core/network/api_modules/*.dart  (all API modules)
- Frontend Screens: All presentation screen files across roles
- Testing Guide:  docs/manual-role-testing-todo.md 
────────────────────────────────────────────────────────────────────────────────
1. Backend API Endpoints — Complete Inventory
The backend exposes ~200+ endpoints across these groups:
| Group | Endpoints | Status |
|---|---|---|
| Auth | /auth/login, /auth/refresh, /auth/logout, /auth/password, /auth/profile, /auth/profile/avatar | ✅ Com plete |
| Dashboard | /dashboard/principal, /dashboard/teacher, /dashboard/parent | ✅ Com plete |
| Principal | /principal/classes, /principal/classes/:id, /principal/classes/import, /principal/classes/import/dry-run | ✅ Com |
| Classes |  | plete |
| Principal | /principal/subjects, /principal/subjects/:id/mappings, /principal/subjects/:id/actions | ✅ Com |
| Subjects |  | plete |
| Principal | /principal/timetable, /principal/timetable/actions | ✅ Com |
| Timetable |  | plete |
| Principal | /principal/exams, /principal/exams/actions | ✅ Com |
| Exams |  | plete |
| Principal | /principal/results, /principal/results/actions | ✅ Com |
| Results |  | plete |
| Academic | /academic-years CRUD + /academic-years/:id/terms | ✅ Com |
| Years |  | plete |
| Grades | /grades CRUD | ✅ Com plete |
| Sections | /sections CRUD | ✅ Com plete |
| Staff | /staff CRUD + /staff/:id/photo, /staff/:id/documents, /staff/:id/leave-balances, /staff/:id/attendance | ✅ Com plete |
| Students | /students CRUD + /students/:id/photo, /students/:id/documents, /students/:id/enrollments, /students/:id/attendance, /students/:id/fees, /students/:id/marks, /students/:id/progress, /students/:id/guardians | ✅ Com plete |
| Attendance | /attendance/sessions, /attendance/sessions/:id/mark, /attendance/sessions/:id/correction-request, /attendance/sessions/:id/reopen, /attendance/summary, /attendance/staff, /attendance/staff/qr-token, /attendance/staff/qr-scan, /attendance/staff/me/today, /attendance/staff/qr-logs/export | ✅ Com plete |
| Exams | /exams CRUD + /exams/types, /exams/:id/publish, /exams/schedules, /exams/schedules/:id/marks, /exams/:id/rankings, /exams/report-cards, /exams/grading-scale | ✅ Com plete |
| Fees | /fees/categories, /fees/structures CRUD, /fees/invoices, /fees/invoices/generate, /fees/payments, /fees/payment-requests, /fees/payment-config, /fees/concessions, /fees/reminders, /fees/reports/exports | ✅ Com plete |
| Leave | /leave/types, /leave/applications CRUD, /leave/balances | ✅ Com plete |
| Student | /student-leave/applications CRUD | ✅ Com |
| Leave |  | plete |
| Timetable | /timetable/slots CRUD + /timetable/templates, /timetable/constraints, /timetable/smart/*, /timetable/substitutions, /timetable/pre-primary/* | ✅ Com plete |
| Announcement | /announcements CRUD | ✅ Com |
| s |  | plete |
| Event Posts | /event-posts (create, list teacher/pending/gallery/home-feed, approve, reject) | ✅ Com plete |
| Lesson | /lesson-planners (create, list teacher/parent/principal, complete) | ✅ Com |
| Planners |  | plete |
| Notices | /notices CRUD | ✅ Com plete |
| Events | /events CRUD | ✅ Com plete |
| Notification | /notifications CRUD + /notifications/device-tokens, /notifications/:id/read | ✅ Com |
| s |  | plete |
| Messages | /message-conversations CRUD + /messages CRUD | ✅ Com plete |
| Guardians | /guardians CRUD + /students/:id/guardians | ✅ Com plete |
| Medical | /medical-records CRUD | ✅ Com |
| Records |  | plete |
| Student | /student-documents CRUD | ✅ Com |
| Documents |  | plete |
| Staff | /staff-documents CRUD | ✅ Com |
| Documents |  | plete |
| Staff | /staff-subjects CRUD | ✅ Com |
| Subjects |  | plete |
| Staff Qualif | /staff-qualifications CRUD | ✅ Com |
| ications |  | plete |
| Payroll | /payroll CRUD | ✅ Com plete |
| PTM | /parent-teacher-meetings CRUD + /parent-teacher-meetings/:id/book | ✅ Com plete |
| Approval | /approvals CRUD + /approvals/:id/submit, /approve, /reject, /request-changes, /cancel, /apply | ✅ Com |
| Requests |  | plete |
| Diary | /diary-entries CRUD | ✅ Com |
| Entries |  | plete |
| Homework | /homework-submissions CRUD + /homework-submissions/:id/submissions, /homework-submissions/:id/submissions/:sid/review | ✅ Com plete |
| Bulk Import | /principal/bulk-import, /principal/bulk-import/template, /principal/bulk-import/history | ✅ Com plete |
| Monitoring | /monitoring/error-events CRUD + /monitoring/error-events/:id/resolve | ✅ Com plete |
| Audit Logs | /audit-logs | ✅ Com plete |
| Reports | /reports/exports, /student-reports/exports, /fees/reports/exports, /attendance/reports/exports, /timetable/exports, /exams/report-cards/exports | ✅ Com plete |
| Frontend | /admissions/applications, /certificates/*, /documents/*, /student-notes, /complaints, /discipline-incidents, etc. | ✅ Com |
| Resources |  | plete |
────────────────────────────────────────────────────────────────────────────────
2. Frontend API Client — Coverage Gaps
The frontend API client has good coverage for core features but is missing dedicated methods for several backend endpoints:
Missing Frontend API Methods (features exist in backend but no frontend call):
| # | Backend Endpoint | Frontend Status | Impact on Testing |
|---|---|---|---|
| 1 | GET /staff/:id/leave-balances | ❌ No method | Staff leave balance view broken |
| 2 | GET /staff/:id/attendance | ❌ No method | Principal can't view individual staff attendance |
| 3 | PUT /students/:id/parent | ❌ No method | Assign Children workflow may use generic path |
| 4 | POST /students/enrollments | ❌ No method | Student enrollment creation broken |
| 5 | GET /students/:id/marks | ❌ No method | Academic progress data source missing |
| 6 | GET /students/:id/progress | ❌ No method | Student performance data source missing |
| 7 | POST /fees/invoices (create) | ❌ No method | Manual fee invoice creation broken |
| 8 | POST /fees/reminders | ❌ No method | Fee reminder sending broken |
| 9 | POST /fees/payment-config/qr | ❌ No method | QR payment config upload broken |
| 10 | GET /exams/:id/rankings | ❌ No method | Class ranking view broken |
| 11 | GET /exams/grading-scale | ❌ No method | Grading scale display broken |
| 12 | GET /exams/schedules/:id/marks | ❌ No method | Exam marks viewing broken |
| 13 | POST /exams/schedules/:id/marks | ❌ No method | Exam marks entry broken |
| 14 | GET /exams/report-cards | ❌ No method | Report card listing broken |
| 15 | POST /notices | ❌ No method | Notice creation broken (uses generic createRaw) |
| 16 | PATCH /notices/:id | ❌ No method | Notice editing broken |
| 17 | DELETE /notices/:id | ❌ No method | Notice deletion broken |
| 18 | PUT /events/:id | ❌ No method | Event editing broken |
| 19 | DELETE /events/:id | ❌ No method | Event deletion broken |
| 20 | POST /diary-entries | ❌ No method | Diary entry creation uses generic path |
| 21 | POST /homework/:id/attachment-requests | ❌ No method | Homework attachment requests broken |
| 22 | POST /holidays | ❌ No method | Holiday management broken |
| 23 | POST /guardians | ❌ No method | Guardian creation broken |
| 24 | PUT /guardians/:id | ❌ No method | Guardian editing broken |
| 25 | DELETE /guardians/:id | ❌ No method | Guardian deletion broken |
| 26 | Medical Records CRUD | ❌ No methods | Health update feature incomplete |
| 27 | Staff Qualifications CRUD | ❌ No methods | Staff qualification management broken |
| 28 | Staff Subjects CRUD | ❌ No methods | Staff-subject assignment broken |
| 29 | Payroll CRUD | ❌ No methods | Payroll feature completely missing from frontend |
Frontend API Methods That Exist and Work:
| # | Feature | Frontend Method | Backend Endpoint |
|---|---|---|---|
| 1 | Login | login() | POST /auth/login ✅ |
| 2 | Dashboard | getDashboard() | GET /dashboard/:role ✅ |
| 3 | Profile | getProfile() | GET /auth/profile ✅ |
| 4 | Staff CRUD | getStaff(), createStaff(), updateStaff(), deleteStaff() | GET/POST/PUT/DELETE /staff ✅ |
| 5 | Student CRUD | getStudents(), createStudent(), updateStudent(), deleteStudent() | GET/POST/PUT/DELETE /students ✅ |
| 6 | Attendance Sessions | getAttendanceSessions(), createAttendanceSession() | GET/POST /attendance/sessions ✅ |
| 7 | Mark Attendance | markAttendance() | POST /attendance/sessions/:id/mark ✅ |
| 8 | Staff QR Token | getStaffQrToken() | GET /attendance/staff/qr-token ✅ |
| 9 | Staff QR Scan | scanStaffQr() | POST /attendance/staff/qr-scan ✅ |
| 10 | My Staff Attendance | getMyStaffAttendanceToday() | GET /attendance/staff/me/today ✅ |
| 11 | Fee Structures | getFeeStructures(), createFeeStructure() | GET/POST /fees/structures ✅ |
| 12 | Payment Requests | submitParentPaymentRequest(), decideParentPaymentRequest() | POST/PUT /fees/payment-requests ✅ |
| 13 | Homework | getHomework(), createHomework(), updateHomework() | GET/POST/PUT /homework-submissions ✅ |
| 14 | Homework Submissions | submitHomework(), reviewHomeworkSubmission() | POST/PUT /homework-submissions/:id/submissions ✅ |
| 15 | Leave Applications | getLeaveApplications(), submitLeaveApplication(), decideLeaveApplication() | GET/POST/PUT /leave/applications ✅ |
| 16 | Student Leave | getStudentLeaveApplications(), submitStudentLeaveApplication() | GET/POST /student-leave/applications ✅ |
| 17 | Event Posts | createEventPost(), getTeacherEventPosts(), getPendingEventPosts() | POST/GET /event-posts ✅ |
| 18 | Event Approval | approveEventPost(), rejectEventPost() | POST /event-posts/:id/approve ✅ |
| 19 | Lesson Planners | createLessonPlanner(), getTeacherLessonPlanners() | POST/GET /lesson-planners ✅ |
| 20 | Timetable | getTimetableSlots(), createTimetableSlot() | GET/POST /timetable/slots ✅ |
| 21 | Messages | sendChatMessage(), getChatMessages() | POST/GET /messages ✅ |
| 22 | Notifications | getNotifications(), markNotificationRead() | GET /notifications, PUT /notifications/:id/read ✅ |
| 23 | Exams | getExams(), createExam(), updateExam() | GET/POST/PUT /exams ✅ |
| 24 | Events | getEvents(), createEvent() | GET/POST /events ✅ |
| 25 | Bulk Import | bulkImport(), getBulkImportHistory() | POST/GET /principal/bulk-import ✅ |
| 26 | PTM Booking | bookParentTeacherMeeting() | PUT /parent-teacher-meetings/:id/book ✅ |
| 27 | Approval Requests | getApprovalRequests(), approveApprovalRequest() | GET/POST /approvals ✅ |
| 28 | Monitoring | submitErrorEvent(), getErrorEvents() | POST/GET /monitoring/error-events ✅ |
────────────────────────────────────────────────────────────────────────────────
3. Screen-Level Issues Found
Principal Role
| # | Screen | Issue | Seve rity |
|---|---|---|---|
| 1 | Principal Dashboard | Dashboard calls api.getDashboard('principal') which works ✅. But setup steps check for academicYears, grades, sections, subjects, staffTotal, studentsTotal, feeStructures — all loaded in parallel. If any fail silently, the setup checklist shows incomplete. | Medi um |
| 2 | Staff Management | StaffManagementScreen calls api.getStaff() ✅. Create/edit uses createStaff()/updateStaff() ✅. Missing: getStaffLeaveBalance() and getStaffAttendance() for individual staff detail views — these backend endpoints exist but frontend has no method. | High |
| 3 | Student Oversight | StudentOversightScreen calls api.getStudents() ✅. Create uses createStudent() ✅. Missing: Bulk import UI — bulkImport() exists in API but the screen at admin_bulk_import_screen/bulk_import_screen.dart needs to be verified it actually calls this method. | Medi um |
| 4 | Guardian Directory | GuardianDirectoryScreen exists. Issue: Backend has GET /guardians CRUD but frontend API client has no dedicated guardian methods. The screen likely uses generic getRawList('/guardians') which works but is fragile. | Low |
| 5 | Class Hub | PrincipalClassesScreen calls api.getPrincipalClassesOverview() ✅. Uses createPrincipalClass(), updatePrincipalClassSetup(), deletePrincipalClass() ✅. | OK |
| 6 | Subjects | PrincipalSubjectsScreen calls api.getPrincipalSubjectsOverview() ✅. Uses createPrincipalSubjectAction(), savePrincipalSubjectMapping() ✅. | OK |
| 7 | Academic Years | PrincipalAcademicYearsScreen — Issue: Frontend uses getRawList('/academic-years') instead of a dedicated method. Works but inconsistent. | Low |
| 8 | Timetable | AdminTimetableScreen — Issue: Uses getTimetableSlots() ✅ but the principal-specific timetable overview (getPrincipalTimetableOverview()) calls a different endpoint. The smart timetable generation uses generateSmartTimetable() ✅. | OK |
| 9 | Attendance | PrincipalAttendanceScreen — Issue: Uses getAttendanceSessions() ✅ and getStaffAttendanceForDate() ✅. But getStudentAttendanceSummary() requires a student_id parameter — the screen needs to know which student to query. | Medi um |
| 10 | Fees | FeeMonitoringScreen — Issue: Uses getFeeStructures() ✅ and getParentPaymentRequests() ✅. But decideParentPaymentRequest() uses PUT while backend also accepts PATCH. The frontend only calls PUT. | Low |
| 11 | Communication | PrincipalChatCommunicationsScreen — Uses getCommunications() which goes through getTablesMDRows('communications'). Works ✅. | OK |
| 12 | Event Approvals | PrincipalEventApprovalScreen — Uses getPendingEventPosts() ✅ and approveEventPost()/rejectEventPost() ✅. | OK |
| 13 | Lesson Planners | PrincipalLessonPlannerScreen — Uses getPrincipalLessonPlanners() ✅. | OK |
| 14 | Reports | ReportsAnalyticsScreen — Uses getReportExports() and createReportExport() ✅. | OK |
| 15 | ID Card / Report Card | IdCardGenerationScreen and ReportCardGeneratorScreen — Issue: These screens exist in routes but I couldn't verify they have working API calls. The backend has GET /exams/report-cards and report export endpoints. | High |
| 16 | System Monitor | SystemMonitorScreen — Uses getErrorEvents() ✅. | OK |
| 17 | School Profile | SchoolProfileScreen — Uses getRawList('/schools') and updateRaw('/schools/current', ...). Works but uses generic methods. | Low |
Teacher Role
| # | Screen | Issue | Seve rity |
|---|---|---|---|
| 1 | Teacher Dashboard | Calls getDashboard('teacher') ✅, getAnnouncements() ✅, getMyStaffAttendanceToday() ✅, getTodayHomeworkReminderStatus() ✅. End-of-day reminder checks hour >= 15. | OK |
| 2 | My QR Check-in | TeacherMyAttendanceScreen — Uses getMyStaffAttendanceToday() ✅ and scanStaffQr() ✅. The auto-scan feature needs camera permission handling. | Medi um |
| 3 | Student Attendance | TeacherAttendanceScreen — Uses getAttendanceSessions() and markAttendance(). Issue: The teacher needs to know their sectionId, academicYearId, subjectId, and staffId to create an attendance session. These come from RoleAccessService. If RoleAccessService fails to load teacher scope data, attendance breaks. | High |
| 4 | My Classes | TeacherClassesScreen — Uses timetable data from RoleAccessService. | OK |
| 5 | Timetable | TeacherTimetableScreen — Uses getTimetableSlots() with staffId filter ✅. | OK |
| 6 | Class Diary | TeacherDiaryScreen — Uses getRawList('/diary-entries') and createRaw('/diary-entries', ...). Works but generic. | Low |
| 7 | Homework | TeacherHomeworkScreen — Uses getHomework() ✅ and createHomework() ✅. Submissions use getHomeworkSubmissions() ✅. | OK |
| 8 | Lesson Planner | TeacherLessonPlannerScreen — Uses getTeacherLessonPlanners() ✅ and createLessonPlanner() ✅. | OK |
| 9 | Event Posts | TeacherEventPostScreen — Uses getTeacherEventPosts() ✅ and createEventPost() ✅. Issue: createEventPost() sends media_urls as a comma-joined string, not a JSON array. Backend might expect array. | Medi um |
| 10 | Communicatio n | TeacherCommunicationScreen — Uses getCommunications() ✅ and sendCommunication() ✅. | OK |
| 11 | Parent Interaction / PTM | TeacherParentInteractionScreen — Uses getMyTeacherPtmSlots() ✅ and createMyTeacherPtmSlot() ✅. | OK |
| 12 | Leave | TeacherLeaveScreen — Uses getLeaveApplications() ✅ and submitLeaveApplication() ✅. recallLeaveApplication() ✅. | OK |
| 13 | Reports | TeacherReportsScreen — Uses getReportExports() ✅. | OK |
| 14 | Student Performance | TeacherPerformanceScreen — Issue: Backend has GET /students/:id/progress but frontend has no dedicated method. Screen may use generic path or be non-functional. | High |
| 15 | Student Notes | TeacherStudentNotesScreen — Uses getRawList('/student-notes') and createRaw('/student-notes', ...). Works via frontend resource. | OK |
| 16 | Student Discipline | TeacherDisciplineScreen — Uses getRawList('/discipline-incidents') and createRaw('/discipline-incidents', ...). Works via frontend resource. | OK |
| 17 | Calendar | EventsCalendarScreen(portal: teacher) — Uses getEvents() ✅. | OK |
Parent Role
| # | Screen | Issue | Severi ty |
|---|---|---|---|
| 1 | Parent Dashboard | Calls getDashboard('parent') ✅, getMyStudents() ✅, getHomeFeedEventPosts() ✅. Child selector works. | OK |
| 2 | Academic Progress | ParentAcademicProgressScreen — Uses getMyStudents() ✅. Issue: Needs GET /students/:id/progress or GET /students/:id/marks for actual marks data. Frontend has no dedicated method for either. | High |
| 3 | Attendance | ParentAttendanceScreen — Uses getMyStudents() ✅ and getStudentAttendanceSummary() ✅. | OK |
| 4 | Homework | ParentHomeworkScreen — Uses getHomework() ✅. Submission uses submitHomework() ✅. | OK |
| 5 | Class Diary | ParentDiaryScreen — Uses getMyStudents() ✅ and getRawList('/diary-entries'). | OK |
| 6 | Lesson Planner | ParentLessonPlannerScreen — Uses getParentLessonPlanners() ✅. | OK |
| 7 | Timetable | ParentTimetableScreen — Uses getMyStudents() ✅ and getTimetableSlots(). Issue: Needs GET /me/timetable endpoint. Frontend calls getRawList('/me/timetable'). Backend has GET /me/timetable ✅. | OK |
| 8 | Exam Schedule | ParentExamScheduleScreen — Uses getMyStudents() ✅. Issue: Backend has GET /me/exam-schedule but frontend may not call it directly. | Medium |
| 9 | Notices | ParentNoticesScreen — Uses getRawList('/notices'). Works via generic method. | OK |
| 10 | Teacher Chat | ParentTeacherChatScreen — Uses getCommunications() ✅ and sendCommunication() ✅. | OK |
| 11 | PTM Booking | ParentPTMBookingScreen — Uses bookParentTeacherMeeting() ✅. | OK |
| 12 | Fees | ParentFeesScreen — Uses getMyStudents() ✅ and getStudentFees() ✅. Payment uses submitParentPaymentRequest() ✅. | OK |
| 13 | Leave | ParentLeaveScreen — Uses getStudentLeaveApplications() ✅ and submitStudentLeaveApplication() ✅. | OK |
| 14 | Documents | ParentDocumentsScreen — Uses getMyStudents() ✅ and getRawList('/student-documents'). | OK |
| 15 | Health Update | ParentHealthUpdateScreen — Uses getMyStudents() ✅. Issue: Backend has POST /medical-records for creation but frontend has no dedicated method. Screen may use createRaw('/medical-records', ...). | Medium |
| 16 | Discipline | ParentDisciplineScreen — Uses getMyStudents() ✅ and getRawList('/discipline-incidents'). | OK |
| 17 | Report Cards | ParentReportCardsScreen — Uses getMyStudents() ✅. Issue: Backend has GET /exams/report-cards but frontend may not call it. | Medium |
Kiosk Role
| # | Screen | Issue | Severity |
|---|---|---|---|
| 1 | QR Attendance | KioskQrAttendanceScreen — Uses getStaffQrToken() ✅ and the timer/refresh logic. ExportStaffQrDailyLogs() ✅. | OK |
| 2 | No back navigation | Route guard should prevent kiosk from accessing other routes. route_access_guard.dart handles this. | OK |
────────────────────────────────────────────────────────────────────────────────
4. Cross-Role Workflow Issues
Workflow 1: Staff Attendance (Kiosk → Teacher → Principal)
- Kiosk:  getStaffQrToken()  → displays QR ✅
- Teacher:  scanStaffQr(token)  → records attendance ✅
- Principal:  getStaffAttendanceForDate()  → views records ✅
- Status: ✅ Works end-to-end
Workflow 2: Student Attendance (Teacher → Principal → Parent)
- Teacher:  createAttendanceSession()  +  markAttendance()  ✅
- Principal:  getAttendanceSessions()  → views ✅
- Parent:  getStudentAttendanceSummary()  → views ✅
- Status: ⚠️ Works but teacher needs correct scope data from RoleAccessService
Workflow 3: Homework (Teacher → Parent → Teacher)
- Teacher:  createHomework()  ✅
- Parent:  getHomework()  →  submitHomework()  ✅
- Teacher:  getHomeworkSubmissions()  →  reviewHomeworkSubmission()  ✅
- Status: ✅ Works end-to-end
Workflow 4: Leave (Parent → Principal → Parent)
- Parent:  submitStudentLeaveApplication()  ✅
- Principal:  decideStudentLeaveApplication()  ✅
- Parent:  getStudentLeaveApplications()  → sees updated status ✅
- Status: ✅ Works end-to-end
Workflow 5: Fee Payment (Principal → Parent → Principal)
- Principal:  createFeeStructure()  →  generateFeeInvoices()  ✅
- Parent:  getStudentFees()  →  submitParentPaymentRequest()  ✅
- Principal:  getParentPaymentRequests()  →  decideParentPaymentRequest()  ✅
- Status: ✅ Works end-to-end
Workflow 6: Event Post (Teacher → Principal → Parent)
- Teacher:  createEventPost()  ✅
- Principal:  getPendingEventPosts()  →  approveEventPost()  ✅
- Parent:  getHomeFeedEventPosts()  → sees in feed ✅
- Status: ⚠️ Works but  media_urls  format may be inconsistent
Workflow 7: Messaging (Teacher ↔ Parent)
- Teacher:  sendCommunication()  ✅
- Parent:  getCommunications()  → sees message ✅
- Parent:  sendCommunication()  → reply ✅
- Teacher:  getCommunications()  → sees reply ✅
- Status: ✅ Works end-to-end
Workflow 8: Account Creation & Access Control
- Principal:  createUser()  via  POST /users  ✅
- New Teacher:  login()  →  getDashboard('teacher')  ✅
- Principal:  assignParentStudents()  via  POST /parents/:id/students  ✅
- New Parent:  login()  →  getDashboard('parent')  →  getMyStudents()  ✅
- Status: ✅ Works end-to-end
────────────────────────────────────────────────────────────────────────────────
5. Critical Issues Summary
🔴 High Severity (Feature Broken or Non-Functional)
| # | Issue | Location | Impact |
|---|---|---|---|
| 1 | No frontend API method for GET /students/:id/progress | students_api.dart | Student Performance screen (Teacher) and Academic Progress screen (Parent) cannot load marks/performance data |
| 2 | No frontend API method for GET /students/:id/marks | students_api.dart | Report cards and exam marks viewing broken |
| 3 | No frontend API method for GET /exams/schedules/:id/marks | exams_events_api.dart | Exam marks entry and viewing broken |
| 4 | No frontend API method for POST /exams/schedules/:id/marks | exams_events_api.dart | Teacher cannot enter exam marks |
| 5 | No frontend API method for GET /exams/report-cards | exams_events_api.dart | Report card generation/listing broken |
| 6 | No frontend API method for GET /staff/:id/leave-balances | staff_api.dart | Staff leave balance display broken |
| 7 | No frontend API method for GET /staff/:id/attendance | staff_api.dart | Individual staff attendance view broken |
| 8 | ID Card Generation and Report Card Generator screens may not have working API calls | id_card_generation_screen.dart, report_card_generator_screen.dart | Two principal features potentially non-functional |
| 9 | No frontend API method for POST /students/enrollments | students_api.dart | Student enrollment creation broken |
| 10 | No frontend API methods for Medical Records CRUD | Missing entirely | Health Update feature incomplete |
🟡 Medium Severity (Feature Partially Working)
| # | Issue | Location | Impact |
|---|---|---|---|
| 1 | RoleAccessService dependency for teacher scope | role_access_service.dart | If teacher scope fails to load, attendance, timetable, and homework all break |
| 2 | createEventPost() sends media_urls as comma-string | exams_events_api.dart | Backend may expect JSON array — media upload in event posts may fail |
| 3 | ParentExamScheduleScreen may not call GET /me/exam-schedule | parent_exam_schedule_screen.dart | Exam schedule viewing may show empty |
| 4 | ParentReportCardsScreen may not call GET /exams/report-cards | parent_report_cards_screen.dart | Report card viewing may show empty |
| 5 | No getStudentFees with proper parent scope | fees_api.dart | Parent fee display depends on getMyStudents() first, then getStudentFees() per child |
| 6 | TeacherMyAttendanceScreen auto-scan needs camera permission | teacher_my_attendance_screen.dart | Auto-scan may fail silently without permission |
🟢 Low Severity (Works but Could Be Better)
| # | Issue | Location | Impact |
|---|---|---|---|
| 1 | Many screens use generic getRawList()/createRaw() instead of typed methods | Various | Works but lacks type safety and error handling |
| 2 | decideParentPaymentRequest() uses PUT only | fees_api.dart | Backend accepts both PUT and PATCH |
| 3 | Guardian CRUD uses generic methods | guardian_directory_screen.dart | Works but fragile |
| 4 | Notice CRUD uses generic methods | Various | Works but no dedicated API methods |
| 5 | Event update/delete not in frontend API | exams_events_api.dart | Principal can't edit/delete events from the UI |
────────────────────────────────────────────────────────────────────────────────
6. Testing Guide Accuracy Assessment
| Section | Accuracy | Notes |
|---|---|---|
| Environment Setup | ✅ Accurate | Backend URL, test accounts, fresh session — all correct |
| Sign In & Authentication | ✅ Accurate | All login flows match actual screen implementations |
| Principal Dashboard | ✅ Accurate | Module tiles, action queue, setup checklist — all match code |
| School Profile | ✅ Accurate | Edit/save flow exists via PATCH /schools/current |
| Access Permissions | ✅ Accurate | createUser(), patchUser() work via /users endpoints |
| Staff Management | ⚠️ Partially accurate | CRUD works but individual staff detail (leave balances, attendance) has no frontend API method |
| Student Oversight | ✅ Accurate | CRUD works. Bulk import API exists. |
| Guardian Directory | ⚠️ Partially accurate | List works via generic methods. CRUD operations lack dedicated frontend methods. |
| Class Hub | ✅ Accurate | Full CRUD via dedicated principal API methods |
| Subjects | ✅ Accurate | Overview and actions work via dedicated methods |
| Academic Years | ✅ Accurate | Works via generic methods |
| Timetable | ✅ Accurate | Smart timetable generation works |
| Lesson Planners | ✅ Accurate | Teacher creates, principal views, parent views — all work |
| Attendance | ⚠️ Partially accurate | Sessions and marking work. But teacher scope dependency is a risk. |
| Exams | ⚠️ Partially accurate | Listing and creation work. But marks entry and report cards lack frontend API methods. |
| Fees | ✅ Accurate | Fee structures, invoices, payment requests — all work |
| Communication | ✅ Accurate | Announcements, messages, event posts — all work |
| Calendar | ✅ Accurate | Events CRUD works |
| Reports & Documents | ⚠️ Partially accurate | Report exports work. ID Card and Report Card Generator screens need verification. |
| Teacher Dashboard | ✅ Accurate | All quick actions and metrics match code |
| Teacher QR Check-in | ✅ Accurate | Scan flow works end-to-end |
| Teacher Student Attendance | ⚠️ Partially accurate | Works but depends on RoleAccessService scope loading |
| Teacher Homework | ✅ Accurate | CRUD and submissions work |
| Teacher Communication | ✅ Accurate | Messages and PTM work |
| Parent Dashboard | ✅ Accurate | Feed, child selector, summary cards — all match |
| Parent Academic Progress | ⚠️ Partially accurate | Screen exists but lacks dedicated marks/performance API method |
| Parent Fees | ✅ Accurate | Fee viewing and payment requests work |
- Speed is important, but a secondary goal.
- If a tool fails, try again, or try a different tool or approach.
- Context is managed for you. The context-pruner agent will automatically run as needed. Gather as much context as you need without worrying about it.
- Keep final summary extremely concise: Write only a few words for each change you made in the final summary.
Response examples
please implement [a complex new feature]
[ You read a few of the relevant files using the read_files tool in two separate tool calls ]
[ You spawn another file-picker and code-searcher to find more relevant files, and use glob tools ]
[ You read a few other relevant files using the read_files tool ]
[ You ask the user for important clarifications on their request or alternate implementation strategies using the ask_user tool ]
[ You implement the changes using the str_replace or write_file tools ]
[ You spawn a code-reviewer-mimo to review the changes, a basher to typecheck the local changes, a basher to typecheck the whole project, and another basher to run tests, all in parallel ]
[ You fix the issues found by the code-reviewer-mimo and type/test errors ]
[ All tests & typechecks pass -- you write a very short final summary of the changes you made ]
what's the best way to refactor [x]