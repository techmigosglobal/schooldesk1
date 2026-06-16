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

type HomeworkReminderHandler struct{}

func NewHomeworkReminderHandler() *HomeworkReminderHandler {
	return &HomeworkReminderHandler{}
}

func (h *HomeworkReminderHandler) TriggerEndOfDayReminders(c *gin.Context) {
	// This can be triggered by a cron job
	schoolID := scopedSchoolID(c)

	var activeTeachers []models.Staff
	if err := database.DB.Where("school_id = ? AND (status = '' OR LOWER(status) = ?)", schoolID, "active").Find(&activeTeachers).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load teachers")
		return
	}

	today := time.Now().Format("2006-01-02")
	var submittedHomeworks []map[string]interface{}
	
	// Check if they uploaded homework today
	if err := database.DB.Table("homework").
		Select("staff_id").
		Where("school_id = ? AND DATE(created_at) = ?", schoolID, today).
		Find(&submittedHomeworks).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to check homework submissions")
		return
	}

	submittedStaff := make(map[string]bool)
	for _, hw := range submittedHomeworks {
		if staffID, ok := hw["staff_id"].(string); ok {
			submittedStaff[staffID] = true
		}
	}

	if services.Queue != nil {
		for _, teacher := range activeTeachers {
			if !submittedStaff[teacher.ID] {
				var user models.User
				if err := database.DB.Where("linked_type = ? AND linked_id = ?", "staff", teacher.ID).First(&user).Error; err == nil {
					_ = services.Queue.Enqueue(context.Background(), "notifications", map[string]interface{}{
						"type":       "homework_reminder",
						"school_id":  schoolID,
						"staff_id":   teacher.ID,
						"user_id":    user.ID,
					})
				}
			}
		}
	}

	success(c, http.StatusOK, nil, "Homework reminders triggered successfully")
}
