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

func setupExamContractTestDB(t *testing.T) *gorm.DB {
	t.Helper()
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.School{},
		&models.AcademicYear{},
		&models.Term{},
		&models.ExamType{},
		&models.Exam{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	school := models.School{BaseModel: models.BaseModel{ID: "school-exam"}, Name: "Exam School", SchoolType: "cbse"}
	year := models.AcademicYear{
		BaseModel: models.BaseModel{ID: "year-exam"},
		SchoolID:  school.ID,
		YearLabel: "2026-2027",
		StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC),
		EndDate:   time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC),
		IsCurrent: true,
	}
	term := models.Term{
		BaseModel:      models.BaseModel{ID: "term-exam"},
		AcademicYearID: year.ID,
		TermNumber:     1,
		TermName:       "Term 1",
		StartDate:      year.StartDate,
		EndDate:        year.EndDate,
		IsCurrent:      true,
	}
	for _, seed := range []any{&school, &year, &term} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}
	return db
}

func newScopedExamRouter(schoolID string) *gin.Engine {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", schoolID)
		c.Set("user_id", "admin-exam")
		c.Set("role", "Admin")
		c.Next()
	})
	handler := NewExamHandler()
	router.POST("/exams/types", handler.CreateExamType)
	router.POST("/exams", handler.CreateExam)
	router.PUT("/exams/:id", handler.UpdateExam)
	router.PATCH("/exams/:id/publish", handler.PublishExam)
	return router
}

func TestCreateExamTypeUsesScopedSchoolWithoutSchoolIDPayload(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := setupExamContractTestDB(t)
	router := newScopedExamRouter("school-exam")

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/exams/types",
		strings.NewReader(`{"name":"Run2 Unit Test","weightage_percent":10,"is_board_exam":false}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)

	if response.Code != http.StatusCreated {
		t.Fatalf("status=%d body=%s", response.Code, response.Body.String())
	}
	var examType models.ExamType
	if err := db.Where("school_id = ? AND name = ?", "school-exam", "Run2 Unit Test").First(&examType).Error; err != nil {
		t.Fatalf("exam type was not scoped/created: %v", err)
	}
}

func TestCreateExamUsesScopedSchoolWithoutSchoolIDPayload(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := setupExamContractTestDB(t)
	examType := models.ExamType{
		BaseModel:        models.BaseModel{ID: "exam-type-existing"},
		SchoolID:         "school-exam",
		Name:             "Unit Test",
		WeightagePercent: 10,
		IsBoardExam:      false,
	}
	if err := db.Create(&examType).Error; err != nil {
		t.Fatalf("seed exam type: %v", err)
	}
	router := newScopedExamRouter("school-exam")

	response := httptest.NewRecorder()
	request := httptest.NewRequest(
		http.MethodPost,
		"/exams",
		strings.NewReader(`{"academic_year_id":"year-exam","term_id":"term-exam","exam_type_id":"exam-type-existing","exam_name":"Run2 Exam","start_date":"2026-05-10","end_date":"2026-05-12"}`),
	)
	request.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(response, request)

	if response.Code != http.StatusCreated {
		t.Fatalf("status=%d body=%s", response.Code, response.Body.String())
	}
	var exam models.Exam
	if err := db.Where("school_id = ? AND exam_name = ?", "school-exam", "Run2 Exam").First(&exam).Error; err != nil {
		t.Fatalf("exam was not scoped/created: %v", err)
	}
}

func TestUpdateAndPublishExamStaySchoolScoped(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db := setupExamContractTestDB(t)
	examType := models.ExamType{
		BaseModel:        models.BaseModel{ID: "exam-type-update"},
		SchoolID:         "school-exam",
		Name:             "Update Test",
		WeightagePercent: 20,
		IsBoardExam:      false,
	}
	exam := models.Exam{
		BaseModel:      models.BaseModel{ID: "exam-update"},
		SchoolID:       "school-exam",
		AcademicYearID: "year-exam",
		TermID:         "term-exam",
		ExamTypeID:     examType.ID,
		ExamName:       "Old Exam",
		StartDate:      time.Date(2026, 6, 1, 0, 0, 0, 0, time.UTC),
		EndDate:        time.Date(2026, 6, 2, 0, 0, 0, 0, time.UTC),
	}
	if err := db.Create(&examType).Error; err != nil {
		t.Fatalf("seed exam type: %v", err)
	}
	if err := db.Create(&exam).Error; err != nil {
		t.Fatalf("seed exam: %v", err)
	}
	router := newScopedExamRouter("school-exam")

	update := httptest.NewRecorder()
	updateReq := httptest.NewRequest(
		http.MethodPut,
		"/exams/exam-update",
		strings.NewReader(`{"academic_year_id":"year-exam","term_id":"term-exam","exam_type_id":"exam-type-update","exam_name":"Updated Exam","start_date":"2026-06-03","end_date":"2026-06-04"}`),
	)
	updateReq.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(update, updateReq)
	if update.Code != http.StatusOK {
		t.Fatalf("update status=%d body=%s", update.Code, update.Body.String())
	}

	publish := httptest.NewRecorder()
	publishReq := httptest.NewRequest(
		http.MethodPatch,
		"/exams/exam-update/publish",
		strings.NewReader(`{"is_published":true}`),
	)
	publishReq.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(publish, publishReq)
	if publish.Code != http.StatusOK {
		t.Fatalf("publish status=%d body=%s", publish.Code, publish.Body.String())
	}

	var saved models.Exam
	if err := db.First(&saved, "id = ?", "exam-update").Error; err != nil {
		t.Fatalf("load exam: %v", err)
	}
	if saved.ExamName != "Updated Exam" || !saved.IsPublished {
		t.Fatalf("exam not updated/published: %#v", saved)
	}
}
