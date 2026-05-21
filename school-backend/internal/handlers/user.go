package handlers

import (
	"net/http"
	"strings"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
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
