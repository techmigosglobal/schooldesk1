package handlers

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func TestHomeworkReminderTodayStatusPersistsTeacherSkip(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.FrontendRecord{}); err != nil {
		t.Fatalf("migrate frontend records: %v", err)
	}
	if err := db.Exec(`
		CREATE TABLE homework (
			homework_id text PRIMARY KEY,
			school_id text,
			staff_id text,
			section_id text,
			created_at datetime,
			status text
		)
	`).Error; err != nil {
		t.Fatalf("create homework table: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", "teacher-user")
		c.Set("role_name", "Teacher")
		c.Set("linked_type", "staff")
		c.Set("linked_id", "staff-test")
		c.Next()
	})
	handler := NewHomeworkReminderHandler()
	router.GET("/homework/reminders/today", handler.TodayStatus)
	router.POST("/homework/reminders/today/skip", handler.SkipToday)

	status := httptest.NewRecorder()
	router.ServeHTTP(status, httptest.NewRequest(http.MethodGet, "/homework/reminders/today?section_id=section-a", nil))
	if status.Code != http.StatusOK {
		t.Fatalf("status code=%d body=%s", status.Code, status.Body.String())
	}
	if !strings.Contains(status.Body.String(), `"status":"pending"`) {
		t.Fatalf("initial status body=%s, want pending", status.Body.String())
	}

	skip := httptest.NewRecorder()
	router.ServeHTTP(
		skip,
		httptest.NewRequest(
			http.MethodPost,
			"/homework/reminders/today/skip",
			strings.NewReader(`{"section_id":"section-a","reason":"No homework today"}`),
		),
	)
	if skip.Code != http.StatusOK {
		t.Fatalf("skip code=%d body=%s", skip.Code, skip.Body.String())
	}
	if !strings.Contains(skip.Body.String(), `"status":"skipped"`) {
		t.Fatalf("skip body=%s, want skipped", skip.Body.String())
	}

	after := httptest.NewRecorder()
	router.ServeHTTP(after, httptest.NewRequest(http.MethodGet, "/homework/reminders/today?section_id=section-a", nil))
	if after.Code != http.StatusOK {
		t.Fatalf("after code=%d body=%s", after.Code, after.Body.String())
	}
	if !strings.Contains(after.Body.String(), `"status":"skipped"`) {
		t.Fatalf("after body=%s, want skipped", after.Body.String())
	}
}
