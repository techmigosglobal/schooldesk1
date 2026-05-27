package handlers

import (
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

func TestUpdateStaffCanResetLinkedLoginWithoutRoleSlugColumn(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.Role{}, &models.User{}, &models.Staff{}, &models.Department{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	role := models.Role{
		BaseModel: models.BaseModel{ID: "role-teacher"},
		SchoolID:  "school-test",
		RoleName:  "Teacher",
	}
	if err := db.Create(&role).Error; err != nil {
		t.Fatalf("create role: %v", err)
	}

	dept := models.Department{
		BaseModel:      models.BaseModel{ID: "dept-math"},
		SchoolID:       "school-test",
		DepartmentName: "Mathematics",
	}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}

	staffID := "staff-test"
	staff := models.Staff{
		BaseModel:      models.BaseModel{ID: staffID},
		SchoolID:       "school-test",
		StaffCode:      "EMP-001",
		FirstName:      "Nursery teacher",
		LastName:       "",
		Email:          "teacher@example.test",
		Phone:          "9876543210",
		DateOfBirth:    time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
		Gender:         "other",
		DepartmentID:   &dept.ID,
		Designation:    "Class Teacher",
		EmploymentType: "full_time",
		JoinDate:       time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
		Status:         "active",
	}
	if err := db.Create(&staff).Error; err != nil {
		t.Fatalf("create staff: %v", err)
	}

	user := models.User{
		BaseModel:    models.BaseModel{ID: "user-linked"},
		SchoolID:     "school-test",
		Name:         "Nursery teacher",
		Username:     "teacher-login",
		Email:        "teacher@example.test",
		Phone:        "9876543210",
		RoleSlug:     "teacher",
		PasswordHash: "old-hash",
		RoleID:       role.ID,
		LinkedType:   "staff",
		LinkedID:     &staffID,
		IsActive:     true,
		IsVerified:   true,
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
	router.PUT("/staff/:id", NewStaffHandler().UpdateStaff)

	body := `{
		"staff_code":"EMP-001",
		"username":"teacher-login",
		"first_name":"Nursery teacher",
		"last_name":"",
		"email":"teacher@example.test",
		"phone":"9876543210",
		"department_id":"Mathematics",
		"designation":"Class Teacher",
		"employment_type":"full_time",
		"gender":"other",
		"join_date":"2026-01-01",
		"date_of_birth":"1990-01-01",
		"password":"teacher12345",
		"account_role":"Teacher"
	}`
	response := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPut, "/staff/"+staffID, strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("update status = %d body=%s", response.Code, response.Body.String())
	}

	var updated models.User
	if err := db.First(&updated, "id = ?", user.ID).Error; err != nil {
		t.Fatalf("load linked user: %v", err)
	}
	if updated.RoleSlug != "teacher" {
		t.Fatalf("role slug = %q, want teacher", updated.RoleSlug)
	}
	if updated.Username != "teacher-login" {
		t.Fatalf("username = %q", updated.Username)
	}
	if updated.PasswordHash == "old-hash" {
		t.Fatalf("password hash was not updated")
	}
}

func TestUpdateStaffWithoutLinkedLoginStillUpdatesProfile(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.Role{}, &models.User{}, &models.Staff{}, &models.Department{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	dept := models.Department{
		BaseModel:      models.BaseModel{ID: "dept-admin"},
		SchoolID:       "school-test",
		DepartmentName: "Administration",
	}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}

	staffID := "staff-without-login"
	staff := models.Staff{
		BaseModel:      models.BaseModel{ID: staffID},
		SchoolID:       "school-test",
		StaffCode:      "EMP-010",
		FirstName:      "Office Staff",
		LastName:       "",
		Email:          "office@example.test",
		Phone:          "9000000000",
		DateOfBirth:    time.Date(1991, 2, 3, 0, 0, 0, 0, time.UTC),
		Gender:         "other",
		DepartmentID:   &dept.ID,
		Designation:    "Admin",
		EmploymentType: "full_time",
		JoinDate:       time.Date(2026, 1, 2, 0, 0, 0, 0, time.UTC),
		Status:         "active",
	}
	if err := db.Create(&staff).Error; err != nil {
		t.Fatalf("create staff: %v", err)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("role_name", "Principal")
		c.Next()
	})
	router.PUT("/staff/:id", NewStaffHandler().UpdateStaff)

	body := `{
		"staff_code":"EMP-010",
		"first_name":"Updated Office Staff",
		"last_name":"",
		"email":"office-updated@example.test",
		"phone":"9111111111",
		"department_id":"Administration",
		"designation":"Admin",
		"employment_type":"full_time",
		"gender":"other",
		"join_date":"2026-01-02",
		"date_of_birth":"1991-02-03",
		"account_role":"Admin"
	}`
	response := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPut, "/staff/"+staffID, strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)

	if response.Code != http.StatusOK {
		t.Fatalf("update status = %d body=%s", response.Code, response.Body.String())
	}

	var updated models.Staff
	if err := db.First(&updated, "id = ?", staffID).Error; err != nil {
		t.Fatalf("load staff: %v", err)
	}
	if updated.FirstName != "Updated Office Staff" {
		t.Fatalf("first name = %q", updated.FirstName)
	}
	if updated.Phone != "9111111111" {
		t.Fatalf("phone = %q", updated.Phone)
	}
}

func TestUpdateStaffRejectsDuplicateEmployeeIDInSameSchool(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(&models.Role{}, &models.User{}, &models.Staff{}, &models.Department{}); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	dept := models.Department{
		BaseModel:      models.BaseModel{ID: "dept-general"},
		SchoolID:       "school-test",
		DepartmentName: "General",
	}
	if err := db.Create(&dept).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}
	for _, staff := range []models.Staff{
		{
			BaseModel:      models.BaseModel{ID: "staff-one"},
			SchoolID:       "school-test",
			StaffCode:      "EMP-100",
			FirstName:      "First Staff",
			DepartmentID:   &dept.ID,
			DateOfBirth:    time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
			JoinDate:       time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
			Status:         "active",
			EmploymentType: "full_time",
		},
		{
			BaseModel:      models.BaseModel{ID: "staff-two"},
			SchoolID:       "school-test",
			StaffCode:      "EMP-200",
			FirstName:      "Second Staff",
			DepartmentID:   &dept.ID,
			DateOfBirth:    time.Date(1990, 1, 1, 0, 0, 0, 0, time.UTC),
			JoinDate:       time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC),
			Status:         "active",
			EmploymentType: "full_time",
		},
	} {
		if err := db.Create(&staff).Error; err != nil {
			t.Fatalf("create staff %s: %v", staff.ID, err)
		}
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("role_name", "Principal")
		c.Next()
	})
	router.PUT("/staff/:id", NewStaffHandler().UpdateStaff)

	body := `{
		"staff_code":"EMP-100",
		"first_name":"Second Staff",
		"last_name":"",
		"email":"second@example.test",
		"phone":"9222222222",
		"department_id":"General",
		"designation":"Teacher",
		"employment_type":"full_time",
		"gender":"other",
		"join_date":"2026-01-01",
		"date_of_birth":"1990-01-01",
		"account_role":"Teacher"
	}`
	response := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPut, "/staff/staff-two", strings.NewReader(body))
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)

	if response.Code != http.StatusBadRequest {
		t.Fatalf("update status = %d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "already exists") {
		t.Fatalf("expected duplicate message, got %s", response.Body.String())
	}
}
