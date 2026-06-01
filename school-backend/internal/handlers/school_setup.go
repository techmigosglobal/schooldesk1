package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/middleware"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type SchoolSetupHandler struct{}

func NewSchoolSetupHandler() *SchoolSetupHandler {
	return &SchoolSetupHandler{}
}

func (h *SchoolSetupHandler) Setup(c *gin.Context) {
	var req struct {
		SchoolName       string `json:"school_name" binding:"required"`
		SchoolType       string `json:"school_type"`
		AffiliationBoard string `json:"affiliation_board"`
		Email            string `json:"email"`
		Phone            string `json:"phone"`
		City             string `json:"city"`
		State            string `json:"state"`
		Timezone         string `json:"timezone"`
		Currency         string `json:"currency"`
		AdminName        string `json:"admin_name" binding:"required"`
		AdminUsername    string `json:"admin_username"`
		AdminEmail       string `json:"admin_email" binding:"required,email"`
		AdminPhone       string `json:"admin_phone"`
		AdminPassword    string `json:"admin_password" binding:"required,min=6"`
		AdminRole        string `json:"admin_role"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	schoolName := strings.TrimSpace(req.SchoolName)
	adminRoleName := titleRole(firstNonEmpty(req.AdminRole, "Principal"))
	if adminRoleName != "Principal" && adminRoleName != "Admin" {
		fail(c, http.StatusBadRequest, "admin_role must be Principal or Admin")
		return
	}

	var duplicate int64
	if err := database.DB.Model(&models.School{}).
		Where("LOWER(name) = ?", strings.ToLower(schoolName)).
		Count(&duplicate).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to check school setup")
		return
	}
	if duplicate > 0 {
		fail(c, http.StatusConflict, "School already exists")
		return
	}

	hash, err := database.HashPassword(req.AdminPassword)
	if err != nil {
		fail(c, http.StatusInternalServerError, "failed to hash password")
		return
	}

	var school models.School
	var adminRole models.Role
	var adminUser models.User
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		school = models.School{
			Name:             schoolName,
			SchoolType:       firstNonEmpty(req.SchoolType, "school"),
			AffiliationBoard: strings.TrimSpace(req.AffiliationBoard),
			Email:            strings.TrimSpace(req.Email),
			Phone:            strings.TrimSpace(req.Phone),
			City:             strings.TrimSpace(req.City),
			State:            strings.TrimSpace(req.State),
			Timezone:         firstNonEmpty(req.Timezone, "Asia/Kolkata"),
			Currency:         firstNonEmpty(req.Currency, "INR"),
			PrincipalName:    strings.TrimSpace(req.AdminName),
		}
		if err := tx.Create(&school).Error; err != nil {
			return err
		}

		roles, err := createSetupRoles(tx, school.ID)
		if err != nil {
			return err
		}
		adminRole = roles[adminRoleName]
		adminUser, err = createUserWithRole(
			tx,
			school.ID,
			adminRole,
			strings.TrimSpace(req.AdminName),
			strings.TrimSpace(req.AdminUsername),
			strings.TrimSpace(req.AdminEmail),
			strings.TrimSpace(req.AdminPhone),
			hash,
			"",
			nil,
			true,
		)
		if err != nil {
			return err
		}
		return tx.Table("users").Where("id = ?", adminUser.ID).Updates(map[string]interface{}{
			"name": strings.TrimSpace(req.AdminName),
			"role": canonicalRole(adminRole.RoleName),
		}).Error
	}); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to set up school")
		return
	}

	login, err := setupLoginResponse(adminUser, adminRole)
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create setup session")
		return
	}
	success(c, http.StatusCreated, gin.H{
		"school": school,
		"auth":   login,
	}, "School setup completed")
}

func createSetupRoles(tx *gorm.DB, schoolID string) (map[string]models.Role, error) {
	roles := map[string]models.Role{}
	for _, roleName := range []string{"Principal", "Admin", "Teacher", "Parent"} {
		role := models.Role{
			SchoolID:     schoolID,
			RoleName:     roleName,
			Description:  roleName + " role",
			IsSystemRole: true,
		}
		if err := tx.Create(&role).Error; err != nil {
			return nil, err
		}
		roles[roleName] = role
	}
	if err := createSetupRolePermissions(tx, roles); err != nil {
		return nil, err
	}
	return roles, nil
}

func createSetupRolePermissions(tx *gorm.DB, roles map[string]models.Role) error {
	modules := []string{
		"dashboard",
		"guardians",
		"medical_records",
		"student_documents",
		"staff_documents",
		"staff_subjects",
		"staff_qualifications",
		"payroll",
		"parent_teacher_meetings",
		"homework",
		"diary_entries",
		"message_conversations",
		"messages",
		"audit_logs",
	}
	for _, module := range modules {
		if err := createSetupPermission(tx, roles["Admin"].ID, module, true, true, true, true, true); err != nil {
			return err
		}
		canPrincipalDelete := module != "audit_logs"
		if err := createSetupPermission(tx, roles["Principal"].ID, module, true, true, true, canPrincipalDelete, true); err != nil {
			return err
		}
		teacherRead := inSetupList(module, "dashboard", "guardians", "medical_records", "student_documents", "staff_subjects", "staff_qualifications", "parent_teacher_meetings", "homework", "diary_entries", "message_conversations", "messages")
		teacherManage := inSetupList(module, "homework", "diary_entries", "message_conversations", "messages", "parent_teacher_meetings")
		if err := createSetupPermission(tx, roles["Teacher"].ID, module, teacherRead, teacherManage, teacherManage, false, false); err != nil {
			return err
		}
		parentRead := inSetupList(module, "dashboard", "guardians", "medical_records", "student_documents", "parent_teacher_meetings", "homework", "diary_entries", "message_conversations", "messages")
		parentCreate := inSetupList(module, "parent_teacher_meetings", "message_conversations", "messages")
		parentUpdate := inSetupList(module, "message_conversations", "messages")
		if err := createSetupPermission(tx, roles["Parent"].ID, module, parentRead, parentCreate, parentUpdate, false, false); err != nil {
			return err
		}
	}
	return nil
}

func createSetupPermission(tx *gorm.DB, roleID, module string, read, create, update, delete, export bool) error {
	return tx.Create(&models.Permission{
		RoleID:    roleID,
		Module:    module,
		CanRead:   read,
		CanCreate: create,
		CanUpdate: update,
		CanDelete: delete,
		CanExport: export,
	}).Error
}

func inSetupList(value string, items ...string) bool {
	for _, item := range items {
		if value == item {
			return true
		}
	}
	return false
}

func setupLoginResponse(user models.User, role models.Role) (models.LoginResponse, error) {
	jti := uuid.NewString()
	tokenTTL := 15 * time.Minute
	token, err := middleware.GenerateToken(
		user.ID,
		user.Email,
		user.RoleID,
		role.RoleName,
		user.SchoolID,
		user.LinkedType,
		stringValue(user.LinkedID),
		jti,
		tokenTTL,
	)
	if err != nil {
		return models.LoginResponse{}, err
	}

	refreshToken := uuid.NewString()
	refreshIssuedAt := time.Now().UTC()
	refreshPayload, _ := json.Marshal(map[string]string{
		"user_id":     user.ID,
		"email":       user.Email,
		"role_id":     user.RoleID,
		"role_name":   role.RoleName,
		"school_id":   user.SchoolID,
		"linked_type": user.LinkedType,
		"linked_id":   stringValue(user.LinkedID),
		"issued_at":   refreshIssuedAt.Format(time.RFC3339Nano),
	})
	if services.Sessions != nil {
		if err := services.Sessions.StoreRefreshToken(context.Background(), refreshToken, string(refreshPayload), 7*24*time.Hour); err != nil {
			return models.LoginResponse{}, err
		}
	}

	return models.LoginResponse{
		Token:        token,
		RefreshToken: refreshToken,
		ExpiresAt:    int64(tokenTTL.Seconds()),
		User: models.UserResponse{
			ID:         user.ID,
			Username:   accountUsername(user.Username, user.Email),
			Email:      user.Email,
			Phone:      user.Phone,
			SchoolID:   user.SchoolID,
			RoleID:     user.RoleID,
			RoleName:   role.RoleName,
			LinkedType: user.LinkedType,
			LinkedID:   stringValue(user.LinkedID),
			IsActive:   user.IsActive,
			IsVerified: user.IsVerified,
		},
	}, nil
}
