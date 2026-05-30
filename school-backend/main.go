package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"school-backend/internal/config"
	"school-backend/internal/database"
	"school-backend/internal/handlers"
	"school-backend/internal/middleware"
	"school-backend/internal/models"
	"school-backend/internal/platform"
	"school-backend/internal/services"
	"school-backend/internal/worker"

	"github.com/gin-gonic/gin"
)

func main() {
	cfg := config.Load()
	if err := cfg.Validate(); err != nil {
		log.Fatalf("Configuration validation failed: %v", err)
	}
	middleware.SetJWTSecret(cfg.JWTSecret)
	middleware.SetAllowedOrigins(cfg.AllowedOrigins)

	redisClient, err := platform.NewRedisClient(cfg)
	if err != nil {
		if cfg.Environment == "production" {
			log.Fatalf("Failed to initialize redis: %v", err)
		}
		log.Printf("Redis unavailable, running without redis-backed features: %v", err)
	} else {
		services.Cache = services.NewCacheService(redisClient, cfg.Environment)
		services.Rate = services.NewRateLimitService(redisClient, cfg.Environment)
		services.Sessions = services.NewSessionStore(redisClient, cfg.Environment)
		services.Queue = services.NewJobQueue(redisClient, cfg.Environment)
	}

	if err := database.Initialize(cfg); err != nil {
		log.Fatalf("Failed to initialize database: %v", err)
	}
	if cfg.EnableFCMPush && cfg.AppMode == "worker" {
		push, err := services.NewFirebasePushSender(context.Background(), cfg.FirebaseProjectID)
		if err != nil {
			if cfg.Environment == "production" {
				log.Fatalf("Failed to initialize FCM push sender: %v", err)
			}
			log.Printf("FCM push disabled: %v", err)
		} else {
			services.Push = push
			log.Println("FCM push sender initialized")
		}
	}

	if cfg.AppMode == "worker" {
		if err := worker.RunNotificationWorker(); err != nil {
			log.Fatalf("Worker failed: %v", err)
		}
		return
	}

	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	r.Use(
		middleware.RequestIDMiddleware(),
		middleware.MetricsMiddleware(),
		middleware.RequestLogMiddleware(),
		middleware.CORSMiddleware(),
	)

	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"message":   "School Desk Backend API",
			"version":   "1.0.0",
			"status":    "running",
			"endpoints": "/api/v1/*path",
		})
	})

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "healthy"})
	})
	r.GET("/ready", func(c *gin.Context) {
		payload, status := readinessPayload(cfg)
		c.JSON(status, payload)
	})
	r.GET("/metrics", func(c *gin.Context) {
		payload, _ := readinessPayload(cfg)
		dbUp := 0
		redisUp := 0
		if payload["database"] == "ok" {
			dbUp = 1
		}
		if payload["redis"] == "ok" {
			redisUp = 1
		}
		metrics := strings.Builder{}
		metrics.WriteString("# HELP schooldesk_backend_up Backend process health.\n")
		metrics.WriteString("# TYPE schooldesk_backend_up gauge\n")
		metrics.WriteString("schooldesk_backend_up 1\n")
		metrics.WriteString("# HELP schooldesk_database_up Database readiness.\n")
		metrics.WriteString("# TYPE schooldesk_database_up gauge\n")
		metrics.WriteString(fmt.Sprintf("schooldesk_database_up %d\n", dbUp))
		metrics.WriteString("# HELP schooldesk_redis_up Redis readiness.\n")
		metrics.WriteString("# TYPE schooldesk_redis_up gauge\n")
		metrics.WriteString(fmt.Sprintf("schooldesk_redis_up %d\n", redisUp))
		metrics.WriteString(prometheusDatabaseMetrics())
		metrics.WriteString(prometheusQueueMetrics())
		metrics.WriteString(middleware.PrometheusHTTPMetrics())
		c.Header("Content-Type", "text/plain; version=0.0.4")
		c.String(200, metrics.String())
	})
	r.Static("/uploads", "./uploads")

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
	accountApprovalHandler := handlers.NewAccountApprovalHandler()
	classApprovalHandler := handlers.NewClassApprovalHandler()
	studentApprovalHandler := handlers.NewStudentApprovalHandler()
	auditLogHandler := handlers.NewAuditLogHandler()
	dashboardHandler := handlers.NewDashboardHandler()
	principalClassesHandler := handlers.NewPrincipalClassesHandler()
	principalSubjectsHandler := handlers.NewPrincipalSubjectsHandler()
	principalAcademicCommandHandler := handlers.NewPrincipalAcademicCommandHandler()
	assistantWorkflowHandler := handlers.NewAssistantWorkflowHandler()
	reportExportHandler := handlers.NewReportExportHandler()
	compatHandler := handlers.NewCompatibilityHandler()
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
		auth := api.Group("/auth")
		{
			auth.POST("/login", middleware.RateLimitMiddleware("auth_login", cfg.RateLimitMaxLogin, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), authHandler.Login)
			auth.POST("/refresh", authHandler.Refresh)
			auth.POST("/logout", middleware.AuthMiddleware(), authHandler.Logout)
			auth.POST("/password", middleware.AuthMiddleware(), middleware.RateLimitMiddleware("auth_password", cfg.RateLimitMaxLogin, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), authHandler.ChangePassword)
			if !cfg.DisablePublicRegistration {
				auth.POST("/register", middleware.RateLimitMiddleware("auth_register", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), authHandler.Register)
			}
			auth.GET("/profile", middleware.AuthMiddleware(), authHandler.GetProfile)
			auth.PATCH("/profile", middleware.AuthMiddleware(), authHandler.UpdateProfile)
			auth.POST("/profile/avatar", middleware.AuthMiddleware(), authHandler.UploadProfileAvatar)
		}

		dashboard := api.Group("/dashboard")
		dashboard.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			dashboard.GET("/admin", middleware.RBACMiddleware("Admin"), middleware.PermissionMiddleware("dashboard", "read"), middleware.CacheMiddleware("dashboard_admin", time.Duration(cfg.CacheTTLSeconds)*time.Second), dashboardHandler.Admin)
			dashboard.GET("/principal", middleware.RBACMiddleware("Principal"), middleware.PermissionMiddleware("dashboard", "read"), dashboardHandler.Principal)
			dashboard.GET("/teacher", middleware.RBACMiddleware("Teacher"), middleware.PermissionMiddleware("dashboard", "read"), dashboardHandler.Teacher)
			dashboard.GET("/parent", middleware.RBACMiddleware("Parent"), middleware.PermissionMiddleware("dashboard", "read"), dashboardHandler.Parent)
		}

		principal := api.Group("/principal")
		principal.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware(), middleware.RBACMiddleware("Principal"))
		{
			principal.GET("/classes", principalClassesHandler.Overview)
			principal.POST("/classes", middleware.RateLimitMiddleware("principal_class_create", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalClassesHandler.CreateClass)
			principal.PUT("/classes/:section_id", middleware.RateLimitMiddleware("principal_class_update", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalClassesHandler.UpdateClassSetup)
			principal.PATCH("/classes/:section_id", middleware.RateLimitMiddleware("principal_class_update", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalClassesHandler.UpdateClassSetup)
			principal.POST("/classes/:section_id/instructions", middleware.RateLimitMiddleware("principal_class_instruction", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalClassesHandler.CreateInstruction)
			principal.GET("/subjects", principalSubjectsHandler.Overview)
			principal.POST("/subjects/:subject_id/mappings", middleware.RateLimitMiddleware("principal_subject_mapping", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalSubjectsHandler.SaveMapping)
			principal.POST("/subjects/:subject_id/actions", middleware.RateLimitMiddleware("principal_subject_action", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalSubjectsHandler.CreateAction)
			principal.GET("/timetable", principalAcademicCommandHandler.TimetableOverview)
			principal.POST("/timetable/actions", middleware.RateLimitMiddleware("principal_timetable_action", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalAcademicCommandHandler.SaveTimetableAction)
			principal.GET("/exams", principalAcademicCommandHandler.ExamsOverview)
			principal.POST("/exams/actions", middleware.RateLimitMiddleware("principal_exam_action", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalAcademicCommandHandler.SaveExamAction)
			principal.GET("/results", principalAcademicCommandHandler.ResultsOverview)
			principal.POST("/results/actions", middleware.RateLimitMiddleware("principal_result_action", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalAcademicCommandHandler.SaveResultAction)
		}

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
			h := handlers.NewCRUDHandler[models.GradeSubject]("grade_subjects", "grade_subjects", []string{"grade_id", "subject_id"}, false, "Grade", "Subject")
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

		studentApprovals := api.Group("/student-approvals")
		studentApprovals.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			studentApprovals.GET("", middleware.RBACMiddleware("Admin", "Principal"), studentApprovalHandler.List)
			studentApprovals.POST("", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentApprovalHandler.Create)
			studentApprovals.PUT("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentApprovalHandler.Decide)
			studentApprovals.PATCH("/:id", middleware.RBACMiddleware("Principal"), middleware.RateLimitMiddleware("student_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), studentApprovalHandler.Decide)
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
			exams.POST("/types", middleware.RBACMiddleware("Admin"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.CreateExamType)
			exams.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), examHandler.GetExams)
			exams.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), examHandler.GetExam)
			exams.GET("/:id/rankings", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), examHandler.GetClassRanking)
			exams.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.CreateExam)
			exams.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.UpdateExam)
			exams.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.UpdateExam)
			exams.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.DeleteExam)
			exams.PATCH("/:id/publish", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("exam_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), examHandler.PublishExam)
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
			fees.GET("/concessions", feeHandler.GetConcessions)
			fees.POST("/reminders", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.QueueFeeReminders)
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
			timetable.PUT("/templates", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SaveTimetableTemplate)
			timetable.GET("/constraints", middleware.RBACMiddleware("Admin", "Principal"), timetableHandler.GetTimetableConstraints)
			timetable.POST("/constraints", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateTimetableConstraint)
			timetable.PUT("/constraints/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.UpdateTimetableConstraint)
			timetable.DELETE("/constraints/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.DeleteTimetableConstraint)
			timetable.POST("/smart/preview", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SmartTimetablePreview)
			timetable.POST("/smart/generate", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SmartTimetableGenerate)
			timetable.GET("/smart/jobs/:id", middleware.RBACMiddleware("Admin", "Principal"), timetableHandler.GetSmartTimetableJob)
			timetable.POST("/smart/validate", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SmartTimetableValidate)
			timetable.POST("/suggestions", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SuggestTimetableSlots)
			timetable.POST("/slots/generate", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.GenerateTimetableSlots)
			timetable.POST("/slots", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateTimetableSlot)
			timetable.PUT("/slots/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.UpdateTimetableSlot)
			timetable.POST("/slots/swap", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.SwapTimetableSlots)
			timetable.POST("/slots/:id/override", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.OverrideTimetableSlot)
			timetable.DELETE("/slots/:id", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.DeleteTimetableSlot)
			timetable.GET("/substitutions", timetableHandler.GetSubstitutions)
			timetable.POST("/substitutions", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateSubstitution)
			timetable.GET("/exports", middleware.RBACMiddleware("Admin", "Principal"), reportExportHandler.List("timetable_reports"))
			timetable.POST("/exports", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("timetable_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), timetableHandler.CreateTimetableExport)
			timetable.GET("/section/:section_id", timetableHandler.GetTimetableBySection)
		}

		announcements := api.Group("/announcements")
		announcements.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			announcements.GET("", announcementHandler.GetAnnouncements)
			announcements.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), middleware.RateLimitMiddleware("announcement_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), announcementHandler.CreateAnnouncement)
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
		}

		users := api.Group("/users")
		users.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			users.GET("", middleware.RBACMiddleware("Admin", "Principal"), userHandler.GetUsers)
			users.POST("", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.CreateUser)
			users.GET("/:id", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.GetUser)
			users.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.PatchUser)
			users.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.PatchUser)
			users.POST("/:id/avatar", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("user_avatar_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), userHandler.UploadUserAvatar)
			users.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.DeleteUser)
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
			h := handlers.NewCRUDHandler[models.StaffSubject]("staff_subjects", "staff_subjects", []string{"staff_id", "subject_id", "grade_id"}, false, "Staff", "Subject", "Grade", "Section")
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
	}

	compatAPI := r.Group("/api")
	{
		auth := compatAPI.Group("/auth")
		{
			auth.POST("/login", middleware.RateLimitMiddleware("auth_login", cfg.RateLimitMaxLogin, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), authHandler.Login)
			auth.POST("/refresh", authHandler.Refresh)
			auth.POST("/logout", middleware.AuthMiddleware(), authHandler.Logout)
			auth.POST("/password", middleware.AuthMiddleware(), middleware.RateLimitMiddleware("auth_password", cfg.RateLimitMaxLogin, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), authHandler.ChangePassword)
			auth.GET("/me", middleware.AuthMiddleware(), authHandler.GetProfile)
			auth.GET("/profile", middleware.AuthMiddleware(), authHandler.GetProfile)
			auth.PATCH("/profile", middleware.AuthMiddleware(), authHandler.UpdateProfile)
			auth.POST("/profile/avatar", middleware.AuthMiddleware(), authHandler.UploadProfileAvatar)
		}

		protected := compatAPI.Group("")
		protected.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
		{
			users := protected.Group("/users")
			{
				users.GET("", middleware.RBACMiddleware("Admin", "Principal"), userHandler.GetUsers)
				users.POST("", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.CreateUser)
				users.GET("/:id", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.GetUser)
				users.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.PatchUser)
				users.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.PatchUser)
				users.POST("/:id/avatar", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("user_avatar_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), userHandler.UploadUserAvatar)
				users.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.DeleteUser)
			}

			me := protected.Group("/me")
			{
				me.GET("/students", parentLinkHandler.GetMyStudents)
			}

			principalCompat := protected.Group("/principal")
			principalCompat.Use(middleware.RBACMiddleware("Principal"))
			{
				principalCompat.GET("/classes", principalClassesHandler.Overview)
				principalCompat.POST("/classes", middleware.RateLimitMiddleware("principal_class_create", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalClassesHandler.CreateClass)
				principalCompat.POST("/classes/:section_id/instructions", middleware.RateLimitMiddleware("principal_class_instruction", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalClassesHandler.CreateInstruction)
				principalCompat.GET("/subjects", principalSubjectsHandler.Overview)
				principalCompat.POST("/subjects/:subject_id/mappings", middleware.RateLimitMiddleware("principal_subject_mapping", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalSubjectsHandler.SaveMapping)
				principalCompat.POST("/subjects/:subject_id/actions", middleware.RateLimitMiddleware("principal_subject_action", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalSubjectsHandler.CreateAction)
				principalCompat.GET("/timetable", principalAcademicCommandHandler.TimetableOverview)
				principalCompat.POST("/timetable/actions", middleware.RateLimitMiddleware("principal_timetable_action", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalAcademicCommandHandler.SaveTimetableAction)
				principalCompat.GET("/exams", principalAcademicCommandHandler.ExamsOverview)
				principalCompat.POST("/exams/actions", middleware.RateLimitMiddleware("principal_exam_action", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalAcademicCommandHandler.SaveExamAction)
				principalCompat.GET("/results", principalAcademicCommandHandler.ResultsOverview)
				principalCompat.POST("/results/actions", middleware.RateLimitMiddleware("principal_result_action", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalAcademicCommandHandler.SaveResultAction)
			}

			schoolsCompat := protected.Group("/schools")
			{
				schoolsCompat.GET("", schoolHandler.GetSchools)
				schoolsCompat.GET("/current", schoolHandler.GetCurrentSchool)
				schoolsCompat.PATCH("/current", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateCurrentSchool)
				schoolsCompat.POST("/current/logo", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UploadCurrentSchoolLogo)
				schoolsCompat.GET("/:id", schoolHandler.GetSchool)
				schoolsCompat.POST("", middleware.RBACMiddleware("Admin"), schoolHandler.CreateSchool)
			}

			academicYearsCompat := protected.Group("/academic-years")
			{
				academicYearsCompat.GET("", schoolHandler.GetAcademicYears)
				academicYearsCompat.GET("/:id", schoolHandler.GetAcademicYear)
				academicYearsCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.CreateAcademicYear)
				academicYearsCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateAcademicYear)
				academicYearsCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateAcademicYear)
				academicYearsCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.DeleteAcademicYear)
				academicYearsCompat.GET("/:id/terms", schoolHandler.GetTerms)
			}

			students := protected.Group("/students")
			{
				students.GET("", studentHandler.GetStudents)
				students.POST("", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.CreateStudent)
				students.POST("/enrollments", middleware.RBACMiddleware("Admin", "Principal"), studentHandler.CreateEnrollment)
				students.GET("/:id", studentHandler.GetStudent)
				students.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), studentHandler.UpdateStudent)
				students.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), studentHandler.UpdateStudent)
				students.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), studentHandler.DeleteStudent)
				students.POST("/:id/photo", middleware.RBACMiddleware("Admin", "Principal"), studentHandler.UploadStudentPhoto)
				students.POST("/:id/documents", middleware.RBACMiddleware("Admin", "Principal"), studentHandler.UploadStudentDocument)
				students.PUT("/:id/parent", middleware.RBACMiddleware("Principal"), parentLinkHandler.SetStudentParent)
				students.GET("/:id/enrollments", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), studentHandler.GetStudentEnrollments)
				students.GET("/:id/attendance", studentHandler.GetStudentAttendance)
				students.GET("/:id/grades", compatHandler.GetStudentGrades)
				students.GET("/:id/marks", compatHandler.GetStudentGrades)
				students.GET("/:id/fees", studentHandler.GetStudentFees)
				students.GET("/:id/progress", studentHandler.GetStudentProgress)
				students.POST("/:id/guardians", middleware.RBACMiddleware("Admin", "Principal"), guardianHandler.LinkGuardianToStudent)
				students.GET("/:id/guardians", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), guardianHandler.GetGuardiansByStudent)
			}

			teachers := protected.Group("/teachers")
			{
				teachers.GET("", staffHandler.GetStaff)
				teachers.POST("", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.CreateStaff)
				teachers.GET("/:id", staffHandler.GetStaffMember)
				teachers.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.UpdateStaff)
				teachers.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.UpdateStaff)
				teachers.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.DeleteStaff)
				teachers.POST("/:id/photo", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.UploadStaffPhoto)
				teachers.POST("/:id/documents", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.UploadStaffDocument)
				teachers.GET("/:id/timetable", compatHandler.GetTeacherTimetable)
			}

			staffCompat := protected.Group("/staff")
			{
				staffCompat.GET("", staffHandler.GetStaff)
				staffCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.CreateStaff)
				staffCompat.GET("/:id", staffHandler.GetStaffMember)
				staffCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.UpdateStaff)
				staffCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.UpdateStaff)
				staffCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.DeleteStaff)
				staffCompat.POST("/:id/photo", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.UploadStaffPhoto)
				staffCompat.POST("/:id/documents", middleware.RBACMiddleware("Admin", "Principal"), staffHandler.UploadStaffDocument)
			}

			staffSubjectsCompat := protected.Group("/staff-subjects")
			{
				h := handlers.NewCRUDHandler[models.StaffSubject]("staff_subjects", "staff_subjects", []string{"staff_id", "subject_id", "grade_id"}, false, "Staff", "Subject", "Grade", "Section")
				staffSubjectsCompat.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), h.List)
				staffSubjectsCompat.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), h.Get)
				staffSubjectsCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), h.Create)
				staffSubjectsCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
				staffSubjectsCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
				staffSubjectsCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Delete)
			}

			staffDocumentsCompat := protected.Group("/staff-documents")
			{
				h := handlers.NewCRUDHandler[models.StaffDocument]("staff_documents", "staff_documents", []string{"staff_id", "doc_type", "file_url"}, false, "Staff")
				staffDocumentsCompat.GET("", middleware.RBACMiddleware("Admin", "Principal"), h.List)
				staffDocumentsCompat.GET("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Get)
				staffDocumentsCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), h.Create)
				staffDocumentsCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
				staffDocumentsCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
				staffDocumentsCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Delete)
			}

			guardiansCompat := protected.Group("/guardians")
			{
				h := handlers.NewCRUDHandler[models.Guardian]("guardians", "guardians", []string{"full_name"}, true, "Students")
				guardiansCompat.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.List)
				guardiansCompat.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Get)
				guardiansCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), h.Create)
				guardiansCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
				guardiansCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
				guardiansCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Delete)
			}

			classes := protected.Group("/classes")
			{
				classes.GET("", compatHandler.ListClasses)
				classes.POST("", middleware.RBACMiddleware("Principal"), compatHandler.CreateClass)
				classes.GET("/:id", compatHandler.GetClass)
				classes.PATCH("/:id", middleware.RBACMiddleware("Admin"), compatHandler.PatchClass)
				classes.DELETE("/:id", middleware.RBACMiddleware("Admin"), compatHandler.DeleteClass)
				classes.GET("/:id/students", compatHandler.GetClassStudents)
				classes.GET("/:id/timetable", compatHandler.GetClassTimetable)
			}

			sectionsCompat := protected.Group("/sections")
			{
				sectionsCompat.GET("", schoolHandler.GetSections)
				sectionsCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.CreateSection)
				sectionsCompat.GET("/:id", schoolHandler.GetSection)
				sectionsCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateSection)
				sectionsCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateSection)
				sectionsCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.DeleteSection)
			}

			attendance := protected.Group("/attendance")
			{
				attendance.GET("/sessions", attendanceHandler.GetAttendanceSessions)
				attendance.POST("/sessions", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), attendanceHandler.CreateAttendanceSession)
				attendance.POST("/sessions/:session_id/mark", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), attendanceHandler.MarkStudentAttendance)
				attendance.GET("/staff", middleware.RBACMiddleware("Admin", "Principal"), attendanceHandler.ListStaffAttendance)
				attendance.GET("/staff/qr-token", middleware.RBACMiddleware("Admin", "Principal"), attendanceHandler.GetStaffQRToken)
				attendance.POST("/staff/qr-scan", middleware.RBACMiddleware("Teacher"), attendanceHandler.ScanStaffQR)
				attendance.GET("/staff/me/today", middleware.RBACMiddleware("Teacher"), attendanceHandler.GetMyStaffAttendanceToday)
				attendance.POST("/staff", middleware.RBACMiddleware("Admin", "Principal"), attendanceHandler.MarkStaffAttendance)
				attendance.GET("/summary", compatHandler.GetAttendanceSummary)
				attendance.POST("/mark", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), compatHandler.MarkAttendance)
				attendance.GET("/class/:classId", compatHandler.GetClassAttendance)
				attendance.GET("/student/:studentId", compatHandler.GetStudentAttendance)
				attendance.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), compatHandler.PatchAttendance)
			}

			timetable := protected.Group("/timetable")
			{
				timetable.GET("/slots", compatHandler.ListTimetable)
				timetable.POST("/suggestions", middleware.RBACMiddleware("Admin", "Principal"), timetableHandler.SuggestTimetableSlots)
				timetable.POST("/slots/generate", middleware.RBACMiddleware("Admin", "Principal"), timetableHandler.GenerateTimetableSlots)
				timetable.POST("/slots", middleware.RBACMiddleware("Admin", "Principal"), timetableHandler.CreateTimetableSlot)
				timetable.PUT("/slots/:id", middleware.RBACMiddleware("Admin", "Principal"), timetableHandler.UpdateTimetableSlot)
				timetable.DELETE("/slots/:id", middleware.RBACMiddleware("Admin", "Principal"), timetableHandler.DeleteTimetableSlot)
				timetable.GET("/substitutions", timetableHandler.GetSubstitutions)
				timetable.POST("/substitutions", middleware.RBACMiddleware("Admin"), timetableHandler.CreateSubstitution)
				timetable.GET("/class/:classId", compatHandler.GetClassTimetable)
				timetable.GET("/teacher/:teacherId", compatHandler.GetTeacherTimetable)
				timetable.POST("", middleware.RBACMiddleware("Admin"), compatHandler.CreateTimetable)
				timetable.PATCH("/:id", middleware.RBACMiddleware("Admin"), compatHandler.PatchTimetable)
				timetable.DELETE("/:id", middleware.RBACMiddleware("Admin"), compatHandler.DeleteTimetable)
			}

			gradeMarks := protected.Group("/grades")
			{
				gradeMarks.GET("", schoolHandler.GetGrades)
				gradeMarks.POST("", middleware.RBACMiddleware("Principal"), schoolHandler.CreateGrade)
				gradeMarks.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateGrade)
				gradeMarks.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.DeleteGrade)
				gradeMarks.POST("/bulk", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), compatHandler.BulkGrades)
				gradeMarks.GET("/student/:studentId", compatHandler.GetGradesByStudent)
				gradeMarks.GET("/class/:classId", compatHandler.GetGradesByClass)
				gradeMarks.PATCH("/:id", middleware.RBACMiddleware("Admin", "Teacher"), compatHandler.PatchGrade)
			}

			examsCompat := protected.Group("/exams")
			{
				examsCompat.GET("", examHandler.GetExams)
				examsCompat.GET("/:id/rankings", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), examHandler.GetClassRanking)
				examsCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), examHandler.CreateExam)
				examsCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), examHandler.UpdateExam)
				examsCompat.PATCH("/:id/publish", middleware.RBACMiddleware("Admin", "Principal"), examHandler.PublishExam)
				examsCompat.GET("/types", examHandler.GetExamTypes)
				examsCompat.POST("/types", middleware.RBACMiddleware("Admin"), examHandler.CreateExamType)
				examsCompat.GET("/schedules", compatHandler.ListExamSchedules)
				examsCompat.POST("/schedules", middleware.RBACMiddleware("Admin", "Principal"), examHandler.CreateExamSchedule)
				examsCompat.GET("/schedules/:schedule_id/marks", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), examHandler.GetScheduleMarks)
				examsCompat.POST("/schedules/:schedule_id/marks", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), examHandler.EnterMarks)
				examsCompat.GET("/report-cards", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), examHandler.GetReportCards)
			}

			fees := protected.Group("/fees")
			{
				fees.GET("", compatHandler.ListFees)
				fees.GET("/invoices", feeHandler.GetInvoices)
				fees.GET("/categories", feeHandler.GetFeeCategories)
				fees.POST("/categories", middleware.RBACMiddleware("Admin", "Principal"), feeHandler.CreateFeeCategory)
				fees.DELETE("/categories/:id", middleware.RBACMiddleware("Admin", "Principal"), feeHandler.DeleteFeeCategory)
				fees.GET("/structures", feeHandler.GetFeeStructures)
				fees.POST("/structures", middleware.RBACMiddleware("Admin", "Principal"), feeHandler.CreateFeeStructure)
				fees.PUT("/structures/:id", middleware.RBACMiddleware("Admin", "Principal"), feeHandler.UpdateFeeStructure)
				fees.PATCH("/structures/:id", middleware.RBACMiddleware("Admin", "Principal"), feeHandler.UpdateFeeStructure)
				fees.DELETE("/structures/:id", middleware.RBACMiddleware("Admin", "Principal"), feeHandler.DeleteFeeStructure)
				fees.POST("/invoices/generate", middleware.RBACMiddleware("Admin", "Principal"), feeHandler.GenerateInvoices)
				fees.POST("/invoices", middleware.RBACMiddleware("Admin", "Principal"), feeHandler.CreateInvoice)
				fees.POST("/assign", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.AssignFee)
				fees.POST("/payments", middleware.RBACMiddleware("Admin", "Principal"), feeHandler.RecordPayment)
				fees.GET("/payment-requests", middleware.RBACMiddleware("Admin", "Principal", "Parent"), feeHandler.GetPaymentRequests)
				fees.POST("/payment-requests", middleware.RBACMiddleware("Parent"), feeHandler.CreateParentPaymentRequest)
				fees.PUT("/payment-requests/:id/decision", middleware.RBACMiddleware("Admin", "Principal"), feeHandler.DecideParentPaymentRequest)
				fees.PATCH("/payment-requests/:id/decision", middleware.RBACMiddleware("Admin", "Principal"), feeHandler.DecideParentPaymentRequest)
				fees.GET("/student/:studentId", compatHandler.GetStudentFees)
				fees.PATCH("/:id/pay", middleware.RBACMiddleware("Admin"), compatHandler.PayFee)
				fees.GET("/overdue", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.GetOverdueFees)
				fees.GET("/stats", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.GetFeeStats)
				fees.POST("/reminders", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.QueueFeeReminders)
			}

			leaveCompat := protected.Group("/leave")
			{
				leaveCompat.GET("/types", leaveHandler.GetLeaveTypes)
				leaveCompat.POST("/types", middleware.RBACMiddleware("Admin", "Principal"), middleware.RateLimitMiddleware("leave_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), leaveHandler.CreateLeaveType)
				leaveCompat.GET("/applications", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), leaveHandler.GetLeaveApplications)
				leaveCompat.POST("/applications", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), leaveHandler.CreateLeaveApplication)
				leaveCompat.PUT("/applications/:id/approve", middleware.RBACMiddleware("Admin", "Principal"), leaveHandler.ApproveLeaveApplication)
				leaveCompat.GET("/balances", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), leaveHandler.GetLeaveBalances)
			}

			studentLeaveCompat := protected.Group("/student-leave")
			{
				studentLeaveCompat.GET("/applications", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), leaveHandler.GetStudentLeaveApplications)
				studentLeaveCompat.POST("/applications", middleware.RBACMiddleware("Parent"), leaveHandler.CreateStudentLeaveApplication)
				studentLeaveCompat.PUT("/applications/:id/decision", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), leaveHandler.DecideStudentLeaveApplication)
				studentLeaveCompat.PATCH("/applications/:id/decision", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), leaveHandler.DecideStudentLeaveApplication)
			}

			announcementsCompat := protected.Group("/announcements")
			{
				announcementsCompat.GET("", announcementHandler.GetAnnouncements)
				announcementsCompat.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), announcementHandler.CreateAnnouncement)
			}

			eventsCompat := protected.Group("/events")
			{
				eventTable := tableCRUD("events")
				eventsCompat.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), eventTable.List)
				eventsCompat.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), eventTable.Get)
				eventsCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), eventTable.Create)
				eventsCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), eventTable.Update)
				eventsCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), eventTable.Update)
				eventsCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), eventTable.Delete)
			}

			notificationsCompat := protected.Group("/notifications")
			{
				notificationsCompat.GET("", announcementHandler.GetNotifications)
				notificationsCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), announcementHandler.CreateNotification)
				notificationsCompat.POST("/device-tokens", middleware.RateLimitMiddleware("notification_device_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), notificationDeviceHandler.UpsertDeviceToken)
				notificationsCompat.DELETE("/device-tokens", middleware.RateLimitMiddleware("notification_device_write", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), notificationDeviceHandler.RevokeDeviceToken)
				notificationsCompat.PUT("/:id/read", announcementHandler.MarkNotificationRead)
			}

			parentsCompat := protected.Group("/parents")
			{
				parentsCompat.POST("/:parent_user_id/students", middleware.RBACMiddleware("Admin", "Principal"), parentLinkHandler.AssignParentStudents)
				parentsCompat.GET("/:parent_user_id/students", middleware.RBACMiddleware("Admin", "Principal"), parentLinkHandler.GetParentStudents)
			}

			accountApprovalsCompat := protected.Group("/account-approvals")
			{
				accountApprovalsCompat.GET("", middleware.RBACMiddleware("Admin", "Principal"), accountApprovalHandler.List)
				accountApprovalsCompat.PUT("/:id", middleware.RBACMiddleware("Principal"), accountApprovalHandler.Decide)
				accountApprovalsCompat.PATCH("/:id", middleware.RBACMiddleware("Principal"), accountApprovalHandler.Decide)
			}

			classApprovalsCompat := protected.Group("/class-approvals")
			{
				classApprovalsCompat.GET("", middleware.RBACMiddleware("Admin", "Principal"), classApprovalHandler.List)
				classApprovalsCompat.POST("", middleware.RBACMiddleware("Admin"), classApprovalHandler.Create)
				classApprovalsCompat.PUT("/:id", middleware.RBACMiddleware("Principal"), classApprovalHandler.Decide)
				classApprovalsCompat.PATCH("/:id", middleware.RBACMiddleware("Principal"), classApprovalHandler.Decide)
			}

			studentApprovalsCompat := protected.Group("/student-approvals")
			{
				studentApprovalsCompat.GET("", middleware.RBACMiddleware("Admin", "Principal"), studentApprovalHandler.List)
				studentApprovalsCompat.POST("", middleware.RBACMiddleware("Admin"), studentApprovalHandler.Create)
				studentApprovalsCompat.PUT("/:id", middleware.RBACMiddleware("Principal"), studentApprovalHandler.Decide)
				studentApprovalsCompat.PATCH("/:id", middleware.RBACMiddleware("Principal"), studentApprovalHandler.Decide)
			}

			auditLogsCompat := protected.Group("/audit-logs")
			{
				auditLogsCompat.GET("", middleware.RBACMiddleware("Admin", "Principal"), auditLogHandler.List)
			}

			homeworkCompat := protected.Group("/homework")
			homeworkCompatTables := tableCRUD("homework")
			{
				homeworkCompat.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), homeworkCompatTables.List)
				homeworkCompat.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), homeworkCompatTables.Get)
				homeworkCompat.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), homeworkCompatTables.Create)
				homeworkCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), homeworkCompatTables.Update)
				homeworkCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), homeworkCompatTables.Update)
				homeworkCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), homeworkCompatTables.Delete)
				homeworkCompat.GET("/:id/submissions", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), homeworkSubmissionHandler.List)
				homeworkCompat.POST("/:id/submissions", middleware.RBACMiddleware("Parent"), homeworkSubmissionHandler.Submit)
				homeworkCompat.PUT("/:id/submissions/:submission_id/review", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), homeworkSubmissionHandler.Review)
				homeworkCompat.PATCH("/:id/submissions/:submission_id/review", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), homeworkSubmissionHandler.Review)
			}

			diaryCompat := protected.Group("/diary-entries")
			{
				h := handlers.NewCRUDHandler[models.DiaryEntry]("diary_entries", "diary_entries", []string{"title"}, true)
				diaryCompat.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.List)
				diaryCompat.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Get)
				diaryCompat.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), h.Create)
				diaryCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), h.Update)
				diaryCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), h.Update)
				diaryCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), h.Delete)
			}

			conversationsCompat := protected.Group("/message-conversations")
			{
				h := handlers.NewCRUDHandler[models.MessageConversation]("message_conversations", "message_conversations", []string{"teacher_id", "parent_id"}, true)
				conversationsCompat.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.List)
				conversationsCompat.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Get)
				conversationsCompat.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Create)
				conversationsCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Update)
				conversationsCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Update)
				conversationsCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Delete)
			}

			messagesCompat := protected.Group("/messages")
			{
				h := handlers.NewCRUDHandler[models.Message]("messages", "messages", []string{"conversation_id", "sender_id", "sender_role", "body"}, false)
				messagesCompat.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.List)
				messagesCompat.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Get)
				messagesCompat.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Create)
				messagesCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Update)
				messagesCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Update)
				messagesCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Delete)
			}

			ptmCompat := protected.Group("/parent-teacher-meetings")
			{
				h := handlers.NewCRUDHandler[models.ParentTeacherMeeting]("parent_teacher_meetings", "parent_teacher_meetings", []string{"event_id", "section_id", "teacher_id", "guardian_id", "student_id"}, false, "Event", "Section", "Teacher", "Guardian", "Student")
				ptmCompat.GET("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.List)
				ptmCompat.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Get)
				ptmCompat.POST("", middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"), h.Create)
				ptmCompat.PUT("/:id/book", middleware.RBACMiddleware("Parent"), ptmHandler.Book)
				ptmCompat.PATCH("/:id/book", middleware.RBACMiddleware("Parent"), ptmHandler.Book)
				ptmCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), h.Update)
				ptmCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal", "Teacher"), h.Update)
				ptmCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Delete)
			}

			parentStudentLinksCompat := protected.Group("/parent-student-links")
			{
				h := handlers.NewCRUDHandler[models.ParentStudentLink]("parent_student_links", "parent_student_links", []string{"parent_user_id", "student_id", "student_admission_number"}, true, "Student", "ParentUser")
				parentStudentLinksCompat.GET("", middleware.RBACMiddleware("Admin", "Principal", "Parent"), h.List)
				parentStudentLinksCompat.GET("/:id", middleware.RBACMiddleware("Admin", "Principal", "Parent"), h.Get)
				parentStudentLinksCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), h.Create)
				parentStudentLinksCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
				parentStudentLinksCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
				parentStudentLinksCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Delete)
			}

			departmentsCompat := protected.Group("/departments")
			{
				departmentsCompat.GET("", schoolHandler.GetDepartments)
				departmentsCompat.POST("", middleware.RBACMiddleware("Admin"), schoolHandler.CreateDepartment)
			}

			subjectsCompat := protected.Group("/subjects")
			{
				subjectsCompat.GET("", schoolHandler.GetSubjects)
				subjectsCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.CreateSubject)
				subjectsCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateSubject)
				subjectsCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.UpdateSubject)
				subjectsCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), schoolHandler.DeleteSubject)
			}

			gradeSubjectsCompat := protected.Group("/grade-subjects")
			{
				h := handlers.NewCRUDHandler[models.GradeSubject]("grade_subjects", "grade_subjects", []string{"grade_id", "subject_id"}, false, "Grade", "Subject")
				gradeSubjectsCompat.GET("", middleware.RBACMiddleware("Admin", "Principal"), h.List)
				gradeSubjectsCompat.GET("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Get)
				gradeSubjectsCompat.POST("", middleware.RBACMiddleware("Admin", "Principal"), h.Create)
				gradeSubjectsCompat.PUT("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
				gradeSubjectsCompat.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Update)
				gradeSubjectsCompat.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), h.Delete)
			}

			termsCompat := protected.Group("/terms")
			{
				h := handlers.NewCRUDHandler[models.Term]("terms", "terms", []string{"academic_year_id", "term_number", "term_name"}, false, "AcademicYear")
				termsCompat.GET("", h.List)
				termsCompat.GET("/:id", h.Get)
				termsCompat.POST("", middleware.RBACMiddleware("Admin"), h.Create)
				termsCompat.PUT("/:id", middleware.RBACMiddleware("Admin"), h.Update)
				termsCompat.PATCH("/:id", middleware.RBACMiddleware("Admin"), h.Update)
				termsCompat.DELETE("/:id", middleware.RBACMiddleware("Admin"), h.Delete)
			}

			frontendResource := func(path string, allowedRoles ...string) {
				resource := strings.TrimPrefix(path, "/")
				h := handlers.NewFrontendRecordHandler(resource)
				group := protected.Group(path)
				if len(allowedRoles) > 0 {
					group.Use(middleware.RBACMiddleware(allowedRoles...))
				}
				group.GET("", h.List)
				group.POST("", h.Create)
				group.PUT("/:id", h.Update)
				group.PATCH("/:id", h.Update)
				group.DELETE("/:id", h.Delete)
			}
			reportExportResource := func(path, category string, allowedRoles ...string) {
				group := protected.Group(path)
				if len(allowedRoles) > 0 {
					group.Use(middleware.RBACMiddleware(allowedRoles...))
				}
				group.GET("", reportExportHandler.List(category))
				group.POST("", reportExportHandler.Create(category))
				group.GET("/:id", reportExportHandler.Get)
			}
			frontendResource("/approvals", "Admin", "Principal")
			frontendResource("/admissions/applications", "Admin", "Principal")
			frontendResource("/certificates/transfer-requests", "Admin", "Principal")
			frontendResource("/events/approvals", "Admin", "Principal")
			frontendResource("/timetable/approvals", "Admin", "Principal")
			frontendResource("/principal/timetable-advice", "Admin", "Principal")
			frontendResource("/principal/exam-advice", "Admin", "Principal")
			frontendResource("/documents/requests", "Admin", "Principal")
			frontendResource("/documents/access-requests", "Admin", "Principal", "Parent")
			frontendResource("/certificates/requests", "Admin", "Principal", "Parent")
			frontendResource("/student-documents", "Admin", "Principal", "Teacher", "Parent")
			frontendResource("/student-notes", "Admin", "Principal", "Teacher")
			frontendResource("/student-alerts", "Admin", "Principal", "Teacher")
			frontendResource("/notice-acknowledgements", "Admin", "Principal", "Teacher", "Parent")
			reportExportResource("/student-reports/exports", "student_reports", "Admin", "Principal")
			reportExportResource("/attendance/reports/exports", "attendance_reports", "Admin", "Principal")
			frontendResource("/documents", "Admin", "Principal", "Teacher", "Parent")
			frontendResource("/threads", "Admin", "Principal", "Teacher", "Parent")
			frontendResource("/curriculum", "Admin", "Principal", "Teacher", "Parent")
			syllabusCompat := handlers.NewFrontendRecordHandler("curriculum")
			syllabus := protected.Group("/syllabus")
			syllabus.Use(middleware.RBACMiddleware("Admin", "Principal", "Teacher", "Parent"))
			{
				syllabus.GET("", syllabusCompat.List)
				syllabus.POST("", syllabusCompat.Create)
				syllabus.PUT("/:id", syllabusCompat.Update)
				syllabus.PATCH("/:id", syllabusCompat.Update)
				syllabus.DELETE("/:id", syllabusCompat.Delete)
			}
			frontendResource("/complaints", "Admin", "Principal", "Teacher")
			frontendResource("/discipline-incidents", "Admin", "Principal", "Teacher", "Parent")
			frontendResource("/helpdesk-tickets", "Admin", "Principal", "Teacher", "Parent")
			reportExportResource("/reports/exports", "general_reports", "Admin", "Principal")

			feeConcessionsCompat := handlers.NewFrontendRecordHandler("fees/concessions")
			protected.GET("/fees/concessions", middleware.RBACMiddleware("Admin", "Principal"), feeConcessionsCompat.List)
			protected.POST("/fees/concessions", middleware.RBACMiddleware("Admin", "Principal", "Parent"), feeConcessionsCompat.Create)
			protected.PUT("/fees/concessions/:id/decision", middleware.RBACMiddleware("Admin", "Principal"), feeConcessionsCompat.Update)
			protected.PATCH("/fees/concessions/:id/decision", middleware.RBACMiddleware("Admin", "Principal"), feeConcessionsCompat.Update)
			protected.DELETE("/fees/concessions/:id", middleware.RBACMiddleware("Admin", "Principal"), feeConcessionsCompat.Delete)
			reportExportResource("/fees/reports/exports", "fee_reports", "Admin", "Principal")
			reportExportResource("/exams/report-cards/exports", "report_cards", "Admin", "Principal", "Teacher", "Parent")
			protected.POST("/documents/requests/:id/prints", middleware.RBACMiddleware("Admin", "Principal"), handlers.NewFrontendRecordHandler("documents/requests/prints").Create)
			protected.POST("/homework/:id/attachment-requests", middleware.RBACMiddleware("Parent"), handlers.NewFrontendRecordHandler("homework/attachment-requests").Create)

			notices := protected.Group("/notices")
			{
				notices.GET("", announcementHandler.GetAnnouncements)
				notices.POST("", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.CreateNotice)
				notices.PATCH("/:id", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.PatchNotice)
				notices.DELETE("/:id", middleware.RBACMiddleware("Admin", "Principal"), compatHandler.DeleteNotice)
			}

			dashboard := protected.Group("/dashboard")
			{
				dashboard.GET("/admin", middleware.RBACMiddleware("Admin"), middleware.CacheMiddleware("dashboard_admin", time.Duration(cfg.CacheTTLSeconds)*time.Second), dashboardHandler.Admin)
				dashboard.GET("/teacher", middleware.RBACMiddleware("Teacher"), dashboardHandler.Teacher)
				dashboard.GET("/parent", middleware.RBACMiddleware("Parent"), dashboardHandler.Parent)
				dashboard.GET("/student", middleware.RBACMiddleware("Parent"), compatHandler.StudentDashboard)
				dashboard.GET("/principal", middleware.RBACMiddleware("Principal"), dashboardHandler.Principal)
			}
		}
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = cfg.Port
	}

	log.Printf("School Desk Backend starting on port %s", port)
	srv := &http.Server{
		Addr:    ":" + port,
		Handler: r,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
	if redisClient != nil {
		_ = redisClient.Close()
	}
	if err := database.Close(); err != nil {
		log.Printf("Database close error: %v", err)
	}
	log.Println("School Desk Backend stopped")
}

func readinessPayload(cfg *config.Config) (gin.H, int) {
	status := http.StatusOK
	payload := gin.H{
		"status":      "ready",
		"database":    "ok",
		"redis":       "ok",
		"environment": cfg.Environment,
	}

	if database.DB == nil {
		payload["status"] = "not_ready"
		payload["database"] = "unavailable"
		return payload, http.StatusServiceUnavailable
	}
	sqlDB, err := database.DB.DB()
	if err != nil || sqlDB.Ping() != nil {
		payload["status"] = "not_ready"
		payload["database"] = "unavailable"
		status = http.StatusServiceUnavailable
	}

	if services.Cache == nil {
		payload["redis"] = "not_configured"
		if cfg.Environment == "production" {
			payload["status"] = "not_ready"
			status = http.StatusServiceUnavailable
		}
		return payload, status
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := services.Cache.Ping(ctx); err != nil {
		payload["redis"] = "unavailable"
		if cfg.Environment == "production" {
			payload["status"] = "not_ready"
			status = http.StatusServiceUnavailable
		}
	}

	return payload, status
}

func prometheusDatabaseMetrics() string {
	var b strings.Builder
	b.WriteString("# HELP schooldesk_db_open_connections Current open database connections.\n")
	b.WriteString("# TYPE schooldesk_db_open_connections gauge\n")
	b.WriteString("# HELP schooldesk_db_in_use_connections Current in-use database connections.\n")
	b.WriteString("# TYPE schooldesk_db_in_use_connections gauge\n")
	b.WriteString("# HELP schooldesk_db_idle_connections Current idle database connections.\n")
	b.WriteString("# TYPE schooldesk_db_idle_connections gauge\n")
	b.WriteString("# HELP schooldesk_db_wait_count_total Total waits for a database connection.\n")
	b.WriteString("# TYPE schooldesk_db_wait_count_total counter\n")
	b.WriteString("# HELP schooldesk_db_wait_duration_seconds_total Total time blocked waiting for database connections.\n")
	b.WriteString("# TYPE schooldesk_db_wait_duration_seconds_total counter\n")
	if database.DB == nil {
		b.WriteString("schooldesk_db_open_connections 0\n")
		b.WriteString("schooldesk_db_in_use_connections 0\n")
		b.WriteString("schooldesk_db_idle_connections 0\n")
		b.WriteString("schooldesk_db_wait_count_total 0\n")
		b.WriteString("schooldesk_db_wait_duration_seconds_total 0\n")
		return b.String()
	}
	sqlDB, err := database.DB.DB()
	if err != nil {
		b.WriteString("schooldesk_db_open_connections 0\n")
		b.WriteString("schooldesk_db_in_use_connections 0\n")
		b.WriteString("schooldesk_db_idle_connections 0\n")
		b.WriteString("schooldesk_db_wait_count_total 0\n")
		b.WriteString("schooldesk_db_wait_duration_seconds_total 0\n")
		return b.String()
	}
	stats := sqlDB.Stats()
	b.WriteString(fmt.Sprintf("schooldesk_db_open_connections %d\n", stats.OpenConnections))
	b.WriteString(fmt.Sprintf("schooldesk_db_in_use_connections %d\n", stats.InUse))
	b.WriteString(fmt.Sprintf("schooldesk_db_idle_connections %d\n", stats.Idle))
	b.WriteString(fmt.Sprintf("schooldesk_db_wait_count_total %d\n", stats.WaitCount))
	b.WriteString(fmt.Sprintf("schooldesk_db_wait_duration_seconds_total %.6f\n", stats.WaitDuration.Seconds()))
	return b.String()
}

func prometheusQueueMetrics() string {
	var b strings.Builder
	queueConfigured := 0
	if services.Queue != nil {
		queueConfigured = 1
	}
	b.WriteString("# HELP schooldesk_queue_configured Redis-backed job queue availability.\n")
	b.WriteString("# TYPE schooldesk_queue_configured gauge\n")
	b.WriteString(fmt.Sprintf("schooldesk_queue_configured %d\n", queueConfigured))
	b.WriteString("# HELP schooldesk_queue_pending_jobs Redis stream length by queue type.\n")
	b.WriteString("# TYPE schooldesk_queue_pending_jobs gauge\n")
	for _, queueType := range []string{"notifications", "fee_reminders"} {
		pending := int64(0)
		if services.Queue != nil {
			ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
			count, err := services.Queue.PendingLength(ctx, queueType)
			cancel()
			if err == nil {
				pending = count
			}
		}
		b.WriteString(fmt.Sprintf("schooldesk_queue_pending_jobs{queue=%q} %d\n", queueType, pending))
	}
	b.WriteString("# HELP schooldesk_notification_worker_failures_total Notification worker delivery failures.\n")
	b.WriteString("# TYPE schooldesk_notification_worker_failures_total counter\n")
	b.WriteString(fmt.Sprintf("schooldesk_notification_worker_failures_total %d\n", services.NotificationWorkerFailures()))
	return b.String()
}
