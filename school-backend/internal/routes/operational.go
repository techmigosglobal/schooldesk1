package routes

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/config"
	"school-backend/internal/database"
	"school-backend/internal/middleware"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
)

func RegisterOperationalRoutes(r *gin.Engine, cfg *config.Config) {
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
