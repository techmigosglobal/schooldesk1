package worker

import (
	"context"
	"log"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"
)

func RunNotificationWorker() error {
	if services.Queue == nil {
		return nil
	}
	log.Println("Notification worker started")
	return services.Queue.Consume("notifications", func(payload map[string]interface{}) error {
		if id, ok := payload["notification_id"].(string); ok && strings.TrimSpace(id) != "" {
			if err := deliverNotificationPush(context.Background(), strings.TrimSpace(id)); err != nil {
				services.RecordNotificationWorkerFailure()
				return err
			}
			return nil
		}
		log.Printf("processed notification job without push target: %v", payload)
		return nil
	})
}

func deliverNotificationPush(ctx context.Context, notificationID string) error {
	var notification models.NotificationLog
	if err := database.DB.First(&notification, "id = ?", notificationID).Error; err != nil {
		return err
	}
	if strings.EqualFold(strings.TrimSpace(notification.PushStatus), "sent") {
		return nil
	}
	if services.Push == nil {
		return database.DB.Model(&notification).Updates(map[string]interface{}{
			"push_status": "skipped",
			"push_error":  "FCM push sender not configured",
		}).Error
	}

	var tokens []models.NotificationDeviceToken
	if err := database.DB.
		Where("school_id = ? AND user_id = ? AND revoked_at IS NULL", notification.SchoolID, notification.RecipientUserID).
		Find(&tokens).Error; err != nil {
		return err
	}
	if len(tokens) == 0 {
		return database.DB.Model(&notification).Updates(map[string]interface{}{
			"push_status": "skipped",
			"push_error":  "No active device tokens",
		}).Error
	}

	data := map[string]string{
		"notification_id": notification.ID,
		"school_id":       notification.SchoolID,
		"reference_type":  notification.ReferenceType,
		"route":           notification.Route,
		"role":            notificationRecipientRole(notification.RecipientUserID),
		"category":        notification.Category,
		"priority":        notification.Priority,
	}
	if notification.ReferenceID != nil {
		data["reference_id"] = *notification.ReferenceID
	}

	successes := 0
	var lastErr error
	for _, token := range tokens {
		if strings.TrimSpace(token.Token) == "" {
			continue
		}
		if _, err := services.Push.SendToToken(ctx, token.Token, services.PushMessage{
			Title: notification.Title,
			Body:  notification.Body,
			Data:  data,
		}); err != nil {
			lastErr = err
			continue
		}
		successes++
	}
	now := time.Now().UTC()
	if successes == 0 {
		errMsg := "No push messages sent"
		if lastErr != nil {
			errMsg = lastErr.Error()
		}
		return database.DB.Model(&notification).Updates(map[string]interface{}{
			"push_status": "failed",
			"push_error":  errMsg,
			"pushed_at":   &now,
		}).Error
	}
	return database.DB.Model(&notification).Updates(map[string]interface{}{
		"push_status": "sent",
		"push_error":  "",
		"pushed_at":   &now,
	}).Error
}

func notificationRecipientRole(userID string) string {
	var user models.User
	if err := database.DB.Preload("Role").First(&user, "id = ?", userID).Error; err != nil {
		return ""
	}
	if user.Role != nil && strings.TrimSpace(user.Role.RoleName) != "" {
		return strings.ToLower(strings.TrimSpace(user.Role.RoleName))
	}
	return strings.ToLower(strings.TrimSpace(user.RoleSlug))
}
