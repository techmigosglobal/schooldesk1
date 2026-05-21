package handlers

import (
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type StaffHandler struct{}

func NewStaffHandler() *StaffHandler {
	return &StaffHandler{}
}

func (h *StaffHandler) GetStaff(c *gin.Context) {
	page, pageSize := parsePagination(c)
	schoolID := scopedSchoolID(c)
	deptID := c.Query("department_id")
	status := c.Query("status")

	var staff []models.Staff
	var total int64

	query := database.DB.Model(&models.Staff{})
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	if deptID != "" {
		query = query.Where("department_id = ?", deptID)
	}
	if status != "" {
		query = query.Where("status = ?", status)
	}

	query.Count(&total)
	query = query.Preload("Department").Preload("Qualifications").Preload("Subjects").Preload("Documents").Offset((page - 1) * pageSize).Limit(pageSize)
	query.Find(&staff)

	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, staff))
}

func (h *StaffHandler) UploadStaffPhoto(c *gin.Context) {
	staffID := c.Param("id")
	schoolID := scopedSchoolID(c)

	var staff models.Staff
	if err := database.DB.First(&staff, "id = ? AND school_id = ?", staffID, schoolID).Error; err != nil {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Success: false,
			Error:   "Staff not found",
		})
		return
	}

	file, err := c.FormFile("photo")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Photo file is required"})
		return
	}
	if file.Size > 3*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Photo file must be 3 MB or smaller"})
		return
	}
	ext := strings.ToLower(filepath.Ext(file.Filename))
	switch ext {
	case ".jpg", ".jpeg", ".png", ".webp":
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Photo must be a JPG, PNG, or WebP image"})
		return
	}

	dir := filepath.Join("uploads", "staff", schoolID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		log.Printf("staff photo upload storage preparation failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to prepare upload storage"})
		return
	}
	filename := fmt.Sprintf("%s_photo_%d%s", staffID, time.Now().UnixNano(), ext)
	relativePath := filepath.ToSlash(filepath.Join(dir, filename))
	if err := c.SaveUploadedFile(file, relativePath); err != nil {
		log.Printf("staff photo upload save failed for staff %s: %v", staffID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save staff photo"})
		return
	}

	publicPath := "/" + relativePath
	now := time.Now().UTC()
	var document models.StaffDocument
	result := database.DB.Where("staff_id = ? AND doc_type = ?", staffID, "profile_photo").First(&document)
	if result.Error == nil {
		if err := database.DB.Model(&document).Updates(map[string]interface{}{
			"file_url":    publicPath,
			"verified":    false,
			"uploaded_at": now,
			"updated_at":  now,
		}).Error; err != nil {
			log.Printf("staff photo document update failed for staff %s: %v", staffID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update staff photo"})
			return
		}
	} else if errors.Is(result.Error, gorm.ErrRecordNotFound) {
		document = models.StaffDocument{
			StaffID:    staffID,
			DocType:    "profile_photo",
			FileURL:    publicPath,
			Verified:   false,
			UploadedAt: now,
		}
		if err := database.DB.Create(&document).Error; err != nil {
			log.Printf("staff photo document create failed for staff %s: %v", staffID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save staff photo"})
			return
		}
	} else {
		log.Printf("staff photo document lookup failed for staff %s: %v", staffID, result.Error)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update staff photo"})
		return
	}

	auditAction(c, "staff_documents", "create", "staff", &staffID)
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"photo":     publicPath,
			"photo_url": absoluteURL(c, publicPath),
		},
	})
}

func (h *StaffHandler) GetStaffMember(c *gin.Context) {
	id := c.Param("id")
	var staff models.Staff
	if err := database.DB.Preload("Department").Preload("Qualifications").Preload("Subjects").Preload("Subjects.Subject").Preload("Documents").First(&staff, "id = ?", id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Staff not found"})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: staff})
}

func (h *StaffHandler) CreateStaff(c *gin.Context) {
	var req models.CreateStaffRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	schoolID := scopedSchoolID(c)
	roleName := normalizeStaffAccountRole(req.AccountRole, req.Designation)
	if err := ensureActorCanManageRole(c, roleName); err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
		return
	}
	requestApproval := req.RequestPrincipalApproval && strings.EqualFold(c.GetString("role_name"), "Admin")
	if strings.TrimSpace(req.Password) != "" && strings.TrimSpace(req.Email) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "email is required when creating a staff login"})
		return
	}

	dob, _ := time.Parse("2006-01-02", req.DateOfBirth)
	joinDate, _ := time.Parse("2006-01-02", req.JoinDate)
	var createdStaff models.Staff
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		departmentID, err := h.resolveDepartmentID(tx, schoolID, req.DepartmentID, req.DepartmentName)
		if err != nil {
			return err
		}
		staffCode := strings.TrimSpace(req.StaffCode)
		if staffCode == "" {
			staffCode = generateStaffCode()
		}
		staff := models.Staff{
			SchoolID:       schoolID,
			StaffCode:      staffCode,
			FirstName:      strings.TrimSpace(req.FirstName),
			LastName:       strings.TrimSpace(req.LastName),
			Email:          strings.TrimSpace(req.Email),
			Phone:          strings.TrimSpace(req.Phone),
			DateOfBirth:    dob,
			Gender:         req.Gender,
			Designation:    strings.TrimSpace(req.Designation),
			EmploymentType: req.EmploymentType,
			JoinDate:       joinDate,
			BasicSalary:    req.BasicSalary,
			Status:         "active",
		}
		if requestApproval {
			staff.Status = "pending_approval"
		}
		if departmentID != "" {
			staff.DepartmentID = &departmentID
		}
		if err := tx.Create(&staff).Error; err != nil {
			return err
		}
		var createdUser *models.User
		if strings.TrimSpace(req.Password) != "" {
			user, err := h.createStaffUser(tx, schoolID, staff, req.Password, req.AccountRole, !requestApproval)
			if err != nil {
				return err
			}
			createdUser = &user
		}
		if requestApproval && createdUser != nil {
			if err := createAccountApprovalRecord(
				tx,
				c,
				createdUser.ID,
				staff.ID,
				strings.TrimSpace(staff.FirstName+" "+staff.LastName),
				strings.TrimSpace(staff.Email),
				roleName,
				"create",
			); err != nil {
				return err
			}
		}
		createdStaff = staff
		id := staff.ID
		auditAction(c, "staff", "create", "staff", &id)
		return nil
	}); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: createdStaff})
}

func generateStaffCode() string {
	return fmt.Sprintf("STF-%d", time.Now().UTC().UnixNano())
}

func (h *StaffHandler) createStaffUser(tx *gorm.DB, schoolID string, staff models.Staff, password string, accountRole string, isActive bool) (models.User, error) {
	roleName := normalizeStaffAccountRole(accountRole, staff.Designation)
	var role models.Role
	if err := tx.Where("school_id = ? AND LOWER(role_name) = ?", schoolID, strings.ToLower(roleName)).First(&role).Error; err != nil {
		return models.User{}, err
	}
	email := strings.TrimSpace(staff.Email)
	username := accountUsername(staff.StaffCode, email)
	var existing models.User
	err := tx.Where(
		"school_id = ? AND (LOWER(email) = ? OR LOWER(username) = ?)",
		schoolID,
		strings.ToLower(email),
		strings.ToLower(username),
	).First(&existing).Error
	if err == nil {
		return models.User{}, fmt.Errorf("a login account already exists for %s", username)
	}
	if err != gorm.ErrRecordNotFound {
		return models.User{}, err
	}
	hash, err := database.HashPassword(password)
	if err != nil {
		return models.User{}, err
	}
	name := strings.TrimSpace(staff.FirstName + " " + staff.LastName)
	user := models.User{
		SchoolID:     schoolID,
		Name:         name,
		Username:     username,
		Email:        email,
		Phone:        strings.TrimSpace(staff.Phone),
		RoleSlug:     strings.ToLower(role.RoleName),
		PasswordHash: hash,
		RoleID:       role.ID,
		LinkedType:   "staff",
		LinkedID:     &staff.ID,
		IsActive:     isActive,
		IsVerified:   isActive,
	}
	if err := tx.Create(&user).Error; err != nil {
		return user, err
	}
	if !isActive {
		if err := tx.Model(&models.User{}).
			Where("id = ?", user.ID).
			Updates(map[string]interface{}{"is_active": false, "is_verified": false}).Error; err != nil {
			return user, err
		}
		user.IsActive = false
		user.IsVerified = false
	}
	return user, nil
}

func normalizeStaffAccountRole(accountRole string, designation string) string {
	role := strings.ToLower(strings.TrimSpace(accountRole))
	switch role {
	case "admin":
		return "Admin"
	case "teacher":
		return "Teacher"
	}
	if strings.Contains(strings.ToLower(designation), "admin") {
		return "Admin"
	}
	return "Teacher"
}

func (h *StaffHandler) resolveDepartmentID(tx *gorm.DB, schoolID string, departmentID string, departmentName string) (string, error) {
	deptValue := strings.TrimSpace(departmentID)
	nameValue := strings.TrimSpace(departmentName)
	if nameValue == "" {
		nameValue = deptValue
	}
	if deptValue != "" {
		var existing models.Department
		if err := tx.First(&existing, "id = ? AND school_id = ?", deptValue, schoolID).Error; err == nil {
			return existing.ID, nil
		}
	}
	if nameValue == "" {
		return "", nil
	}
	var dept models.Department
	err := tx.Where("school_id = ? AND LOWER(department_name) = ?", schoolID, strings.ToLower(nameValue)).First(&dept).Error
	if err == nil {
		return dept.ID, nil
	}
	if err != gorm.ErrRecordNotFound {
		return "", err
	}
	dept = models.Department{
		SchoolID:       schoolID,
		DepartmentName: nameValue,
		Description:    "Created from staff management",
	}
	if err := tx.Create(&dept).Error; err != nil {
		return "", err
	}
	return dept.ID, nil
}

func (h *StaffHandler) UpdateStaff(c *gin.Context) {
	id := c.Param("id")
	var staff models.Staff
	if err := database.DB.First(&staff, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Staff not found"})
		return
	}

	var req models.CreateStaffRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if linkedUser, linkedRoleName, err := loadLinkedUserByStaffID(database.DB, scopedSchoolID(c), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to resolve linked user"})
		return
	} else if linkedUser != nil {
		if err := ensureActorCanManageRole(c, linkedRoleName); err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
	}

	staff.FirstName = strings.TrimSpace(req.FirstName)
	staff.LastName = strings.TrimSpace(req.LastName)
	staff.Email = strings.TrimSpace(req.Email)
	staff.Phone = strings.TrimSpace(req.Phone)
	staff.Designation = strings.TrimSpace(req.Designation)
	staff.EmploymentType = req.EmploymentType
	staff.BasicSalary = req.BasicSalary

	if req.DateOfBirth != "" {
		staff.DateOfBirth, _ = time.Parse("2006-01-02", req.DateOfBirth)
	}
	if req.DepartmentID != "" || req.DepartmentName != "" {
		deptID, err := h.resolveDepartmentID(database.DB, scopedSchoolID(c), req.DepartmentID, req.DepartmentName)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to resolve department"})
			return
		}
		if deptID != "" {
			staff.DepartmentID = &deptID
		}
	}

	if err := database.DB.Save(&staff).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update staff"})
		return
	}

	auditAction(c, "staff", "update", "staff", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: staff})
}

func (h *StaffHandler) DeleteStaff(c *gin.Context) {
	id := c.Param("id")
	if linkedUser, linkedRoleName, err := loadLinkedUserByStaffID(database.DB, scopedSchoolID(c), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to resolve linked user"})
		return
	} else if linkedUser != nil {
		if err := ensureActorCanManageRole(c, linkedRoleName); err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
	}
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		var staff models.Staff
		if err := tx.First(&staff, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
			return err
		}
		if err := tx.Model(&models.User{}).
			Where("linked_type = ? AND linked_id = ?", "staff", id).
			Update("is_active", false).Error; err != nil {
			return err
		}
		return tx.Delete(&staff).Error
	}); err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "Staff not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete staff"})
		return
	}
	auditAction(c, "staff", "delete", "staff", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Staff deleted successfully"})
}

func (h *StaffHandler) GetStaffLeaveBalance(c *gin.Context) {
	staffID := c.Param("id")
	var balances []models.LeaveBalance
	database.DB.Preload("LeaveType").Where("staff_id = ?", staffID).Find(&balances)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: balances})
}

func (h *StaffHandler) GetStaffAttendance(c *gin.Context) {
	staffID := c.Param("id")
	month := c.Query("month")
	year := c.Query("year")

	var attendance []models.StaffAttendance
	query := database.DB.Where("staff_id = ?", staffID)
	if month != "" {
		start, end, ok := monthYearRange(month, year)
		if ok {
			query = query.Where("date >= ? AND date < ?", start, end)
		}
	} else if year != "" {
		start, _, ok := monthYearRange("01", year)
		if ok {
			yearEnd := start.AddDate(1, 0, 0)
			query = query.Where("date >= ? AND date < ?", start, yearEnd)
		}
	}
	query.Find(&attendance)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: attendance})
}
