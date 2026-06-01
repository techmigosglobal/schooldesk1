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

type UserManagementHandler struct{}

func NewUserManagementHandler() *UserManagementHandler {
	return &UserManagementHandler{}
}

func (h *UserManagementHandler) CreateUser(c *gin.Context) {
	var req struct {
		Name                     string `json:"name"`
		Username                 string `json:"username"`
		Email                    string `json:"email"`
		Password                 string `json:"password" binding:"required,min=6"`
		Role                     string `json:"role" binding:"required"`
		Phone                    string `json:"phone"`
		Avatar                   string `json:"avatar"`
		RequestPrincipalApproval bool   `json:"request_principal_approval"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	username := accountUsername(req.Username, req.Email)
	email := strings.TrimSpace(req.Email)
	if username == "" {
		fail(c, http.StatusBadRequest, "username or email is required")
		return
	}
	if email == "" && strings.Contains(username, "@") {
		email = username
	}
	role, err := resolveRole(scopedSchoolID(c), req.Role)
	if err != nil {
		fail(c, http.StatusBadRequest, "role not found")
		return
	}
	if err := ensureActorCanManageRole(c, role.RoleName); err != nil {
		fail(c, http.StatusForbidden, err.Error())
		return
	}
	hash, err := database.HashPassword(req.Password)
	if err != nil {
		fail(c, http.StatusInternalServerError, "failed to hash password")
		return
	}
	requestApproval := req.RequestPrincipalApproval && strings.EqualFold(c.GetString("role_name"), "Admin")
	isActive := !requestApproval
	var user models.User
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		createdUser, err := createUserWithRole(
			tx,
			scopedSchoolID(c),
			role,
			req.Name,
			username,
			email,
			req.Phone,
			hash,
			"",
			nil,
			isActive,
		)
		if err != nil {
			return err
		}
		user = createdUser
		if err := tx.Table("users").Where("id = ?", user.ID).Updates(map[string]interface{}{
			"name":   req.Name,
			"avatar": req.Avatar,
			"role":   canonicalRole(req.Role),
		}).Error; err != nil {
			return err
		}
		if requestApproval {
			if err := createAccountApprovalRecord(tx, c, user.ID, "", req.Name, email, role.RoleName, "create"); err != nil {
				return err
			}
		}
		return nil
	}); err != nil {
		fail(c, http.StatusInternalServerError, "failed to create user")
		return
	}
	auditAction(c, "users", "create", "users", &user.ID)
	response := userResponse(user, role.RoleName, req.Name, req.Avatar)
	if requestApproval {
		response["approval_status"] = "pending"
	}
	success(c, http.StatusCreated, response, "User created successfully")
}

func (h *UserManagementHandler) GetUser(c *gin.Context) {
	var user models.User
	if err := database.DB.Preload("Role").First(&user, "id = ? AND school_id = ?", c.Param("id"), scopedSchoolID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "User not found")
		return
	}
	var extra struct {
		Name   string
		Avatar string
	}
	_ = database.DB.Table("users").Select("name, avatar").Where("id = ?", user.ID).Scan(&extra).Error
	roleName := ""
	if user.Role != nil {
		roleName = user.Role.RoleName
	}
	success(c, http.StatusOK, userResponse(user, roleName, extra.Name, extra.Avatar), "")
}

func (h *UserManagementHandler) PatchUser(c *gin.Context) {
	id := c.Param("id")
	user, currentRoleName, err := loadManagedUser(database.DB, c, id)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			fail(c, http.StatusNotFound, "User not found")
			return
		}
		fail(c, http.StatusForbidden, err.Error())
		return
	}
	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	updates := map[string]interface{}{"updated_at": time.Now().UTC()}
	for _, key := range []string{"username", "email", "phone", "name", "avatar", "is_active"} {
		if value, ok := payload[key]; ok {
			updates[key] = value
		}
	}
	if roleValue, ok := payload["role"].(string); ok && strings.TrimSpace(roleValue) != "" {
		role, err := resolveRole(scopedSchoolID(c), roleValue)
		if err != nil {
			fail(c, http.StatusBadRequest, "role not found")
			return
		}
		if err := ensureActorCanManageRole(c, role.RoleName); err != nil {
			fail(c, http.StatusForbidden, err.Error())
			return
		}
		updates["role_id"] = role.ID
		updates["role"] = canonicalRole(roleValue)
		currentRoleName = role.RoleName
	}
	if password, ok := payload["password"].(string); ok && strings.TrimSpace(password) != "" {
		hash, err := database.HashPassword(password)
		if err != nil {
			fail(c, http.StatusInternalServerError, "failed to hash password")
			return
		}
		updates["password_hash"] = hash
	}
	result := database.DB.Table("users").Where("id = ? AND school_id = ?", id, scopedSchoolID(c)).Updates(updates)
	if result.Error != nil {
		fail(c, http.StatusInternalServerError, "Failed to update user")
		return
	}
	if result.RowsAffected == 0 {
		fail(c, http.StatusNotFound, "User not found")
		return
	}
	auditAction(c, "users", "update", "users", &id)
	_ = currentRoleName
	_ = user
	h.GetUser(c)
}

func (h *UserManagementHandler) DeleteUser(c *gin.Context) {
	id := c.Param("id")
	if _, _, err := loadManagedUser(database.DB, c, id); err != nil {
		if err == gorm.ErrRecordNotFound {
			fail(c, http.StatusNotFound, "User not found")
			return
		}
		fail(c, http.StatusForbidden, err.Error())
		return
	}
	if c.Query("permanent") == "true" {
		var user models.User
		if err := database.DB.First(&user, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
			fail(c, http.StatusNotFound, "User not found")
			return
		}
		if user.IsActive {
			fail(c, http.StatusBadRequest, "Deactivate the user before permanent deletion")
			return
		}
		if err := database.DB.Transaction(func(tx *gorm.DB) error {
			if tx.Migrator().HasTable(&models.UserSession{}) {
				if err := tx.Delete(&models.UserSession{}, "user_id = ?", id).Error; err != nil {
					return err
				}
			}
			if tx.Migrator().HasTable(&models.AuditLog{}) {
				if err := tx.Delete(&models.AuditLog{}, "user_id = ?", id).Error; err != nil {
					return err
				}
			}
			if tx.Migrator().HasTable(&models.ParentStudentLink{}) {
				if err := tx.Delete(&models.ParentStudentLink{}, "parent_user_id = ?", id).Error; err != nil {
					return err
				}
			}
			if tx.Migrator().HasTable(&models.NotificationLog{}) {
				if err := tx.Delete(&models.NotificationLog{}, "recipient_user_id = ?", id).Error; err != nil {
					return err
				}
			}
			return tx.Delete(&models.User{}, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error
		}); err != nil {
			fail(c, http.StatusInternalServerError, "Failed to delete user")
			return
		}
		auditAction(c, "users", "delete_permanent", "users", &id)
		success(c, http.StatusOK, gin.H{"id": id}, "User permanently deleted")
		return
	}
	result := database.DB.Model(&models.User{}).Where("id = ? AND school_id = ?", id, scopedSchoolID(c)).Update("is_active", false)
	if result.Error != nil {
		fail(c, http.StatusInternalServerError, "Failed to deactivate user")
		return
	}
	if result.RowsAffected == 0 {
		fail(c, http.StatusNotFound, "User not found")
		return
	}
	auditAction(c, "users", "delete", "users", &id)
	success(c, http.StatusOK, gin.H{"id": id}, "User deactivated successfully")
}

func (h *UserManagementHandler) UploadAvatar(c *gin.Context) {
	NewUserHandler().UploadUserAvatar(c)
}
