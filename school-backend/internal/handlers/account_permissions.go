package handlers

import (
	"encoding/json"
	"fmt"
	"strings"

	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func canonicalActorRole(role string) string {
	return strings.ToLower(strings.TrimSpace(role))
}

func canActorManageRole(actorRole, targetRole string) bool {
	switch canonicalActorRole(actorRole) {
	case "principal":
		return targetRole == "Admin" || targetRole == "Teacher" || targetRole == "Parent"
	case "admin":
		return targetRole == "Teacher" || targetRole == "Parent"
	default:
		return false
	}
}

func ensureActorCanManageRole(c *gin.Context, targetRole string) error {
	if canActorManageRole(c.GetString("role_name"), titleRole(targetRole)) {
		return nil
	}
	return fmt.Errorf("%s cannot manage %s accounts", c.GetString("role_name"), titleRole(targetRole))
}

func loadManagedUser(tx *gorm.DB, c *gin.Context, id string) (models.User, string, error) {
	var user models.User
	if err := tx.Preload("Role").
		First(&user, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		return user, "", err
	}
	roleName := ""
	if user.Role != nil {
		roleName = user.Role.RoleName
	} else {
		roleName = titleRole(user.RoleSlug)
	}
	if err := ensureActorCanManageRole(c, roleName); err != nil {
		return user, roleName, err
	}
	return user, roleName, nil
}

func loadLinkedUserByStaffID(tx *gorm.DB, schoolID, staffID string) (*models.User, string, error) {
	var user models.User
	if err := tx.Preload("Role").
		Where("school_id = ? AND linked_type = ? AND linked_id = ?", schoolID, "staff", staffID).
		First(&user).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, "", nil
		}
		return nil, "", err
	}
	roleName := ""
	if user.Role != nil {
		roleName = user.Role.RoleName
	} else {
		roleName = titleRole(user.RoleSlug)
	}
	return &user, roleName, nil
}

func createAccountApprovalRecord(
	tx *gorm.DB,
	c *gin.Context,
	userID string,
	staffID string,
	targetName string,
	targetEmail string,
	targetRole string,
	action string,
) error {
	record := models.FrontendRecord{
		SchoolID:  scopedSchoolID(c),
		Resource:  "account-approvals",
		CreatedBy: c.GetString("user_id"),
	}
	payload := gin.H{
		"type":            "account",
		"action":          action,
		"status":          "pending",
		"user_id":         userID,
		"staff_id":        staffID,
		"target_name":     targetName,
		"target_email":    targetEmail,
		"target_role":     titleRole(targetRole),
		"requester_name":  targetName,
		"requester_role":  fmt.Sprintf("%s Account", titleRole(targetRole)),
		"class_name":      c.GetString("role_name"),
		"submittedDate":   "",
		"summary":         fmt.Sprintf("%s account approval for %s", titleRole(targetRole), targetName),
		"details":         fmt.Sprintf("Requested by %s for %s (%s).", c.GetString("role_name"), targetName, targetEmail),
		"requested_by_id": c.GetString("user_id"),
		"requested_by":    c.GetString("email"),
		"requested_role":  titleRole(targetRole),
		"decisionPath":    "",
	}
	encoded, err := jsonMarshal(payload)
	if err != nil {
		return err
	}
	record.Payload = encoded
	if err := tx.Create(&record).Error; err != nil {
		return err
	}
	if logs, err := createApprovalRequestedNotificationsTx(
		tx,
		c,
		record.ID,
		fmt.Sprintf("%s approval pending", titleRole(targetRole)),
		fmt.Sprintf("%s requested a %s account for %s.", c.GetString("role_name"), titleRole(targetRole), targetName),
	); err == nil {
		enqueuePushNotifications(logs)
	}
	return nil
}

func jsonMarshal(payload gin.H) (string, error) {
	encoded, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}
	return string(encoded), nil
}

func stringMapValue(value interface{}) string {
	switch typed := value.(type) {
	case string:
		return typed
	case *string:
		return stringValue(typed)
	default:
		return ""
	}
}

func setLinkedStaffStatus(tx *gorm.DB, schoolID, staffID, status string) error {
	if strings.TrimSpace(staffID) == "" {
		return nil
	}
	return tx.Model(&models.Staff{}).
		Where("id = ? AND school_id = ?", staffID, schoolID).
		Update("status", status).Error
}

func activateManagedUser(tx *gorm.DB, schoolID, userID string, active bool) error {
	return tx.Model(&models.User{}).
		Where("id = ? AND school_id = ?", userID, schoolID).
		Updates(map[string]interface{}{
			"is_active":   active,
			"is_verified": active,
		}).Error
}

func deactivateManagedUser(tx *gorm.DB, schoolID, userID string) error {
	return activateManagedUser(tx, schoolID, userID, false)
}

func createUserWithRole(
	tx *gorm.DB,
	schoolID string,
	role models.Role,
	name string,
	username string,
	email string,
	phone string,
	passwordHash string,
	linkedType string,
	linkedID *string,
	isActive bool,
) (models.User, error) {
	user := models.User{
		SchoolID:     schoolID,
		Name:         name,
		Username:     accountUsername(username, email),
		Email:        email,
		Phone:        phone,
		PasswordHash: passwordHash,
		RoleID:       role.ID,
		RoleSlug:     strings.ToLower(role.RoleName),
		LinkedType:   linkedType,
		LinkedID:     linkedID,
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
