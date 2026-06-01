package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"school-backend/internal/config"
	"school-backend/internal/database"
	"school-backend/internal/middleware"
	"school-backend/internal/platform"
	"school-backend/internal/routes"
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
	middleware.SetDevMode(cfg.Environment != "production")

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

	routes.RegisterOperationalRoutes(r, cfg)

	routes.RegisterV1Routes(r, cfg)

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
