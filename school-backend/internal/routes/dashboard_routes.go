package routes

import (
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
