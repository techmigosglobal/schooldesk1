package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func setupAuthLoginDB(t *testing.T) *gorm.DB {
	t.Helper()
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.Role{}, &models.User{}, &models.UserSession{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func seedLoginUser(t *testing.T, db *gorm.DB) models.User {
	t.Helper()
	role := models.Role{
		SchoolID: "school-test",
		RoleName: "Teacher",
	}
	if err := db.Create(&role).Error; err != nil {
		t.Fatalf("create role: %v", err)
	}
	hash, err := database.HashPassword("Teacher@12345")
	if err != nil {
		t.Fatalf("hash password: %v", err)
	}
	user := models.User{
		SchoolID:     "school-test",
		Name:         "Teacher One",
		Username:     "teacher01",
		Email:        "teacher01@example.test",
		PasswordHash: hash,
		RoleID:       role.ID,
		IsActive:     true,
		IsVerified:   true,
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}
	return user
}

func TestLoginAcceptsUsernamePrimaryIdentity(t *testing.T) {
	db := setupAuthLoginDB(t)
	seedLoginUser(t, db)

	router := gin.New()
	router.POST("/auth/login", NewAuthHandler().Login)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/auth/login",
		strings.NewReader(`{"username":"teacher01","password":"Teacher@12345"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("login status = %d body=%s", response.Code, response.Body.String())
	}
	var payload map[string]interface{}
	if err := json.Unmarshal(response.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	data := payload["data"].(map[string]interface{})
	user := data["user"].(map[string]interface{})
	if user["username"] != "teacher01" {
		t.Fatalf("username response = %v, want teacher01", user["username"])
	}
}

func TestLoginStillAcceptsEmailFallback(t *testing.T) {
	db := setupAuthLoginDB(t)
	seedLoginUser(t, db)

	router := gin.New()
	router.POST("/auth/login", NewAuthHandler().Login)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/auth/login",
		strings.NewReader(`{"email":"teacher01@example.test","password":"Teacher@12345"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("login status = %d body=%s", response.Code, response.Body.String())
	}
}

func TestChangePasswordVerifiesCurrentPasswordAndUpdatesHash(t *testing.T) {
	db := setupAuthLoginDB(t)
	user := seedLoginUser(t, db)
	handler := NewAuthHandler()
	session := models.UserSession{
		UserID:           user.ID,
		RefreshTokenHash: "refresh-hash",
		IssuedAt:         time.Now().UTC().Add(-time.Hour),
		ExpiresAt:        time.Now().UTC().Add(time.Hour),
	}
	if err := db.Create(&session).Error; err != nil {
		t.Fatalf("create user session: %v", err)
	}

	router := gin.New()
	router.POST("/auth/password", func(c *gin.Context) {
		c.Set("user_id", user.ID)
		c.Set("jti", "current-access-jti")
		handler.ChangePassword(c)
	})

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/auth/password",
		strings.NewReader(`{"current_password":"Teacher@12345","new_password":"Teacher@54321"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("change password status = %d body=%s", response.Code, response.Body.String())
	}

	var updated models.User
	if err := db.First(&updated, "id = ?", user.ID).Error; err != nil {
		t.Fatalf("load updated user: %v", err)
	}
	if database.CheckPassword("Teacher@12345", updated.PasswordHash) {
		t.Fatal("old password still matches updated hash")
	}
	if !database.CheckPassword("Teacher@54321", updated.PasswordHash) {
		t.Fatal("new password does not match updated hash")
	}
	if updated.AuthInvalidatedAt == nil {
		t.Fatal("auth_invalidated_at was not set after password change")
	}
	var updatedSession models.UserSession
	if err := db.First(&updatedSession, "id = ?", session.ID).Error; err != nil {
		t.Fatalf("load updated session: %v", err)
	}
	if !updatedSession.IsRevoked {
		t.Fatal("existing user sessions were not marked revoked")
	}
}

func TestChangePasswordRejectsWrongCurrentPassword(t *testing.T) {
	db := setupAuthLoginDB(t)
	user := seedLoginUser(t, db)
	handler := NewAuthHandler()

	router := gin.New()
	router.POST("/auth/password", func(c *gin.Context) {
		c.Set("user_id", user.ID)
		handler.ChangePassword(c)
	})

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/auth/password",
		strings.NewReader(`{"current_password":"WrongPass@123","new_password":"Teacher@54321"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)

	if response.Code != http.StatusBadRequest {
		t.Fatalf("wrong current password status = %d body=%s", response.Code, response.Body.String())
	}
	var unchanged models.User
	if err := db.First(&unchanged, "id = ?", user.ID).Error; err != nil {
		t.Fatalf("load user: %v", err)
	}
	if !database.CheckPassword("Teacher@12345", unchanged.PasswordHash) {
		t.Fatal("password hash changed after wrong current password")
	}
	if unchanged.AuthInvalidatedAt != nil {
		t.Fatal("auth_invalidated_at changed after wrong current password")
	}
}

func TestRefreshTokenIssuedAfterInvalidation(t *testing.T) {
	invalidatedAt := time.Date(2026, 5, 18, 12, 0, 0, 0, time.UTC)
	if refreshTokenIssuedAfterInvalidation("", &invalidatedAt) {
		t.Fatal("missing issued_at should not survive auth invalidation")
	}
	if refreshTokenIssuedAfterInvalidation(invalidatedAt.Add(-time.Second).Format(time.RFC3339Nano), &invalidatedAt) {
		t.Fatal("old refresh token survived auth invalidation")
	}
	if !refreshTokenIssuedAfterInvalidation(invalidatedAt.Add(time.Second).Format(time.RFC3339Nano), &invalidatedAt) {
		t.Fatal("new refresh token was rejected after auth invalidation")
	}
}
