package routes

import (
	"log"
	"strings"
	"time"

	"school-backend/internal/config"
	"school-backend/internal/handlers"
	"school-backend/internal/middleware"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
)

func RegisterV1Routes(r *gin.Engine, cfg *config.Config) {
	authHandler := handlers.NewAuthHandler()
	schoolHandler := handlers.NewSchoolHandler()
	staffHandler := handlers.NewStaffHandler()
	studentHandler := handlers.NewStudentHandler()
	guardianHandler := handlers.NewGuardianHandler()
	attendanceHandler := handlers.NewAttendanceHandler()
	examHandler := handlers.NewExamHandler()
	feeHandler := handlers.NewFeeHandler()
	leaveHandler := handlers.NewLeaveHandler()
	timetableHandler := handlers.NewTimetableHandler()
	ptmHandler := handlers.NewParentTeacherMeetingHandler()
	homeworkSubmissionHandler := handlers.NewHomeworkSubmissionHandler()
	announcementHandler := handlers.NewAnnouncementHandler()
	eventPostHandler := handlers.NewEventPostHandler()
	lessonPlannerHandler := handlers.NewLessonPlannerHandler()
	homeworkReminderHandler := handlers.NewHomeworkReminderHandler()
	notificationDeviceHandler := handlers.NewNotificationDeviceHandler()
	parentLinkHandler := handlers.NewParentLinkHandler()
	userHandler := handlers.NewUserHandler()
	userManagementHandler := handlers.NewUserManagementHandler()
	schoolSetupHandler := handlers.NewSchoolSetupHandler()
	accountApprovalHandler := handlers.NewAccountApprovalHandler()
	classApprovalHandler := handlers.NewClassApprovalHandler()
	studentApprovalHandler := handlers.NewStudentApprovalHandler()
	approvalRequestHandler := handlers.NewApprovalRequestHandler()
	auditLogHandler := handlers.NewAuditLogHandler()
	dashboardHandler := handlers.NewDashboardHandler()
	principalClassesHandler := handlers.NewPrincipalClassesHandler()
	principalSubjectsHandler := handlers.NewPrincipalSubjectsHandler()
	principalAcademicCommandHandler := handlers.NewPrincipalAcademicCommandHandler()
	assistantWorkflowHandler := handlers.NewAssistantWorkflowHandler()
	reportExportHandler := handlers.NewReportExportHandler()
	aliasHandler := handlers.NewOperationalAliasHandler()
	parentSelfHandler := handlers.NewParentSelfHandler()
	teacherSelfHandler := handlers.NewTeacherSelfHandler()
	bulkImportHandler := handlers.NewBulkImportHandler()
	uploadHandler := handlers.NewUploadHandler()

	parentFeeHandler := handlers.NewParentFeeHandler()
	tableCRUD := func(table string) *handlers.TablesMDCRUDHandler {
		resource, ok := handlers.TablesMDResourceFor(table)
		if !ok {
			log.Fatalf("Tables.md resource %s is not configured", table)
		}
		return handlers.NewTablesMDCRUDHandler(resource)
	}
	registerTableCRUD := func(group *gin.RouterGroup, table string, readRoles []string, writeRoles []string) {
		handler := tableCRUD(table)
		group.GET("", middleware.RBACMiddleware(readRoles...), handler.List)
		group.GET("/:id", middleware.RBACMiddleware(readRoles...), handler.Get)
		group.POST("", middleware.RBACMiddleware(writeRoles...), handler.Create)
		group.PUT("/:id", middleware.RBACMiddleware(writeRoles...), handler.Update)
		group.PATCH("/:id", middleware.RBACMiddleware(writeRoles...), handler.Update)
		group.DELETE("/:id", middleware.RBACMiddleware(writeRoles...), handler.Delete)
	}

	api := r.Group("/api/v1")
	{
		frontendResource := func(path string, allowedRoles ...string) {
			resource := strings.TrimPrefix(path, "/")
			h := handlers.NewFrontendRecordHandler(resource)
			group := api.Group(path)
			group.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
			if len(allowedRoles) > 0 {
				group.Use(middleware.RBACMiddleware(allowedRoles...))
			}
			group.GET("", h.List)
			group.POST("", h.Create)
			group.PUT("/:id", h.Update)
			group.PATCH("/:id", h.Update)
			group.DELETE("/:id", h.Delete)
		}

		registerAuthRoutes(api, cfg, authHandler)
		registerDashboardRoutes(api, cfg, dashboardHandler)
		registerPrincipalRoutes(
			api,
			cfg,
			principalClassesHandler,
			principalSubjectsHandler,
			principalAcademicCommandHandler,
		)

		assistant := api.Group("/assistant")
		assistant.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware(), middleware.RBACMiddleware("Principal"))
		{
			assistant.GET("/workflows", assistantWorkflowHandler.Catalog)
			assistant.POST("/intent", assistantWorkflowHandler.DetectIntent)
			assistant.GET("/sessions", assistantWorkflowHandler.ListSessions)
			assistant.POST("/sessions", middleware.RateLimitMiddleware("assistant_session_create", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), assistantWorkflowHandler.CreateSession)
			assistant.GET("/sessions/:id", assistantWorkflowHandler.GetSession)
			assistant.PUT("/sessions/:id/steps/:step_id", assistantWorkflowHandler.SaveStep)
			assistant.PATCH("/sessions/:id/steps/:step_id", assistantWorkflowHandler.SaveStep)
			assistant.POST("/sessions/:id/validate", assistantWorkflowHandler.ValidateSession)
			assistant.POST("/sessions/:id/execute", middleware.RateLimitMiddleware("assistant_session_execute", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), assistantWorkflowHandler.ExecuteSession)
			assistant.DELETE("/sessions/:id", assistantWorkflowHandler.CancelSession)
			assistant.GET("/templates/:workflow_type", assistantWorkflowHandler.ExportTemplate)
			assistant.POST("/sessions/:id/import-preview", assistantWorkflowHandler.ImportPreview)
		}

		admin := api.Group("/admin")
		admin.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware(), middleware.RBACMiddleware("Principal"))
		{
			admin.POST("/bulk-import", middleware.RateLimitMiddleware("bulk_import", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), bulkImportHandler.BulkImport)
			admin.GET("/bulk-import/template", bulkImportHandler.GetImportTemplate)
			admin.GET("/bulk-import/history", bulkImportHandler.GetImportHistory)
		}

		schools := api.Group("/schools")
		schools.POST("/setup", middleware.RateLimitMiddleware("school_setup", cfg.RateLimitMaxLogin, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), schoolSetupHandler.Setup)
		schools.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			schools.GET("", middleware.CacheMiddleware("schools_list", time.Duration(cfg.CacheTTLSeconds)*time.Second), schoolHandler.GetSchools)
			schools.GET("/current", schoolHandler.GetCurrentSchool)
			schools.PATCH("/current", middleware.RBACMiddleware("Principal"), schoolHandler.UpdateCurrentSchool)
			schools.POST("/current/logo", middleware.RBACMiddleware("Principal"), schoolHandler.UploadCurrentSchoolLogo)
			schools.GET("/:id", middleware.CacheMiddleware("schools_detail", time.Duration(cfg.CacheTTLSeconds)*time.Second), schoolHandler.GetSchool)
			schools.POST("", middleware.RBACMiddleware("Principal"), schoolHandler.CreateSchool)
		}

		academicYears := api.Group("/academic-years")
		academicYears.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			academicYears.GET("", middleware.CacheMiddleware("academic_years_list", time.Duration(cfg.CacheTTLSeconds)*time.Second), schoolHandler.GetAcademicYears)
			academicYears.GET("/:id", middleware.CacheMiddleware("academic_years_detail", time.Duration(cfg.CacheTTLSeconds)*time.Second), schoolHandler.GetAcademicYear)
			academicYears.POST("", middleware.RBACMiddleware("Principal"), schoolHandler.CreateAcademicYear)
			academicYears.PUT("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.UpdateAcademicYear)
			academicYears.PATCH("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.UpdateAcademicYear)
			academicYears.DELETE("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.DeleteAcademicYear)
			academicYears.GET("/:id/terms", schoolHandler.GetTerms)
		}

		grades := api.Group("/grades")
		grades.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			grades.GET("", schoolHandler.GetGrades)
			grades.GET("/:id", schoolHandler.GetGrade)
			grades.POST("", middleware.RBACMiddleware("Principal"), schoolHandler.CreateGrade)
			grades.PUT("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.UpdateGrade)
			grades.PATCH("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.UpdateGrade)
			grades.DELETE("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.DeleteGrade)
		}

		sections := api.Group("/sections")
		sections.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			sections.GET("", schoolHandler.GetSections)
			sections.GET("/:id", schoolHandler.GetSection)
			sections.POST("", middleware.RBACMiddleware("Principal"), schoolHandler.CreateSection)
			sections.PUT("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.UpdateSection)
			sections.PATCH("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.UpdateSection)
			sections.DELETE("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.DeleteSection)
		}

		classes := api.Group("/classes")
		classes.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(classes, "classes", []string{"Principal", "Teacher", "Parent"}, []string{"Principal"})
		}

		departments := api.Group("/departments")
		departments.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			departments.GET("", schoolHandler.GetDepartments)
			departments.POST("", middleware.RBACMiddleware("Principal"), schoolHandler.CreateDepartment)
		}

		subjects := api.Group("/subjects")
		subjects.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			subjects.GET("", schoolHandler.GetSubjects)
			subjects.POST("", middleware.RBACMiddleware("Principal"), schoolHandler.CreateSubject)
			subjects.PUT("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.UpdateSubject)
			subjects.PATCH("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.UpdateSubject)
			subjects.DELETE("/:id", middleware.RBACMiddleware("Principal"), schoolHandler.DeleteSubject)
		}

		gradeSubjects := api.Group("/grade-subjects")
		gradeSubjects.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.GradeSubject]("grade_subjects", "grade_subjects", []string{"academic_year_id", "grade_id", "subject_id"}, true, "AcademicYear", "Grade", "Subject")
			gradeSubjects.GET("", middleware.RBACMiddleware("Principal"), h.List)
			gradeSubjects.GET("/:id", middleware.RBACMiddleware("Principal"), h.Get)
			gradeSubjects.POST("", middleware.RBACMiddleware("Principal"), h.Create)
			gradeSubjects.PUT("/:id", middleware.RBACMiddleware("Principal"), h.Update)
			gradeSubjects.PATCH("/:id", middleware.RBACMiddleware("Principal"), h.Update)
			gradeSubjects.DELETE("/:id", middleware.RBACMiddleware("Principal"), h.Delete)
		}

		rooms := api.Group("/rooms")
		rooms.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			rooms.GET("", schoolHandler.GetRooms)
			rooms.POST("", middleware.RBACMiddleware("Principal"), schoolHandler.CreateRoom)
		}

		staff := api.Group("/staff")
		staff.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			staff.GET("", staffHandler.GetStaff)
			staff.GET("/:id", staffHandler.GetStaffMember)
			staff.POST("", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("staff_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), staffHandler.CreateStaff)
			staff.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("staff_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), staffHandler.UpdateStaff)
			staff.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("staff_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), staffHandler.DeleteStaff)
			staff.POST("/:id/photo", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("staff_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), staffHandler.UploadStaffPhoto)
			staff.POST("/:id/documents", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("staff_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), staffHandler.UploadStaffDocument)
			staff.GET("/:id/leave-balances", staffHandler.GetStaffLeaveBalance)
			staff.GET("/:id/attendance", staffHandler.GetStaffAttendance)
		}

		students := api.Group("/students")
		students.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			students.GET("", studentHandler.GetStudents)
			students.GET("/:id", studentHandler.GetStudent)
			students.POST("", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.CreateStudent)
			students.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.UpdateStudent)
			students.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.DeleteStudent)
			students.POST("/:id/photo", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.UploadStudentPhoto)
			students.POST("/:id/documents", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.UploadStudentDocument)
			students.PUT("/:id/parent", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), parentLinkHandler.SetStudentParent)
			students.GET("/:id/enrollments", middleware.RBACMiddleware("Principal", "Teacher"), studentHandler.GetStudentEnrollments)
			students.POST("/enrollments", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.CreateEnrollment)
			students.GET("/:id/attendance", studentHandler.GetStudentAttendance)
			students.GET("/:id/fees", studentHandler.GetStudentFees)
			students.GET("/:id/marks", studentHandler.GetStudentMarks)
			students.GET("/:id/progress", studentHandler.GetStudentProgress)
			students.POST("/:id/guardians", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), guardianHandler.LinkGuardianToStudent)
			students.GET("/:id/guardians", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), guardianHandler.GetGuardiansByStudent)
		}

		accountApprovals := api.Group("/account-approvals")
		accountApprovals.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			accountApprovals.GET("", middleware.RBACMiddleware("Principal"), accountApprovalHandler.List)
			accountApprovals.PUT("/:id", middleware.RBACMiddleware("Principal"), accountApprovalHandler.Decide)
			accountApprovals.PATCH("/:id", middleware.RBACMiddleware("Principal"), accountApprovalHandler.Decide)
		}

		classApprovals := api.Group("/class-approvals")
		classApprovals.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			classApprovals.GET("", middleware.RBACMiddleware("Principal"), classApprovalHandler.List)
			classApprovals.POST("", middleware.RBACMiddleware("Principal"), classApprovalHandler.Create)
			classApprovals.PUT("/:id", middleware.RBACMiddleware("Principal"), classApprovalHandler.Decide)
			classApprovals.PATCH("/:id", middleware.RBACMiddleware("Principal"), classApprovalHandler.Decide)
		}

		studentApprovals := api.Group("/student-approvals")
		studentApprovals.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			studentApprovals.GET("", middleware.RBACMiddleware("Principal"), studentApprovalHandler.List)
			studentApprovals.POST("", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentApprovalHandler.Create)
			studentApprovals.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentApprovalHandler.Decide)
			studentApprovals.PATCH("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentApprovalHandler.Decide)
		}

		approvals := api.Group("/approvals")
		approvals.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			approvals.GET("", middleware.RBACMiddleware("Principal"), approvalRequestHandler.List)
			approvals.GET("/:id", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Get)
			approvals.POST("", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Create)
			approvals.PUT("/:id", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Update)
			approvals.PATCH("/:id", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Update)
			approvals.POST("/:id/submit", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Submit)
			approvals.POST("/:id/approve", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Approve)
			approvals.POST("/:id/reject", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Reject)
			approvals.POST("/:id/request-changes", middleware.RBACMiddleware("Principal"), approvalRequestHandler.RequestChanges)
			approvals.POST("/:id/cancel", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Cancel)
			approvals.POST("/:id/apply", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Apply)
		}

		attendance := api.Group("/attendance")
		attendance.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			attendance.GET("/sessions", attendanceHandler.GetAttendanceSessions)
			attendance.POST("/sessions", middleware.RBACMiddleware("Principal", "Teacher"), middleware.RateLimitMiddleware("attendance_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), attendanceHandler.CreateAttendanceSession)
			attendance.POST("/sessions/:session_id/mark", middleware.RBACMiddleware("Principal", "Teacher"), middleware.RateLimitMiddleware("attendance_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), attendanceHandler.MarkStudentAttendance)
			attendance.POST("/sessions/:session_id/reopen", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("attendance_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), attendanceHandler.ReopenAttendanceSession)
			attendance.GET("/summary", attendanceHandler.GetStudentAttendanceSummary)
			attendance.GET("/staff", middleware.RBACMiddleware("Principal", "Kiosk"), attendanceHandler.ListStaffAttendance)
			attendance.GET("/staff/qr-token", middleware.RBACMiddleware("Principal", "Kiosk"), attendanceHandler.GetStaffQRToken)
			attendance.GET("/staff/qr-logs/export", middleware.RBACMiddleware("Principal", "Kiosk"), attendanceHandler.ExportStaffQRDailyLogs)
			attendance.POST("/staff/qr-scan", middleware.RBACMiddleware("Teacher", "Kiosk"), middleware.RateLimitMiddleware("attendance_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), attendanceHandler.ScanStaffQR)
			attendance.GET("/staff/me/today", middleware.RBACMiddleware("Teacher"), attendanceHandler.GetMyStaffAttendanceToday)
			attendance.POST("/staff", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("attendance_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), attendanceHandler.MarkStaffAttendance)
			attendance.GET("/reports/exports", middleware.RBACMiddleware("Principal"), reportExportHandler.List("attendance_reports"))
			attendance.POST("/reports/exports", middleware.RBACMiddleware("Principal"), reportExportHandler.Create("attendance_reports"))
			attendance.GET("/reports/exports/:id", middleware.RBACMiddleware("Principal"), reportExportHandler.Get)
			attendanceTable := tableCRUD("attendance")
			attendance.GET("", middleware.RBACMiddleware("Principal", "Teacher"), attendanceTable.List)
			attendance.POST("", middleware.RBACMiddleware("Principal", "Teacher"), attendanceTable.Create)
			attendance.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher"), attendanceTable.Get)
			attendance.PUT("/:id", middleware.RBACMiddleware("Principal", "Teacher"), attendanceTable.Update)
			attendance.PATCH("/:id", middleware.RBACMiddleware("Principal", "Teacher"), attendanceTable.Update)
			attendance.DELETE("/:id", middleware.RBACMiddleware("Principal"), attendanceTable.Delete)
		}

		exams := api.Group("/exams")
		exams.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			exams.GET("/types", examHandler.GetExamTypes)
			exams.POST("/types", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.CreateExamType)
			exams.GET("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), examHandler.GetExams)
			exams.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), examHandler.GetExam)
			exams.GET("/:id/rankings", middleware.RBACMiddleware("Principal", "Teacher"), examHandler.GetClassRanking)
			exams.POST("", middleware.RBACMiddleware("Principal", "Teacher"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.CreateExam)
			exams.PUT("/:id", middleware.RBACMiddleware("Principal", "Teacher"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.UpdateExam)
			exams.PATCH("/:id", middleware.RBACMiddleware("Principal", "Teacher"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.UpdateExam)
			exams.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.DeleteExam)
			exams.PATCH("/:id/publish", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.PublishExam)
			exams.GET("/schedules", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), aliasHandler.ListExamSchedules)
			exams.POST("/schedules", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.CreateExamSchedule)
			exams.GET("/schedules/:schedule_id/marks", middleware.RBACMiddleware("Principal", "Teacher"), examHandler.GetScheduleMarks)
			exams.POST("/schedules/:schedule_id/marks", middleware.RBACMiddleware("Principal", "Teacher"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.EnterMarks)
			exams.GET("/report-cards", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), examHandler.GetReportCards)
			exams.GET("/report-cards/exports", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), reportExportHandler.List("report_cards"))
			exams.POST("/report-cards/exports", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), reportExportHandler.Create("report_cards"))
			exams.GET("/report-cards/exports/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), reportExportHandler.Get)
			exams.GET("/grading-scale", examHandler.GetGradingScale)
		}

		fees := api.Group("/fees")
		fees.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			fees.GET("/categories", feeHandler.GetFeeCategories)
			fees.POST("/categories", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.CreateFeeCategory)
			fees.DELETE("/categories/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.DeleteFeeCategory)
			fees.GET("/structures", feeHandler.GetFeeStructures)
			fees.POST("/structures", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.CreateFeeStructure)
			fees.PUT("/structures/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.UpdateFeeStructure)
			fees.PATCH("/structures/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.UpdateFeeStructure)
			fees.DELETE("/structures/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.DeleteFeeStructure)
			fees.GET("/invoices", feeHandler.GetInvoices)
			fees.POST("/invoices/generate", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.GenerateInvoices)
			fees.POST("/invoices", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.CreateInvoice)
			fees.POST("/payments", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.RecordPayment)
			fees.GET("/payment-requests", middleware.RBACMiddleware("Principal", "Parent"), feeHandler.GetPaymentRequests)
			fees.POST("/payment-requests", middleware.RBACMiddleware("Parent"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.CreateParentPaymentRequest)
			fees.PUT("/payment-requests/:id/decision", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.DecideParentPaymentRequest)
			fees.PATCH("/payment-requests/:id/decision", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.DecideParentPaymentRequest)
			fees.GET("/payment-config", middleware.RBACMiddleware("Parent"), feeHandler.GetPaymentConfig)
			feeConcessions := handlers.NewFrontendRecordHandler("fees/concessions")
			fees.GET("/concessions", middleware.RBACMiddleware("Principal", "Parent"), feeConcessions.List)
			fees.POST("/concessions", middleware.RBACMiddleware("Principal", "Parent"), feeConcessions.Create)
			fees.PUT("/concessions/:id/decision", middleware.RBACMiddleware("Principal"), feeConcessions.Update)
			fees.PATCH("/concessions/:id/decision", middleware.RBACMiddleware("Principal"), feeConcessions.Update)
			fees.DELETE("/concessions/:id", middleware.RBACMiddleware("Principal"), feeConcessions.Delete)
			fees.POST("/reminders", middleware.RBACMiddleware("Principal"), aliasHandler.QueueFeeReminders)
			fees.GET("/reports/exports", middleware.RBACMiddleware("Principal"), reportExportHandler.List("fee_reports"))
			fees.POST("/reports/exports", middleware.RBACMiddleware("Principal"), reportExportHandler.Create("fee_reports"))
			fees.GET("/reports/exports/:id", middleware.RBACMiddleware("Principal"), reportExportHandler.Get)
			feeTable := tableCRUD("fees")
			fees.GET("", middleware.RBACMiddleware("Principal", "Parent"), feeTable.List)
			fees.POST("", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeTable.Create)
			fees.GET("/:id", middleware.RBACMiddleware("Principal", "Parent"), feeTable.Get)
			fees.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeTable.Update)
			fees.PATCH("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeTable.Update)
			fees.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeTable.Delete)
		}

		reports := api.Group("/reports")
		reports.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			reports.GET("/exports", middleware.RBACMiddleware("Principal"), reportExportHandler.List("general_reports"))
			reports.POST("/exports", middleware.RBACMiddleware("Principal"), reportExportHandler.Create("general_reports"))
			reports.GET("/exports/:id", middleware.RBACMiddleware("Principal"), reportExportHandler.Get)
		}

		studentReports := api.Group("/student-reports")
		studentReports.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			studentReports.GET("/exports", middleware.RBACMiddleware("Principal"), reportExportHandler.List("student_reports"))
			studentReports.POST("/exports", middleware.RBACMiddleware("Principal"), reportExportHandler.Create("student_reports"))
			studentReports.GET("/exports/:id", middleware.RBACMiddleware("Principal"), reportExportHandler.Get)
		}

		leave := api.Group("/leave")
		leave.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			leave.GET("/types", leaveHandler.GetLeaveTypes)
			leave.POST("/types", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.CreateLeaveType)
			leave.GET("/applications", middleware.RBACMiddleware("Principal", "Teacher"), leaveHandler.GetLeaveApplications)
			leave.POST("/applications", middleware.RBACMiddleware("Principal", "Teacher"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.CreateLeaveApplication)
			leave.PUT("/applications/:id/approve", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.ApproveLeaveApplication)
			leave.POST("/applications/:id/recall", middleware.RBACMiddleware("Teacher"), teacherSelfHandler.RecallLeaveApplication)
			leave.GET("/balances", middleware.RBACMiddleware("Principal", "Teacher"), leaveHandler.GetLeaveBalances)
			leave.POST("/balances/initialize", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.InitializeLeaveBalances)
		}

		studentLeave := api.Group("/student-leave")
		studentLeave.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			studentLeave.GET("/applications", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), leaveHandler.GetStudentLeaveApplications)
			studentLeave.POST("/applications", middleware.RBACMiddleware("Parent"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.CreateStudentLeaveApplication)
			studentLeave.PUT("/applications/:id/decision", middleware.RBACMiddleware("Principal", "Teacher"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.DecideStudentLeaveApplication)
			studentLeave.PATCH("/applications/:id/decision", middleware.RBACMiddleware("Principal", "Teacher"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.DecideStudentLeaveApplication)
		}

		leaves := api.Group("/leaves")
		leaves.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(leaves, "leaves", []string{"Principal", "Teacher", "Parent"}, []string{"Principal", "Teacher", "Parent"})
		}

		timetable := api.Group("/timetable")
		timetable.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			timetable.GET("/slots", timetableHandler.GetTimetableSlots)
			timetable.GET("/templates", middleware.RBACMiddleware("Principal"), timetableHandler.GetTimetableTemplates)
			timetable.PUT("/templates", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SaveTimetableTemplate)
			timetable.GET("/constraints", middleware.RBACMiddleware("Principal"), timetableHandler.GetTimetableConstraints)
			timetable.POST("/constraints", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateTimetableConstraint)
			timetable.PUT("/constraints/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.UpdateTimetableConstraint)
			timetable.DELETE("/constraints/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.DeleteTimetableConstraint)
			timetable.POST("/smart/preview", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SmartTimetablePreview)
			timetable.POST("/smart/generate", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SmartTimetableGenerate)
			timetable.GET("/smart/jobs/:id", middleware.RBACMiddleware("Principal"), timetableHandler.GetSmartTimetableJob)
			timetable.POST("/smart/validate", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SmartTimetableValidate)
			timetable.POST("/suggestions", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SuggestTimetableSlots)
			timetable.POST("/slots/generate", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.GenerateTimetableSlots)
			timetable.POST("/slots", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateTimetableSlot)
			timetable.PUT("/slots/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.UpdateTimetableSlot)
			timetable.POST("/slots/swap", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SwapTimetableSlots)
			timetable.POST("/slots/:id/override", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.OverrideTimetableSlot)
			timetable.DELETE("/slots/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.DeleteTimetableSlot)
			timetable.GET("/substitutions", timetableHandler.GetSubstitutions)
			timetable.POST("/substitutions", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateSubstitution)
			timetable.GET("/exports", middleware.RBACMiddleware("Principal"), reportExportHandler.List("timetable_reports"))
			timetable.POST("/exports", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateTimetableExport)
			timetable.GET("/section/:section_id", timetableHandler.GetTimetableBySection)

			// Pre-Primary Timetable Templates
			timetable.GET("/pre-primary/templates", middleware.RBACMiddleware("Principal"), timetableHandler.GetPrePrimaryTimetableTemplates)
			timetable.POST("/pre-primary/templates", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreatePrePrimaryTimetableTemplate)
			timetable.PUT("/pre-primary/templates/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.UpdatePrePrimaryTimetableTemplate)
			timetable.DELETE("/pre-primary/templates/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.DeletePrePrimaryTimetableTemplate)
			timetable.POST("/pre-primary/apply", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.ApplyPrePrimaryClassSchedule)
			timetable.GET("/pre-primary/section/:section_id", timetableHandler.GetPrePrimaryTimetableBySection)
		}

		announcements := api.Group("/announcements")
		announcements.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			announcements.GET("", announcementHandler.GetAnnouncements)
			announcements.POST("", middleware.RBACMiddleware("Principal", "Teacher"), middleware.RateLimitMiddleware("announcement_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), announcementHandler.CreateAnnouncement)
		}

		// Generic file upload — used by event posts and lesson planners
		uploads := api.Group("/uploads")
		uploads.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware(), middleware.RBACMiddleware("Teacher", "Principal"))
		{
			uploads.POST("", uploadHandler.UploadFile)
		}

		eventPosts := api.Group("/event-posts")
		eventPosts.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			eventPosts.POST("", middleware.RBACMiddleware("Teacher"), eventPostHandler.CreateEventPost)
			eventPosts.GET("", middleware.RBACMiddleware("Principal"), eventPostHandler.ListAllEventPosts)
			eventPosts.GET("/teacher", middleware.RBACMiddleware("Teacher"), eventPostHandler.ListTeacherEventPosts)
			eventPosts.GET("/pending", middleware.RBACMiddleware("Principal"), eventPostHandler.ListPendingEventPosts)
			eventPosts.POST("/:id/approve", middleware.RBACMiddleware("Principal"), eventPostHandler.ApproveEventPost)
			eventPosts.POST("/:id/reject", middleware.RBACMiddleware("Principal"), eventPostHandler.RejectEventPost)
			eventPosts.GET("/gallery", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), eventPostHandler.ListGalleryEventPosts)
			eventPosts.GET("/home-feed", middleware.RBACMiddleware("Parent"), eventPostHandler.ListParentHomeFeed)
		}

		lessonPlanners := api.Group("/lesson-planners")
		lessonPlanners.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			lessonPlanners.POST("", middleware.RBACMiddleware("Teacher"), lessonPlannerHandler.CreateLessonPlanner)
			lessonPlanners.GET("/teacher", middleware.RBACMiddleware("Teacher"), lessonPlannerHandler.ListTeacherLessonPlanners)
			lessonPlanners.POST("/:id/complete", middleware.RBACMiddleware("Teacher"), lessonPlannerHandler.CompleteLessonPlanner)
			lessonPlanners.GET("/parent", middleware.RBACMiddleware("Parent"), lessonPlannerHandler.ListParentLessonPlanners)
			lessonPlanners.GET("/principal", middleware.RBACMiddleware("Principal"), lessonPlannerHandler.ListPrincipalLessonPlanners)
		}

		api.GET("/landing/events", eventPostHandler.ListLandingEvents)

		notices := api.Group("/notices")
		notices.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			notices.GET("", announcementHandler.GetAnnouncements)
			notices.POST("", middleware.RBACMiddleware("Principal"), aliasHandler.CreateNotice)
			notices.PATCH("/:id", middleware.RBACMiddleware("Principal"), aliasHandler.PatchNotice)
			notices.DELETE("/:id", middleware.RBACMiddleware("Principal"), aliasHandler.DeleteNotice)
		}

		events := api.Group("/events")
		events.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			eventTable := tableCRUD("events")
			events.GET("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), eventTable.List)
			events.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), eventTable.Get)
			events.POST("", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("event_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), eventTable.Create)
			events.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("event_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), eventTable.Update)
			events.PATCH("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("event_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), eventTable.Update)
			events.DELETE("/:id", middleware.RBACMiddleware("Principal"), eventTable.Delete)
		}

		notifications := api.Group("/notifications")
		notifications.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			notificationTable := tableCRUD("notifications")
			notifications.GET("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), announcementHandler.GetNotifications)
			notifications.POST("", middleware.RBACMiddleware("Principal"), announcementHandler.CreateNotification)
			notifications.POST("/device-tokens", middleware.RateLimitMiddleware("notification_device_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), notificationDeviceHandler.UpsertDeviceToken)
			notifications.DELETE("/device-tokens", middleware.RateLimitMiddleware("notification_device_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), notificationDeviceHandler.RevokeDeviceToken)
			notifications.PUT("/:id/read", announcementHandler.MarkNotificationRead)
			notifications.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), notificationTable.Get)
			notifications.PUT("/:id", middleware.RBACMiddleware("Principal"), notificationTable.Update)
			notifications.PATCH("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), notificationTable.Update)
			notifications.DELETE("/:id", middleware.RBACMiddleware("Principal"), notificationTable.Delete)
		}

		holidays := api.Group("/holidays")
		holidays.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(holidays, "holidays", []string{"Principal", "Teacher", "Parent"}, []string{"Principal"})
		}

		parents := api.Group("/parents")
		parents.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			parents.POST("/:parent_user_id/students", middleware.RBACMiddleware("Principal"), parentLinkHandler.AssignParentStudents)
			parents.GET("/:parent_user_id/students", middleware.RBACMiddleware("Principal"), parentLinkHandler.GetParentStudents)
			parents.GET("/me/students", middleware.RBACMiddleware("Parent"), parentFeeHandler.GetMyStudents)
			parents.GET("/students/:student_id/fees/summary", middleware.RBACMiddleware("Parent"), parentFeeHandler.GetStudentFeeSummary)
		}

		parentFees := api.Group("/parents/fees")
		parentFees.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware(), middleware.RBACMiddleware("Parent"))
		{
			parentFees.GET("/payments", parentFeeHandler.GetPaymentHistory)
			parentFees.GET("/receipts/:receipt_id", parentFeeHandler.GetReceipt)
		}

		me := api.Group("/me")
		me.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			me.GET("/students", middleware.RBACMiddleware("Parent"), parentLinkHandler.GetMyStudents)
			me.GET("/profile", middleware.RBACMiddleware("Parent", "Teacher"), parentSelfHandler.GetMyProfile)
			me.PATCH("/profile", middleware.RBACMiddleware("Parent", "Teacher"), parentSelfHandler.PatchMyProfile)
			me.GET("/timetable", middleware.RBACMiddleware("Parent"), parentSelfHandler.GetMyChildTimetable)
			me.GET("/exam-schedule", middleware.RBACMiddleware("Parent"), parentSelfHandler.GetMyChildExamSchedule)
		}

		teacherGroup := api.Group("/teacher")
		teacherGroup.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			teacherGroup.GET("/ptm-slots", middleware.RBACMiddleware("Teacher"), teacherSelfHandler.GetMyPTMSlots)
			teacherGroup.POST("/ptm-slots", middleware.RBACMiddleware("Teacher"), teacherSelfHandler.CreateMyPTMSlot)
		}

		users := api.Group("/users")
		users.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			users.GET("", middleware.RBACMiddleware("Principal"), userHandler.GetUsers)
			users.POST("", middleware.RBACMiddleware("Principal"), userManagementHandler.CreateUser)
			users.GET("/:id", middleware.RBACMiddleware("Principal"), userManagementHandler.GetUser)
			users.PUT("/:id", middleware.RBACMiddleware("Principal"), userManagementHandler.PatchUser)
			users.PATCH("/:id", middleware.RBACMiddleware("Principal"), userManagementHandler.PatchUser)
			users.POST("/:id/avatar", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("user_avatar_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), userManagementHandler.UploadAvatar)
			users.DELETE("/:id", middleware.RBACMiddleware("Principal"), userManagementHandler.DeleteUser)
		}

		guardians := api.Group("/guardians")
		guardians.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.Guardian]("guardians", "guardians", []string{"full_name"}, true, "Students")
			guardians.GET("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("guardians", "read"), h.List)
			guardians.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("guardians", "read"), h.Get)
			guardians.POST("", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("guardians", "create"), h.Create)
			guardians.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("guardians", "update"), h.Update)
			guardians.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("guardians", "delete"), h.Delete)
		}

		medicalRecords := api.Group("/medical-records")
		medicalRecords.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.MedicalRecord]("medical_records", "medical_records", []string{"student_id"}, false, "Student")
			medicalRecords.GET("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("medical_records", "read"), h.List)
			medicalRecords.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("medical_records", "read"), h.Get)
			medicalRecords.POST("", middleware.RBACMiddleware("Principal", "Parent"), middleware.PermissionMiddleware("medical_records", "create"), h.Create)
			medicalRecords.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("medical_records", "update"), h.Update)
			medicalRecords.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("medical_records", "delete"), h.Delete)
		}

		studentDocuments := api.Group("/student-documents")
		studentDocuments.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.StudentDocument]("student_documents", "student_documents", []string{"student_id", "doc_type", "file_url"}, false, "Student")
			studentDocuments.GET("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("student_documents", "read"), h.List)
			studentDocuments.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("student_documents", "read"), h.Get)
			studentDocuments.POST("", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("student_documents", "create"), h.Create)
			studentDocuments.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("student_documents", "update"), h.Update)
			studentDocuments.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("student_documents", "delete"), h.Delete)
		}

		staffDocuments := api.Group("/staff-documents")
		staffDocuments.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.StaffDocument]("staff_documents", "staff_documents", []string{"staff_id", "doc_type", "file_url"}, false, "Staff")
			staffDocuments.GET("", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("staff_documents", "read"), h.List)
			staffDocuments.GET("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("staff_documents", "read"), h.Get)
			staffDocuments.POST("", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("staff_documents", "create"), h.Create)
			staffDocuments.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("staff_documents", "update"), h.Update)
			staffDocuments.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("staff_documents", "delete"), h.Delete)
		}

		staffSubjects := api.Group("/staff-subjects")
		staffSubjects.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.StaffSubject]("staff_subjects", "staff_subjects", []string{"academic_year_id", "staff_id", "subject_id", "grade_id"}, true, "AcademicYear", "Staff", "Subject", "Grade", "Section")
			staffSubjects.GET("", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("staff_subjects", "read"), h.List)
			staffSubjects.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("staff_subjects", "read"), h.Get)
			staffSubjects.POST("", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("staff_subjects", "create"), h.Create)
			staffSubjects.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("staff_subjects", "update"), h.Update)
			staffSubjects.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("staff_subjects", "delete"), h.Delete)
		}

		staffQualifications := api.Group("/staff-qualifications")
		staffQualifications.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.StaffQualification]("staff_qualifications", "staff_qualifications", []string{"staff_id", "degree"}, false, "Staff")
			staffQualifications.GET("", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("staff_qualifications", "read"), h.List)
			staffQualifications.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("staff_qualifications", "read"), h.Get)
			staffQualifications.POST("", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("staff_qualifications", "create"), h.Create)
			staffQualifications.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("staff_qualifications", "update"), h.Update)
			staffQualifications.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("staff_qualifications", "delete"), h.Delete)
		}

		// Library and transport route groups are intentionally not registered in
		// the current product scope. Historical schema models remain for data
		// preservation, but no active API surface is exposed.

		payroll := api.Group("/payroll")
		payroll.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.Payroll]("payroll", "payrolls", []string{"staff_id", "academic_year_id", "month", "year"}, false, "Staff", "AcademicYear")
			payroll.GET("", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("payroll", "read"), h.List)
			payroll.GET("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("payroll", "read"), h.Get)
			payroll.POST("", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("payroll", "create"), h.Create)
			payroll.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("payroll", "update"), h.Update)
			payroll.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("payroll", "delete"), h.Delete)
		}

		ptm := api.Group("/parent-teacher-meetings")
		ptm.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.ParentTeacherMeeting]("parent_teacher_meetings", "parent_teacher_meetings", []string{"event_id", "section_id", "teacher_id", "guardian_id", "student_id"}, false, "Event", "Section", "Teacher", "Guardian", "Student")
			ptm.GET("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("parent_teacher_meetings", "read"), h.List)
			ptm.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("parent_teacher_meetings", "read"), h.Get)
			ptm.POST("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("parent_teacher_meetings", "create"), h.Create)
			ptm.PUT("/:id/book", middleware.RBACMiddleware("Parent"), ptmHandler.Book)
			ptm.PATCH("/:id/book", middleware.RBACMiddleware("Parent"), ptmHandler.Book)
			ptm.PUT("/:id", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("parent_teacher_meetings", "update"), h.Update)
			ptm.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("parent_teacher_meetings", "delete"), h.Delete)
		}

		auditLogs := api.Group("/audit-logs")
		auditLogs.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			auditLogs.GET("", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("audit_logs", "read"), auditLogHandler.List)
		}

		homework := api.Group("/homework")
		homework.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			homework.POST("/reminders/trigger-end-of-day", middleware.RBACMiddleware("Principal"), homeworkReminderHandler.TriggerEndOfDayReminders)
		}

		homeworkSubmissions := api.Group("/homework-submissions")
		homeworkSubmissions.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			homeworkTable := tableCRUD("homework")
			homework.GET("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("homework", "read"), homeworkTable.List)
			homework.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("homework", "read"), homeworkTable.Get)
			homework.POST("", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("homework", "create"), homeworkTable.Create)
			homework.PUT("/:id", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("homework", "update"), homeworkTable.Update)
			homework.PATCH("/:id", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("homework", "update"), homeworkTable.Update)
			homework.DELETE("/:id", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("homework", "delete"), homeworkTable.Delete)
			homework.GET("/:id/submissions", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("homework", "read"), homeworkSubmissionHandler.List)
			homework.POST("/:id/submissions", middleware.RBACMiddleware("Parent"), homeworkSubmissionHandler.Submit)
			homework.PUT("/:id/submissions/:submission_id/review", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("homework", "update"), homeworkSubmissionHandler.Review)
			homework.PATCH("/:id/submissions/:submission_id/review", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("homework", "update"), homeworkSubmissionHandler.Review)
			homework.POST("/:id/attachment-requests", middleware.RBACMiddleware("Parent"), handlers.NewFrontendRecordHandler("homework/attachment-requests").Create)
		}

		diary := api.Group("/diary-entries")
		diary.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.DiaryEntry]("diary_entries", "diary_entries", []string{"title"}, true)
			diary.GET("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("diary_entries", "read"), h.List)
			diary.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("diary_entries", "read"), h.Get)
			diary.POST("", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("diary_entries", "create"), h.Create)
			diary.PUT("/:id", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("diary_entries", "update"), h.Update)
			diary.DELETE("/:id", middleware.RBACMiddleware("Principal", "Teacher"), middleware.PermissionMiddleware("diary_entries", "delete"), h.Delete)
		}

		conversations := api.Group("/message-conversations")
		conversations.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.MessageConversation]("message_conversations", "message_conversations", []string{"teacher_id", "parent_id"}, true)
			conversations.GET("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("message_conversations", "read"), h.List)
			conversations.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("message_conversations", "read"), h.Get)
			conversations.POST("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("message_conversations", "create"), h.Create)
			conversations.PUT("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("message_conversations", "update"), h.Update)
			conversations.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("message_conversations", "delete"), h.Delete)
		}

		messages := api.Group("/messages")
		messages.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.Message]("messages", "messages", []string{"conversation_id", "sender_id", "sender_role", "body"}, false)
			messages.GET("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("messages", "read"), h.List)
			messages.GET("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("messages", "read"), h.Get)
			messages.POST("", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("messages", "create"), h.Create)
			messages.PUT("/:id", middleware.RBACMiddleware("Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("messages", "update"), h.Update)
			messages.DELETE("/:id", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("messages", "delete"), h.Delete)
		}

		approvalRequests := api.Group("/approval-requests")
		approvalRequests.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(approvalRequests, "approval_requests", []string{"Principal", "Teacher"}, []string{"Principal", "Teacher"})
		}

		communications := api.Group("/communications")
		communications.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(communications, "communications", []string{"Principal", "Teacher", "Parent"}, []string{"Principal", "Teacher", "Parent"})
		}

		principalReports := api.Group("/principal-reports")
		principalReports.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(principalReports, "principal_reports", []string{"Principal"}, []string{"Principal"})
		}

		frontendResource("/admissions/applications", "Principal")
		frontendResource("/certificates/transfer-requests", "Principal")
		frontendResource("/events/approvals", "Principal")
		frontendResource("/timetable/approvals", "Principal")
		frontendResource("/principal/timetable-advice", "Principal")
		frontendResource("/principal/exam-advice", "Principal")
		frontendResource("/documents/requests", "Principal")
		frontendResource("/documents/access-requests", "Principal", "Parent")
		frontendResource("/certificates/requests", "Principal", "Parent")
		frontendResource("/student-notes", "Principal", "Teacher")
		frontendResource("/student-alerts", "Principal", "Teacher")
		frontendResource("/notice-acknowledgements", "Principal", "Teacher", "Parent")
		frontendResource("/documents", "Principal", "Teacher", "Parent")
		frontendResource("/threads", "Principal", "Teacher", "Parent")
		frontendResource("/curriculum", "Principal", "Teacher", "Parent")
		frontendResource("/syllabus", "Principal", "Teacher", "Parent")
		frontendResource("/complaints", "Principal", "Teacher")
		frontendResource("/discipline-incidents", "Principal", "Teacher", "Parent")
		frontendResource("/helpdesk-tickets", "Principal", "Teacher", "Parent")
		api.POST("/documents/requests/:id/prints", middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware(), middleware.RBACMiddleware("Principal"), handlers.NewFrontendRecordHandler("documents/requests/prints").Create)
	}
}
