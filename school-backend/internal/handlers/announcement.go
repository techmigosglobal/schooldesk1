package handlers

import (
	"context"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AnnouncementHandler struct{}

func NewAnnouncementHandler() *AnnouncementHandler {
	return &AnnouncementHandler{}
}

func (h *AnnouncementHandler) GetAnnouncements(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	audience := c.Query("target_audience")

	var announcements []models.Announcement
	query := database.DB.Preload("TargetGrade").Preload("TargetSection").Preload("Creator")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	if audience != "" {
		query = query.Where("target_audience = ?", audience)
	}
	query.Order("published_at DESC").Find(&announcements)
	announcements = filterAnnouncementsForUser(c, announcements)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: announcements})
}

func (h *AnnouncementHandler) CreateAnnouncement(c *gin.Context) {
	var req struct {
		Title           string `json:"title" binding:"required"`
		Content         string `json:"content" binding:"required"`
		TargetAudience  string `json:"target_audience"`
		TargetGradeID   string `json:"target_grade_id"`
		TargetSectionID string `json:"target_section_id"`
		IsUrgent        bool   `json:"is_urgent"`
		CreatedBy       string `json:"created_by"`
		ExpiresAt       string `json:"expires_at"`
		AttachmentURL   string `json:"attachment_url"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	announcement := models.Announcement{
		SchoolID:       scopedSchoolID(c),
		Title:          req.Title,
		Content:        req.Content,
		TargetAudience: firstNonEmpty(req.TargetAudience, "all"),
		IsUrgent:       req.IsUrgent,
		CreatedBy:      c.GetString("user_id"),
		PublishedAt:    time.Now(),
		AttachmentURL:  req.AttachmentURL,
	}

	if req.TargetGradeID != "" {
		announcement.TargetGradeID = &req.TargetGradeID
	}
	if req.TargetSectionID != "" {
		announcement.TargetSectionID = &req.TargetSectionID
	}
	if req.ExpiresAt != "" {
		expiresAt, _ := time.Parse("2006-01-02T15:04:05Z", req.ExpiresAt)
		announcement.ExpiresAt = &expiresAt
	}

	if err := database.DB.Create(&announcement).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create announcement"})
		return
	}
	id := announcement.ID
	auditAction(c, "announcements", "create", "announcements", &id)
	createAnnouncementNotifications(announcement, "announcement")
	if services.Queue != nil {
		_ = services.Queue.Enqueue(context.Background(), "notifications", map[string]interface{}{
			"type":            "announcement_created",
			"announcement_id": announcement.ID,
			"school_id":       announcement.SchoolID,
		})
	}

	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: announcement})
}

func (h *AnnouncementHandler) GetEvents(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	yearID := c.Query("academic_year_id")

	var events []models.EventCalendar
	query := database.DB.Preload("Creator")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	if yearID != "" {
		query = query.Where("academic_year_id = ?", yearID)
	}
	query.Order("start_datetime ASC").Find(&events)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: events})
}

func (h *AnnouncementHandler) CreateEvent(c *gin.Context) {
	var req struct {
		AcademicYearID string `json:"academic_year_id" binding:"required"`
		EventTitle     string `json:"event_title" binding:"required"`
		EventType      string `json:"event_type" binding:"required"`
		Description    string `json:"description"`
		StartDatetime  string `json:"start_datetime" binding:"required"`
		EndDatetime    string `json:"end_datetime" binding:"required"`
		Location       string `json:"location"`
		IsHoliday      bool   `json:"is_holiday"`
		CreatedBy      string `json:"created_by"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	startTime, _ := time.Parse(time.RFC3339, req.StartDatetime)
	endTime, _ := time.Parse(time.RFC3339, req.EndDatetime)

	event := models.EventCalendar{
		SchoolID:       scopedSchoolID(c),
		AcademicYearID: req.AcademicYearID,
		EventTitle:     req.EventTitle,
		EventType:      req.EventType,
		Description:    req.Description,
		StartDatetime:  startTime,
		EndDatetime:    endTime,
		Location:       req.Location,
		IsHoliday:      req.IsHoliday,
		CreatedBy:      c.GetString("user_id"),
	}

	if err := database.DB.Create(&event).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create event"})
		return
	}
	id := event.ID
	auditAction(c, "events", "create", "event_calendars", &id)
	createEventNotifications(event)

	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: event})
}

func (h *AnnouncementHandler) DeleteEvent(c *gin.Context) {
	id := c.Param("id")
	result := database.DB.Delete(&models.EventCalendar{}, "id = ? AND school_id = ?", id, scopedSchoolID(c))
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete event"})
		return
	}
	if result.RowsAffected == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
		return
	}
	auditAction(c, "events", "delete", "event_calendars", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Event deleted successfully", Data: gin.H{"id": id}})
}

func (h *AnnouncementHandler) GetNotifications(c *gin.Context) {
	userID := c.GetString("user_id")
	schoolID := scopedSchoolID(c)
	var notifications []models.NotificationLog
	query := database.DB.Where("recipient_user_id = ?", userID)
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	if err := query.Order("sent_at DESC").Find(&notifications).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load notifications")
		return
	}
	rows := make([]gin.H, 0, len(notifications))
	for _, notification := range notifications {
		rows = append(rows, notificationLogResponse(notification))
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: rows})
}

func (h *AnnouncementHandler) CreateNotification(c *gin.Context) {
	var req struct {
		Title            string `json:"title"`
		Message          string `json:"message"`
		Body             string `json:"body"`
		NotificationType string `json:"notification_type"`
		Type             string `json:"type"`
		TargetRole       string `json:"target_role"`
		TargetUserID     string `json:"target_user_id"`
		Priority         string `json:"priority"`
		DeliveryMode     string `json:"delivery_mode"`
		ExpiryDate       string `json:"expiry_date"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	title := strings.TrimSpace(req.Title)
	message := strings.TrimSpace(firstNonEmpty(req.Message, req.Body))
	if title == "" || message == "" {
		fail(c, http.StatusBadRequest, "title and message are required")
		return
	}
	schoolID := scopedSchoolID(c)
	notificationID := uuid.New().String()
	notificationType := strings.TrimSpace(firstNonEmpty(req.NotificationType, req.Type, "general"))
	targetRole := strings.TrimSpace(firstNonEmpty(req.TargetRole, "all"))
	targetUserID := strings.TrimSpace(req.TargetUserID)
	priority := strings.TrimSpace(firstNonEmpty(req.Priority, "medium"))
	deliveryMode := strings.TrimSpace(firstNonEmpty(req.DeliveryMode, notificationChannelInApp))
	now := time.Now().UTC()
	row := map[string]interface{}{
		"notification_id":   notificationID,
		"school_id":         schoolID,
		"title":             title,
		"message":           message,
		"notification_type": notificationType,
		"target_role":       targetRole,
		"target_user_id":    targetUserID,
		"priority":          priority,
		"delivery_mode":     deliveryMode,
		"is_read":           false,
		"sent_by":           currentUserID(c),
		"sent_at":           now,
		"created_at":        now,
		"updated_at":        now,
	}
	if expiry := strings.TrimSpace(req.ExpiryDate); expiry != "" {
		row["expiry_date"] = expiry
	}

	var logs []models.NotificationLog
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Table("notifications").Create(row).Error; err != nil {
			return err
		}
		var createErr error
		if targetUserID != "" {
			logs, createErr = createNotificationLogsForUserIDsTx(
				tx, schoolID, []string{targetUserID}, title, message,
				notificationType, priority, notificationType, notificationID,
			)
		} else {
			logs, createErr = createNotificationLogsForRolesTx(
				tx, schoolID, notificationTargetRoles(targetRole), "",
				title, message, notificationType, priority, notificationType, notificationID,
			)
		}
		return createErr
	})
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create notification")
		return
	}
	auditAction(c, "notifications", "create", "notifications", &notificationID)
	enqueuePushNotifications(logs)
	c.JSON(http.StatusCreated, models.APIResponse{
		Success: true,
		Data: gin.H{
			"notification": row,
			"logs":         logs,
		},
	})
}

func (h *AnnouncementHandler) MarkNotificationRead(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	schoolID := scopedSchoolID(c)
	now := time.Now().UTC()
	result := database.DB.Model(&models.NotificationLog{}).
		Where("school_id = ? AND recipient_user_id = ?", schoolID, userID).
		Where("(id = ? OR reference_id = ?)", id, id).
		Updates(map[string]interface{}{
			"is_read": true,
			"read_at": now,
		})
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark notification as read"})
		return
	}
	if result.RowsAffected == 0 {
		legacy := database.DB.Table("notifications").
			Where(`"notification_id" = ? AND "school_id" = ?`, id, schoolID).
			Where(
				`("target_user_id" = ? OR LOWER(COALESCE("target_role", '')) IN ('parent', 'parents', 'teacher', 'teachers', 'staff', 'admin', 'principal', 'all', 'everyone'))`,
				userID,
			).
			Updates(map[string]interface{}{
				"is_read": true,
				"read_at": now,
			})
		if legacy.Error != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark notification as read"})
			return
		}
		if legacy.RowsAffected == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "Notification not found"})
			return
		}
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Notification marked as read"})
}

func notificationTargetRoles(targetRole string) []string {
	cleaned := strings.ToLower(strings.TrimSpace(targetRole))
	if cleaned == "" || cleaned == "all" || cleaned == "everyone" {
		return nil
	}
	parts := strings.FieldsFunc(cleaned, func(r rune) bool {
		return r == ',' || r == ';' || r == '|'
	})
	roles := make([]string, 0, len(parts))
	for _, part := range parts {
		role := strings.TrimSpace(part)
		switch role {
		case "", "all", "everyone":
			return nil
		case "parents", "guardian", "guardians":
			role = "parent"
		case "teachers", "staff":
			role = "teacher"
		case "admins":
			role = "admin"
		case "principals", "principle":
			role = "principal"
		}
		roles = append(roles, role)
	}
	return roles
}

func notificationLogResponse(row models.NotificationLog) gin.H {
	notificationID := row.ID
	if row.ReferenceID != nil && strings.TrimSpace(*row.ReferenceID) != "" {
		notificationID = strings.TrimSpace(*row.ReferenceID)
	}
	return gin.H{
		"id":                  row.ID,
		"notification_log_id": row.ID,
		"notification_id":     notificationID,
		"school_id":           row.SchoolID,
		"recipient_user_id":   row.RecipientUserID,
		"target_user_id":      row.RecipientUserID,
		"title":               row.Title,
		"message":             row.Body,
		"body":                row.Body,
		"notification_type":   row.Category,
		"type":                row.Category,
		"priority":            row.Priority,
		"route":               row.Route,
		"reference_type":      row.ReferenceType,
		"reference_id":        row.ReferenceID,
		"is_read":             row.IsRead,
		"read_at":             row.ReadAt,
		"sent_at":             row.SentAt,
		"delivery_status":     row.DeliveryStatus,
		"push_status":         row.PushStatus,
		"push_error":          row.PushError,
		"pushed_at":           row.PushedAt,
		"created_at":          row.CreatedAt,
		"updated_at":          row.UpdatedAt,
	}
}
