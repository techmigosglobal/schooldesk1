package routes

import (
	"time"

	"school-backend/internal/config"
	"school-backend/internal/handlers"
	"school-backend/internal/middleware"

	"github.com/gin-gonic/gin"
)

func registerDashboardRoutes(
	api *gin.RouterGroup,
	cfg *config.Config,
	dashboardHandler *handlers.DashboardHandler,
) {
	dashboard := api.Group("/dashboard")
	dashboard.Use(middleware.AuthMiddleware(), middleware.SchoolScopeMiddleware())
	dashboard.GET(
		"/admin",
		middleware.RBACMiddleware("Admin"),
		middleware.PermissionMiddleware("dashboard", "read"),
		middleware.CacheMiddleware(
			"dashboard_admin",
			time.Duration(cfg.CacheTTLSeconds)*time.Second,
		),
		dashboardHandler.Admin,
	)
	dashboard.GET(
		"/principal",
		middleware.RBACMiddleware("Principal"),
		middleware.PermissionMiddleware("dashboard", "read"),
		dashboardHandler.Principal,
	)
	dashboard.GET(
		"/teacher",
		middleware.RBACMiddleware("Teacher"),
		middleware.PermissionMiddleware("dashboard", "read"),
		dashboardHandler.Teacher,
	)
	dashboard.GET(
		"/parent",
		middleware.RBACMiddleware("Parent"),
		middleware.PermissionMiddleware("dashboard", "read"),
		dashboardHandler.Parent,
	)
}
