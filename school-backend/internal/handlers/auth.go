package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/middleware"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type AuthHandler struct{}

func NewAuthHandler() *AuthHandler {
	return &AuthHandler{}
}

func stringValue(value *string) string {
	if value == nil {
		return ""
	}
	return *value
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req models.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	identityValues := loginIdentityValues(req.Username, req.Email)
	if len(identityValues) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "username or email is required"})
		return
	}

	var user models.User
	if err := database.DB.
		Preload("Role").
		Where("LOWER(username) IN ? OR LOWER(email) IN ?", identityValues, identityValues).
		First(&user).Error; err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	if !database.CheckPassword(req.Password, user.PasswordHash) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid credentials"})
		return
	}

	if !user.IsActive {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Account is deactivated"})
		return
	}

	jti := uuid.NewString()
	tokenTTL := 24 * time.Hour
	token, err := middleware.GenerateToken(
		user.ID,
		user.Email,
		user.RoleID,
		user.Role.RoleName,
		user.SchoolID,
		user.LinkedType,
		stringValue(user.LinkedID),
		jti,
		tokenTTL,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	refreshToken := uuid.NewString()
	refreshIssuedAt := time.Now().UTC()
	refreshPayload, _ := json.Marshal(map[string]string{
		"user_id":     user.ID,
		"email":       user.Email,
		"role_id":     user.RoleID,
		"role_name":   user.Role.RoleName,
		"school_id":   user.SchoolID,
		"linked_type": user.LinkedType,
		"linked_id":   stringValue(user.LinkedID),
		"issued_at":   refreshIssuedAt.Format(time.RFC3339Nano),
	})
	if services.Sessions != nil {
		if err := services.Sessions.StoreRefreshToken(context.Background(), refreshToken, string(refreshPayload), 7*24*time.Hour); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to persist session"})
			return
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: models.LoginResponse{
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
				RoleName:   user.Role.RoleName,
				LinkedType: user.LinkedType,
				LinkedID:   stringValue(user.LinkedID),
				IsActive:   user.IsActive,
				IsVerified: user.IsVerified,
			},
		},
	})
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req models.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	hashedPassword, err := database.HashPassword(req.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	if strings.TrimSpace(req.RoleID) != "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "role_id cannot be provided for public registration"})
		return
	}

	var parentRole models.Role
	if err := database.DB.Where("LOWER(role_name) = ?", "parent").First(&parentRole).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Default role not available"})
		return
	}

	user := models.User{
		Username:     accountUsername(req.Username, req.Email),
		Email:        req.Email,
		Phone:        req.Phone,
		PasswordHash: hashedPassword,
		SchoolID:     req.SchoolID,
		RoleID:       parentRole.ID,
		IsActive:     true,
		IsVerified:   false,
	}

	if err := database.DB.Create(&user).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	c.JSON(http.StatusCreated, models.APIResponse{
		Success: true,
		Message: "User registered successfully",
		Data:    user.ID,
	})
}

func (h *AuthHandler) Refresh(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if services.Sessions == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Session store not available"})
		return
	}

	rawPayload, err := services.Sessions.GetRefreshToken(context.Background(), req.RefreshToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid refresh token"})
		return
	}

	var payload map[string]string
	if err := json.Unmarshal([]byte(rawPayload), &payload); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid refresh token payload"})
		return
	}

	var user models.User
	if err := database.DB.First(&user, "id = ?", payload["user_id"]).Error; err != nil || !user.IsActive {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid refresh token"})
		return
	}
	if !refreshTokenIssuedAfterInvalidation(payload["issued_at"], user.AuthInvalidatedAt) {
		_ = services.Sessions.RevokeRefreshToken(context.Background(), req.RefreshToken)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Refresh token has been revoked"})
		return
	}

	_ = services.Sessions.RevokeRefreshToken(context.Background(), req.RefreshToken)
	newRefresh := uuid.NewString()
	payload["issued_at"] = time.Now().UTC().Format(time.RFC3339Nano)
	rotatedPayload, _ := json.Marshal(payload)
	if err := services.Sessions.StoreRefreshToken(context.Background(), newRefresh, string(rotatedPayload), 7*24*time.Hour); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to rotate refresh token"})
		return
	}

	jti := uuid.NewString()
	accessTTL := 24 * time.Hour
	token, err := middleware.GenerateToken(
		payload["user_id"],
		payload["email"],
		payload["role_id"],
		payload["role_name"],
		payload["school_id"],
		payload["linked_type"],
		payload["linked_id"],
		jti,
		accessTTL,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to refresh access token"})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"token":         token,
			"refresh_token": newRefresh,
			"expires_at":    int64(accessTTL.Seconds()),
		},
	})
}

func (h *AuthHandler) Logout(c *gin.Context) {
	var req struct {
		RefreshToken string `json:"refresh_token"`
	}
	_ = c.ShouldBindJSON(&req)

	if services.Sessions != nil {
		jti := c.GetString("jti")
		if jti != "" {
			_ = services.Sessions.RevokeJTI(context.Background(), jti, 24*time.Hour)
		}
		if strings.TrimSpace(req.RefreshToken) != "" {
			_ = services.Sessions.RevokeRefreshToken(context.Background(), req.RefreshToken)
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Logged out successfully",
	})
}

func (h *AuthHandler) ChangePassword(c *gin.Context) {
	var req struct {
		CurrentPassword string `json:"current_password" binding:"required"`
		NewPassword     string `json:"new_password" binding:"required,min=8"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if strings.TrimSpace(req.CurrentPassword) == "" || strings.TrimSpace(req.NewPassword) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "current_password and new_password are required"})
		return
	}
	if req.CurrentPassword == req.NewPassword {
		c.JSON(http.StatusBadRequest, gin.H{"error": "new_password must be different from current_password"})
		return
	}

	var user models.User
	if err := database.DB.First(&user, "id = ?", c.GetString("user_id")).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	if !database.CheckPassword(req.CurrentPassword, user.PasswordHash) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Current password is incorrect"})
		return
	}

	hashedPassword, err := database.HashPassword(req.NewPassword)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}
	invalidatedAt := time.Now().UTC()
	if err := database.DB.Model(&user).Updates(map[string]interface{}{
		"password_hash":       hashedPassword,
		"auth_invalidated_at": invalidatedAt,
	}).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update password"})
		return
	}
	_ = database.DB.Model(&models.UserSession{}).
		Where("user_id = ?", user.ID).
		Update("is_revoked", true).Error
	if services.Sessions != nil {
		if jti := strings.TrimSpace(c.GetString("jti")); jti != "" {
			_ = services.Sessions.RevokeJTI(context.Background(), jti, 24*time.Hour)
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Password updated successfully",
	})
}

func refreshTokenIssuedAfterInvalidation(rawIssuedAt string, invalidatedAt *time.Time) bool {
	if invalidatedAt == nil {
		return true
	}
	issuedAt, err := time.Parse(time.RFC3339Nano, strings.TrimSpace(rawIssuedAt))
	if err != nil {
		return false
	}
	return !issuedAt.Before(*invalidatedAt)
}

func (h *AuthHandler) GetProfile(c *gin.Context) {
	userID := c.GetString("user_id")

	var user models.User
	if err := database.DB.Preload("Role").Preload("Role.Permissions").Preload("School").First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"id":          user.ID,
			"username":    accountUsername(user.Username, user.Email),
			"name":        user.Name,
			"email":       user.Email,
			"phone":       user.Phone,
			"avatar":      user.Avatar,
			"school_id":   user.SchoolID,
			"role_id":     user.RoleID,
			"role":        canonicalRole(user.Role.RoleName),
			"role_name":   user.Role.RoleName,
			"linked_type": user.LinkedType,
			"linked_id":   stringValue(user.LinkedID),
			"is_active":   user.IsActive,
			"is_verified": user.IsVerified,
			"school":      user.School,
		},
	})
}

func (h *AuthHandler) UpdateProfile(c *gin.Context) {
	userID := c.GetString("user_id")
	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if _, ok := payload["avatar"]; ok {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Use /auth/profile/avatar to update profile pictures"})
		return
	}
	updates := map[string]interface{}{"updated_at": time.Now().UTC()}
	for _, key := range []string{"name", "username", "phone"} {
		if value, ok := payload[key]; ok {
			updates[key] = value
		}
	}
	if email, ok := payload["email"].(string); ok && strings.TrimSpace(email) != "" {
		updates["email"] = strings.TrimSpace(email)
	}
	if err := database.DB.Model(&models.User{}).Where("id = ?", userID).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
		return
	}
	h.GetProfile(c)
}

func (h *AuthHandler) UploadProfileAvatar(c *gin.Context) {
	userID := c.GetString("user_id")
	file, err := c.FormFile("avatar")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Avatar file is required"})
		return
	}
	if file.Size > 3*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Avatar file must be 3 MB or smaller"})
		return
	}
	ext := strings.ToLower(filepath.Ext(file.Filename))
	switch ext {
	case ".jpg", ".jpeg", ".png", ".webp":
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Avatar must be a JPG, PNG, or WebP image"})
		return
	}
	if err := os.MkdirAll("uploads/avatars", 0o755); err != nil {
		log.Printf("profile avatar upload storage preparation failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to prepare upload storage"})
		return
	}
	filename := fmt.Sprintf("%s_%d%s", userID, time.Now().UnixNano(), ext)
	relativePath := filepath.ToSlash(filepath.Join("uploads", "avatars", filename))
	if err := c.SaveUploadedFile(file, relativePath); err != nil {
		log.Printf("profile avatar upload save failed for user %s: %v", userID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save avatar"})
		return
	}
	publicPath := "/" + relativePath
	if err := database.DB.Model(&models.User{}).Where("id = ?", userID).Updates(map[string]interface{}{
		"avatar":     publicPath,
		"updated_at": time.Now().UTC(),
	}).Error; err != nil {
		log.Printf("profile avatar database update failed for user %s: %v", userID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update avatar"})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"avatar":     publicPath,
			"avatar_url": absoluteURL(c, publicPath),
		},
	})
}

func absoluteURL(c *gin.Context, path string) string {
	scheme := c.GetHeader("X-Forwarded-Proto")
	if scheme == "" {
		if c.Request.TLS != nil {
			scheme = "https"
		} else {
			scheme = "http"
		}
	}
	host := c.GetHeader("X-Forwarded-Host")
	if host == "" {
		host = c.Request.Host
	}
	return scheme + "://" + host + path
}
