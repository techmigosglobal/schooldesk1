package handlers

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type ErrorEventHandler struct{}

func NewErrorEventHandler() *ErrorEventHandler {
	return &ErrorEventHandler{}
}

type errorEventRequest struct {
	Source     string                 `json:"source"`
	Severity   string                 `json:"severity"`
	RequestID  string                 `json:"request_id"`
	ErrorID    string                 `json:"error_id"`
	Method     string                 `json:"method"`
	Path       string                 `json:"path"`
	RouteName  string                 `json:"route_name"`
	Screen     string                 `json:"screen"`
	Message    string                 `json:"message"`
	ErrorType  string                 `json:"error_type"`
	StackTrace string                 `json:"stack_trace"`
	StatusCode int                    `json:"status_code"`
	Metadata   map[string]interface{} `json:"metadata"`
	AppVersion string                 `json:"app_version"`
	DeviceInfo string                 `json:"device_info"`
	OccurredAt *time.Time             `json:"occurred_at"`
}

type resolveErrorEventRequest struct {
	ResolutionNote string `json:"resolution_note"`
}

func (h *ErrorEventHandler) Create(c *gin.Context) {
	var req errorEventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, "Invalid error event payload")
		return
	}
	if strings.TrimSpace(req.Message) == "" {
		fail(c, http.StatusBadRequest, "Error message is required")
		return
	}

	event := models.ErrorEvent{
		SchoolID:     scopedSchoolID(c),
		UserID:       c.GetString("user_id"),
		Role:         c.GetString("role_name"),
		Source:       cleanErrorChoice(req.Source, "flutter"),
		Severity:     cleanErrorChoice(req.Severity, "error"),
		Status:       "open",
		RequestID:    firstNonEmptyErrorValue(req.RequestID, c.GetString("request_id")),
		ErrorID:      firstNonEmptyErrorValue(req.ErrorID, newErrorID()),
		Method:       truncateErrorText(req.Method, 16),
		Path:         truncateErrorText(req.Path, 300),
		RouteName:    truncateErrorText(req.RouteName, 200),
		Screen:       truncateErrorText(req.Screen, 200),
		Message:      truncateErrorText(req.Message, 2000),
		ErrorType:    truncateErrorText(req.ErrorType, 200),
		StackTrace:   truncateErrorText(req.StackTrace, 12000),
		StatusCode:   req.StatusCode,
		MetadataJSON: sanitizeErrorMetadata(req.Metadata),
		AppVersion:   truncateErrorText(req.AppVersion, 80),
		DeviceInfo:   truncateErrorText(req.DeviceInfo, 500),
		OccurredAt:   time.Now().UTC(),
	}
	if req.OccurredAt != nil && !req.OccurredAt.IsZero() {
		event.OccurredAt = req.OccurredAt.UTC()
	}

	if err := database.DB.Create(&event).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to store error event")
		return
	}
	success(c, http.StatusCreated, event, "Error event recorded")
}

func (h *ErrorEventHandler) List(c *gin.Context) {
	page, pageSize := parsePagination(c)
	offset := (page - 1) * pageSize
	var rows []models.ErrorEvent
	var total int64
	query := database.DB.Model(&models.ErrorEvent{}).
		Where("school_id = ?", scopedSchoolID(c)).
		Order("created_at DESC")

	for _, field := range []string{"source", "severity", "status", "role", "request_id", "error_id"} {
		if value := strings.TrimSpace(c.Query(field)); value != "" {
			query = query.Where(field+" = ?", value)
		}
	}
	if err := query.Count(&total).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to count error events")
		return
	}
	if err := query.Offset(offset).Limit(pageSize).Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to list error events")
		return
	}
	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, rows))
}

func (h *ErrorEventHandler) Get(c *gin.Context) {
	var event models.ErrorEvent
	if err := database.DB.Where("school_id = ? AND (id = ? OR error_id = ?)", scopedSchoolID(c), c.Param("id"), c.Param("id")).First(&event).Error; err != nil {
		fail(c, http.StatusNotFound, "Error event not found")
		return
	}
	success(c, http.StatusOK, event, "")
}

func (h *ErrorEventHandler) Resolve(c *gin.Context) {
	var req resolveErrorEventRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, "Invalid resolve payload")
		return
	}
	var event models.ErrorEvent
	if err := database.DB.Where("school_id = ? AND (id = ? OR error_id = ?)", scopedSchoolID(c), c.Param("id"), c.Param("id")).First(&event).Error; err != nil {
		fail(c, http.StatusNotFound, "Error event not found")
		return
	}
	now := time.Now().UTC()
	resolvedBy := c.GetString("user_id")
	event.Status = "resolved"
	event.ResolvedAt = &now
	event.ResolvedBy = &resolvedBy
	event.ResolutionNote = truncateErrorText(req.ResolutionNote, 1000)
	if err := database.DB.Save(&event).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to resolve error event")
		return
	}
	success(c, http.StatusOK, event, "Error event resolved")
}

func sanitizeErrorMetadata(metadata map[string]interface{}) string {
	if len(metadata) == 0 {
		return "{}"
	}
	clean := make(map[string]interface{}, len(metadata))
	for key, value := range metadata {
		lower := strings.ToLower(key)
		if strings.Contains(lower, "token") ||
			strings.Contains(lower, "password") ||
			strings.Contains(lower, "secret") ||
			strings.Contains(lower, "authorization") {
			clean[key] = "[redacted]"
			continue
		}
		clean[key] = value
	}
	encoded, err := json.Marshal(clean)
	if err != nil {
		return "{}"
	}
	return truncateErrorText(string(encoded), 4000)
}

func newErrorID() string {
	return "ERR-" + time.Now().UTC().Format("20060102") + "-" + strings.ToUpper(strings.ReplaceAll(uuid.NewString()[:8], "-", ""))
}

func cleanErrorChoice(value, fallback string) string {
	value = strings.TrimSpace(strings.ToLower(value))
	if value == "" {
		return fallback
	}
	return truncateErrorText(value, 40)
}

func firstNonEmptyErrorValue(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func truncateErrorText(value string, max int) string {
	value = strings.TrimSpace(value)
	if max <= 0 || len(value) <= max {
		return value
	}
	return value[:max]
}
