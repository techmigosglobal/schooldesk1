package handlers

import (
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func (h *LeaveHandler) GetStudentLeaveApplications(c *gin.Context) {
	page, pageSize := parsePagination(c)
	query := scopedStudentLeaveQuery(c)
	if studentID := strings.TrimSpace(c.Query("student_id")); studentID != "" {
		query = query.Where("student_leave_applications.student_id = ?", studentID)
	}
	if status := strings.TrimSpace(c.Query("status")); status != "" {
		query = query.Where("student_leave_applications.status = ?", strings.ToLower(status))
	}

	var total int64
	query.Count(&total)
	var rows []models.StudentLeaveApplication
	if err := preloadStudentLeaveDetails(query).
		Order("student_leave_applications.created_at DESC").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch student leave applications")
		return
	}
	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, rows))
}

func (h *LeaveHandler) CreateStudentLeaveApplication(c *gin.Context) {
	if currentRole(c) != "parent" {
		fail(c, http.StatusForbidden, "Only parents can submit student leave applications")
		return
	}

	var req models.CreateStudentLeaveApplicationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	req.StudentID = strings.TrimSpace(req.StudentID)
	req.LeaveType = strings.TrimSpace(req.LeaveType)
	req.Reason = strings.TrimSpace(req.Reason)
	if req.StudentID == "" || req.LeaveType == "" || req.Reason == "" {
		fail(c, http.StatusBadRequest, "student_id, leave_type, and reason are required")
		return
	}
	if !canAccessStudent(c, req.StudentID) {
		fail(c, http.StatusForbidden, "Parent is not linked to this student")
		return
	}

	fromDate, err := parseDate(strings.TrimSpace(req.FromDate))
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid from_date format. Use YYYY-MM-DD")
		return
	}
	toDate, err := parseDate(strings.TrimSpace(req.ToDate))
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid to_date format. Use YYYY-MM-DD")
		return
	}
	if toDate.Before(fromDate) {
		fail(c, http.StatusBadRequest, "to_date must be on or after from_date")
		return
	}
	if req.HalfDay && !fromDate.Equal(toDate) {
		fail(c, http.StatusBadRequest, "half_day leave must start and end on the same date")
		return
	}

	totalDays := toDate.Sub(fromDate).Hours()/24 + 1
	if req.HalfDay {
		totalDays = 0.5
	}
	row := models.StudentLeaveApplication{
		SchoolID:     scopedSchoolID(c),
		StudentID:    req.StudentID,
		ParentUserID: currentUserID(c),
		LeaveType:    req.LeaveType,
		FromDate:     fromDate,
		ToDate:       toDate,
		HalfDay:      req.HalfDay,
		TotalDays:    totalDays,
		Reason:       req.Reason,
		Status:       "pending",
		AppliedAt:    time.Now().UTC(),
	}
	if err := database.DB.Create(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create student leave application")
		return
	}
	id := row.ID
	auditAction(c, "student_leave", "create", "student_leave_applications", &id)
	if logs, err := createNotificationLogsForRolesTx(
		database.DB,
		scopedSchoolID(c),
		[]string{"admin", "principal"},
		c.GetString("user_id"),
		"Student leave approval pending",
		"A parent submitted a student leave request.",
		"pending_approval",
		"high",
		"leave",
		row.ID,
	); err == nil {
		enqueuePushNotifications(logs)
	}
	if err := preloadStudentLeaveDetails(database.DB).First(&row, "id = ?", row.ID).Error; err != nil {
		success(c, http.StatusCreated, row, "Student leave application submitted")
		return
	}
	success(c, http.StatusCreated, row, "Student leave application submitted")
}

func (h *LeaveHandler) DecideStudentLeaveApplication(c *gin.Context) {
	if currentRole(c) != "admin" && currentRole(c) != "principal" && currentRole(c) != "teacher" {
		fail(c, http.StatusForbidden, "Only school staff can decide student leave applications")
		return
	}
	var req struct {
		Status          string `json:"status" binding:"required"`
		RejectionReason string `json:"rejection_reason"`
		Remarks         string `json:"remarks"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	status := strings.ToLower(strings.TrimSpace(req.Status))
	if status != "approved" && status != "rejected" {
		fail(c, http.StatusBadRequest, "status must be approved or rejected")
		return
	}

	var row models.StudentLeaveApplication
	if err := scopedStudentLeaveQuery(c).First(&row, "student_leave_applications.id = ?", c.Param("id")).Error; err != nil {
		fail(c, http.StatusNotFound, "Student leave application not found")
		return
	}
	if row.Status != "pending" {
		fail(c, http.StatusBadRequest, "Student leave application has already been actioned")
		return
	}

	now := time.Now().UTC()
	decider := currentUserID(c)
	row.Status = status
	row.DecidedBy = &decider
	row.DecidedByRole = currentRole(c)
	row.DecidedAt = &now
	if status == "rejected" {
		reason := strings.TrimSpace(req.RejectionReason)
		if reason == "" {
			reason = strings.TrimSpace(req.Remarks)
		}
		if reason == "" {
			fail(c, http.StatusBadRequest, "rejection_reason is required when rejecting")
			return
		}
		row.RejectionReason = reason
	}
	if err := database.DB.Save(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update student leave application")
		return
	}
	id := row.ID
	auditAction(c, "student_leave", status, "student_leave_applications", &id)
	if logs, err := createNotificationLogsForUserIDsTx(
		database.DB,
		scopedSchoolID(c),
		[]string{row.ParentUserID},
		"Student leave "+status,
		"Your student leave request was "+status+".",
		"pending_approval",
		"medium",
		"leave",
		row.ID,
	); err == nil {
		enqueuePushNotifications(logs)
	}
	if err := preloadStudentLeaveDetails(database.DB).First(&row, "id = ?", row.ID).Error; err != nil {
		success(c, http.StatusOK, row, "Student leave application updated")
		return
	}
	success(c, http.StatusOK, row, "Student leave application updated")
}

func scopedStudentLeaveQuery(c *gin.Context) *gorm.DB {
	query := database.DB.Model(&models.StudentLeaveApplication{}).
		Where("student_leave_applications.school_id = ?", scopedSchoolID(c))
	switch currentRole(c) {
	case "admin", "principal":
		return query
	case "parent":
		return query.Where(
			"(student_leave_applications.parent_user_id = ? OR student_leave_applications.student_id IN (?))",
			currentUserID(c),
			linkedStudentSubquery(c),
		)
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			return query.Where("1 = 0")
		}
		sections := teacherSectionSubquery(staffID, scopedSchoolID(c))
		return query.
			Joins("JOIN students ON students.id = student_leave_applications.student_id").
			Where("students.school_id = ?", scopedSchoolID(c)).
			Where(`
			(
				students.current_section_id IN (?)
				OR EXISTS (
					SELECT 1 FROM enrollments
					WHERE enrollments.student_id = students.id
						AND enrollments.section_id IN (?)
				)
			)
			`, sections, teacherSectionSubquery(staffID, scopedSchoolID(c)))
	default:
		return query.Where("1 = 0")
	}
}

func preloadStudentLeaveDetails(query *gorm.DB) *gorm.DB {
	return query.
		Preload("Student").
		Preload("Student.CurrentSection").
		Preload("Student.CurrentSection.Grade").
		Preload("ParentUser").
		Preload("Decider")
}
