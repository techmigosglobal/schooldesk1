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

func setupStudentApprovalDB(t *testing.T) (*gorm.DB, models.Section, models.User) {
	t.Helper()
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		t.Fatalf("sql db: %v", err)
	}
	sqlDB.SetMaxOpenConns(1)
	database.DB = db
	if err := db.AutoMigrate(
		&models.School{},
		&models.Role{},
		&models.User{},
		&models.FrontendRecord{},
		&models.AcademicYear{},
		&models.Grade{},
		&models.Section{},
		&models.Student{},
		&models.Enrollment{},
		&models.ParentStudentLink{},
		&models.Staff{},
		&models.LeaveApplication{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	school := models.School{BaseModel: models.BaseModel{ID: "school-test"}, Name: "Public School", SchoolType: "K-12"}
	if err := db.Create(&school).Error; err != nil {
		t.Fatalf("create school: %v", err)
	}
	year := models.AcademicYear{
		BaseModel: models.BaseModel{ID: "year-test"},
		SchoolID:  school.ID,
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
	grade := models.Grade{
		BaseModel:   models.BaseModel{ID: "grade-test"},
		SchoolID:    school.ID,
		GradeNumber: 5,
		GradeName:   "Class 5",
	}
	if err := db.Create(&grade).Error; err != nil {
		t.Fatalf("create grade: %v", err)
	}
	section := models.Section{
		BaseModel:      models.BaseModel{ID: "section-test"},
		GradeID:        grade.ID,
		AcademicYearID: year.ID,
		SectionName:    "A",
		Capacity:       40,
	}
	if err := db.Create(&section).Error; err != nil {
		t.Fatalf("create section: %v", err)
	}
	parentRole := models.Role{
		BaseModel: models.BaseModel{ID: "role-parent"},
		SchoolID:  school.ID,
		RoleName:  "Parent",
	}
	if err := db.Create(&parentRole).Error; err != nil {
		t.Fatalf("create parent role: %v", err)
	}
	parent := models.User{
		BaseModel:    models.BaseModel{ID: "parent-user"},
		SchoolID:     school.ID,
		Name:         "Test Parent",
		Username:     "parent",
		Email:        "parent@example.test",
		PasswordHash: "hash",
		RoleID:       parentRole.ID,
		RoleSlug:     "parent",
		IsActive:     true,
	}
	if err := db.Create(&parent).Error; err != nil {
		t.Fatalf("create parent user: %v", err)
	}
	return db, section, parent
}

func studentApprovalRouter(role string) *gin.Engine {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", strings.ToLower(role)+"-user")
		c.Set("role_name", role)
		c.Set("email", strings.ToLower(role)+"@example.test")
		c.Next()
	})
	handler := NewStudentApprovalHandler()
	router.GET("/student-approvals", handler.List)
	router.POST("/student-approvals", handler.Create)
	router.PUT("/student-approvals/:id", handler.Decide)
	return router
}

func TestAdminStudentCreationCreatesPendingApprovalOnly(t *testing.T) {
	db, section, parent := setupStudentApprovalDB(t)
	router := studentApprovalRouter("Admin")

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/student-approvals",
		strings.NewReader(`{"action":"create","parent_user_id":"`+parent.ID+`","student":{"first_name":"Asha","last_name":"Rao","date_of_birth":"2012-01-01","gender":"female","admission_number":"ADM-101","student_code":"STU-101","current_section_id":"`+section.ID+`","class_label":"Class 5 A","status":"active"}}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusCreated {
		t.Fatalf("create approval status = %d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), `"status":"pending"`) {
		t.Fatalf("response missing pending status: %s", response.Body.String())
	}

	var approvalCount int64
	if err := db.Model(&models.FrontendRecord{}).Where("resource = ?", studentApprovalResource).Count(&approvalCount).Error; err != nil {
		t.Fatalf("count approvals: %v", err)
	}
	if approvalCount != 1 {
		t.Fatalf("expected 1 student approval, got %d", approvalCount)
	}
	var studentCount int64
	if err := db.Model(&models.Student{}).Count(&studentCount).Error; err != nil {
		t.Fatalf("count students: %v", err)
	}
	if studentCount != 0 {
		t.Fatalf("admin student request should not create active student, got %d", studentCount)
	}
	count, err := pendingPrincipalApprovalsCount("school-test")
	if err != nil {
		t.Fatalf("count pending approvals: %v", err)
	}
	if count != 1 {
		t.Fatalf("pending approvals = %d, want 1", count)
	}
}

func TestPrincipalApprovalCreatesStudentEnrollmentAndParentLink(t *testing.T) {
	db, section, parent := setupStudentApprovalDB(t)
	payload, err := jsonMarshal(gin.H{
		"type":           "student",
		"status":         "pending",
		"action":         "create",
		"parent_user_id": parent.ID,
		"student": gin.H{
			"first_name":         "Asha",
			"last_name":          "Rao",
			"date_of_birth":      "2012-01-01",
			"gender":             "female",
			"admission_number":   "ADM-101",
			"student_code":       "STU-101",
			"current_section_id": section.ID,
			"class_label":        "Class 5 A",
			"status":             "active",
		},
	})
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}
	record := models.FrontendRecord{
		SchoolID:  "school-test",
		Resource:  studentApprovalResource,
		Payload:   payload,
		CreatedBy: "admin-user",
	}
	if err := db.Create(&record).Error; err != nil {
		t.Fatalf("create approval: %v", err)
	}

	router := studentApprovalRouter("Principal")
	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPut,
		"/student-approvals/"+record.ID,
		strings.NewReader(`{"status":"approved","remarks":"Approved"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("approve status = %d body=%s", response.Code, response.Body.String())
	}

	var student models.Student
	if err := db.First(&student, "school_id = ? AND admission_number = ?", "school-test", "ADM-101").Error; err != nil {
		t.Fatalf("load approved student: %v", err)
	}
	if student.CurrentSectionID == nil || *student.CurrentSectionID != section.ID {
		t.Fatalf("student section = %v, want %s", student.CurrentSectionID, section.ID)
	}
	var enrollment models.Enrollment
	if err := db.First(&enrollment, "student_id = ? AND section_id = ?", student.ID, section.ID).Error; err != nil {
		t.Fatalf("load enrollment: %v", err)
	}
	var link models.ParentStudentLink
	if err := db.First(&link, "parent_user_id = ? AND student_id = ?", parent.ID, student.ID).Error; err != nil {
		t.Fatalf("load parent link: %v", err)
	}
	if link.StudentAdmissionNumber != "ADM-101" {
		t.Fatalf("link admission = %s, want ADM-101", link.StudentAdmissionNumber)
	}
}

func TestApprovedStudentDeleteDeactivatesAndUnlinksParent(t *testing.T) {
	db, section, parent := setupStudentApprovalDB(t)
	student := models.Student{
		BaseModel:        models.BaseModel{ID: "student-test"},
		SchoolID:         "school-test",
		StudentCode:      "STU-101",
		AdmissionNumber:  "ADM-101",
		FirstName:        "Asha",
		LastName:         "Rao",
		DateOfBirth:      time.Date(2012, 1, 1, 0, 0, 0, 0, time.UTC),
		Gender:           "female",
		AdmissionDate:    time.Now(),
		CurrentSectionID: &section.ID,
		Status:           "active",
	}
	if err := db.Create(&student).Error; err != nil {
		t.Fatalf("create student: %v", err)
	}
	link := models.ParentStudentLink{
		SchoolID:               "school-test",
		ParentUserID:           parent.ID,
		StudentID:              student.ID,
		StudentAdmissionNumber: student.AdmissionNumber,
	}
	if err := db.Create(&link).Error; err != nil {
		t.Fatalf("create link: %v", err)
	}
	payload, err := jsonMarshal(gin.H{
		"type":       "student",
		"status":     "pending",
		"action":     "delete",
		"student_id": student.ID,
		"student": gin.H{
			"first_name":       student.FirstName,
			"last_name":        student.LastName,
			"admission_number": student.AdmissionNumber,
		},
	})
	if err != nil {
		t.Fatalf("marshal payload: %v", err)
	}
	record := models.FrontendRecord{SchoolID: "school-test", Resource: studentApprovalResource, Payload: payload}
	if err := db.Create(&record).Error; err != nil {
		t.Fatalf("create approval: %v", err)
	}

	router := studentApprovalRouter("Principal")
	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPut,
		"/student-approvals/"+record.ID,
		strings.NewReader(`{"status":"approved"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("approve delete status = %d body=%s", response.Code, response.Body.String())
	}

	var updated models.Student
	if err := db.First(&updated, "id = ?", student.ID).Error; err != nil {
		t.Fatalf("load student: %v", err)
	}
	if updated.Status != "inactive" {
		t.Fatalf("student status = %s, want inactive", updated.Status)
	}
	var linkCount int64
	if err := db.Model(&models.ParentStudentLink{}).Where("student_id = ?", student.ID).Count(&linkCount).Error; err != nil {
		t.Fatalf("count links: %v", err)
	}
	if linkCount != 0 {
		t.Fatalf("parent links after delete = %d, want 0", linkCount)
	}
}
