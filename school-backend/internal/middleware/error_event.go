package middleware

import (
	"encoding/json"
	"fmt"
	"log"
	"runtime/debug"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const errorIDHeader = "X-Error-ID"

func ErrorEventMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if recovered := recover(); recovered != nil {
				errorID := recordBackendErrorEvent(
					c,
					"fatal",
					500,
					fmt.Sprint(recovered),
					string(debug.Stack()),
				)
				c.Header(errorIDHeader, errorID)
				c.AbortWithStatusJSON(500, gin.H{
					"success":    false,
					"message":    "Internal server error",
					"error":      "Internal server error",
					"error_id":   errorID,
					"request_id": c.GetString("request_id"),
				})
			}
		}()

		c.Next()

		status := c.Writer.Status()
		if status < 500 {
			return
		}
		message := "Server returned HTTP " + fmt.Sprint(status)
		if len(c.Errors) > 0 {
			message = c.Errors.String()
		}
		errorID := recordBackendErrorEvent(c, "error", status, message, "")
		if errorID != "" {
			c.Header(errorIDHeader, errorID)
		}
	}
}

func recordBackendErrorEvent(c *gin.Context, severity string, statusCode int, message string, stackTrace string) string {
	errorID := newMiddlewareErrorID()
	if database.DB == nil {
		return errorID
	}
	path := c.FullPath()
	if path == "" && c.Request != nil && c.Request.URL != nil {
		path = c.Request.URL.Path
	}
	metadata, _ := json.Marshal(gin.H{
		"client_ip":  c.ClientIP(),
		"user_agent": c.GetHeader("User-Agent"),
	})
	event := models.ErrorEvent{
		SchoolID:     c.GetString("school_id"),
		UserID:       c.GetString("user_id"),
		Role:         c.GetString("role_name"),
		Source:       "backend",
		Severity:     severity,
		Status:       "open",
		RequestID:    c.GetString("request_id"),
		ErrorID:      errorID,
		Method:       c.Request.Method,
		Path:         truncateMiddlewareText(path, 300),
		Message:      truncateMiddlewareText(message, 2000),
		ErrorType:    "http_500",
		StackTrace:   truncateMiddlewareText(stackTrace, 12000),
		StatusCode:   statusCode,
		MetadataJSON: string(metadata),
		OccurredAt:   time.Now().UTC(),
	}
	if err := database.DB.Create(&event).Error; err != nil {
		log.Printf("failed to persist error event request_id=%s error_id=%s: %v", event.RequestID, errorID, err)
	}
	return errorID
}

func newMiddlewareErrorID() string {
	return "ERR-" + time.Now().UTC().Format("20060102") + "-" + strings.ToUpper(strings.ReplaceAll(uuid.NewString()[:8], "-", ""))
}

func truncateMiddlewareText(value string, max int) string {
	value = strings.TrimSpace(value)
	if max <= 0 || len(value) <= max {
		return value
	}
	return value[:max]
}
