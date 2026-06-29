package handlers

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
)

type EventPostHandler struct{}

func NewEventPostHandler() *EventPostHandler {
	return &EventPostHandler{}
}

// publicEventPost is intentionally retained for public feed contracts.
type publicEventPost struct {
	Title       string     `json:"title"`
	Description string     `json:"description"`
	EventDate   time.Time  `json:"event_date"`
	MediaUrls   string     `json:"media_urls"`
	PublishedAt *time.Time `json:"published_at,omitempty"`
}

type eventPostRequest struct {
	GradeID      *string               `json:"grade_id"`
	SectionID    *string               `json:"section_id"`
	Title        string                `json:"title" binding:"required"`
	Description  string                `json:"description"`
	EventDate    string                `json:"event_date" binding:"required"`
	MediaUrls    json.RawMessage       `json:"media_urls"`
	Media        []eventPostMediaInput `json:"media"`
	Destinations []string              `json:"destinations" binding:"required"`
	IsSubmit     bool                  `json:"is_submit"`
}

type eventPostMediaInput struct {
	URL      string `json:"url"`
	Name     string `json:"name,omitempty"`
	MimeType string `json:"mime_type,omitempty"`
	Kind     string `json:"kind,omitempty"`
	Size     int64  `json:"size,omitempty"`
}

// Teacher Create
func (h *EventPostHandler) CreateEventPost(c *gin.Context) {
	var req eventPostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	eventDate, err := time.Parse(time.RFC3339, req.EventDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid event date format. Use RFC3339")
		return
	}

	schoolID := scopedSchoolID(c)
	teacherID := c.GetString("linked_id")
	if teacherID == "" {
		fail(c, http.StatusUnauthorized, "Teacher profile not linked")
		return
	}

	destinations, ok := normalizeEventPostDestinations(req.Destinations)
	if !ok {
		fail(c, http.StatusBadRequest, "At least one valid destination is required")
		return
	}
	destinationsStr := strings.Join(destinations, ",")

	status := models.ApprovalStatusDraft
	if req.IsSubmit {
		status = models.ApprovalStatusPending
	}

	post := models.EventPost{
		SchoolID:           schoolID,
		GradeID:            req.GradeID,
		SectionID:          req.SectionID,
		Title:              req.Title,
		Description:        req.Description,
		EventDate:          eventDate,
		CreatedByTeacherID: teacherID,
		MediaUrls:          normalizeEventPostMedia(req.Media, req.MediaUrls),
		Destinations:       destinationsStr,
		ApprovalStatus:     status,
	}

	if err := database.DB.Create(&post).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create event post")
		return
	}

	// Fetch with preload for returning
	database.DB.Preload("CreatedByTeacher").First(&post, "id = ?", post.ID)

	if req.IsSubmit {
		if logs, err := createEventPostApprovalRequestedNotificationsTx(database.DB, c, post.ID, post.Title); err == nil {
			enqueuePushNotifications(logs)
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: post})
}

func (h *EventPostHandler) UpdateEventPost(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	schoolID := scopedSchoolID(c)
	teacherID := strings.TrimSpace(c.GetString("linked_id"))
	if teacherID == "" {
		fail(c, http.StatusUnauthorized, "Teacher profile not linked")
		return
	}

	var req eventPostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	eventDate, err := time.Parse(time.RFC3339, req.EventDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid event date format. Use RFC3339")
		return
	}
	destinations, ok := normalizeEventPostDestinations(req.Destinations)
	if !ok {
		fail(c, http.StatusBadRequest, "At least one valid destination is required")
		return
	}

	var post models.EventPost
	if err := database.DB.Where("id = ? AND school_id = ? AND created_by_teacher_id = ?", id, schoolID, teacherID).First(&post).Error; err != nil {
		fail(c, http.StatusNotFound, "Event post not found")
		return
	}
	if post.ApprovalStatus != models.ApprovalStatusDraft && post.ApprovalStatus != models.ApprovalStatusRejected {
		fail(c, http.StatusBadRequest, "Only draft or rejected event posts can be edited")
		return
	}

	post.GradeID = req.GradeID
	post.SectionID = req.SectionID
	post.Title = strings.TrimSpace(req.Title)
	post.Description = req.Description
	post.EventDate = eventDate
	post.MediaUrls = normalizeEventPostMedia(req.Media, req.MediaUrls)
	post.Destinations = strings.Join(destinations, ",")
	post.RejectionReason = nil
	post.ApprovedByPrincipalID = nil
	post.ApprovedAt = nil
	post.PublishedAt = nil
	if req.IsSubmit {
		post.ApprovalStatus = models.ApprovalStatusPending
	} else {
		post.ApprovalStatus = models.ApprovalStatusDraft
	}

	if err := database.DB.Save(&post).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update event post")
		return
	}
	database.DB.Preload("CreatedByTeacher").First(&post, "id = ?", post.ID)

	if req.IsSubmit {
		if logs, err := createEventPostApprovalRequestedNotificationsTx(database.DB, c, post.ID, post.Title); err == nil {
			enqueuePushNotifications(logs)
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: post})
}

func (h *EventPostHandler) DeleteEventPost(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	schoolID := scopedSchoolID(c)
	teacherID := strings.TrimSpace(c.GetString("linked_id"))
	if teacherID == "" {
		fail(c, http.StatusUnauthorized, "Teacher profile not linked")
		return
	}

	var post models.EventPost
	if err := database.DB.Where("id = ? AND school_id = ? AND created_by_teacher_id = ?", id, schoolID, teacherID).First(&post).Error; err != nil {
		fail(c, http.StatusNotFound, "Event post not found")
		return
	}
	if post.ApprovalStatus != models.ApprovalStatusDraft && post.ApprovalStatus != models.ApprovalStatusRejected {
		fail(c, http.StatusBadRequest, "Only draft or rejected event posts can be deleted")
		return
	}
	if err := database.DB.Delete(&post).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to delete event post")
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: gin.H{"id": id}})
}

// Teacher List
func (h *EventPostHandler) ListTeacherEventPosts(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	teacherID := c.GetString("linked_id")

	var posts []models.EventPost
	if err := database.DB.Preload("CreatedByTeacher").Where("school_id = ? AND created_by_teacher_id = ?", schoolID, teacherID).Order("updated_at desc, created_at desc").Find(&posts).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch event posts")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: posts})
}

// Principal/Admin List Pending
func (h *EventPostHandler) ListAllEventPosts(c *gin.Context) {
	schoolID := scopedSchoolID(c)

	var posts []models.EventPost
	if err := database.DB.Preload("CreatedByTeacher").Where("school_id = ?", schoolID).Order("created_at desc").Find(&posts).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch event posts")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: posts})
}

// Principal List Pending
func (h *EventPostHandler) ListPendingEventPosts(c *gin.Context) {
	schoolID := scopedSchoolID(c)

	var posts []models.EventPost
	if err := database.DB.Preload("CreatedByTeacher").Where("school_id = ? AND approval_status = ?", schoolID, models.ApprovalStatusPending).Order("created_at desc").Find(&posts).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch pending event posts")
		return
	}

	// Admin/Principal approvals require full payload (id, destinations, status, etc.).
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: posts})
}

func (h *EventPostHandler) GetEventPost(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	schoolID := scopedSchoolID(c)
	roleName := strings.ToLower(strings.TrimSpace(c.GetString("role_name")))
	teacherID := strings.TrimSpace(c.GetString("linked_id"))

	query := database.DB.Preload("CreatedByTeacher").
		Where("id = ? AND school_id = ?", id, schoolID)
	if roleName == "teacher" {
		if teacherID == "" {
			fail(c, http.StatusUnauthorized, "Teacher profile not linked")
			return
		}
		query = query.Where("created_by_teacher_id = ?", teacherID)
	}

	var post models.EventPost
	if err := query.First(&post).Error; err != nil {
		fail(c, http.StatusNotFound, "Event post not found")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: post})
}

func normalizeEventPostDestinations(raw []string) ([]string, bool) {
	allowed := map[string]bool{
		string(models.DestinationParentsHome):   true,
		string(models.DestinationSchoolGallery): true,
		string(models.DestinationSchoolLanding): true,
	}
	seen := map[string]bool{}
	destinations := make([]string, 0, len(raw))
	for _, item := range raw {
		value := strings.ToUpper(strings.TrimSpace(item))
		if !allowed[value] || seen[value] {
			continue
		}
		seen[value] = true
		destinations = append(destinations, value)
	}
	return destinations, len(destinations) > 0
}

func normalizeEventPostMedia(media []eventPostMediaInput, raw json.RawMessage) string {
	if len(media) > 0 {
		normalized := make([]eventPostMediaInput, 0, len(media))
		for _, item := range media {
			item.URL = strings.TrimSpace(item.URL)
			item.Name = strings.TrimSpace(item.Name)
			item.MimeType = strings.TrimSpace(item.MimeType)
			item.Kind = strings.ToLower(strings.TrimSpace(item.Kind))
			if item.URL == "" {
				continue
			}
			normalized = append(normalized, item)
		}
		if len(normalized) == 0 {
			return ""
		}
		bytes, err := json.Marshal(normalized)
		if err == nil {
			return string(bytes)
		}
	}
	if len(raw) == 0 || string(raw) == "null" {
		return ""
	}
	var urls []string
	if err := json.Unmarshal(raw, &urls); err == nil {
		cleaned := make([]string, 0, len(urls))
		for _, url := range urls {
			if trimmed := strings.TrimSpace(url); trimmed != "" {
				cleaned = append(cleaned, trimmed)
			}
		}
		bytes, err := json.Marshal(cleaned)
		if err == nil {
			return string(bytes)
		}
	}
	var text string
	if err := json.Unmarshal(raw, &text); err == nil {
		return strings.TrimSpace(text)
	}
	return strings.TrimSpace(string(raw))
}

// Principal Approve
func (h *EventPostHandler) ApproveEventPost(c *gin.Context) {
	id := c.Param("id")
	schoolID := scopedSchoolID(c)
	principalID := c.GetString("linked_id")
	now := time.Now()

	var post models.EventPost
	if err := database.DB.Where("id = ? AND school_id = ?", id, schoolID).First(&post).Error; err != nil {
		fail(c, http.StatusNotFound, "Event post not found")
		return
	}

	post.ApprovalStatus = models.ApprovalStatusApproved
	post.Destinations = ensureEventPostDestinations(post.Destinations, models.DestinationSchoolGallery)
	post.ApprovedByPrincipalID = &principalID
	post.ApprovedAt = &now
	post.PublishedAt = &now

	if err := database.DB.Save(&post).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to approve event post")
		return
	}

	database.DB.Preload("CreatedByTeacher").First(&post, "id = ?", post.ID)

	if logs, err := createEventPostDecisionNotificationsTx(database.DB, c, post.CreatedByTeacherID, post.ID, "approved", ""); err == nil {
		enqueuePushNotifications(logs)
	}
	if strings.Contains(post.Destinations, "PARENTS_HOME") {
		createNotificationLogsForRolesTx(database.DB, schoolID, []string{"parent"}, "", "New School Event", post.Title, "event", "medium", "event_post", post.ID)
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: post})
}

func ensureEventPostDestinations(raw string, extra models.EventPostDestination) string {
	seen := map[string]bool{}
	destinations := make([]string, 0, 4)
	for _, part := range strings.Split(raw, ",") {
		normalized := strings.ToUpper(strings.TrimSpace(part))
		if normalized == "" || seen[normalized] {
			continue
		}
		seen[normalized] = true
		destinations = append(destinations, normalized)
	}
	extraValue := strings.ToUpper(strings.TrimSpace(string(extra)))
	if extraValue != "" && !seen[extraValue] {
		destinations = append(destinations, extraValue)
	}
	return strings.Join(destinations, ",")
}

// Principal Reject
func (h *EventPostHandler) RejectEventPost(c *gin.Context) {
	id := c.Param("id")
	schoolID := scopedSchoolID(c)
	var req struct {
		Reason string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	var post models.EventPost
	if err := database.DB.Where("id = ? AND school_id = ?", id, schoolID).First(&post).Error; err != nil {
		fail(c, http.StatusNotFound, "Event post not found")
		return
	}

	post.ApprovalStatus = models.ApprovalStatusRejected
	post.RejectionReason = &req.Reason

	if err := database.DB.Save(&post).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to reject event post")
		return
	}

	database.DB.Preload("CreatedByTeacher").First(&post, "id = ?", post.ID)

	if logs, err := createEventPostDecisionNotificationsTx(database.DB, c, post.CreatedByTeacherID, post.ID, "rejected", req.Reason); err == nil {
		enqueuePushNotifications(logs)
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: post})
}

// Parent/Gallery List
func (h *EventPostHandler) ListGalleryEventPosts(c *gin.Context) {
	schoolID := scopedSchoolID(c)

	var posts []models.EventPost
	if err := database.DB.Preload("CreatedByTeacher").Where("school_id = ? AND approval_status = ? AND destinations LIKE ?", schoolID, models.ApprovalStatusApproved, "%SCHOOL_GALLERY%").Order("published_at desc").Find(&posts).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch gallery posts")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: posts})
}

// Parent Home List
func (h *EventPostHandler) ListParentHomeFeed(c *gin.Context) {
	schoolID := scopedSchoolID(c)

	var posts []models.EventPost
	if err := database.DB.Preload("CreatedByTeacher").Where("school_id = ? AND approval_status = ? AND destinations LIKE ?", schoolID, models.ApprovalStatusApproved, "%PARENTS_HOME%").Order("published_at desc").Limit(10).Find(&posts).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch home feed")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: posts})
}

// Public Landing Events
func (h *EventPostHandler) ListLandingEvents(c *gin.Context) {
	schoolID := c.Query("school_id")
	query := database.DB.Where("approval_status = ? AND destinations LIKE ?", models.ApprovalStatusApproved, "%SCHOOL_LANDING%")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}

	var posts []models.EventPost
	if err := query.Order("published_at desc").Limit(10).Find(&posts).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch landing events")
		return
	}

	publicPosts := make([]publicEventPost, 0, len(posts))
	for _, post := range posts {
		publicPosts = append(publicPosts, publicEventPost{
			Title:       post.Title,
			Description: post.Description,
			EventDate:   post.EventDate,
			MediaUrls:   post.MediaUrls,
			PublishedAt: post.PublishedAt,
		})
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: publicPosts})
}
