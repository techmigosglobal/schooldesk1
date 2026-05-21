package worker

import (
	"context"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"
)

type capturePushSender struct {
	token   string
	message services.PushMessage
}

func (s *capturePushSender) SendToToken(ctx context.Context, token string, message services.PushMessage) (string, error) {
	s.token = token
	s.message = message
	return "message-id", nil
}

func TestDeliverNotificationPushSendsRoutePayload(t *testing.T) {
	if err := database.SetupTestDB(); err != nil {
		t.Fatalf("setup db: %v", err)
	}
	previousPush := services.Push
	sender := &capturePushSender{}
	services.Push = sender
	t.Cleanup(func() { services.Push = previousPush })

	schoolID := "school-push"
	roleID := "role-parent-push"
	userID := "user-parent-push"
	referenceID := "notice-push"
	now := time.Now().UTC()
	seeds := []any{
		&models.School{BaseModel: models.BaseModel{ID: schoolID}, Name: "Push School", SchoolType: "K-12"},
		&models.Role{BaseModel: models.BaseModel{ID: roleID}, SchoolID: schoolID, RoleName: "Parent", IsSystemRole: true},
		&models.User{BaseModel: models.BaseModel{ID: userID}, SchoolID: schoolID, Name: "Parent", RoleID: roleID, RoleSlug: "parent", PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.NotificationDeviceToken{SchoolID: schoolID, UserID: userID, Platform: "android", Token: "fcm-token", TokenHash: "hash-token", LastSeenAt: now},
		&models.NotificationLog{
			BaseModel:       models.BaseModel{ID: "notification-push"},
			SchoolID:        schoolID,
			RecipientUserID: userID,
			Channel:         "in_app",
			Title:           "Notice posted",
			Body:            "A new circular is available.",
			Category:        "general",
			Priority:        "high",
			Route:           "/parent-notices-screen",
			ReferenceType:   "announcement",
			ReferenceID:     &referenceID,
			IsRead:          false,
			SentAt:          now,
			DeliveryStatus:  "delivered",
			PushStatus:      "pending",
		},
	}
	for _, seed := range seeds {
		if err := database.DB.Create(seed).Error; err != nil {
			t.Fatalf("seed %T: %v", seed, err)
		}
	}

	if err := deliverNotificationPush(context.Background(), "notification-push"); err != nil {
		t.Fatalf("deliverNotificationPush: %v", err)
	}
	if sender.token != "fcm-token" {
		t.Fatalf("push token=%q, want fcm-token", sender.token)
	}
	if sender.message.Data["route"] != "/parent-notices-screen" {
		t.Fatalf("route payload=%q, want /parent-notices-screen", sender.message.Data["route"])
	}
	if sender.message.Data["role"] != "parent" {
		t.Fatalf("role payload=%q, want parent", sender.message.Data["role"])
	}
	if sender.message.Data["reference_id"] != referenceID {
		t.Fatalf("reference_id payload=%q, want %q", sender.message.Data["reference_id"], referenceID)
	}

	var log models.NotificationLog
	if err := database.DB.First(&log, "id = ?", "notification-push").Error; err != nil {
		t.Fatalf("reload notification log: %v", err)
	}
	if log.PushStatus != "sent" || log.PushedAt == nil {
		t.Fatalf("push status=%q pushed_at=%v, want sent with timestamp", log.PushStatus, log.PushedAt)
	}
}
