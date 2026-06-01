package handlers

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"school-backend/internal/database"
	"school-backend/internal/middleware"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func setupSchoolSetupDB(t *testing.T) *gorm.DB {
	t.Helper()
	gin.SetMode(gin.TestMode)
	middleware.SetJWTSecret("12345678901234567890123456789012")
	services.Sessions = nil
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.School{}, &models.Role{}, &models.Permission{}, &models.User{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func TestSchoolSetupCreatesSchoolRolesPermissionsAndPrincipalSession(t *testing.T) {
	db := setupSchoolSetupDB(t)
	router := gin.New()
	router.POST("/schools/setup", NewSchoolSetupHandler().Setup)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/schools/setup",
		strings.NewReader(`{"school_name":"Green Valley School","school_type":"CBSE","affiliation_board":"CBSE","admin_name":"School Principal","admin_username":"principal","admin_email":"principal@example.test","admin_phone":"9999999999","admin_password":"Principal@12345"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)

	if response.Code != http.StatusCreated {
		t.Fatalf("setup status=%d body=%s", response.Code, response.Body.String())
	}
	var body map[string]interface{}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode body: %v", err)
	}
	data := body["data"].(map[string]interface{})
	auth := data["auth"].(map[string]interface{})
	user := auth["user"].(map[string]interface{})
	if auth["token"] == "" || auth["refresh_token"] == "" {
		t.Fatalf("setup response missing auth tokens: %s", response.Body.String())
	}
	if user["role_name"] != "Principal" {
		t.Fatalf("role_name=%v, want Principal", user["role_name"])
	}

	var school models.School
	if err := db.First(&school, "name = ?", "Green Valley School").Error; err != nil {
		t.Fatalf("load school: %v", err)
	}
	var roleCount int64
	if err := db.Model(&models.Role{}).Where("school_id = ?", school.ID).Count(&roleCount).Error; err != nil {
		t.Fatalf("count roles: %v", err)
	}
	if roleCount != 4 {
		t.Fatalf("role count=%d, want 4", roleCount)
	}
	var principal models.User
	if err := db.Preload("Role").First(&principal, "email = ?", "principal@example.test").Error; err != nil {
		t.Fatalf("load principal: %v", err)
	}
	if principal.Role == nil || principal.Role.RoleName != "Principal" {
		t.Fatalf("principal role=%v, want Principal", principal.Role)
	}
	if !principal.IsActive || !principal.IsVerified {
		t.Fatalf("principal should be active and verified")
	}
	var dashboardPermission models.Permission
	if err := db.Joins("JOIN roles ON roles.id = permissions.role_id").
		First(&dashboardPermission, "roles.school_id = ? AND roles.role_name = ? AND permissions.module = ?", school.ID, "Principal", "dashboard").Error; err != nil {
		t.Fatalf("principal dashboard permission missing: %v", err)
	}
	if !dashboardPermission.CanRead {
		t.Fatalf("principal dashboard permission should allow read")
	}
}

func TestSchoolSetupRejectsDuplicateSchoolName(t *testing.T) {
	db := setupSchoolSetupDB(t)
	if err := db.Create(&models.School{Name: "Green Valley School", SchoolType: "CBSE"}).Error; err != nil {
		t.Fatalf("seed school: %v", err)
	}
	router := gin.New()
	router.POST("/schools/setup", NewSchoolSetupHandler().Setup)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/schools/setup",
		strings.NewReader(`{"school_name":"green valley school","admin_name":"School Principal","admin_email":"principal@example.test","admin_password":"Principal@12345"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)

	if response.Code != http.StatusConflict {
		t.Fatalf("duplicate setup status=%d body=%s", response.Code, response.Body.String())
	}
	var count int64
	if err := db.Model(&models.School{}).Count(&count).Error; err != nil {
		t.Fatalf("count schools: %v", err)
	}
	if count != 1 {
		t.Fatalf("duplicate setup created school, count=%d", count)
	}
}
