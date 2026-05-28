package handlers

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type NotificationDeviceHandler struct{}

func NewNotificationDeviceHandler() *NotificationDeviceHandler {
	return &NotificationDeviceHandler{}
}

const (
	maxNotificationTokenLength      = 4096
	maxNotificationDeviceIDLength   = 128
	maxNotificationAppVersionLength = 64
)

type notificationDeviceTokenRequest struct {
	Token      string `json:"token" binding:"required"`
	Platform   string `json:"platform" binding:"required"`
	DeviceID   string `json:"device_id"`
	AppVersion string `json:"app_version"`
}

func (h *NotificationDeviceHandler) UpsertDeviceToken(c *gin.Context) {
	var req notificationDeviceTokenRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	token := strings.TrimSpace(req.Token)
	platform := canonicalNotificationPlatform(req.Platform)
	if token == "" || platform == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token and platform are required"})
		return
	}
	if len(token) > maxNotificationTokenLength {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token is too long"})
		return
	}
	deviceID := strings.TrimSpace(req.DeviceID)
	if len(deviceID) > maxNotificationDeviceIDLength {
		c.JSON(http.StatusBadRequest, gin.H{"error": "device_id is too long"})
		return
	}
	appVersion := strings.TrimSpace(req.AppVersion)
	if len(appVersion) > maxNotificationAppVersionLength {
		c.JSON(http.StatusBadRequest, gin.H{"error": "app_version is too long"})
		return
	}

	tokenHash := notificationTokenHash(token)
	now := time.Now().UTC()
	userID := c.GetString("user_id")
	schoolID := scopedSchoolID(c)
	var existing models.NotificationDeviceToken
	err := database.DB.First(&existing, "token_hash = ?", tokenHash).Error
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to look up device token"})
		return
	}

	record := models.NotificationDeviceToken{
		SchoolID:   schoolID,
		UserID:     userID,
		Platform:   platform,
		Token:      token,
		TokenHash:  tokenHash,
		DeviceID:   deviceID,
		AppVersion: appVersion,
		LastSeenAt: now,
		RevokedAt:  nil,
	}
	if errors.Is(err, gorm.ErrRecordNotFound) {
		if err := database.DB.Create(&record).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to register device token"})
			return
		}
	} else {
		record.ID = existing.ID
		if err := database.DB.Model(&existing).Updates(map[string]interface{}{
			"school_id":    schoolID,
			"user_id":      userID,
			"platform":     platform,
			"token":        token,
			"device_id":    deviceID,
			"app_version":  appVersion,
			"last_seen_at": now,
			"revoked_at":   nil,
		}).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update device token"})
			return
		}
	}

	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Device token registered",
		Data: gin.H{
			"token_hash": tokenHash,
			"platform":   platform,
		},
	})
}

func (h *NotificationDeviceHandler) RevokeDeviceToken(c *gin.Context) {
	var req struct {
		Token string `json:"token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	token := strings.TrimSpace(req.Token)
	if token == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token is required"})
		return
	}
	if len(token) > maxNotificationTokenLength {
		c.JSON(http.StatusBadRequest, gin.H{"error": "token is too long"})
		return
	}
	tokenHash := notificationTokenHash(token)
	now := time.Now().UTC()
	result := database.DB.Model(&models.NotificationDeviceToken{}).
		Where("token_hash = ? AND user_id = ? AND school_id = ?", tokenHash, c.GetString("user_id"), scopedSchoolID(c)).
		Updates(map[string]interface{}{"revoked_at": &now})
	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to revoke device token"})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Device token revoked",
		Data:    gin.H{"token_hash": tokenHash},
	})
}

func canonicalNotificationPlatform(platform string) string {
	switch strings.ToLower(strings.TrimSpace(platform)) {
	case "android", "ios", "web", "macos", "windows", "linux":
		return strings.ToLower(strings.TrimSpace(platform))
	default:
		return ""
	}
}

func notificationTokenHash(token string) string {
	token = strings.TrimSpace(token)
	if token == "" {
		return ""
	}
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}
