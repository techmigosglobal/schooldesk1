package handlers

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type TeacherSelfHandler struct{}

func NewTeacherSelfHandler() *TeacherSelfHandler {
	return &TeacherSelfHandler{}
}

func (h *TeacherSelfHandler) GetMyPTMSlots(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	staffID := currentStaffID(c)
	if staffID == "" {
		fail(c, http.StatusForbidden, "Teacher details not found")
		return
	}

	var slots []models.ParentTeacherMeeting
	if err := database.DB.
		Preload("Section").
		Preload("Guardian").
		Preload("Student").
		Joins("JOIN events ON events.event_id = parent_teacher_meetings.event_id").
		Where("events.school_id = ? AND parent_teacher_meetings.teacher_id = ?", schoolID, staffID).
		Find(&slots).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load PTM slots")
		return
	}

	success(c, http.StatusOK, slots, "")
}

func (h *TeacherSelfHandler) CreateMyPTMSlot(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	staffID := currentStaffID(c)
	if staffID == "" {
		fail(c, http.StatusForbidden, "Teacher details not found")
		return
	}

	var req struct {
		EventID     string `json:"event_id"`
		SectionID   string `json:"section_id" binding:"required"`
		SlotDate    string `json:"slot_date" binding:"required"`
		SlotTime    string `json:"slot_time" binding:"required"`
		DurationMin int    `json:"duration_min" binding:"required"`
		StudentID   string `json:"student_id"`
		GuardianID  string `json:"guardian_id"`
		Reason      string `json:"reason"`
		Notes       string `json:"notes"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	slotDate, err := time.Parse("2006-01-02", strings.TrimSpace(req.SlotDate))
	if err != nil {
		fail(c, http.StatusBadRequest, "slot_date must use YYYY-MM-DD")
		return
	}

	eventID := strings.TrimSpace(req.EventID)
	if eventID == "" {
		if err := database.DB.
			Table("events").
			Select("event_id").
			Where("school_id = ? AND event_type = ? AND is_holiday = ?", schoolID, "PTM", false).
			Order("start_date DESC, created_at DESC").
			Limit(1).
			Scan(&eventID).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Failed to load PTM event entry")
			return
		}
		if eventID == "" {
			var academicYear models.AcademicYear
			if err := database.DB.Where("school_id = ? AND is_current = ?", schoolID, true).First(&academicYear).Error; err != nil {
				fail(c, http.StatusBadRequest, "No current academic year found to create default PTM event")
				return
			}
			eventID = uuid.NewString()
			now := time.Now().UTC()
			newEvent := map[string]interface{}{
				"event_id":         eventID,
				"school_id":        schoolID,
				"academic_year_id": academicYear.ID,
				"event_name":       "Parent-Teacher Meetings",
				"event_type":       "PTM",
				"description":      "Automated calendar container for PTM slots",
				"start_date":       now.Format("2006-01-02"),
				"end_date":         now.AddDate(0, 0, 30).Format("2006-01-02"),
				"organizer_id":     staffID,
				"status":           "scheduled",
				"is_holiday":       false,
				"created_at":       now,
				"updated_at":       now,
			}
			if err := database.DB.Table("events").Create(newEvent).Error; err != nil {
				fail(c, http.StatusInternalServerError, "Failed to create default PTM event entry")
				return
			}
		}
	}

	notes := strings.TrimSpace(req.Notes)
	if notes == "" {
		notes = strings.TrimSpace(req.Reason)
	}

	ptmSlot := models.ParentTeacherMeeting{
		EventID:     eventID,
		SectionID:   strings.TrimSpace(req.SectionID),
		SlotDate:    slotDate,
		SlotTime:    strings.TrimSpace(req.SlotTime),
		DurationMin: req.DurationMin,
		TeacherID:   staffID,
		StudentID:   strings.TrimSpace(req.StudentID),
		GuardianID:  strings.TrimSpace(req.GuardianID),
		Status:      "scheduled",
		Notes:       notes,
	}

	err = database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&ptmSlot).Error; err != nil {
			return err
		}
		if _, err := notifyParentsForTeacherPTMSlotTx(tx, schoolID, ptmSlot); err != nil {
			return err
		}
		return nil
	})
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create PTM slot")
		return
	}

	success(c, http.StatusCreated, ptmSlot, "PTM slot created successfully")
}

func notifyParentsForTeacherPTMSlotTx(
	tx *gorm.DB,
	schoolID string,
	slot models.ParentTeacherMeeting,
) ([]models.NotificationLog, error) {
	schoolID = strings.TrimSpace(schoolID)
	if schoolID == "" {
		return nil, nil
	}
	var parentUserIDs []string
	studentID := strings.TrimSpace(slot.StudentID)
	if studentID != "" {
		if err := tx.Model(&models.ParentStudentLink{}).
			Where("school_id = ? AND student_id = ?", schoolID, studentID).
			Pluck("parent_user_id", &parentUserIDs).Error; err != nil {
			return nil, err
		}
	} else {
		if err := tx.Model(&models.ParentStudentLink{}).
			Distinct("parent_student_links.parent_user_id").
			Joins("JOIN enrollments ON enrollments.student_id = parent_student_links.student_id").
			Where("parent_student_links.school_id = ? AND enrollments.section_id = ?", schoolID, slot.SectionID).
			Pluck("parent_student_links.parent_user_id", &parentUserIDs).Error; err != nil {
			return nil, err
		}
	}
	if len(parentUserIDs) == 0 {
		return nil, nil
	}

	teacherName := "Teacher"
	var teacher models.Staff
	if err := tx.Select("first_name", "last_name").First(&teacher, "id = ?", slot.TeacherID).Error; err == nil {
		name := strings.TrimSpace(strings.TrimSpace(teacher.FirstName) + " " + strings.TrimSpace(teacher.LastName))
		if name != "" {
			teacherName = name
		}
	}

	body := ""
	if slot.SlotTime != "" {
		body = "PTM scheduled at " + strings.TrimSpace(slot.SlotTime)
	} else {
		body = "A PTM slot has been scheduled"
	}
	if note := strings.TrimSpace(slot.Notes); note != "" {
		body += ". Reason: " + note
	}
	body += ". By " + teacherName + "."

	logs, err := createNotificationLogsForUserIDsTx(
		tx,
		schoolID,
		parentUserIDs,
		"PTM slot scheduled",
		body,
		"event",
		"high",
		"ptm",
		slot.ID,
	)
	if err != nil {
		return nil, err
	}
	enqueuePushNotifications(logs)
	return logs, nil
}

func (h *TeacherSelfHandler) RecallLeaveApplication(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	staffID := currentStaffID(c)
	if staffID == "" {
		fail(c, http.StatusForbidden, "Teacher details not found")
		return
	}

	id := strings.TrimSpace(c.Param("id"))
	var application models.LeaveApplication
	if err := database.DB.
		Joins("JOIN staffs ON staffs.id = leave_applications.staff_id").
		Joins("LEFT JOIN leave_types ON leave_types.id = leave_applications.leave_type_id").
		Where(
			"leave_applications.id = ? AND leave_applications.staff_id = ? AND staffs.school_id = ? AND (leave_applications.leave_type_id = '' OR leave_types.school_id = ?)",
			id,
			staffID,
			schoolID,
			schoolID,
		).
		First(&application).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			fail(c, http.StatusNotFound, "Leave application not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to fetch leave application")
		return
	}

	if strings.ToLower(application.Status) != "pending" {
		fail(c, http.StatusBadRequest, "Only pending leave applications can be recalled")
		return
	}

	application.Status = "withdrawn"
	if err := database.DB.Save(&application).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to recall leave application")
		return
	}

	auditAction(c, "leave", "recall", "leave_applications", &id)
	success(c, http.StatusOK, application, "Leave application withdrawn successfully")
}
