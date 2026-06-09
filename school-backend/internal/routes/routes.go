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
		assistant.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware(), middleware.RBACMiddleware("Admin", "Principal"))
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

		schools := api.Group("/schools")
		schools.POST("/setup", middleware.RateLimitMiddleware("school_setup", cfg.RateLimitMaxLogin, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), schoolSetupHandler.Setup)
		schools.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			schools.GET("", middleware.CacheMiddleware("schools_list", time.Duration(cfg.CacheTTLSeconds)*time.Second), schoolHandler.GetSchools)
			schools.GET("/current", schoolHandler.GetCurrentSchool)
			schools.PATCH("/current", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateCurrentSchool)
			schools.POST("/current/logo", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UploadCurrentSchoolLogo)
			schools.GET("/:id", middleware.CacheMiddleware("schools_detail", time.Duration(cfg.CacheTTLSeconds)*time.Second), schoolHandler.GetSchool)
			schools.POST("", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.CreateSchool)
		}

		academicYears := api.Group("/academic-years")
		academicYears.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			academicYears.GET("", middleware.CacheMiddleware("academic_years_list", time.Duration(cfg.CacheTTLSeconds)*time.Second), schoolHandler.GetAcademicYears)
			academicYears.GET("/:id", middleware.CacheMiddleware("academic_years_detail", time.Duration(cfg.CacheTTLSeconds)*time.Second), schoolHandler.GetAcademicYear)
			academicYears.POST("", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.CreateAcademicYear)
			academicYears.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateAcademicYear)
			academicYears.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateAcademicYear)
			academicYears.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.DeleteAcademicYear)
			academicYears.GET("/:id/terms", schoolHandler.GetTerms)
		}

		grades := api.Group("/grades")
		grades.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			grades.GET("", schoolHandler.GetGrades)
			grades.GET("/:id", schoolHandler.GetGrade)
			grades.POST("", middleware.RBACMiddleware("Principal"), schoolHandler.CreateGrade)
			grades.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateGrade)
			grades.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateGrade)
			grades.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.DeleteGrade)
		}

		sections := api.Group("/sections")
		sections.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			sections.GET("", schoolHandler.GetSections)
			sections.GET("/:id", schoolHandler.GetSection)
			sections.POST("", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.CreateSection)
			sections.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateSection)
			sections.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateSection)
			sections.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.DeleteSection)
		}

		classes := api.Group("/classes")
		classes.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(classes, "classes", []string{"Admin", "Principal", "Teacher", "Parent"}, []string{"Admin", "Principal"})
		}

		departments := api.Group("/departments")
		departments.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			departments.GET("", schoolHandler.GetDepartments)
			departments.POST("", middleware.RBACMiddleware("Admin"), schoolHandler.CreateDepartment)
		}

		subjects := api.Group("/subjects")
		subjects.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			subjects.GET("", schoolHandler.GetSubjects)
			subjects.POST("", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.CreateSubject)
			subjects.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateSubject)
			subjects.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateSubject)
			subjects.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.DeleteSubject)
		}

		gradeSubjects := api.Group("/grade-subjects")
		gradeSubjects.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.GradeSubject]("grade_subjects", "grade_subjects", []string{"academic_year_id", "grade_id", "subject_id"}, true, "AcademicYear", "Grade", "Subject")
			gradeSubjects.GET("", middleware.RBACMiddleware("Admin", "Principal"), h.List)
			gradeSubjects.GET("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Get)
			gradeSubjects.POST("", middleware.RBACMiddleware("Admin", "Principal"), h.Create)
			gradeSubjects.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
			gradeSubjects.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
			gradeSubjects.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Delete)
		}

		rooms := api.Group("/rooms")
		rooms.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			rooms.GET("", schoolHandler.GetRooms)
			rooms.POST("", middleware.RBACMiddleware("Admin"), schoolHandler.CreateRoom)
		}

		staff := api.Group("/staff")
		staff.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			staff.GET("", staffHandler.GetStaff)
			staff.GET("/:id", staffHandler.GetStaffMember)
			staff.POST("", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("staff_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), staffHandler.CreateStaff)
			staff.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("staff_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), staffHandler.UpdateStaff)
			staff.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("staff_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), staffHandler.DeleteStaff)
			staff.POST("/:id/photo", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("staff_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), staffHandler.UploadStaffPhoto)
			staff.POST("/:id/documents", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("staff_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), staffHandler.UploadStaffDocument)
			staff.GET("/:id/leave-balances", staffHandler.GetStaffLeaveBalance)
			staff.GET("/:id/attendance", staffHandler.GetStaffAttendance)
		}

		students := api.Group("/students")
		students.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			students.GET("", studentHandler.GetStudents)
			students.GET("/:id", studentHandler.GetStudent)
			students.POST("", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.CreateStudent)
			students.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.UpdateStudent)
			students.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.DeleteStudent)
			students.POST("/:id/photo", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.UploadStudentPhoto)
			students.POST("/:id/documents", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.UploadStudentDocument)
			students.PUT("/:id/parent", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), parentLinkHandler.SetStudentParent)
			students.GET("/:id/enrollments", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), studentHandler.GetStudentEnrollments)
			students.POST("/enrollments", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentHandler.CreateEnrollment)
			students.GET("/:id/attendance", studentHandler.GetStudentAttendance)
			students.GET("/:id/fees", studentHandler.GetStudentFees)
			students.GET("/:id/marks", studentHandler.GetStudentMarks)
			students.GET("/:id/progress", studentHandler.GetStudentProgress)
			students.POST("/:id/guardians", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), guardianHandler.LinkGuardianToStudent)
			students.GET("/:id/guardians", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), guardianHandler.GetGuardiansByStudent)
		}

		accountApprovals := api.Group("/account-approvals")
		accountApprovals.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			accountApprovals.GET("", middleware.RBACMiddleware("Admin", "Principal"), accountApprovalHandler.List)
			accountApprovals.PUT("/:id", middleware.RBACMiddleware("Principal"), accountApprovalHandler.Decide)
			accountApprovals.PATCH("/:id", middleware.RBACMiddleware("Principal"), accountApprovalHandler.Decide)
		}

		classApprovals := api.Group("/class-approvals")
		classApprovals.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			classApprovals.GET("", middleware.RBACMiddleware("Admin", "Principal"), classApprovalHandler.List)
			classApprovals.POST("", middleware.RBACMiddleware("Admin"), classApprovalHandler.Create)
			classApprovals.PUT("/:id", middleware.RBACMiddleware("Principal"), classApprovalHandler.Decide)
			classApprovals.PATCH("/:id", middleware.RBACMiddleware("Principal"), classApprovalHandler.Decide)
		}

		studentApprovals := api.Group("/student-approvals")
		studentApprovals.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			studentApprovals.GET("", middleware.RBACMiddleware("Admin", "Principal"), studentApprovalHandler.List)
			studentApprovals.POST("", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentApprovalHandler.Create)
			studentApprovals.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentApprovalHandler.Decide)
			studentApprovals.PATCH("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentApprovalHandler.Decide)
		}

		approvals := api.Group("/approvals")
		approvals.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			approvals.GET("", middleware.RBACMiddleware("Admin", "Principal"), approvalRequestHandler.List)
			approvals.GET("/:id", middleware.RBACMiddleware("Admin", "Principal"), approvalRequestHandler.Get)
			approvals.POST("", middleware.RBACMiddleware("Admin"), approvalRequestHandler.Create)
			approvals.PUT("/:id", middleware.RBACMiddleware("Admin"), approvalRequestHandler.Update)
			approvals.PATCH("/:id", middleware.RBACMiddleware("Admin"), approvalRequestHandler.Update)
			approvals.POST("/:id/submit", middleware.RBACMiddleware("Admin"), approvalRequestHandler.Submit)
			approvals.POST("/:id/approve", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Approve)
			approvals.POST("/:id/reject", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Reject)
			approvals.POST("/:id/request-changes", middleware.RBACMiddleware("Principal"), approvalRequestHandler.RequestChanges)
			approvals.POST("/:id/cancel", middleware.RBACMiddleware("Admin"), approvalRequestHandler.Cancel)
			approvals.POST("/:id/apply", middleware.RBACMiddleware("Principal"), approvalRequestHandler.Apply)
		}

		attendance := api.Group("/attendance")
		attendance.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			attendance.GET("/sessions", attendanceHandler.GetAttendanceSessions)
			attendance.POST("/sessions", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("attendance_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), attendanceHandler.CreateAttendanceSession)
			attendance.POST("/sessions/:session_id/mark", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("attendance_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), attendanceHandler.MarkStudentAttendance)
			attendance.GET("/summary", attendanceHandler.GetStudentAttendanceSummary)
			attendance.GET("/staff", middleware.RBACMiddleware("Admin", "Principal"), attendanceHandler.ListStaffAttendance)
			attendance.GET("/staff/qr-token", middleware.RBACMiddleware("Admin", "Principal"), attendanceHandler.GetStaffQRToken)
			attendance.POST("/staff/qr-scan", middleware.RBACMiddleware("Teacher"), middleware.RateLimitMiddleware("attendance_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), attendanceHandler.ScanStaffQR)
			attendance.GET("/staff/me/today", middleware.RBACMiddleware("Teacher"), attendanceHandler.GetMyStaffAttendanceToday)
			attendance.POST("/staff", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("attendance_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), attendanceHandler.MarkStaffAttendance)
			attendance.GET("/reports/exports", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.List("attendance_reports"))
			attendance.POST("/reports/exports", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.Create("attendance_reports"))
			attendance.GET("/reports/exports/:id", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.Get)
			attendanceTable := tableCRUD("attendance")
			attendance.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), attendanceTable.List)
			attendance.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), attendanceTable.Create)
			attendance.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), attendanceTable.Get)
			attendance.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), attendanceTable.Update)
			attendance.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), attendanceTable.Update)
			attendance.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), attendanceTable.Delete)
		}

		exams := api.Group("/exams")
		exams.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			exams.GET("/types", examHandler.GetExamTypes)
			exams.POST("/types", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.CreateExamType)
			exams.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), examHandler.GetExams)
			exams.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), examHandler.GetExam)
			exams.GET("/:id/rankings", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), examHandler.GetClassRanking)
			exams.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.CreateExam)
			exams.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.UpdateExam)
			exams.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.UpdateExam)
			exams.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.DeleteExam)
			exams.PATCH("/:id/publish", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.PublishExam)
			exams.GET("/schedules", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), aliasHandler.ListExamSchedules)
			exams.POST("/schedules", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.CreateExamSchedule)
			exams.GET("/schedules/:schedule_id/marks", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), examHandler.GetScheduleMarks)
			exams.POST("/schedules/:schedule_id/marks", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.EnterMarks)
			exams.GET("/report-cards", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), examHandler.GetReportCards)
			exams.GET("/report-cards/exports", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), reportExportHandler.List("report_cards"))
			exams.POST("/report-cards/exports", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), reportExportHandler.Create("report_cards"))
			exams.GET("/report-cards/exports/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), reportExportHandler.Get)
			exams.GET("/grading-scale", examHandler.GetGradingScale)
		}

		fees := api.Group("/fees")
		fees.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			fees.GET("/categories", feeHandler.GetFeeCategories)
			fees.POST("/categories", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.CreateFeeCategory)
			fees.DELETE("/categories/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.DeleteFeeCategory)
			fees.GET("/structures", feeHandler.GetFeeStructures)
			fees.POST("/structures", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.CreateFeeStructure)
			fees.PUT("/structures/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.UpdateFeeStructure)
			fees.PATCH("/structures/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.UpdateFeeStructure)
			fees.DELETE("/structures/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.DeleteFeeStructure)
			fees.GET("/invoices", feeHandler.GetInvoices)
			fees.POST("/invoices/generate", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.GenerateInvoices)
			fees.POST("/invoices", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.CreateInvoice)
			fees.POST("/payments", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.RecordPayment)
			fees.GET("/payment-requests", middleware.RBACMiddleware("Admin", "Principal", "Parent"), feeHandler.GetPaymentRequests)
			fees.POST("/payment-requests", middleware.RBACMiddleware("Parent"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.CreateParentPaymentRequest)
			fees.PUT("/payment-requests/:id/decision", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.DecideParentPaymentRequest)
			fees.PATCH("/payment-requests/:id/decision", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeHandler.DecideParentPaymentRequest)
			feeConcessions := handlers.NewFrontendRecordHandler("fees/concessions")
			fees.GET("/concessions", middleware.RBACMiddleware("Admin", "Principal", "Parent"), feeConcessions.List)
			fees.POST("/concessions", middleware.RBACMiddleware("Admin", "Principal", "Parent"), feeConcessions.Create)
			fees.PUT("/concessions/:id/decision", middleware.RBACMiddleware("Admin", "Principal"), feeConcessions.Update)
			fees.PATCH("/concessions/:id/decision", middleware.RBACMiddleware("Admin", "Principal"), feeConcessions.Update)
			fees.DELETE("/concessions/:id", middleware.RBACMiddleware("Admin", "Principal"), feeConcessions.Delete)
			fees.POST("/reminders", middleware.RBACMiddleware("Admin", "Principal"), aliasHandler.QueueFeeReminders)
			fees.GET("/reports/exports", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.List("fee_reports"))
			fees.POST("/reports/exports", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.Create("fee_reports"))
			fees.GET("/reports/exports/:id", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.Get)
			feeTable := tableCRUD("fees")
			fees.GET("", middleware.RBACMiddleware("Admin", "Principal", "Parent"), feeTable.List)
			fees.POST("", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeTable.Create)
			fees.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Parent"), feeTable.Get)
			fees.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeTable.Update)
			fees.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeTable.Update)
			fees.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("fee_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), feeTable.Delete)
		}

		reports := api.Group("/reports")
		reports.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			reports.GET("/exports", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.List("general_reports"))
			reports.POST("/exports", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.Create("general_reports"))
			reports.GET("/exports/:id", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.Get)
		}

		studentReports := api.Group("/student-reports")
		studentReports.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			studentReports.GET("/exports", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.List("student_reports"))
			studentReports.POST("/exports", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.Create("student_reports"))
			studentReports.GET("/exports/:id", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.Get)
		}

		leave := api.Group("/leave")
		leave.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			leave.GET("/types", leaveHandler.GetLeaveTypes)
			leave.POST("/types", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.CreateLeaveType)
			leave.GET("/applications", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), leaveHandler.GetLeaveApplications)
			leave.POST("/applications", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.CreateLeaveApplication)
			leave.PUT("/applications/:id/approve", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.ApproveLeaveApplication)
			leave.POST("/applications/:id/recall", middleware.RBACMiddleware("Teacher"), teacherSelfHandler.RecallLeaveApplication)
			leave.GET("/balances", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), leaveHandler.GetLeaveBalances)
			leave.POST("/balances/initialize", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.InitializeLeaveBalances)
		}

		studentLeave := api.Group("/student-leave")
		studentLeave.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			studentLeave.GET("/applications", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), leaveHandler.GetStudentLeaveApplications)
			studentLeave.POST("/applications", middleware.RBACMiddleware("Parent"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.CreateStudentLeaveApplication)
			studentLeave.PUT("/applications/:id/decision", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.DecideStudentLeaveApplication)
			studentLeave.PATCH("/applications/:id/decision", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.DecideStudentLeaveApplication)
		}

		leaves := api.Group("/leaves")
		leaves.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(leaves, "leaves", []string{"Admin", "Principal", "Teacher", "Parent"}, []string{"Admin", "Principal", "Teacher", "Parent"})
		}

		timetable := api.Group("/timetable")
		timetable.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			timetable.GET("/slots", timetableHandler.GetTimetableSlots)
			timetable.GET("/templates", middleware.RBACMiddleware("Admin", "Principal"), timetableHandler.GetTimetableTemplates)
			timetable.PUT("/templates", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SaveTimetableTemplate)
			timetable.GET("/constraints", middleware.RBACMiddleware("Admin", "Principal"), timetableHandler.GetTimetableConstraints)
			timetable.POST("/constraints", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateTimetableConstraint)
			timetable.PUT("/constraints/:id", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.UpdateTimetableConstraint)
			timetable.DELETE("/constraints/:id", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.DeleteTimetableConstraint)
			timetable.POST("/smart/preview", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SmartTimetablePreview)
			timetable.POST("/smart/generate", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SmartTimetableGenerate)
			timetable.GET("/smart/jobs/:id", middleware.RBACMiddleware("Admin"), timetableHandler.GetSmartTimetableJob)
			timetable.POST("/smart/validate", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SmartTimetableValidate)
			timetable.POST("/suggestions", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SuggestTimetableSlots)
			timetable.POST("/slots/generate", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.GenerateTimetableSlots)
			timetable.POST("/slots", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateTimetableSlot)
			timetable.PUT("/slots/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.UpdateTimetableSlot)
			timetable.POST("/slots/swap", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SwapTimetableSlots)
			timetable.POST("/slots/:id/override", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.OverrideTimetableSlot)
			timetable.DELETE("/slots/:id", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.DeleteTimetableSlot)
			timetable.GET("/substitutions", timetableHandler.GetSubstitutions)
			timetable.POST("/substitutions", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateSubstitution)
			timetable.GET("/exports", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.List("timetable_reports"))
			timetable.POST("/exports", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateTimetableExport)
			timetable.GET("/section/:section_id", timetableHandler.GetTimetableBySection)
		}

		announcements := api.Group("/announcements")
		announcements.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			announcements.GET("", announcementHandler.GetAnnouncements)
			announcements.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("announcement_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), announcementHandler.CreateAnnouncement)
		}

		notices := api.Group("/notices")
		notices.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			notices.GET("", announcementHandler.GetAnnouncements)
			notices.POST("", middleware.RBACMiddleware("Admin", "Principal"), aliasHandler.CreateNotice)
			notices.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), aliasHandler.PatchNotice)
			notices.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), aliasHandler.DeleteNotice)
		}

		events := api.Group("/events")
		events.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			eventTable := tableCRUD("events")
			events.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), eventTable.List)
			events.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), eventTable.Get)
			events.POST("", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("event_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), eventTable.Create)
			events.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("event_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), eventTable.Update)
			events.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("event_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), eventTable.Update)
			events.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), eventTable.Delete)
		}

		notifications := api.Group("/notifications")
		notifications.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			notificationTable := tableCRUD("notifications")
			notifications.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), announcementHandler.GetNotifications)
			notifications.POST("", middleware.RBACMiddleware("Admin", "Principal"), announcementHandler.CreateNotification)
			notifications.POST("/device-tokens", middleware.RateLimitMiddleware("notification_device_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), notificationDeviceHandler.UpsertDeviceToken)
			notifications.DELETE("/device-tokens", middleware.RateLimitMiddleware("notification_device_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), notificationDeviceHandler.RevokeDeviceToken)
			notifications.PUT("/:id/read", announcementHandler.MarkNotificationRead)
			notifications.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), notificationTable.Get)
			notifications.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), notificationTable.Update)
			notifications.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), notificationTable.Update)
			notifications.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), notificationTable.Delete)
		}

		holidays := api.Group("/holidays")
		holidays.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(holidays, "holidays", []string{"Admin", "Principal", "Teacher", "Parent"}, []string{"Admin", "Principal"})
		}

		parents := api.Group("/parents")
		parents.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			parents.POST("/:parent_user_id/students", middleware.RBACMiddleware("Admin", "Principal"), parentLinkHandler.AssignParentStudents)
			parents.GET("/:parent_user_id/students", middleware.RBACMiddleware("Admin", "Principal"), parentLinkHandler.GetParentStudents)
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
			users.GET("", middleware.RBACMiddleware("Admin", "Principal"), userHandler.GetUsers)
			users.POST("", middleware.RBACMiddleware("Admin", "Principal"), userManagementHandler.CreateUser)
			users.GET("/:id", middleware.RBACMiddleware("Admin", "Principal"), userManagementHandler.GetUser)
			users.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), userManagementHandler.PatchUser)
			users.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), userManagementHandler.PatchUser)
			users.POST("/:id/avatar", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("user_avatar_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), userManagementHandler.UploadAvatar)
			users.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), userManagementHandler.DeleteUser)
		}

		guardians := api.Group("/guardians")
		guardians.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.Guardian]("guardians", "guardians", []string{"full_name"}, true, "Students")
			guardians.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("guardians", "read"), h.List)
			guardians.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("guardians", "read"), h.Get)
			guardians.POST("", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("guardians", "create"), h.Create)
			guardians.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("guardians", "update"), h.Update)
			guardians.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("guardians", "delete"), h.Delete)
		}

		medicalRecords := api.Group("/medical-records")
		medicalRecords.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.MedicalRecord]("medical_records", "medical_records", []string{"student_id"}, false, "Student")
			medicalRecords.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("medical_records", "read"), h.List)
			medicalRecords.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("medical_records", "read"), h.Get)
			medicalRecords.POST("", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("medical_records", "create"), h.Create)
			medicalRecords.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("medical_records", "update"), h.Update)
			medicalRecords.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("medical_records", "delete"), h.Delete)
		}

		studentDocuments := api.Group("/student-documents")
		studentDocuments.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.StudentDocument]("student_documents", "student_documents", []string{"student_id", "doc_type", "file_url"}, false, "Student")
			studentDocuments.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("student_documents", "read"), h.List)
			studentDocuments.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("student_documents", "read"), h.Get)
			studentDocuments.POST("", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("student_documents", "create"), h.Create)
			studentDocuments.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("student_documents", "update"), h.Update)
			studentDocuments.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("student_documents", "delete"), h.Delete)
		}

		staffDocuments := api.Group("/staff-documents")
		staffDocuments.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.StaffDocument]("staff_documents", "staff_documents", []string{"staff_id", "doc_type", "file_url"}, false, "Staff")
			staffDocuments.GET("", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("staff_documents", "read"), h.List)
			staffDocuments.GET("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("staff_documents", "read"), h.Get)
			staffDocuments.POST("", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("staff_documents", "create"), h.Create)
			staffDocuments.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("staff_documents", "update"), h.Update)
			staffDocuments.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("staff_documents", "delete"), h.Delete)
		}

		staffSubjects := api.Group("/staff-subjects")
		staffSubjects.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.StaffSubject]("staff_subjects", "staff_subjects", []string{"academic_year_id", "staff_id", "subject_id", "grade_id"}, true, "AcademicYear", "Staff", "Subject", "Grade", "Section")
			staffSubjects.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("staff_subjects", "read"), h.List)
			staffSubjects.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("staff_subjects", "read"), h.Get)
			staffSubjects.POST("", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("staff_subjects", "create"), h.Create)
			staffSubjects.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("staff_subjects", "update"), h.Update)
			staffSubjects.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("staff_subjects", "delete"), h.Delete)
		}

		staffQualifications := api.Group("/staff-qualifications")
		staffQualifications.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.StaffQualification]("staff_qualifications", "staff_qualifications", []string{"staff_id", "degree"}, false, "Staff")
			staffQualifications.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("staff_qualifications", "read"), h.List)
			staffQualifications.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("staff_qualifications", "read"), h.Get)
			staffQualifications.POST("", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("staff_qualifications", "create"), h.Create)
			staffQualifications.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("staff_qualifications", "update"), h.Update)
			staffQualifications.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("staff_qualifications", "delete"), h.Delete)
		}

		// Library and transport route groups are intentionally not registered in
		// the current product scope. Historical schema models remain for data
		// preservation, but no active API surface is exposed.

		payroll := api.Group("/payroll")
		payroll.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.Payroll]("payroll", "payrolls", []string{"staff_id", "academic_year_id", "month", "year"}, false, "Staff", "AcademicYear")
			payroll.GET("", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("payroll", "read"), h.List)
			payroll.GET("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("payroll", "read"), h.Get)
			payroll.POST("", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("payroll", "create"), h.Create)
			payroll.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("payroll", "update"), h.Update)
			payroll.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("payroll", "delete"), h.Delete)
		}

		ptm := api.Group("/parent-teacher-meetings")
		ptm.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.ParentTeacherMeeting]("parent_teacher_meetings", "parent_teacher_meetings", []string{"event_id", "section_id", "teacher_id", "guardian_id", "student_id"}, false, "Event", "Section", "Teacher", "Guardian", "Student")
			ptm.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("parent_teacher_meetings", "read"), h.List)
			ptm.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("parent_teacher_meetings", "read"), h.Get)
			ptm.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("parent_teacher_meetings", "create"), h.Create)
			ptm.PUT("/:id/book", middleware.RBACMiddleware("Parent"), ptmHandler.Book)
			ptm.PATCH("/:id/book", middleware.RBACMiddleware("Parent"), ptmHandler.Book)
			ptm.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("parent_teacher_meetings", "update"), h.Update)
			ptm.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("parent_teacher_meetings", "delete"), h.Delete)
		}

		auditLogs := api.Group("/audit-logs")
		auditLogs.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			auditLogs.GET("", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("audit_logs", "read"), auditLogHandler.List)
		}

		homework := api.Group("/homework")
		homework.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			homeworkTable := tableCRUD("homework")
			homework.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("homework", "read"), homeworkTable.List)
			homework.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("homework", "read"), homeworkTable.Get)
			homework.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("homework", "create"), homeworkTable.Create)
			homework.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("homework", "update"), homeworkTable.Update)
			homework.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("homework", "update"), homeworkTable.Update)
			homework.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("homework", "delete"), homeworkTable.Delete)
			homework.GET("/:id/submissions", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("homework", "read"), homeworkSubmissionHandler.List)
			homework.POST("/:id/submissions", middleware.RBACMiddleware("Parent"), homeworkSubmissionHandler.Submit)
			homework.PUT("/:id/submissions/:submission_id/review", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("homework", "update"), homeworkSubmissionHandler.Review)
			homework.PATCH("/:id/submissions/:submission_id/review", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("homework", "update"), homeworkSubmissionHandler.Review)
			homework.POST("/:id/attachment-requests", middleware.RBACMiddleware("Parent"), handlers.NewFrontendRecordHandler("homework/attachment-requests").Create)
		}

		diary := api.Group("/diary-entries")
		diary.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.DiaryEntry]("diary_entries", "diary_entries", []string{"title"}, true)
			diary.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("diary_entries", "read"), h.List)
			diary.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("diary_entries", "read"), h.Get)
			diary.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("diary_entries", "create"), h.Create)
			diary.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("diary_entries", "update"), h.Update)
			diary.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.PermissionMiddleware("diary_entries", "delete"), h.Delete)
		}

		conversations := api.Group("/message-conversations")
		conversations.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.MessageConversation]("message_conversations", "message_conversations", []string{"teacher_id", "parent_id"}, true)
			conversations.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("message_conversations", "read"), h.List)
			conversations.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("message_conversations", "read"), h.Get)
			conversations.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("message_conversations", "create"), h.Create)
			conversations.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("message_conversations", "update"), h.Update)
			conversations.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("message_conversations", "delete"), h.Delete)
		}

		messages := api.Group("/messages")
		messages.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			h := handlers.NewCRUDHandler[models.Message]("messages", "messages", []string{"conversation_id", "sender_id", "sender_role", "body"}, false)
			messages.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("messages", "read"), h.List)
			messages.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("messages", "read"), h.Get)
			messages.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("messages", "create"), h.Create)
			messages.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), middleware.PermissionMiddleware("messages", "update"), h.Update)
			messages.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.PermissionMiddleware("messages", "delete"), h.Delete)
		}

		approvalRequests := api.Group("/approval-requests")
		approvalRequests.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(approvalRequests, "approval_requests", []string{"Admin", "Principal", "Teacher"}, []string{"Admin", "Principal", "Teacher"})
		}

		communications := api.Group("/communications")
		communications.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(communications, "communications", []string{"Admin", "Principal", "Teacher", "Parent"}, []string{"Admin", "Principal", "Teacher", "Parent"})
		}

		principalReports := api.Group("/principal-reports")
		principalReports.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			registerTableCRUD(principalReports, "principal_reports", []string{"Admin", "Principal"}, []string{"Admin", "Principal"})
		}

		frontendResource("/admissions/applications", "Admin", "Principal")
		frontendResource("/certificates/transfer-requests", "Admin", "Principal")
		frontendResource("/events/approvals", "Admin", "Principal")
		frontendResource("/timetable/approvals", "Admin", "Principal")
		frontendResource("/principal/timetable-advice", "Admin", "Principal")
		frontendResource("/principal/exam-advice", "Admin", "Principal")
		frontendResource("/documents/requests", "Admin", "Principal")
		frontendResource("/documents/access-requests", "Admin", "Principal", "Parent")
		frontendResource("/certificates/requests", "Admin", "Principal", "Parent")
		frontendResource("/student-notes", "Admin", "Principal", "Teacher")
		frontendResource("/student-alerts", "Admin", "Principal", "Teacher")
		frontendResource("/notice-acknowledgements", "Admin", "Principal", "Teacher", "Parent")
		frontendResource("/documents", "Admin", "Principal", "Teacher", "Parent")
		frontendResource("/threads", "Admin", "Principal", "Teacher", "Parent")
		frontendResource("/curriculum", "Admin", "Principal", "Teacher", "Parent")
		frontendResource("/syllabus", "Admin", "Principal", "Teacher", "Parent")
		frontendResource("/complaints", "Admin", "Principal", "Teacher")
		frontendResource("/discipline-incidents", "Admin", "Principal", "Teacher", "Parent")
		frontendResource("/helpdesk-tickets", "Admin", "Principal", "Teacher", "Parent")
		api.POST("/documents/requests/:id/prints", middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware(), middleware.RBACMiddleware("Admin", "Principal"), handlers.NewFrontendRecordHandler("documents/requests/prints").Create)
	}

}
