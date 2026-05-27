package middleware

import (
	"fmt"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/gin-gonic/gin"
)

type httpMetricKey struct {
	Method      string
	Path        string
	StatusClass string
}

type httpMetricValue struct {
	Requests      atomic.Uint64
	LatencyMicros atomic.Uint64
	Errors        atomic.Uint64
}

var httpMetrics sync.Map

func MetricsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()

		path := c.FullPath()
		if strings.TrimSpace(path) == "" {
			path = c.Request.URL.Path
		}
		status := c.Writer.Status()
		key := httpMetricKey{
			Method:      c.Request.Method,
			Path:        path,
			StatusClass: fmt.Sprintf("%dxx", status/100),
		}
		value := loadHTTPMetricValue(key)
		value.Requests.Add(1)
		value.LatencyMicros.Add(uint64(time.Since(start).Microseconds()))
		if status >= 400 {
			value.Errors.Add(1)
		}
	}
}

func PrometheusHTTPMetrics() string {
	type row struct {
		Key   httpMetricKey
		Value *httpMetricValue
	}
	rows := []row{}
	httpMetrics.Range(func(key, value any) bool {
		k, okKey := key.(httpMetricKey)
		v, okValue := value.(*httpMetricValue)
		if okKey && okValue {
			rows = append(rows, row{Key: k, Value: v})
		}
		return true
	})
	sort.Slice(rows, func(i, j int) bool {
		a := rows[i].Key
		b := rows[j].Key
		if a.Path != b.Path {
			return a.Path < b.Path
		}
		if a.Method != b.Method {
			return a.Method < b.Method
		}
		return a.StatusClass < b.StatusClass
	})

	var b strings.Builder
	b.WriteString("# HELP schooldesk_http_requests_total Total HTTP requests by method, path, and status class.\n")
	b.WriteString("# TYPE schooldesk_http_requests_total counter\n")
	b.WriteString("# HELP schooldesk_http_request_duration_seconds Total and count of HTTP request duration.\n")
	b.WriteString("# TYPE schooldesk_http_request_duration_seconds summary\n")
	b.WriteString("# HELP schooldesk_http_errors_total Total HTTP 4xx/5xx responses by method, path, and status class.\n")
	b.WriteString("# TYPE schooldesk_http_errors_total counter\n")
	for _, row := range rows {
		labels := fmt.Sprintf(
			`method="%s",path="%s",status_class="%s"`,
			metricLabel(row.Key.Method),
			metricLabel(row.Key.Path),
			metricLabel(row.Key.StatusClass),
		)
		requests := row.Value.Requests.Load()
		latencySeconds := float64(row.Value.LatencyMicros.Load()) / 1_000_000
		b.WriteString(fmt.Sprintf("schooldesk_http_requests_total{%s} %d\n", labels, requests))
		b.WriteString(fmt.Sprintf("schooldesk_http_request_duration_seconds_sum{%s} %.6f\n", labels, latencySeconds))
		b.WriteString(fmt.Sprintf("schooldesk_http_request_duration_seconds_count{%s} %d\n", labels, requests))
		if errors := row.Value.Errors.Load(); errors > 0 {
			b.WriteString(fmt.Sprintf("schooldesk_http_errors_total{%s} %d\n", labels, errors))
		}
	}
	return b.String()
}

func loadHTTPMetricValue(key httpMetricKey) *httpMetricValue {
	value, _ := httpMetrics.LoadOrStore(key, &httpMetricValue{})
	return value.(*httpMetricValue)
}

func metricLabel(value string) string {
	value = strings.ReplaceAll(value, `\`, `\\`)
	value = strings.ReplaceAll(value, `"`, `\"`)
	value = strings.ReplaceAll(value, "\n", "")
	return value
}
