package handlers

import (
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

// Teacher Create
func (h *EventPostHandler) CreateEventPost(c *gin.Context) {
	var req struct {
		GradeID      *string  `json:"grade_id"`
		Title        string   `json:"title" binding:"required"`
		Description  string   `json:"description"`
		EventDate    string   `json:"event_date" binding:"required"`
		MediaUrls    string   `json:"media_urls"`
		Destinations []string `json:"destinations" binding:"required"`
		IsSubmit     bool     `json:"is_submit"`
	}
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

	destinationsStr := strings.Join(req.Destinations, ",")

	status := models.ApprovalStatusDraft
	if req.IsSubmit {
		status = models.ApprovalStatusPending
	}

	post := models.EventPost{
		SchoolID:           schoolID,
		GradeID:            req.GradeID,
		Title:              req.Title,
		Description:        req.Description,
		EventDate:          eventDate,
		CreatedByTeacherID: teacherID,
		MediaUrls:          req.MediaUrls,
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
		createApprovalRequestedNotificationsTx(database.DB, c, post.ID, "Event Post Submitted", "A new event post requires your approval.")
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: post})
}

// Teacher List
func (h *EventPostHandler) ListTeacherEventPosts(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	teacherID := c.GetString("linked_id")

	var posts []models.EventPost
	if err := database.DB.Preload("CreatedByTeacher").Where("school_id = ? AND created_by_teacher_id = ?", schoolID, teacherID).Order("created_at desc").Find(&posts).Error; err != nil {
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

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: posts})
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
	post.ApprovedByPrincipalID = &principalID
	post.ApprovedAt = &now
	post.PublishedAt = &now

	if err := database.DB.Save(&post).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to approve event post")
		return
	}

	database.DB.Preload("CreatedByTeacher").First(&post, "id = ?", post.ID)

	createApprovalDecisionNotificationsTx(database.DB, c, post.CreatedByTeacherID, post.ID, "Event Post Approved", "Your event post has been approved.")
	if strings.Contains(post.Destinations, "PARENTS_HOME") {
		createNotificationLogsForRolesTx(database.DB, schoolID, []string{"parent"}, "", "New School Event", post.Title, "event", "medium", "event_post", post.ID)
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: post})
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

	createApprovalDecisionNotificationsTx(database.DB, c, post.CreatedByTeacherID, post.ID, "Event Post Rejected", "Your event post has been rejected. Reason: " + req.Reason)

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

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: posts})
}
