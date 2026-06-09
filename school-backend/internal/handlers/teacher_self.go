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
		Preload("Event").
		Preload("Section").
		Preload("Guardian").
		Preload("Student").
		Joins("JOIN events ON events.id = parent_teacher_meetings.event_id").
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
		var activeEvent models.EventCalendar
		err := database.DB.Where("school_id = ? AND event_type = ? AND is_holiday = ?", schoolID, "PTM", false).First(&activeEvent).Error
		if err == nil {
			eventID = activeEvent.ID
		} else {
			var academicYear models.AcademicYear
			if err := database.DB.Where("school_id = ? AND is_current = ?", schoolID, true).First(&academicYear).Error; err != nil {
				fail(c, http.StatusBadRequest, "No current academic year found to create default PTM event")
				return
			}
			newEvent := models.EventCalendar{
				SchoolID:       schoolID,
				AcademicYearID: academicYear.ID,
				EventTitle:     "Parent-Teacher Meetings",
				EventType:      "PTM",
				Description:    "Automated calendar container for PTM slots",
				StartDatetime:  time.Now(),
				EndDatetime:    time.Now().AddDate(0, 0, 30),
				CreatedBy:      c.GetString("user_id"),
			}
			if err := database.DB.Create(&newEvent).Error; err != nil {
				fail(c, http.StatusInternalServerError, "Failed to create default PTM event entry")
				return
			}
			eventID = newEvent.ID
		}
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
	}

	if err := database.DB.Create(&ptmSlot).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create PTM slot")
		return
	}

	success(c, http.StatusCreated, ptmSlot, "PTM slot created successfully")
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
		Joins("JOIN leave_types ON leave_types.id = leave_applications.leave_type_id").
		Where("leave_applications.id = ? AND leave_applications.staff_id = ? AND leave_types.school_id = ?", id, staffID, schoolID).
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
