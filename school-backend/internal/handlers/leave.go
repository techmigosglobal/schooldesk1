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

type LeaveHandler struct{}

func NewLeaveHandler() *LeaveHandler {
	return &LeaveHandler{}
}

func (h *LeaveHandler) GetLeaveTypes(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var leaveTypes []models.LeaveType
	query := database.DB.Preload("School")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	query.Find(&leaveTypes)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: leaveTypes})
}

func (h *LeaveHandler) CreateLeaveType(c *gin.Context) {
	var req struct {
		SchoolID         string `json:"school_id" binding:"required"`
		LeaveName        string `json:"leave_name" binding:"required"`
		MaxDaysPerYear   int    `json:"max_days_per_year"`
		CarryForwardDays int    `json:"carry_forward_days"`
		IsPaid           bool   `json:"is_paid"`
		ApplicableTo     string `json:"applicable_to"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	leaveType := models.LeaveType{
		SchoolID:         scopedSchoolID(c),
		LeaveName:        req.LeaveName,
		MaxDaysPerYear:   req.MaxDaysPerYear,
		CarryForwardDays: req.CarryForwardDays,
		IsPaid:           req.IsPaid,
		ApplicableTo:     req.ApplicableTo,
	}

	if err := database.DB.Create(&leaveType).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create leave type"})
		return
	}

	id := leaveType.ID
	auditAction(c, "leave", "create", "leave_types", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: leaveType})
}

func (h *LeaveHandler) GetLeaveApplications(c *gin.Context) {
	staffID := strings.TrimSpace(c.Query("staff_id"))
	status := strings.ToLower(strings.TrimSpace(c.Query("status")))

	var applications []models.LeaveApplication
	query := scopedStaffLeaveQuery(c).
		Preload("Staff").
		Preload("LeaveType").
		Preload("Approver")
	if staffID != "" {
		if currentRole(c) == "teacher" && staffID != currentStaffID(c) {
			fail(c, http.StatusForbidden, "staff access denied")
			return
		}
		query = query.Where("leave_applications.staff_id = ?", staffID)
	}
	if status != "" {
		if !validStaffLeaveStatus(status) {
			fail(c, http.StatusBadRequest, "invalid leave status")
			return
		}
		query = query.Where("LOWER(leave_applications.status) = ?", status)
	}
	query.Find(&applications)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: applications})
}

func (h *LeaveHandler) CreateLeaveApplication(c *gin.Context) {
	var req models.CreateLeaveApplicationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	req.StaffID = strings.TrimSpace(req.StaffID)
	req.LeaveTypeID = strings.TrimSpace(req.LeaveTypeID)
	if !canSubmitStaffLeave(c, req.StaffID, req.LeaveTypeID) {
		fail(c, http.StatusForbidden, "staff or leave type access denied")
		return
	}

	fromDate, err := time.Parse("2006-01-02", strings.TrimSpace(req.FromDate))
	if err != nil {
		fail(c, http.StatusBadRequest, "from_date must use YYYY-MM-DD")
		return
	}
	toDate, err := time.Parse("2006-01-02", strings.TrimSpace(req.ToDate))
	if err != nil {
		fail(c, http.StatusBadRequest, "to_date must use YYYY-MM-DD")
		return
	}
	if toDate.Before(fromDate) {
		fail(c, http.StatusBadRequest, "to_date cannot be before from_date")
		return
	}
	if req.HalfDay && !fromDate.Equal(toDate) {
		fail(c, http.StatusBadRequest, "half-day leave must start and end on the same date")
		return
	}

	var totalDays float64
	if fromDate.Equal(toDate) {
		totalDays = 1
	} else {
		totalDays = toDate.Sub(fromDate).Hours()/24 + 1
	}
	if req.HalfDay {
		totalDays = 0.5
	}

	application := models.LeaveApplication{
		StaffID:     req.StaffID,
		LeaveTypeID: req.LeaveTypeID,
		FromDate:    fromDate,
		ToDate:      toDate,
		HalfDay:     req.HalfDay,
		TotalDays:   totalDays,
		Reason:      req.Reason,
		Status:      "pending",
		AppliedAt:   time.Now(),
	}

	if err := database.DB.Create(&application).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create leave application"})
		return
	}

	id := application.ID
	auditAction(c, "leave", "create", "leave_applications", &id)
	if logs, err := createNotificationLogsForRolesTx(
		database.DB,
		scopedSchoolID(c),
		[]string{"admin", "principal"},
		c.GetString("user_id"),
		"Teacher leave approval pending",
		"A teacher leave request is waiting for approval.",
		"pending_approval",
		"high",
		"leave",
		application.ID,
	); err == nil {
		enqueuePushNotifications(logs)
	}
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: application})
}

func (h *LeaveHandler) ApproveLeaveApplication(c *gin.Context) {
	id := c.Param("id")
	var application models.LeaveApplication
	if err := scopedStaffLeaveQuery(c).First(&application, "leave_applications.id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Application not found"})
		return
	}

	var req struct {
		Status string `json:"status" binding:"required"`
		Reason string `json:"reason"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	status := strings.ToLower(strings.TrimSpace(req.Status))
	switch status {
	case "approved", "rejected":
	default:
		fail(c, http.StatusBadRequest, "status must be approved or rejected")
		return
	}
	application.Status = status
	if approverID := currentStaffID(c); approverID != "" && staffBelongsToSchool(approverID, scopedSchoolID(c)) {
		application.ApprovedBy = &approverID
	}
	if status == "rejected" {
		application.RejectionReason = strings.TrimSpace(req.Reason)
	} else {
		application.RejectionReason = ""
	}

	if err := database.DB.Save(&application).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update application"})
		return
	}

	auditAction(c, "leave", "update", "leave_applications", &id)
	if userID := staffUserIDForNotification(scopedSchoolID(c), application.StaffID); userID != "" {
		if logs, err := createNotificationLogsForUserIDsTx(
			database.DB,
			scopedSchoolID(c),
			[]string{userID},
			"Leave request "+status,
			"Your leave request was "+status+".",
			"pending_approval",
			"medium",
			"leave",
			application.ID,
		); err == nil {
			enqueuePushNotifications(logs)
		}
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: application})
}

func staffUserIDForNotification(schoolID, staffID string) string {
	var user models.User
	if err := database.DB.
		Where("school_id = ? AND linked_type = ? AND linked_id = ? AND is_active = ?", schoolID, "staff", staffID, true).
		First(&user).Error; err != nil {
		return ""
	}
	return user.ID
}

func (h *LeaveHandler) GetLeaveBalances(c *gin.Context) {
	staffID := strings.TrimSpace(c.Query("staff_id"))
	yearID := strings.TrimSpace(c.Query("academic_year_id"))

	var balances []models.LeaveBalance
	query := scopedStaffLeaveBalanceQuery(c).
		Preload("LeaveType").
		Preload("Staff").
		Preload("AcademicYear")
	if staffID != "" {
		if currentRole(c) == "teacher" && staffID != currentStaffID(c) {
			fail(c, http.StatusForbidden, "staff access denied")
			return
		}
		query = query.Where("leave_balances.staff_id = ?", staffID)
	}
	if yearID != "" {
		if !academicYearBelongsToSchool(yearID, scopedSchoolID(c)) {
			fail(c, http.StatusForbidden, "academic year access denied")
			return
		}
		query = query.Where("leave_balances.academic_year_id = ?", yearID)
	}
	query.Find(&balances)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: balances})
}

func (h *LeaveHandler) InitializeLeaveBalances(c *gin.Context) {
	var req struct {
		StaffID        string `json:"staff_id" binding:"required"`
		AcademicYearID string `json:"academic_year_id" binding:"required"`
		LeaveTypeID    string `json:"leave_type_id" binding:"required"`
		TotalEntitled  int    `json:"total_entitled" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	req.StaffID = strings.TrimSpace(req.StaffID)
	req.AcademicYearID = strings.TrimSpace(req.AcademicYearID)
	req.LeaveTypeID = strings.TrimSpace(req.LeaveTypeID)
	if req.TotalEntitled <= 0 {
		fail(c, http.StatusBadRequest, "total_entitled must be greater than zero")
		return
	}
	schoolID := scopedSchoolID(c)
	if !staffBelongsToSchool(req.StaffID, schoolID) {
		fail(c, http.StatusForbidden, "staff access denied")
		return
	}
	if !academicYearBelongsToSchool(req.AcademicYearID, schoolID) {
		fail(c, http.StatusForbidden, "academic year access denied")
		return
	}
	if !leaveTypeBelongsToSchool(req.LeaveTypeID, schoolID) {
		fail(c, http.StatusForbidden, "leave type access denied")
		return
	}

	balance := models.LeaveBalance{
		StaffID:        req.StaffID,
		AcademicYearID: req.AcademicYearID,
		LeaveTypeID:    req.LeaveTypeID,
		TotalEntitled:  req.TotalEntitled,
		UsedDays:       0,
		PendingDays:    0,
		RemainingDays:  float64(req.TotalEntitled),
	}

	if err := database.DB.Create(&balance).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to initialize balance"})
		return
	}

	id := balance.ID
	auditAction(c, "leave", "create", "leave_balances", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: balance})
}

func scopedStaffLeaveQuery(c *gin.Context) *gorm.DB {
	query := database.DB.
		Model(&models.LeaveApplication{}).
		Joins("JOIN staffs ON staffs.id = leave_applications.staff_id").
		Joins("JOIN leave_types ON leave_types.id = leave_applications.leave_type_id").
		Where("staffs.school_id = ? AND leave_types.school_id = ?", scopedSchoolID(c), scopedSchoolID(c))
	switch currentRole(c) {
	case "admin", "principal":
		return query
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			return query.Where("1 = 0")
		}
		return query.Where("leave_applications.staff_id = ?", staffID)
	default:
		return query.Where("1 = 0")
	}
}

func scopedStaffLeaveBalanceQuery(c *gin.Context) *gorm.DB {
	query := database.DB.
		Model(&models.LeaveBalance{}).
		Joins("JOIN staffs ON staffs.id = leave_balances.staff_id").
		Joins("JOIN leave_types ON leave_types.id = leave_balances.leave_type_id").
		Joins("JOIN academic_years ON academic_years.id = leave_balances.academic_year_id").
		Where("staffs.school_id = ? AND leave_types.school_id = ? AND academic_years.school_id = ?", scopedSchoolID(c), scopedSchoolID(c), scopedSchoolID(c))
	switch currentRole(c) {
	case "admin", "principal":
		return query
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			return query.Where("1 = 0")
		}
		return query.Where("leave_balances.staff_id = ?", staffID)
	default:
		return query.Where("1 = 0")
	}
}

func canSubmitStaffLeave(c *gin.Context, staffID, leaveTypeID string) bool {
	schoolID := scopedSchoolID(c)
	if !leaveTypeBelongsToSchool(leaveTypeID, schoolID) || !staffBelongsToSchool(staffID, schoolID) {
		return false
	}
	switch currentRole(c) {
	case "admin", "principal":
		return true
	case "teacher":
		return staffID == currentStaffID(c)
	default:
		return false
	}
}

func leaveTypeBelongsToSchool(leaveTypeID, schoolID string) bool {
	return countRows(database.DB.Model(&models.LeaveType{}).
		Where("id = ? AND school_id = ?", strings.TrimSpace(leaveTypeID), strings.TrimSpace(schoolID))) > 0
}

func validStaffLeaveStatus(status string) bool {
	switch strings.ToLower(strings.TrimSpace(status)) {
	case "pending", "approved", "rejected":
		return true
	default:
		return false
	}
}
