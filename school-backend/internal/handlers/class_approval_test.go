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

func setupClassApprovalDB(t *testing.T) *gorm.DB {
	t.Helper()
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.FrontendRecord{},
		&models.AcademicYear{},
		&models.Grade{},
		&models.Section{},
		&models.Staff{},
		&models.LeaveApplication{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func TestAdminClassCreationCreatesPendingApprovalOnly(t *testing.T) {
	db := setupClassApprovalDB(t)

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", "admin-user")
		c.Set("role_name", "Admin")
		c.Set("email", "admin@example.test")
		c.Next()
	})
	handler := NewClassApprovalHandler()
	router.POST("/class-approvals", handler.Create)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/class-approvals",
		strings.NewReader(`{"class_name":"Class 8","sections":["A","B"],"capacity":35}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusCreated {
		t.Fatalf("create status = %d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), `"status":"pending"`) {
		t.Fatalf("response missing pending status: %s", response.Body.String())
	}

	var approvalCount int64
	if err := db.Model(&models.FrontendRecord{}).Where("resource = ?", classApprovalResource).Count(&approvalCount).Error; err != nil {
		t.Fatalf("count approvals: %v", err)
	}
	if approvalCount != 1 {
		t.Fatalf("expected 1 class approval, got %d", approvalCount)
	}
	var gradeCount int64
	if err := db.Model(&models.Grade{}).Count(&gradeCount).Error; err != nil {
		t.Fatalf("count grades: %v", err)
	}
	if gradeCount != 0 {
		t.Fatalf("admin class request should not create active grade, got %d", gradeCount)
	}
}

func TestPrincipalApprovalCreatesGradeAndSections(t *testing.T) {
	db := setupClassApprovalDB(t)
	year := models.AcademicYear{
		BaseModel: models.BaseModel{ID: "year-test"},
		SchoolID:  "school-test",
		YearLabel: "2026-27",
		Year:      "2026-27",
		StartDate: time.Now(),
		EndDate:   time.Now().AddDate(1, 0, 0),
		IsCurrent: true,
		Status:    "active",
	}
	if err := db.Create(&year).Error; err != nil {
		t.Fatalf("create year: %v", err)
	}
	payload, err := jsonMarshal(gin.H{
		"type":         "class",
		"status":       "pending",
		"class_name":   "Class 8",
		"sections":     []string{"A", "B"},
		"capacity":     35,
		"grade_number": 8,
	})
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}
	record := models.FrontendRecord{
		SchoolID:  "school-test",
		Resource:  classApprovalResource,
		Payload:   payload,
		CreatedBy: "admin-user",
	}
	if err := db.Create(&record).Error; err != nil {
		t.Fatalf("create approval: %v", err)
	}

	count, err := pendingPrincipalApprovalsCount("school-test")
	if err != nil {
		t.Fatalf("count pending approvals: %v", err)
	}
	if count != 1 {
		t.Fatalf("pending approvals before decision = %d, want 1", count)
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", "principal-user")
		c.Set("role_name", "Principal")
		c.Set("email", "principal@example.test")
		c.Next()
	})
	handler := NewClassApprovalHandler()
	router.PUT("/class-approvals/:id", handler.Decide)

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPut,
		"/class-approvals/"+record.ID,
		strings.NewReader(`{"status":"approved","remarks":"Approved"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("approve status = %d body=%s", response.Code, response.Body.String())
	}

	var grade models.Grade
	if err := db.First(&grade, "school_id = ? AND grade_name = ?", "school-test", "Class 8").Error; err != nil {
		t.Fatalf("load approved grade: %v", err)
	}
	if grade.GradeNumber != 8 {
		t.Fatalf("grade number = %d, want 8", grade.GradeNumber)
	}
	var sections []models.Section
	if err := db.Where("grade_id = ? AND academic_year_id = ?", grade.ID, "year-test").Find(&sections).Error; err != nil {
		t.Fatalf("load sections: %v", err)
	}
	if len(sections) != 2 {
		t.Fatalf("created sections = %d, want 2", len(sections))
	}
	for _, section := range sections {
		if section.Capacity != 35 {
			t.Fatalf("section %s capacity = %d, want 35", section.SectionName, section.Capacity)
		}
	}

	count, err = pendingPrincipalApprovalsCount("school-test")
	if err != nil {
		t.Fatalf("count pending after decision: %v", err)
	}
	if count != 0 {
		t.Fatalf("pending approvals after decision = %d, want 0", count)
	}

	var updated models.FrontendRecord
	if err := db.First(&updated, "id = ?", record.ID).Error; err != nil {
		t.Fatalf("load updated approval: %v", err)
	}
	var updatedPayload map[string]interface{}
	if err := json.Unmarshal([]byte(updated.Payload), &updatedPayload); err != nil {
		t.Fatalf("decode payload: %v", err)
	}
	gradeID, _ := updatedPayload["grade_id"].(string)
	if updatedPayload["status"] != "approved" || gradeID == "" {
		t.Fatalf("approval payload not finalized: %s", updated.Payload)
	}
}
