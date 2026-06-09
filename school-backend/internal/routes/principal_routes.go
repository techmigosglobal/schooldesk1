package routes

import (
	"time"

	"school-backend/internal/config"
	"school-backend/internal/handlers"
	"school-backend/internal/middleware"

	"github.com/gin-gonic/gin"
)

func registerPrincipalRoutes(
	api *gin.RouterGroup,
	cfg *config.Config,
	principalClassesHandler *handlers.PrincipalClassesHandler,
	principalSubjectsHandler *handlers.PrincipalSubjectsHandler,
	principalAcademicCommandHandler *handlers.PrincipalAcademicCommandHandler,
) {
	principal := api.Group("/principal")
	principal.Use(
		middleware.AuthMiddleware(),
		middleware.SchoolScopeMiddleware(),
		middleware.RBACMiddleware("Principal"),
	)

	principal.GET("/classes", principalClassesHandler.Overview)
	principal.POST("/classes", middleware.RateLimitMiddleware("principal_class_create", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalClassesHandler.CreateClass)
	principal.POST(
		"/classes/import/dry-run",
		middleware.RateLimitMiddleware(
			"principal_class_import_dry_run",
			cfg.RateLimitMaxAPI,
			time.Duration(cfg.RateLimitWindowSeconds)*time.Second,
		),
		principalClassesHandler.DryRunClassCsvImport,
	)
	principal.POST(
		"/classes/import",
		middleware.RateLimitMiddleware(
			"principal_class_import",
			cfg.RateLimitMaxAPI,
			time.Duration(cfg.RateLimitWindowSeconds)*time.Second,
		),
		principalClassesHandler.ImportClassCsv,
	)
	principal.PUT(
		"/classes/:section_id",
		middleware.RateLimitMiddleware(
			"principal_class_update",
			cfg.RateLimitMaxAPI,
			time.Duration(cfg.RateLimitWindowSeconds)*time.Second,
		),
		principalClassesHandler.UpdateClassSetup,
	)
	principal.PATCH(
		"/classes/:section_id",
		middleware.RateLimitMiddleware(
			"principal_class_update",
			cfg.RateLimitMaxAPI,
			time.Duration(cfg.RateLimitWindowSeconds)*time.Second,
		),
		principalClassesHandler.UpdateClassSetup,
	)
	principal.DELETE(
		"/classes/:section_id",
		middleware.RateLimitMiddleware(
			"principal_class_delete",
			cfg.RateLimitMaxAPI,
			time.Duration(cfg.RateLimitWindowSeconds)*time.Second,
		),
		principalClassesHandler.DeleteClass,
	)
	principal.POST("/classes/:section_id/instructions", middleware.RateLimitMiddleware("principal_class_instruction", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalClassesHandler.CreateInstruction)

	principal.GET("/subjects", principalSubjectsHandler.Overview)
	principal.POST("/subjects/:subject_id/mappings", middleware.RateLimitMiddleware("principal_subject_mapping", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalSubjectsHandler.SaveMapping)
	principal.POST("/subjects/:subject_id/actions", middleware.RateLimitMiddleware("principal_subject_action", cfg.RateLimitMaxAPI, time.Duration(cfg.RateLimitWindowSeconds)*time.Second), principalSubjectsHandler.CreateAction)

	principal.GET("/timetable", principalAcademicCommandHandler.TimetableOverview)
	principal.POST(
		"/timetable/actions",
		middleware.RateLimitMiddleware(
			"principal_timetable_action",
			cfg.RateLimitMaxAPI,
			time.Duration(cfg.RateLimitWindowSeconds)*time.Second,
		),
		principalAcademicCommandHandler.SaveTimetableAction,
	)
	principal.GET("/exams", principalAcademicCommandHandler.ExamsOverview)
	principal.POST(
		"/exams/actions",
		middleware.RateLimitMiddleware(
			"principal_exam_action",
			cfg.RateLimitMaxAPI,
			time.Duration(cfg.RateLimitWindowSeconds)*time.Second,
		),
		principalAcademicCommandHandler.SaveExamAction,
	)
	principal.GET("/results", principalAcademicCommandHandler.ResultsOverview)
	principal.POST(
		"/results/actions",
		middleware.RateLimitMiddleware(
			"principal_result_action",
			cfg.RateLimitMaxAPI,
			time.Duration(cfg.RateLimitWindowSeconds)*time.Second,
		),
		principalAcademicCommandHandler.SaveResultAction,
	)
}
