package handlers

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func TestDeleteUserCanPermanentlyRemoveInactiveAccount(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.User{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	user := models.User{
		SchoolID:     "school-test",
		Name:         "Inactive User",
		Email:        "inactive@example.test",
		RoleSlug:     "teacher",
		PasswordHash: "hash",
		RoleID:       "role-teacher",
		IsActive:     false,
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}
	if err := db.Model(&models.User{}).Where("id = ?", user.ID).Update("is_active", false).Error; err != nil {
		t.Fatalf("deactivate user: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("role_name", "Principal")
		c.Next()
	})
	handler := NewUserManagementHandler()
	router.DELETE("/users/:id", handler.DeleteUser)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodDelete, "/users/"+user.ID+"?permanent=true", nil)
	router.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("delete status = %d body=%s", response.Code, response.Body.String())
	}

	var count int64
	if err := db.Model(&models.User{}).Where("id = ?", user.ID).Count(&count).Error; err != nil {
		t.Fatalf("count user: %v", err)
	}
	if count != 0 {
		t.Fatalf("inactive user still exists after permanent delete")
	}
}

func TestDeleteUserPermanentRefusesActiveAccount(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.User{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	user := models.User{
		SchoolID:     "school-test",
		Name:         "Active User",
		Email:        "active@example.test",
		RoleSlug:     "teacher",
		PasswordHash: "hash",
		RoleID:       "role-teacher",
		IsActive:     true,
	}
	if err := db.Create(&user).Error; err != nil {
		t.Fatalf("create user: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("role_name", "Principal")
		c.Next()
	})
	handler := NewUserManagementHandler()
	router.DELETE("/users/:id", handler.DeleteUser)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodDelete, "/users/"+user.ID+"?permanent=true", nil)
	router.ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest {
		t.Fatalf("delete status = %d body=%s", response.Code, response.Body.String())
	}

	var reloaded models.User
	if err := db.First(&reloaded, "id = ?", user.ID).Error; err != nil {
		t.Fatalf("active user should still exist: %v", err)
	}
	if !reloaded.IsActive {
		t.Fatalf("active user should not be deactivated by rejected permanent delete")
	}
}
