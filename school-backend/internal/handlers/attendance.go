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

type AttendanceHandler struct{}

func NewAttendanceHandler() *AttendanceHandler {
	return &AttendanceHandler{}
}

func (h *AttendanceHandler) GetAttendanceSessions(c *gin.Context) {
	sectionID := c.Query("section_id")
	date := c.Query("date")

	var sessions []models.AttendanceSession
	query := database.DB.Model(&models.AttendanceSession{}).
		Joins("JOIN sections ON sections.id = attendance_sessions.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", scopedSchoolID(c)).
		Preload("Subject").
		Preload("Staff")
	if currentRole(c) == "teacher" {
		staffID := currentStaffID(c)
		if staffID == "" {
			query = query.Where("1 = 0")
		} else {
			query = query.Where("attendance_sessions.staff_id = ?", staffID)
		}
	}
	if sectionID != "" {
		query = query.Where("attendance_sessions.section_id = ?", sectionID)
	}
	if date != "" {
		parsed, err := time.Parse("2006-01-02", date)
		if err != nil {
			fail(c, http.StatusBadRequest, "Invalid date format. Use YYYY-MM-DD")
			return
		}
		query = query.Where("attendance_sessions.date >= ? AND attendance_sessions.date < ?", parsed, parsed.AddDate(0, 0, 1))
	}
	if err := query.Find(&sessions).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load attendance sessions")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: sessions})
}

func (h *AttendanceHandler) CreateAttendanceSession(c *gin.Context) {
	var req struct {
		SectionID       string `json:"section_id" binding:"required"`
		SubjectID       string `json:"subject_id" binding:"required"`
		StaffID         string `json:"staff_id" binding:"required"`
		Date            string `json:"date" binding:"required"`
		PeriodNumber    int    `json:"period_number"`
		TimetableSlotID string `json:"timetable_slot_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Parse date
	date, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid date format. Use YYYY-MM-DD"})
		return
	}
	if req.PeriodNumber < 1 {
		fail(c, http.StatusBadRequest, "period_number must be greater than zero")
		return
	}
	if currentRole(c) != "" && !canTeachSectionSubject(c, req.StaffID, req.SectionID, req.SubjectID, req.TimetableSlotID) {
		fail(c, http.StatusForbidden, "attendance session ownership denied")
		return
	}

	session := models.AttendanceSession{
		SectionID:     req.SectionID,
		SubjectID:     req.SubjectID,
		StaffID:       req.StaffID,
		Date:          date,
		PeriodNumber:  req.PeriodNumber,
		TotalStudents: 0,
		PresentCount:  0,
		IsFinalized:   false,
	}

	if req.TimetableSlotID != "" {
		session.TimetableSlotID = &req.TimetableSlotID
	}

	if err := database.DB.Create(&session).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create session"})
		return
	}

	id := session.ID
	auditAction(c, "attendance", "create", "attendance_sessions", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: session})
}

func (h *AttendanceHandler) MarkStudentAttendance(c *gin.Context) {
	sessionID := c.Param("session_id")
	var req struct {
		Attendances []struct {
			StudentID    string `json:"student_id" binding:"required"`
			EnrollmentID string `json:"enrollment_id" binding:"required"`
			Status       string `json:"status" binding:"required"`
			Reason       string `json:"reason"`
		} `json:"attendances" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if len(req.Attendances) == 0 {
		fail(c, http.StatusBadRequest, "attendances must contain at least one record")
		return
	}

	var session models.AttendanceSession
	if err := database.DB.Model(&models.AttendanceSession{}).
		Joins("JOIN sections ON sections.id = attendance_sessions.section_id").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("attendance_sessions.id = ? AND grades.school_id = ?", sessionID, scopedSchoolID(c)).
		First(&session).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			fail(c, http.StatusNotFound, "Attendance session not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to load attendance session")
		return
	}
	if currentRole(c) != "" && !canTeachSectionSubject(c, session.StaffID, session.SectionID, session.SubjectID, stringValue(session.TimetableSlotID)) {
		fail(c, http.StatusForbidden, "attendance session ownership denied")
		return
	}
	for _, att := range req.Attendances {
		if err := validateStudentEnrollmentForSession(scopedSchoolID(c), session, att.StudentID, att.EnrollmentID); err != nil {
			fail(c, http.StatusBadRequest, err.Error())
			return
		}
	}

	now := time.Now().UTC()
	markedBy := c.GetString("user_id")
	presentCount := 0
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("session_id = ?", sessionID).Delete(&models.StudentAttendance{}).Error; err != nil {
			return err
		}
		for _, att := range req.Attendances {
			status := strings.TrimSpace(att.Status)
			if !validAttendanceStatus(status) {
				return errInvalidAttendanceStatus
			}
			if strings.EqualFold(status, "present") || strings.EqualFold(status, "late") {
				presentCount++
			}
			attendance := models.StudentAttendance{
				SessionID:    sessionID,
				StudentID:    att.StudentID,
				EnrollmentID: att.EnrollmentID,
				Status:       status,
				Reason:       att.Reason,
				MarkedAt:     now,
				MarkedBy:     &markedBy,
			}
			if err := tx.Create(&attendance).Error; err != nil {
				return err
			}
		}
		session.TotalStudents = len(req.Attendances)
		session.PresentCount = presentCount
		return tx.Save(&session).Error
	})
	if err != nil {
		if err == errInvalidAttendanceStatus {
			fail(c, http.StatusBadRequest, "Invalid attendance status")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to mark attendance")
		return
	}

	auditAction(c, "attendance", "update", "student_attendances", &sessionID)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Attendance marked successfully"})
}

var errInvalidAttendanceStatus = errors.New("invalid attendance status")

func validAttendanceStatus(status string) bool {
	switch strings.ToLower(strings.TrimSpace(status)) {
	case "present", "absent", "late", "half-day", "leave":
		return true
	default:
		return false
	}
}

func combineDateAndClock(date time.Time, clock string) (time.Time, error) {
	parsed, err := time.Parse("15:04:05", clock)
	if err != nil {
		return time.Time{}, err
	}
	return time.Date(
		date.Year(), date.Month(), date.Day(),
		parsed.Hour(), parsed.Minute(), parsed.Second(), 0,
		time.UTC,
	), nil
}

func (h *AttendanceHandler) GetStudentAttendanceSummary(c *gin.Context) {
	studentID := c.Query("student_id")
	yearID := c.Query("academic_year_id")
	termID := c.Query("term_id")
	if strings.TrimSpace(studentID) == "" {
		fail(c, http.StatusBadRequest, "student_id is required")
		return
	}
	if !canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}

	var summary models.AttendanceSummary
	query := database.DB.Where("student_id = ?", studentID)
	if yearID != "" {
		query = query.Where("academic_year_id = ?", yearID)
	}
	if termID != "" {
		query = query.Where("term_id = ?", termID)
	}
	if err := query.First(&summary).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			fail(c, http.StatusNotFound, "Attendance summary not found")
			return
		}
		fail(c, http.StatusInternalServerError, "Failed to load attendance summary")
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: summary})
}

func (h *AttendanceHandler) MarkStaffAttendance(c *gin.Context) {
	var req struct {
		StaffID     string `json:"staff_id" binding:"required"`
		Date        string `json:"date" binding:"required"`
		Status      string `json:"status" binding:"required"`
		CheckIn     string `json:"check_in"`
		CheckOut    string `json:"check_out"`
		BiometricID string `json:"biometric_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Parse date
	date, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid date format. Use YYYY-MM-DD"})
		return
	}

	attendance := models.StaffAttendance{
		StaffID:     req.StaffID,
		Date:        date,
		Status:      req.Status,
		BiometricID: req.BiometricID,
	}

	// Parse check_in if provided
	if req.CheckIn != "" {
		checkIn, err := combineDateAndClock(date, req.CheckIn)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid check_in format. Use HH:MM:SS"})
			return
		}
		attendance.CheckIn = &checkIn
	}

	// Parse check_out if provided
	if req.CheckOut != "" {
		checkOut, err := combineDateAndClock(date, req.CheckOut)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid check_out format. Use HH:MM:SS"})
			return
		}
		attendance.CheckOut = &checkOut
	}

	if err := database.DB.Create(&attendance).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark attendance"})
		return
	}

	id := attendance.ID
	auditAction(c, "attendance", "create", "staff_attendances", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: attendance})
}
