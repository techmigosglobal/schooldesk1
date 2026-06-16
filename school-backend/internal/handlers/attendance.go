package handlers

import (
	"bytes"
	"crypto/hmac"
	cryptoRand "crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"os"
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

const staffQRRefreshSeconds = 5

var (
	errInvalidStaffQRToken = errors.New("invalid staff qr token")
	errExpiredStaffQRToken = errors.New("expired staff qr token")
)

type staffQRPayload struct {
	SchoolID  string `json:"school_id"`
	Date      string `json:"date"`
	IssuedAt  int64  `json:"issued_at"`
	ExpiresAt int64  `json:"expires_at"`
	Nonce     string `json:"nonce"`
}

type staffQRTokenResponse struct {
	Token               string    `json:"token"`
	SchoolDate          string    `json:"school_date"`
	IssuedAt            time.Time `json:"issued_at"`
	ExpiresAt           time.Time `json:"expires_at"`
	ServerTime          time.Time `json:"server_time"`
	RefreshAfterSeconds int       `json:"refresh_after_seconds"`
}

func (h *AttendanceHandler) GetAttendanceSessions(c *gin.Context) {
	sectionID := c.Query("section_id")
	academicYearID := c.Query("academic_year_id")
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
			query = query.Where("sections.class_teacher_id = ?", staffID)
		}
	}
	if sectionID != "" {
		query = query.Where("attendance_sessions.section_id = ?", sectionID)
	}
	if academicYearID != "" {
		query = query.Where("attendance_sessions.academic_year_id = ?", academicYearID)
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
		AcademicYearID  string `json:"academic_year_id" binding:"required"`
		SectionID       string `json:"section_id" binding:"required"`
		SubjectID       string `json:"subject_id"`
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
	req.SubjectID = strings.TrimSpace(req.SubjectID)
	req.TimetableSlotID = strings.TrimSpace(req.TimetableSlotID)
	if currentRole(c) == "teacher" {
		if req.StaffID != currentStaffID(c) ||
			!classTeacherForSection(currentStaffID(c), req.SectionID, scopedSchoolID(c)) {
			fail(c, http.StatusForbidden, "Only the class teacher can take attendance for this class")
			return
		}
	} else if currentRole(c) != "" && !canTeachSectionSubject(c, req.StaffID, req.SectionID, req.SubjectID, req.TimetableSlotID) {
		fail(c, http.StatusForbidden, "attendance session ownership denied")
		return
	}
	if req.SubjectID == "" {
		subjectID, err := defaultAttendanceSubjectID(scopedSchoolID(c), req.AcademicYearID, req.SectionID, req.StaffID)
		if err != nil {
			fail(c, http.StatusBadRequest, err.Error())
			return
		}
		req.SubjectID = subjectID
	}
	if err := academicDomainService().ValidateTimetableSlotRefs(scopedSchoolID(c), req.AcademicYearID, req.SectionID, req.SubjectID, req.StaffID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	session := models.AttendanceSession{
		SectionID:      req.SectionID,
		AcademicYearID: req.AcademicYearID,
		SubjectID:      req.SubjectID,
		StaffID:        req.StaffID,
		Date:           date,
		PeriodNumber:   req.PeriodNumber,
		TotalStudents:  0,
		PresentCount:   0,
		IsFinalized:    false,
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

func defaultAttendanceSubjectID(schoolID, academicYearID, sectionID, staffID string) (string, error) {
	var section models.Section
	if err := database.DB.Model(&models.Section{}).
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("sections.id = ? AND sections.academic_year_id = ? AND grades.school_id = ?", sectionID, academicYearID, schoolID).
		First(&section).Error; err != nil {
		return "", errors.New("section must belong to the selected academic year")
	}

	baseQuery := database.DB.Model(&models.StaffSubject{}).
		Joins("JOIN staffs ON staffs.id = staff_subjects.staff_id").
		Joins("JOIN subjects ON subjects.id = staff_subjects.subject_id").
		Where("staffs.school_id = ? AND subjects.school_id = ?", schoolID, schoolID).
		Where("staff_subjects.academic_year_id = ? AND staff_subjects.staff_id = ? AND staff_subjects.grade_id = ?", academicYearID, staffID, section.GradeID).
		Order("staff_subjects.is_primary DESC, staff_subjects.created_at ASC")

	var assignment models.StaffSubject
	if err := baseQuery.Where("staff_subjects.section_id = ?", sectionID).First(&assignment).Error; err == nil {
		return assignment.SubjectID, nil
	} else if !errors.Is(err, gorm.ErrRecordNotFound) {
		return "", errors.New("Failed to resolve attendance subject")
	}

	if err := baseQuery.Where("staff_subjects.section_id IS NULL OR staff_subjects.section_id = ''").First(&assignment).Error; err != nil {
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return "", errors.New("Failed to resolve attendance subject")
		}
		return "", errors.New("No subject assignment is available for attendance in this class")
	}
	return assignment.SubjectID, nil
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
	role := currentRole(c)
	if role == "teacher" && session.IsFinalized {
		fail(c, http.StatusForbidden, "Attendance is locked. Ask the principal to reopen this session.")
		return
	}
	if role == "teacher" {
		if !classTeacherForSection(currentStaffID(c), session.SectionID, scopedSchoolID(c)) {
			fail(c, http.StatusForbidden, "Only the class teacher can take attendance for this class")
			return
		}
	} else if role != "" && role != "admin" && role != "principal" && !canTeachSectionSubject(c, session.StaffID, session.SectionID, session.SubjectID, stringValue(session.TimetableSlotID)) {
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
		session.IsFinalized = true
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

func (h *AttendanceHandler) ReopenAttendanceSession(c *gin.Context) {
	sessionID := c.Param("session_id")
	var req struct {
		Reason string `json:"reason" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, "reason is required")
		return
	}
	reason := strings.TrimSpace(req.Reason)
	if reason == "" {
		fail(c, http.StatusBadRequest, "reason is required")
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

	if err := database.DB.Model(&session).Update("is_finalized", false).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to reopen attendance session")
		return
	}
	session.IsFinalized = false
	auditAction(c, "attendance", "reopen: "+reason, "attendance_sessions", &sessionID)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: session, Message: "Attendance session reopened"})
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

func staffAttendanceLocation() *time.Location {
	location, err := time.LoadLocation("Asia/Kolkata")
	if err != nil {
		return time.UTC
	}
	return location
}

func staffAttendanceDate(now time.Time) (time.Time, string) {
	dateText := now.In(staffAttendanceLocation()).Format("2006-01-02")
	date, _ := time.Parse("2006-01-02", dateText)
	return date, dateText
}

func staffAttendanceDayRange(date time.Time) (time.Time, time.Time) {
	start := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, time.UTC)
	return start, start.AddDate(0, 0, 1)
}

func staffQRSecret() []byte {
	secret := strings.TrimSpace(os.Getenv("STAFF_QR_SECRET"))
	if secret == "" {
		secret = strings.TrimSpace(os.Getenv("JWT_SECRET"))
	}
	if secret == "" {
		secret = "dev-staff-qr-secret-change-me"
	}
	return []byte(secret)
}

func randomStaffQRNonce() (string, error) {
	bytes := make([]byte, 12)
	if _, err := cryptoRand.Read(bytes); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(bytes), nil
}

func signStaffQRPayload(encodedPayload string) string {
	mac := hmac.New(sha256.New, staffQRSecret())
	mac.Write([]byte(encodedPayload))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}

func newStaffQRToken(schoolID string, now time.Time) (string, staffQRPayload, error) {
	_, dateText := staffAttendanceDate(now)
	nonce, err := randomStaffQRNonce()
	if err != nil {
		return "", staffQRPayload{}, err
	}
	payload := staffQRPayload{
		SchoolID:  schoolID,
		Date:      dateText,
		IssuedAt:  now.Unix(),
		ExpiresAt: now.Add(time.Duration(staffQRRefreshSeconds) * time.Second).Unix(),
		Nonce:     nonce,
	}
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return "", staffQRPayload{}, err
	}
	encodedPayload := base64.RawURLEncoding.EncodeToString(payloadBytes)
	token := encodedPayload + "." + signStaffQRPayload(encodedPayload)
	return token, payload, nil
}

func verifyStaffQRToken(token string, now time.Time) (staffQRPayload, error) {
	parts := strings.Split(token, ".")
	if len(parts) != 2 || strings.TrimSpace(parts[0]) == "" || strings.TrimSpace(parts[1]) == "" {
		return staffQRPayload{}, errInvalidStaffQRToken
	}
	expected := signStaffQRPayload(parts[0])
	expectedBytes, err := base64.RawURLEncoding.DecodeString(expected)
	if err != nil {
		return staffQRPayload{}, errInvalidStaffQRToken
	}
	actualBytes, err := base64.RawURLEncoding.DecodeString(parts[1])
	if err != nil {
		return staffQRPayload{}, errInvalidStaffQRToken
	}
	if !hmac.Equal(actualBytes, expectedBytes) {
		return staffQRPayload{}, errInvalidStaffQRToken
	}
	payloadBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return staffQRPayload{}, errInvalidStaffQRToken
	}
	var payload staffQRPayload
	if err := json.Unmarshal(payloadBytes, &payload); err != nil {
		return staffQRPayload{}, errInvalidStaffQRToken
	}
	if payload.SchoolID == "" || payload.Date == "" || payload.IssuedAt == 0 || payload.ExpiresAt == 0 || payload.Nonce == "" {
		return staffQRPayload{}, errInvalidStaffQRToken
	}
	if _, err := time.Parse("2006-01-02", payload.Date); err != nil {
		return staffQRPayload{}, errInvalidStaffQRToken
	}
	if now.Unix() > payload.ExpiresAt {
		return staffQRPayload{}, errExpiredStaffQRToken
	}
	if payload.IssuedAt > now.Add(2*time.Minute).Unix() || payload.ExpiresAt <= payload.IssuedAt {
		return staffQRPayload{}, errInvalidStaffQRToken
	}
	return payload, nil
}

func attendanceStringPtr(value string) *string {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	return &value
}

func upsertStaffAttendance(
	tx *gorm.DB,
	staffID string,
	date time.Time,
	status string,
	checkIn *time.Time,
	checkOut *time.Time,
	source string,
	biometricID string,
	markedBy *string,
) (models.StaffAttendance, bool, error) {
	start, end := staffAttendanceDayRange(date)
	status = strings.ToLower(strings.TrimSpace(status))
	source = strings.ToLower(strings.TrimSpace(source))
	biometricID = strings.TrimSpace(biometricID)

	var attendance models.StaffAttendance
	err := tx.Where("staff_id = ? AND date >= ? AND date < ?", staffID, start, end).First(&attendance).Error
	if err == nil {
		checkInRecorded := false
		if status != "" {
			attendance.Status = status
		}
		if checkIn != nil && attendance.CheckIn == nil {
			attendance.CheckIn = checkIn
			checkInRecorded = true
		}
		if checkOut != nil {
			attendance.CheckOut = checkOut
		}
		if source != "" {
			attendance.Source = source
		}
		if biometricID != "" {
			attendance.BiometricID = biometricID
		}
		if markedBy != nil {
			attendance.MarkedBy = markedBy
			attendance.ApprovedBy = markedBy
		}
		if err := tx.Save(&attendance).Error; err != nil {
			return attendance, false, err
		}
		return attendance, checkInRecorded, nil
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return attendance, false, err
	}

	attendance = models.StaffAttendance{
		StaffID:     staffID,
		Date:        start,
		CheckIn:     checkIn,
		CheckOut:    checkOut,
		Status:      status,
		BiometricID: biometricID,
		Source:      source,
		MarkedBy:    markedBy,
		ApprovedBy:  markedBy,
	}
	if attendance.Source == "" {
		attendance.Source = "manual"
	}
	if err := tx.Create(&attendance).Error; err != nil {
		return attendance, false, err
	}
	return attendance, checkIn != nil, nil
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
			c.JSON(http.StatusOK, models.APIResponse{
				Success: true,
				Data: gin.H{
					"student_id":        studentID,
					"academic_year_id":  yearID,
					"term_id":           termID,
					"total_days":        0,
					"present_days":      0,
					"absent_days":       0,
					"late_count":        0,
					"attendance_pct":    0,
					"attendance_status": "not_started",
				},
			})
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
	if !validAttendanceStatus(req.Status) {
		fail(c, http.StatusBadRequest, "Invalid attendance status")
		return
	}
	schoolID := scopedSchoolID(c)
	if schoolID != "" && !staffBelongsToSchool(req.StaffID, schoolID) {
		fail(c, http.StatusForbidden, "staff access denied")
		return
	}

	// Parse date
	date, err := time.Parse("2006-01-02", req.Date)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid date format. Use YYYY-MM-DD"})
		return
	}

	var checkIn *time.Time
	// Parse check_in if provided
	if req.CheckIn != "" {
		parsed, err := combineDateAndClock(date, req.CheckIn)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid check_in format. Use HH:MM:SS"})
			return
		}
		checkIn = &parsed
	}

	var checkOut *time.Time
	// Parse check_out if provided
	if req.CheckOut != "" {
		parsed, err := combineDateAndClock(date, req.CheckOut)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid check_out format. Use HH:MM:SS"})
			return
		}
		checkOut = &parsed
	}

	attendance, _, err := upsertStaffAttendance(
		database.DB,
		req.StaffID,
		date,
		req.Status,
		checkIn,
		checkOut,
		"manual",
		req.BiometricID,
		attendanceStringPtr(currentUserID(c)),
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to mark attendance"})
		return
	}

	id := attendance.ID
	auditAction(c, "attendance", "create", "staff_attendances", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: attendance})
}

func (h *AttendanceHandler) GetStaffQRToken(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	if schoolID == "" {
		fail(c, http.StatusForbidden, "school scope required")
		return
	}
	now := time.Now().UTC()
	token, payload, err := newStaffQRToken(schoolID, now)
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create staff QR token")
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: staffQRTokenResponse{
			Token:               token,
			SchoolDate:          payload.Date,
			IssuedAt:            time.Unix(payload.IssuedAt, 0).UTC(),
			ExpiresAt:           time.Unix(payload.ExpiresAt, 0).UTC(),
			ServerTime:          now,
			RefreshAfterSeconds: staffQRRefreshSeconds,
		},
	})
}

func (h *AttendanceHandler) ScanStaffQR(c *gin.Context) {
	var req struct {
		Token   string `json:"token" binding:"required"`
		StaffID string `json:"staff_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	payload, err := verifyStaffQRToken(strings.TrimSpace(req.Token), time.Now().UTC())
	if err != nil {
		if errors.Is(err, errExpiredStaffQRToken) {
			fail(c, http.StatusBadRequest, "QR code expired")
			return
		}
		fail(c, http.StatusBadRequest, "Invalid QR code")
		return
	}

	schoolID := scopedSchoolID(c)
	if schoolID == "" || payload.SchoolID != schoolID {
		fail(c, http.StatusForbidden, "QR code is not valid for this school")
		return
	}
	var staffID string
	switch currentRole(c) {
	case "kiosk":
		staffID = strings.TrimSpace(req.StaffID)
		if staffID == "" {
			fail(c, http.StatusBadRequest, "staff_id is required for kiosk QR scans")
			return
		}
	default:
		staffID = currentStaffID(c)
	}
	if staffID == "" {
		fail(c, http.StatusForbidden, "teacher account is not linked to a staff profile")
		return
	}
	if !staffBelongsToSchool(staffID, schoolID) {
		fail(c, http.StatusForbidden, "staff access denied")
		return
	}
	date, err := time.Parse("2006-01-02", payload.Date)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid QR date")
		return
	}

	now := time.Now().UTC()
	var attendance models.StaffAttendance
	var punchRecorded bool
	var notificationLogs []models.NotificationLog
	err = database.DB.Transaction(func(tx *gorm.DB) error {
		var upsertErr error
		attendance, punchRecorded, upsertErr = upsertStaffAttendance(
			tx,
			staffID,
			date,
			"present",
			&now,
			nil,
			"qr",
			"qr:"+payload.Nonce,
			attendanceStringPtr(currentUserID(c)),
		)
		if upsertErr != nil {
			return upsertErr
		}
		if !punchRecorded {
			return nil
		}
		var notifyErr error
		notificationLogs, notifyErr = createStaffPunchInNotificationsTx(
			tx,
			c,
			schoolID,
			attendance,
			now,
		)
		return notifyErr
	})
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to record staff attendance")
		return
	}
	message := "Staff attendance recorded"
	if !punchRecorded {
		message = "Staff attendance already recorded"
	}
	id := attendance.ID
	if punchRecorded {
		auditAction(c, "attendance", "punch_in", "staff_attendances", &id)
		enqueuePushNotifications(notificationLogs)
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: message, Data: attendance})
}

func createStaffPunchInNotificationsTx(
	tx *gorm.DB,
	c *gin.Context,
	schoolID string,
	attendance models.StaffAttendance,
	checkIn time.Time,
) ([]models.NotificationLog, error) {
	staffName := strings.TrimSpace(attendance.StaffID)
	var staff models.Staff
	if err := tx.First(&staff, "id = ? AND school_id = ?", attendance.StaffID, schoolID).Error; err == nil {
		name := strings.TrimSpace(strings.TrimSpace(staff.FirstName) + " " + strings.TrimSpace(staff.LastName))
		if name != "" {
			staffName = name
		}
	}
	if staffName == "" {
		staffName = "A staff member"
	}
	body := staffName + " punched in at " + checkIn.In(staffAttendanceLocation()).Format("15:04") + "."
	return createNotificationLogsForRolesTx(
		tx,
		schoolID,
		[]string{"principal", "admin"},
		currentUserID(c),
		"Staff punch-in recorded",
		body,
		"attendance",
		"medium",
		"staff_attendance",
		attendance.ID,
	)
}

func (h *AttendanceHandler) GetMyStaffAttendanceToday(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	if schoolID == "" {
		fail(c, http.StatusForbidden, "school scope required")
		return
	}
	staffID := currentStaffID(c)
	if staffID == "" {
		fail(c, http.StatusForbidden, "teacher account is not linked to a staff profile")
		return
	}
	if !staffBelongsToSchool(staffID, schoolID) {
		fail(c, http.StatusForbidden, "staff access denied")
		return
	}
	date, dateText := staffAttendanceDate(time.Now().UTC())
	start, end := staffAttendanceDayRange(date)
	var attendance models.StaffAttendance
	err := database.DB.Preload("Staff").
		Where("staff_id = ? AND date >= ? AND date < ?", staffID, start, end).
		First(&attendance).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: gin.H{
			"checked_in":  false,
			"school_date": dateText,
			"attendance":  nil,
		}})
		return
	}
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load staff attendance")
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: gin.H{
		"checked_in":  attendance.CheckIn != nil,
		"school_date": dateText,
		"attendance":  attendance,
	}})
}

func (h *AttendanceHandler) ListStaffAttendance(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	if schoolID == "" {
		fail(c, http.StatusForbidden, "school scope required")
		return
	}
	dateText := strings.TrimSpace(c.Query("date"))
	var date time.Time
	var err error
	if dateText == "" {
		date, dateText = staffAttendanceDate(time.Now().UTC())
	} else {
		date, err = time.Parse("2006-01-02", dateText)
		if err != nil {
			fail(c, http.StatusBadRequest, "Invalid date format. Use YYYY-MM-DD")
			return
		}
	}
	start, end := staffAttendanceDayRange(date)
	var attendances []models.StaffAttendance
	if err := database.DB.Model(&models.StaffAttendance{}).
		Joins("JOIN staffs ON staffs.id = staff_attendances.staff_id").
		Where("staffs.school_id = ? AND staff_attendances.date >= ? AND staff_attendances.date < ?", schoolID, start, end).
		Preload("Staff").
		Order("staff_attendances.check_in DESC, staff_attendances.updated_at DESC").
		Find(&attendances).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load staff attendance")
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: gin.H{
		"date":        dateText,
		"attendances": attendances,
	}})
}

func (h *AttendanceHandler) ExportStaffQRDailyLogs(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	if schoolID == "" {
		fail(c, http.StatusForbidden, "school scope required")
		return
	}
	dateText := strings.TrimSpace(c.Query("date"))
	var date time.Time
	var err error
	if dateText == "" {
		date, dateText = staffAttendanceDate(time.Now().UTC())
	} else {
		date, err = time.Parse("2006-01-02", dateText)
		if err != nil {
			fail(c, http.StatusBadRequest, "Invalid date format. Use YYYY-MM-DD")
			return
		}
	}

	start, end := staffAttendanceDayRange(date)
	var attendances []models.StaffAttendance
	if err := database.DB.Model(&models.StaffAttendance{}).
		Joins("JOIN staffs ON staffs.id = staff_attendances.staff_id").
		Where("staffs.school_id = ? AND staff_attendances.date >= ? AND staff_attendances.date < ? AND LOWER(staff_attendances.source) = ?", schoolID, start, end, "qr").
		Preload("Staff").
		Order("staff_attendances.check_in ASC, staff_attendances.updated_at ASC").
		Find(&attendances).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to export staff QR logs")
		return
	}

	var buffer bytes.Buffer
	writer := csv.NewWriter(&buffer)
	_ = writer.Write([]string{"date", "staff_id", "staff_name", "status", "check_in", "source"})
	for _, row := range attendances {
		_ = writer.Write(staffQRLogExportRow(row))
	}
	writer.Flush()
	if err := writer.Error(); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to build staff QR log export")
		return
	}

	filename := fmt.Sprintf("staff_qr_logs_%s.csv", dateText)
	c.Header("Content-Disposition", fmt.Sprintf(`attachment; filename="%s"`, filename))
	c.Data(http.StatusOK, "text/csv; charset=utf-8", buffer.Bytes())
}

func staffQRLogExportRow(row models.StaffAttendance) []string {
	staffName := strings.TrimSpace(row.StaffID)
	if row.Staff != nil {
		name := strings.TrimSpace(strings.TrimSpace(row.Staff.FirstName) + " " + strings.TrimSpace(row.Staff.LastName))
		if name != "" {
			staffName = name
		}
	}
	checkIn := ""
	if row.CheckIn != nil {
		checkIn = row.CheckIn.In(staffAttendanceLocation()).Format(time.RFC3339)
	}
	return []string{
		row.Date.Format("2006-01-02"),
		row.StaffID,
		staffName,
		row.Status,
		checkIn,
		row.Source,
	}
}
