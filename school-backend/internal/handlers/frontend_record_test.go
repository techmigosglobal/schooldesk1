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

func TestFrontendRecordHandlerPersistsResourceRecords(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.FrontendRecord{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", "user-test")
		c.Next()
	})
	handler := NewFrontendRecordHandler("documents/requests")
	router.GET("/documents/requests", handler.List)
	router.POST("/documents/requests", handler.Create)
	router.PUT("/documents/requests/:id", handler.Update)

	create := httptest.NewRecorder()
	router.ServeHTTP(
		create,
		httptest.NewRequest(
			http.MethodPost,
			"/documents/requests",
			strings.NewReader(`{"title":"Transfer certificate","status":"pending"}`),
		),
	)
	if create.Code != http.StatusCreated {
		t.Fatalf("create status = %d body=%s", create.Code, create.Body.String())
	}
	if !strings.Contains(create.Body.String(), `"title":"Transfer certificate"`) {
		t.Fatalf("create body missing payload: %s", create.Body.String())
	}

	list := httptest.NewRecorder()
	router.ServeHTTP(list, httptest.NewRequest(http.MethodGet, "/documents/requests", nil))
	if list.Code != http.StatusOK {
		t.Fatalf("list status = %d body=%s", list.Code, list.Body.String())
	}
	if !strings.Contains(list.Body.String(), `"title":"Transfer certificate"`) {
		t.Fatalf("list body missing record: %s", list.Body.String())
	}
}

func TestFrontendRecordHandlerScopesParentOwnedRecords(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.FrontendRecord{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	records := []models.FrontendRecord{
		{
			BaseModel: models.BaseModel{ID: "own-ack"},
			SchoolID:  "school-test",
			Resource:  "notice-acknowledgements",
			Payload:   `{"notice_id":"notice-own"}`,
			CreatedBy: "parent-a",
		},
		{
			BaseModel: models.BaseModel{ID: "other-ack"},
			SchoolID:  "school-test",
			Resource:  "notice-acknowledgements",
			Payload:   `{"notice_id":"notice-other"}`,
			CreatedBy: "parent-b",
		},
	}
	if err := db.Create(&records).Error; err != nil {
		t.Fatalf("seed records: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", "parent-a")
		c.Set("role_name", "Parent")
		c.Next()
	})
	handler := NewFrontendRecordHandler("notice-acknowledgements")
	router.GET("/notice-acknowledgements", handler.List)
	router.PUT("/notice-acknowledgements/:id", handler.Update)

	list := httptest.NewRecorder()
	router.ServeHTTP(list, httptest.NewRequest(http.MethodGet, "/notice-acknowledgements", nil))
	if list.Code != http.StatusOK {
		t.Fatalf("list status = %d body=%s", list.Code, list.Body.String())
	}
	if !strings.Contains(list.Body.String(), `"notice_id":"notice-own"`) {
		t.Fatalf("list body missing own record: %s", list.Body.String())
	}
	if strings.Contains(list.Body.String(), "notice-other") {
		t.Fatalf("list body leaked another parent's record: %s", list.Body.String())
	}

	updateOther := httptest.NewRecorder()
	router.ServeHTTP(
		updateOther,
		httptest.NewRequest(
			http.MethodPut,
			"/notice-acknowledgements/other-ack",
			strings.NewReader(`{"acknowledged_at":"2026-05-23T00:00:00Z"}`),
		),
	)
	if updateOther.Code != http.StatusForbidden {
		t.Fatalf("update other status = %d body=%s", updateOther.Code, updateOther.Body.String())
	}
}

func TestFrontendRecordHandlerScopesDisciplineIncidentsToCreatorForTeacherAndParent(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.FrontendRecord{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	records := []models.FrontendRecord{
		{
			BaseModel: models.BaseModel{ID: "teacher-own-incident"},
			SchoolID:  "school-test",
			Resource:  "discipline-incidents",
			Payload:   `{"student_id":"student-a","title":"Own incident"}`,
			CreatedBy: "teacher-a",
		},
		{
			BaseModel: models.BaseModel{ID: "teacher-other-incident"},
			SchoolID:  "school-test",
			Resource:  "discipline-incidents",
			Payload:   `{"student_id":"student-b","title":"Other incident"}`,
			CreatedBy: "teacher-b",
		},
	}
	if err := db.Create(&records).Error; err != nil {
		t.Fatalf("seed records: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", "teacher-a")
		c.Set("role_name", "Teacher")
		c.Next()
	})
	handler := NewFrontendRecordHandler("discipline-incidents")
	router.GET("/discipline-incidents", handler.List)
	router.PUT("/discipline-incidents/:id", handler.Update)

	list := httptest.NewRecorder()
	router.ServeHTTP(list, httptest.NewRequest(http.MethodGet, "/discipline-incidents", nil))
	if list.Code != http.StatusOK {
		t.Fatalf("list status = %d body=%s", list.Code, list.Body.String())
	}
	if !strings.Contains(list.Body.String(), "Own incident") {
		t.Fatalf("list body missing own incident: %s", list.Body.String())
	}
	if strings.Contains(list.Body.String(), "Other incident") {
		t.Fatalf("list body leaked another teacher's incident: %s", list.Body.String())
	}

	updateOther := httptest.NewRecorder()
	router.ServeHTTP(
		updateOther,
		httptest.NewRequest(
			http.MethodPut,
			"/discipline-incidents/teacher-other-incident",
			strings.NewReader(`{"status":"reviewed"}`),
		),
	)
	if updateOther.Code != http.StatusForbidden {
		t.Fatalf("update other status = %d body=%s", updateOther.Code, updateOther.Body.String())
	}
}
