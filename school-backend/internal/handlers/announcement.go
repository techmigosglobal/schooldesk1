package handlers

import (
	"context"
	"net/http"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
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
	query.Order("sent_at DESC").Find(&notifications)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: notifications})
}

func (h *AnnouncementHandler) MarkNotificationRead(c *gin.Context) {
	id := c.Param("id")
	userID := c.GetString("user_id")
	schoolID := scopedSchoolID(c)
	var notification models.NotificationLog
	if err := database.DB.First(&notification, "id = ? AND recipient_user_id = ? AND school_id = ?", id, userID, schoolID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Notification not found"})
		return
	}

	notification.IsRead = true
	database.DB.Save(&notification)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Notification marked as read"})
}
