package handlers

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type ParentTeacherMeetingHandler struct{}

func NewParentTeacherMeetingHandler() *ParentTeacherMeetingHandler {
	return &ParentTeacherMeetingHandler{}
}

func (h *ParentTeacherMeetingHandler) Book(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	var req struct {
		Notes string `json:"notes"`
	}
	_ = c.ShouldBindJSON(&req)

	var row models.ParentTeacherMeeting
	if err := database.DB.
		Joins(`JOIN events ON events.event_id = parent_teacher_meetings.event_id`).
		Where("parent_teacher_meetings.id = ? AND events.school_id = ?", id, scopedSchoolID(c)).
		First(&row).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			fail(c, http.StatusNotFound, "PTM slot not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to load PTM slot")
		return
	}
	if !canAccessStudent(c, row.StudentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	updates := map[string]interface{}{
		"status":     "booked",
		"updated_at": time.Now().UTC(),
	}
	if notes := strings.TrimSpace(req.Notes); notes != "" {
		updates["notes"] = notes
	}
	if err := database.DB.Model(&row).Updates(updates).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to book PTM slot")
		return
	}
	if err := database.DB.
		Preload("Event").
		Preload("Section").
		Preload("Teacher").
		Preload("Guardian").
		Preload("Student").
		First(&row, "id = ?", row.ID).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load booked PTM slot")
		return
	}
	auditAction(c, "parent_teacher_meetings", "book", "parent_teacher_meetings", &row.ID)
	success(c, http.StatusOK, row, "PTM slot booked successfully")
}
