package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
)

type HomeworkReminderHandler struct{}

const homeworkReminderStatusResource = "homework/reminder-status"

func NewHomeworkReminderHandler() *HomeworkReminderHandler {
	return &HomeworkReminderHandler{}
}

func (h *HomeworkReminderHandler) TodayStatus(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	staffID := currentStaffID(c)
	if staffID == "" {
		fail(c, http.StatusForbidden, "teacher staff linkage missing")
		return
	}
	sectionID := strings.TrimSpace(c.Query("section_id"))
	status, err := homeworkReminderStatusFor(schoolID, staffID, sectionID, time.Now())
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load homework reminder status")
		return
	}
	success(c, http.StatusOK, status, "")
}

func (h *HomeworkReminderHandler) SkipToday(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	staffID := currentStaffID(c)
	if staffID == "" {
		fail(c, http.StatusForbidden, "teacher staff linkage missing")
		return
	}
	var req struct {
		SectionID string `json:"section_id"`
		Reason    string `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	sectionID := strings.TrimSpace(req.SectionID)
	today := time.Now()
	date := today.Format("2006-01-02")
	payload := gin.H{
		"staff_id":    staffID,
		"section_id":  sectionID,
		"date":        date,
		"status":      "skipped",
		"reason":      strings.TrimSpace(req.Reason),
		"skipped_by":  currentUserID(c),
		"skipped_at":  today.UTC().Format(time.RFC3339),
		"today_count": 0,
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid reminder payload")
		return
	}
	recordID := homeworkReminderRecordID(schoolID, staffID, sectionID, date)
	row := models.FrontendRecord{
		BaseModel: models.BaseModel{ID: recordID},
		SchoolID:  schoolID,
		Resource:  homeworkReminderStatusResource,
		Payload:   string(encoded),
		CreatedBy: currentUserID(c),
	}
	var existing models.FrontendRecord
	if err := database.DB.First(&existing, "id = ? AND school_id = ? AND resource = ?", recordID, schoolID, homeworkReminderStatusResource).Error; err == nil {
		existing.Payload = row.Payload
		existing.CreatedBy = row.CreatedBy
		if err := database.DB.Save(&existing).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Failed to save homework reminder skip")
			return
		}
		auditAction(c, homeworkReminderStatusResource, "skip", "frontend_records", &existing.ID)
	} else if err := database.DB.Create(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save homework reminder skip")
		return
	} else {
		auditAction(c, homeworkReminderStatusResource, "skip", "frontend_records", &row.ID)
	}
	status, err := homeworkReminderStatusFor(schoolID, staffID, sectionID, today)
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load homework reminder status")
		return
	}
	success(c, http.StatusOK, status, "Homework reminder skipped for today")
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
			status, err := homeworkReminderStatusFor(schoolID, teacher.ID, "", time.Now())
			if err == nil && (status["status"] == "skipped" || status["status"] == "assigned") {
				continue
			}
			if !submittedStaff[teacher.ID] {
				var user models.User
				if err := database.DB.Where("linked_type = ? AND linked_id = ?", "staff", teacher.ID).First(&user).Error; err == nil {
					_ = services.Queue.Enqueue(context.Background(), "notifications", map[string]interface{}{
						"type":      "homework_reminder",
						"school_id": schoolID,
						"staff_id":  teacher.ID,
						"user_id":   user.ID,
					})
				}
			}
		}
	}

	success(c, http.StatusOK, nil, "Homework reminders triggered successfully")
}

func homeworkReminderStatusFor(schoolID, staffID, sectionID string, now time.Time) (gin.H, error) {
	todayStart, todayEnd := dayRange(now)
	var todayCount int64
	query := database.DB.Table("homework").
		Where("school_id = ? AND staff_id = ? AND created_at >= ? AND created_at < ?", schoolID, staffID, todayStart, todayEnd)
	if strings.TrimSpace(sectionID) != "" {
		query = query.Where("section_id = ?", strings.TrimSpace(sectionID))
	}
	if err := query.Count(&todayCount).Error; err != nil {
		return nil, err
	}
	date := now.Format("2006-01-02")
	status := "pending"
	if todayCount > 0 {
		status = "assigned"
	} else {
		var row models.FrontendRecord
		err := database.DB.First(
			&row,
			"id = ? AND school_id = ? AND resource = ?",
			homeworkReminderRecordID(schoolID, staffID, sectionID, date),
			schoolID,
			homeworkReminderStatusResource,
		).Error
		if err == nil {
			payload := frontendPayload(row.Payload)
			if strings.EqualFold(strings.TrimSpace(fmt.Sprint(payload["status"])), "skipped") {
				status = "skipped"
			}
		}
	}
	return gin.H{
		"staff_id":    staffID,
		"section_id":  strings.TrimSpace(sectionID),
		"date":        date,
		"status":      status,
		"today_count": todayCount,
		"can_remind":  status == "pending",
		"record_id":   homeworkReminderRecordID(schoolID, staffID, sectionID, date),
		"resource":    homeworkReminderStatusResource,
	}, nil
}

func homeworkReminderRecordID(schoolID, staffID, sectionID, date string) string {
	key := strings.Join([]string{
		"homework-reminder",
		strings.TrimSpace(schoolID),
		strings.TrimSpace(staffID),
		strings.TrimSpace(sectionID),
		strings.TrimSpace(date),
	}, ":")
	return strings.ReplaceAll(key, " ", "_")
}
