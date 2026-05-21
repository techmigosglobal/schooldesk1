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

func setupSectionTeacherDB(t *testing.T) *gorm.DB {
	t.Helper()
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.AcademicYear{},
		&models.Grade{},
		&models.Section{},
		&models.Staff{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	if err := db.Create(&models.AcademicYear{
		BaseModel: models.BaseModel{ID: "year-test"},
		SchoolID:  "school-test",
		YearLabel: "2026-27",
		IsCurrent: true,
		Status:    "active",
	}).Error; err != nil {
		t.Fatalf("create academic year: %v", err)
	}
	if err := db.Create(&models.Grade{
		BaseModel:   models.BaseModel{ID: "grade-test"},
		SchoolID:    "school-test",
		GradeNumber: 5,
		GradeName:   "Class 5",
	}).Error; err != nil {
		t.Fatalf("create grade: %v", err)
	}
	if err := db.Create(&models.Staff{
		BaseModel: models.BaseModel{ID: "teacher-test"},
		SchoolID:  "school-test",
		StaffCode: "T-001",
		FirstName: "Asha",
		LastName:  "Teacher",
		Email:     "asha.teacher@example.test",
		Status:    "active",
	}).Error; err != nil {
		t.Fatalf("create teacher: %v", err)
	}
	return db
}

func sectionTeacherRouter() *gin.Engine {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", "admin-user")
		c.Set("role_name", "Admin")
		c.Next()
	})
	handler := NewSchoolHandler()
	router.POST("/sections", handler.CreateSection)
	router.PUT("/sections/:id", handler.UpdateSection)
	return router
}

func TestSectionClassTeacherCanBeAssignedAndCleared(t *testing.T) {
	db := setupSectionTeacherDB(t)
	router := sectionTeacherRouter()

	createResponse := httptest.NewRecorder()
	createRequest := httptest.NewRequest(
		http.MethodPost,
		"/sections",
		strings.NewReader(`{"grade_id":"grade-test","academic_year_id":"year-test","section_name":"A","class_teacher_id":"teacher-test","capacity":40}`),
	)
	createRequest.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(createResponse, createRequest)
	if createResponse.Code != http.StatusCreated {
		t.Fatalf("create status = %d body=%s", createResponse.Code, createResponse.Body.String())
	}

	var section models.Section
	if err := db.First(&section, "grade_id = ? AND section_name = ?", "grade-test", "A").Error; err != nil {
		t.Fatalf("load section: %v", err)
	}
	if section.ClassTeacherID == nil || *section.ClassTeacherID != "teacher-test" {
		t.Fatalf("class teacher not assigned: %#v", section.ClassTeacherID)
	}

	updateResponse := httptest.NewRecorder()
	updateRequest := httptest.NewRequest(
		http.MethodPut,
		"/sections/"+section.ID,
		strings.NewReader(`{"grade_id":"grade-test","academic_year_id":"year-test","section_name":"A","class_teacher_id":"","capacity":40}`),
	)
	updateRequest.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(updateResponse, updateRequest)
	if updateResponse.Code != http.StatusOK {
		t.Fatalf("update status = %d body=%s", updateResponse.Code, updateResponse.Body.String())
	}

	var updated models.Section
	if err := db.First(&updated, "id = ?", section.ID).Error; err != nil {
		t.Fatalf("reload section: %v", err)
	}
	if updated.ClassTeacherID != nil {
		t.Fatalf("class teacher should be cleared, got %#v", updated.ClassTeacherID)
	}
}

func TestSectionRejectsClassTeacherFromAnotherSchool(t *testing.T) {
	db := setupSectionTeacherDB(t)
	if err := db.Create(&models.Staff{
		BaseModel: models.BaseModel{ID: "other-school-teacher"},
		SchoolID:  "school-other",
		StaffCode: "T-OTHER",
		FirstName: "Other",
		LastName:  "Teacher",
		Email:     "other.teacher@example.test",
		Status:    "active",
	}).Error; err != nil {
		t.Fatalf("create other-school teacher: %v", err)
	}

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/sections",
		strings.NewReader(`{"grade_id":"grade-test","academic_year_id":"year-test","section_name":"A","class_teacher_id":"other-school-teacher","capacity":40}`),
	)
	request.Header.Set("Content-Type", "application/json")
	sectionTeacherRouter().ServeHTTP(response, request)

	if response.Code != http.StatusBadRequest {
		t.Fatalf("status = %d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "Class teacher must be active staff in this school") {
		t.Fatalf("response should explain class teacher scope: %s", response.Body.String())
	}
}
