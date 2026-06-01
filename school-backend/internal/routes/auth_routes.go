package routes

import (
	"time"

	"school-backend/internal/config"
	"school-backend/internal/handlers"
	"school-backend/internal/middleware"

	"github.com/gin-gonic/gin"
)

func registerAuthRoutes(
	api *gin.RouterGroup,
	cfg *config.Config,
	authHandler *handlers.AuthHandler,
) {
	auth := api.Group("/auth")
	auth.POST(
		"/login",
		middleware.RateLimitMiddleware(
			"auth_login",
			cfg.RateLimitMaxLogin,
			time.Duration(cfg.RateLimitWindowSeconds)*time.Second,
		),
		authHandler.Login,
	)
	auth.POST("/refresh", authHandler.Refresh)
	auth.POST("/logout", middleware.AuthMiddleware(), authHandler.Logout)
	auth.POST(
		"/password",
		middleware.AuthMiddleware(),
		middleware.RateLimitMiddleware(
			"auth_password",
			cfg.RateLimitMaxLogin,
			time.Duration(cfg.RateLimitWindowSeconds)*time.Second,
		),
		authHandler.ChangePassword,
	)
	if !cfg.DisablePublicRegistration {
		auth.POST(
			"/register",
			middleware.RateLimitMiddleware(
				"auth_register",
				cfg.RateLimitMaxAPI,
				time.Duration(cfg.RateLimitWindowSeconds)*time.Second,
			),
			authHandler.Register,
		)
	}
	auth.GET("/profile", middleware.AuthMiddleware(), authHandler.GetProfile)
	auth.PATCH(
		"/profile",
		middleware.AuthMiddleware(),
		authHandler.UpdateProfile,
	)
	auth.POST("/profile/avatar", middleware.AuthMiddleware(), authHandler.UploadProfileAvatar)
}
