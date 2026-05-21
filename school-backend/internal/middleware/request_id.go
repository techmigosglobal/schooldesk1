package middleware

import (
	"encoding/json"
	"log"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const requestIDHeader = "X-Request-ID"

func RequestIDMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		requestID := c.GetHeader(requestIDHeader)
		if requestID == "" {
			requestID = uuid.NewString()
		}
		c.Set("request_id", requestID)
		c.Writer.Header().Set(requestIDHeader, requestID)
		c.Next()
	}
}

func RequestLogMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		fields := map[string]interface{}{
			"event":      "http_request",
			"request_id": c.GetString("request_id"),
			"method":     c.Request.Method,
			"path":       c.FullPath(),
			"status":     c.Writer.Status(),
			"latency_ms": time.Since(start).Milliseconds(),
			"role":       c.GetString("role_name"),
			"user_id":    c.GetString("user_id"),
			"client_ip":  c.ClientIP(),
		}
		if fields["path"] == "" {
			fields["path"] = c.Request.URL.Path
		}
		encoded, err := json.Marshal(fields)
		if err != nil {
			log.Printf("http_request request_id=%s method=%s path=%s status=%d latency_ms=%d",
				c.GetString("request_id"),
				c.Request.Method,
				c.Request.URL.Path,
				c.Writer.Status(),
				time.Since(start).Milliseconds(),
			)
			return
		}
		log.Println(string(encoded))
	}
}
