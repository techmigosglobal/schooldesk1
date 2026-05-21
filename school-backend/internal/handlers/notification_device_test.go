package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"school-backend/internal/database"
	"school-backend/internal/models"
)

func TestNotificationDeviceTokenUpsertStoresScopedTokenHash(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	handler := NewNotificationDeviceHandler()
	router.POST("/notifications/device-tokens", handler.UpsertDeviceToken)

	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, httptest.NewRequest(
		http.MethodPost,
		"/notifications/device-tokens",
		strings.NewReader(`{"token":"fcm-token-1","platform":"android","device_id":"device-1","app_version":"1.0.4+6"}`),
	))
	if resp.Code != http.StatusOK {
		t.Fatalf("UpsertDeviceToken status=%d body=%s, want 200", resp.Code, resp.Body.String())
	}
	var response struct {
		Data map[string]string `json:"data"`
	}
	if err := json.Unmarshal(resp.Body.Bytes(), &response); err != nil {
		t.Fatalf("decode UpsertDeviceToken response: %v", err)
	}
	if response.Data["token_hash"] == "" {
		t.Fatalf("UpsertDeviceToken token_hash is empty, want populated hash")
	}

	var token models.NotificationDeviceToken
	if err := database.DB.First(&token, "token_hash = ?", response.Data["token_hash"]).Error; err != nil {
		t.Fatalf("load notification device token: %v", err)
	}
	if token.UserID != f.parentUserID {
		t.Fatalf("device token user_id=%q, want %q", token.UserID, f.parentUserID)
	}
	if token.SchoolID != f.schoolID {
		t.Fatalf("device token school_id=%q, want %q", token.SchoolID, f.schoolID)
	}
	if token.Platform != "android" {
		t.Fatalf("device token platform=%q, want android", token.Platform)
	}
	if token.Token == "" {
		t.Fatalf("device token raw token is empty, want stored server-side token for FCM delivery")
	}
}

func TestNotificationDeviceTokenRevokeMarksOnlyCurrentUserToken(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	handler := NewNotificationDeviceHandler()
	router.POST("/notifications/device-tokens", handler.UpsertDeviceToken)
	router.DELETE("/notifications/device-tokens", handler.RevokeDeviceToken)

	register := httptest.NewRecorder()
	router.ServeHTTP(register, httptest.NewRequest(
		http.MethodPost,
		"/notifications/device-tokens",
		strings.NewReader(`{"token":"fcm-token-2","platform":"web"}`),
	))
	if register.Code != http.StatusOK {
		t.Fatalf("register token status=%d body=%s, want 200", register.Code, register.Body.String())
	}

	revoke := httptest.NewRecorder()
	router.ServeHTTP(revoke, httptest.NewRequest(
		http.MethodDelete,
		"/notifications/device-tokens",
		strings.NewReader(`{"token":"fcm-token-2"}`),
	))
	if revoke.Code != http.StatusOK {
		t.Fatalf("RevokeDeviceToken status=%d body=%s, want 200", revoke.Code, revoke.Body.String())
	}

	var token models.NotificationDeviceToken
	if err := database.DB.First(&token, "token_hash = ?", notificationTokenHash("fcm-token-2")).Error; err != nil {
		t.Fatalf("load revoked device token: %v", err)
	}
	if token.RevokedAt == nil {
		t.Fatalf("device token revoked_at=nil, want timestamp")
	}
}

func TestNotificationDeviceTokenRejectsInvalidPlatformAndOversizedPayload(t *testing.T) {
	f := setupRelationshipPolicyFixture(t)
	router := scopedPolicyRouter("Parent", f.parentUserID, "", "", "parent@policy.test", f.schoolID)
	handler := NewNotificationDeviceHandler()
	router.POST("/notifications/device-tokens", handler.UpsertDeviceToken)
	router.DELETE("/notifications/device-tokens", handler.RevokeDeviceToken)

	invalidPlatform := httptest.NewRecorder()
	router.ServeHTTP(invalidPlatform, httptest.NewRequest(
		http.MethodPost,
		"/notifications/device-tokens",
		strings.NewReader(`{"token":"fcm-token-invalid","platform":"pager"}`),
	))
	if invalidPlatform.Code != http.StatusBadRequest {
		t.Fatalf("invalid platform status=%d body=%s, want 400", invalidPlatform.Code, invalidPlatform.Body.String())
	}

	oversizedToken := strings.Repeat("x", maxNotificationTokenLength+1)
	oversizedRegister := httptest.NewRecorder()
	router.ServeHTTP(oversizedRegister, httptest.NewRequest(
		http.MethodPost,
		"/notifications/device-tokens",
		strings.NewReader(`{"token":"`+oversizedToken+`","platform":"android"}`),
	))
	if oversizedRegister.Code != http.StatusBadRequest {
		t.Fatalf("oversized register status=%d body=%s, want 400", oversizedRegister.Code, oversizedRegister.Body.String())
	}

	oversizedRevoke := httptest.NewRecorder()
	router.ServeHTTP(oversizedRevoke, httptest.NewRequest(
		http.MethodDelete,
		"/notifications/device-tokens",
		strings.NewReader(`{"token":"`+oversizedToken+`"}`),
	))
	if oversizedRevoke.Code != http.StatusBadRequest {
		t.Fatalf("oversized revoke status=%d body=%s, want 400", oversizedRevoke.Code, oversizedRevoke.Body.String())
	}
}
