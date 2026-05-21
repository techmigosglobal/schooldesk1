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

func TestGetUsersCanFilterParentsByRoleAndStatus(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.Role{}, &models.User{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	parentRole := models.Role{
		BaseModel: models.BaseModel{ID: "role-parent"},
		SchoolID:  "school-test",
		RoleName:  "Parent",
	}
	adminRole := models.Role{
		BaseModel: models.BaseModel{ID: "role-admin"},
		SchoolID:  "school-test",
		RoleName:  "Admin",
	}
	if err := db.Create(&parentRole).Error; err != nil {
		t.Fatalf("create parent role: %v", err)
	}
	if err := db.Create(&adminRole).Error; err != nil {
		t.Fatalf("create admin role: %v", err)
	}

	users := []models.User{
		{
			BaseModel:    models.BaseModel{ID: "parent-active"},
			SchoolID:     "school-test",
			Name:         "Active Parent",
			Username:     "parent01",
			Email:        "parent01@example.test",
			RoleID:       parentRole.ID,
			RoleSlug:     "parent",
			PasswordHash: "hash",
			IsActive:     true,
		},
		{
			BaseModel:    models.BaseModel{ID: "parent-inactive"},
			SchoolID:     "school-test",
			Name:         "Inactive Parent",
			Username:     "parent02",
			Email:        "parent02@example.test",
			RoleID:       parentRole.ID,
			RoleSlug:     "parent",
			PasswordHash: "hash",
			IsActive:     false,
		},
		{
			BaseModel:    models.BaseModel{ID: "admin-active"},
			SchoolID:     "school-test",
			Name:         "Active Admin",
			Username:     "admin01",
			Email:        "admin01@example.test",
			RoleID:       adminRole.ID,
			RoleSlug:     "admin",
			PasswordHash: "hash",
			IsActive:     true,
		},
	}
	for i := range users {
		if err := db.Create(&users[i]).Error; err != nil {
			t.Fatalf("create user %s: %v", users[i].ID, err)
		}
	}
	if err := db.Model(&models.User{}).
		Where("id = ?", "parent-inactive").
		Update("is_active", false).Error; err != nil {
		t.Fatalf("mark inactive parent inactive: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("role_name", "Principal")
		c.Next()
	})
	router.GET("/users", NewUserHandler().GetUsers)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodGet,
		"/users?role=Parent&status=active&page=1&page_size=20",
		nil,
	)
	router.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("status = %d body=%s", response.Code, response.Body.String())
	}
	body := response.Body.String()
	if !strings.Contains(body, "parent01") {
		t.Fatalf("active parent missing from response: %s", body)
	}
	if strings.Contains(body, "parent02") || strings.Contains(body, "admin01") {
		t.Fatalf("response includes non-matching users: %s", body)
	}
}
