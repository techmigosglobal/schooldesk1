package handlers

import (
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

type UserHandler struct{}

func NewUserHandler() *UserHandler {
	return &UserHandler{}
}

func (h *UserHandler) GetUsers(c *gin.Context) {
	page, pageSize := parsePagination(c)
	schoolID := scopedSchoolID(c)
	roleName := strings.TrimSpace(c.Query("role"))
	status := strings.ToLower(strings.TrimSpace(c.Query("status")))

	var users []models.User
	var total int64

	query := database.DB.Model(&models.User{}).
		Where("users.school_id = ?", schoolID)

	if roleName != "" {
		query = query.Joins("JOIN roles ON roles.id = users.role_id").
			Where("LOWER(roles.role_name) = ?", strings.ToLower(roleName))
	}

	if status != "" {
		switch status {
		case "active":
			query = query.Where("users.is_active = ?", true)
		case "inactive":
			query = query.Where("users.is_active = ?", false)
		}
	}

	query.Count(&total)
	if err := query.
		Preload("Role").
		Order("users.created_at DESC").
		Offset((page - 1) * pageSize).
		Limit(pageSize).
		Find(&users).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch users")
		return
	}

	result := make([]gin.H, 0, len(users))
	for _, u := range users {
		role := ""
		if u.Role != nil {
			role = u.Role.RoleName
		}
		result = append(result, gin.H{
			"id":          u.ID,
			"name":        u.Name,
			"username":    accountUsername(u.Username, u.Email),
			"email":       u.Email,
			"phone":       u.Phone,
			"school_id":   u.SchoolID,
			"role_id":     u.RoleID,
			"avatar":      u.Avatar,
			"role_name":   role,
			"linked_type": u.LinkedType,
			"linked_id":   u.LinkedID,
			"is_active":   u.IsActive,
			"is_verified": u.IsVerified,
			"last_login":  u.LastLogin,
			"created_at":  u.CreatedAt,
		})
	}

	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, result))
}

func (h *UserHandler) UploadUserAvatar(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	user, _, err := loadManagedUser(database.DB, c, id)
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			fail(c, http.StatusNotFound, "User not found")
			return
		}
		fail(c, http.StatusForbidden, err.Error())
		return
	}

	file, err := c.FormFile("avatar")
	if err != nil {
		fail(c, http.StatusBadRequest, "Avatar file is required")
		return
	}
	if file.Size > 3*1024*1024 {
		fail(c, http.StatusBadRequest, "Avatar file must be 3 MB or smaller")
		return
	}
	ext := strings.ToLower(filepath.Ext(file.Filename))
	switch ext {
	case ".jpg", ".jpeg", ".png", ".webp":
	default:
		fail(c, http.StatusBadRequest, "Avatar must be a JPG, PNG, or WebP image")
		return
	}

	dir := filepath.Join("uploads", "avatars", scopedSchoolID(c))
	if err := os.MkdirAll(dir, 0o755); err != nil {
		log.Printf("managed user avatar upload storage preparation failed: %v", err)
		fail(c, http.StatusInternalServerError, "Failed to prepare upload storage")
		return
	}
	filename := fmt.Sprintf("%s_%d%s", id, time.Now().UnixNano(), ext)
	relativePath := filepath.ToSlash(filepath.Join(dir, filename))
	if err := c.SaveUploadedFile(file, relativePath); err != nil {
		log.Printf("managed user avatar upload save failed for user %s: %v", id, err)
		fail(c, http.StatusInternalServerError, "Failed to save avatar")
		return
	}

	publicPath := "/" + relativePath
	if err := database.DB.Model(&models.User{}).
		Where("id = ? AND school_id = ?", id, scopedSchoolID(c)).
		Updates(map[string]interface{}{
			"avatar":     publicPath,
			"updated_at": time.Now().UTC(),
		}).Error; err != nil {
		log.Printf("managed user avatar database update failed for user %s: %v", id, err)
		fail(c, http.StatusInternalServerError, "Failed to update avatar")
		return
	}

	auditAction(c, "users", "avatar", "users", &id)
	success(c, http.StatusOK, gin.H{
		"id":         user.ID,
		"avatar":     publicPath,
		"avatar_url": absoluteURL(c, publicPath),
	}, "Avatar uploaded")
}
