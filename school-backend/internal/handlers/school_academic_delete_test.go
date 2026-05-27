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

func setupAcademicDeleteDB(t *testing.T) *gorm.DB {
	t.Helper()
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.AcademicYear{},
		&models.Term{},
		&models.Holiday{},
		&models.Department{},
		&models.Subject{},
		&models.Grade{},
		&models.GradeSubject{},
		&models.Section{},
		&models.Student{},
		&models.Enrollment{},
		&models.AttendanceSession{},
		&models.StudentAttendance{},
		&models.AttendanceSummary{},
		&models.FeeStructure{},
		&models.FeeInvoice{},
		&models.TimetableSlot{},
		&models.Substitution{},
		&models.ExamSchedule{},
		&models.StudentMark{},
		&models.ReportCard{},
		&models.StaffSubject{},
		&models.EventCalendar{},
		&models.ParentTeacherMeeting{},
		&models.Homework{},
		&models.HomeworkSubmission{},
		&models.DiaryEntry{},
		&models.AuditLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	return db
}

func academicDeleteRouter() *gin.Engine {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", "school-test")
		c.Set("user_id", "principal-user")
		c.Set("role_name", "Principal")
		c.Next()
	})
	handler := NewSchoolHandler()
	router.DELETE("/subjects/:id", handler.DeleteSubject)
	router.DELETE("/sections/:id", handler.DeleteSection)
	router.DELETE("/grades/:id", handler.DeleteGrade)
	return router
}

func TestDeleteSubjectCleansLinkedEmptyTimetableSlot(t *testing.T) {
	db := setupAcademicDeleteDB(t)
	if err := db.Create(&models.Department{
		BaseModel:      models.BaseModel{ID: "dept-test"},
		SchoolID:       "school-test",
		DepartmentName: "Academics",
	}).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}
	if err := db.Create(&models.Subject{
		BaseModel:    models.BaseModel{ID: "subject-test"},
		SchoolID:     "school-test",
		DepartmentID: "dept-test",
		SubjectName:  "Mathematics",
	}).Error; err != nil {
		t.Fatalf("create subject: %v", err)
	}
	if err := db.Create(&models.TimetableSlot{
		BaseModel:      models.BaseModel{ID: "slot-test"},
		SectionID:      "section-test",
		AcademicYearID: "year-test",
		TermID:         "term-test",
		DayOfWeek:      1,
		PeriodNumber:   1,
		SubjectID:      "subject-test",
		StaffID:        "staff-test",
	}).Error; err != nil {
		t.Fatalf("create timetable slot: %v", err)
	}

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/subjects/subject-test", nil),
	)

	if response.Code != http.StatusOK {
		t.Fatalf("delete status = %d body=%s", response.Code, response.Body.String())
	}
	var count int64
	db.Model(&models.TimetableSlot{}).Where("subject_id = ?", "subject-test").Count(&count)
	if count != 0 {
		t.Fatalf("timetable slot should be removed with empty subject setup")
	}
}

func TestDeleteSubjectRejectsLinkedAttendanceSession(t *testing.T) {
	db := setupAcademicDeleteDB(t)
	if err := db.Create(&models.Department{
		BaseModel:      models.BaseModel{ID: "dept-test"},
		SchoolID:       "school-test",
		DepartmentName: "Academics",
	}).Error; err != nil {
		t.Fatalf("create department: %v", err)
	}
	if err := db.Create(&models.Subject{
		BaseModel:    models.BaseModel{ID: "subject-test"},
		SchoolID:     "school-test",
		DepartmentID: "dept-test",
		SubjectName:  "Mathematics",
	}).Error; err != nil {
		t.Fatalf("create subject: %v", err)
	}
	if err := db.Create(&models.AttendanceSession{
		BaseModel:     models.BaseModel{ID: "attendance-session-test"},
		SectionID:     "section-test",
		SubjectID:     "subject-test",
		StaffID:       "staff-test",
		Date:          mustParseAcademicDeleteDate(t, "2026-05-27"),
		PeriodNumber:  1,
		TotalStudents: 1,
	}).Error; err != nil {
		t.Fatalf("create attendance session: %v", err)
	}

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/subjects/subject-test", nil),
	)

	if response.Code != http.StatusConflict {
		t.Fatalf("delete status = %d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "linked attendance sessions") {
		t.Fatalf("delete response should explain linked attendance session: %s", response.Body.String())
	}
}

func mustParseAcademicDeleteDate(t *testing.T, value string) time.Time {
	t.Helper()
	parsed, err := time.Parse("2006-01-02", value)
	if err != nil {
		t.Fatalf("parse date: %v", err)
	}
	return parsed
}

func TestDeleteSectionRejectsLinkedStudent(t *testing.T) {
	db := setupAcademicDeleteDB(t)
	if err := db.Create(&models.Grade{
		BaseModel:   models.BaseModel{ID: "grade-test"},
		SchoolID:    "school-test",
		GradeNumber: 5,
		GradeName:   "Class 5",
	}).Error; err != nil {
		t.Fatalf("create grade: %v", err)
	}
	if err := db.Create(&models.Section{
		BaseModel:      models.BaseModel{ID: "section-test"},
		GradeID:        "grade-test",
		AcademicYearID: "year-test",
		SectionName:    "A",
		Capacity:       40,
	}).Error; err != nil {
		t.Fatalf("create section: %v", err)
	}
	sectionID := "section-test"
	if err := db.Create(&models.Student{
		BaseModel:        models.BaseModel{ID: "student-test"},
		SchoolID:         "school-test",
		StudentCode:      "ST-001",
		AdmissionNumber:  "ADM-001",
		FirstName:        "Asha",
		LastName:         "Rao",
		CurrentSectionID: &sectionID,
		Status:           "active",
	}).Error; err != nil {
		t.Fatalf("create student: %v", err)
	}

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/sections/section-test", nil),
	)

	if response.Code != http.StatusConflict {
		t.Fatalf("delete status = %d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "linked students") {
		t.Fatalf("delete response should explain linked student: %s", response.Body.String())
	}
}

func TestDeleteSectionClearsInactiveStudentAndLinkedClassRecords(t *testing.T) {
	db := setupAcademicDeleteDB(t)
	if err := db.Create(&models.Grade{
		BaseModel:   models.BaseModel{ID: "grade-test"},
		SchoolID:    "school-test",
		GradeNumber: 5,
		GradeName:   "Class 5",
	}).Error; err != nil {
		t.Fatalf("create grade: %v", err)
	}
	if err := db.Create(&models.Section{
		BaseModel:      models.BaseModel{ID: "section-test"},
		GradeID:        "grade-test",
		AcademicYearID: "year-test",
		SectionName:    "A",
		Capacity:       40,
	}).Error; err != nil {
		t.Fatalf("create section: %v", err)
	}
	sectionID := "section-test"
	if err := db.Create(&models.Student{
		BaseModel:        models.BaseModel{ID: "student-test"},
		SchoolID:         "school-test",
		StudentCode:      "ST-001",
		AdmissionNumber:  "ADM-001",
		FirstName:        "Asha",
		LastName:         "Rao",
		CurrentSectionID: &sectionID,
		Status:           "inactive",
	}).Error; err != nil {
		t.Fatalf("create inactive student: %v", err)
	}
	if err := db.Create(&models.Enrollment{
		BaseModel:      models.BaseModel{ID: "enrollment-test"},
		StudentID:      "student-test",
		SectionID:      "section-test",
		AcademicYearID: "year-test",
		Status:         "enrolled",
	}).Error; err != nil {
		t.Fatalf("create enrollment: %v", err)
	}
	if err := db.Create(&models.TimetableSlot{
		BaseModel:      models.BaseModel{ID: "slot-test"},
		SectionID:      "section-test",
		AcademicYearID: "year-test",
		TermID:         "term-test",
		DayOfWeek:      1,
		PeriodNumber:   1,
		SubjectID:      "subject-test",
		StaffID:        "staff-test",
	}).Error; err != nil {
		t.Fatalf("create timetable slot: %v", err)
	}
	if err := db.Create(&models.Homework{
		BaseModel: models.BaseModel{ID: "homework-test"},
		SchoolID:  "school-test",
		Title:     "Practice",
		SectionID: "section-test",
	}).Error; err != nil {
		t.Fatalf("create homework: %v", err)
	}

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/sections/section-test", nil),
	)

	if response.Code != http.StatusOK {
		t.Fatalf("delete status = %d body=%s", response.Code, response.Body.String())
	}
	var count int64
	db.Model(&models.Section{}).Where("id = ?", "section-test").Count(&count)
	if count != 0 {
		t.Fatalf("section still exists")
	}
	db.Model(&models.TimetableSlot{}).Where("section_id = ?", "section-test").Count(&count)
	if count != 0 {
		t.Fatalf("timetable links still exist")
	}
	db.Model(&models.Homework{}).Where("section_id = ?", "section-test").Count(&count)
	if count != 0 {
		t.Fatalf("homework links still exist")
	}
	var student models.Student
	if err := db.First(&student, "id = ?", "student-test").Error; err != nil {
		t.Fatalf("load student: %v", err)
	}
	if student.CurrentSectionID != nil {
		t.Fatalf("inactive student section link was not cleared")
	}
}

func TestDeleteGradeRejectsExistingSections(t *testing.T) {
	db := setupAcademicDeleteDB(t)
	if err := db.Create(&models.Grade{
		BaseModel:   models.BaseModel{ID: "grade-test"},
		SchoolID:    "school-test",
		GradeNumber: 5,
		GradeName:   "Class 5",
	}).Error; err != nil {
		t.Fatalf("create grade: %v", err)
	}
	if err := db.Create(&models.Section{
		BaseModel:      models.BaseModel{ID: "section-test"},
		GradeID:        "grade-test",
		AcademicYearID: "year-test",
		SectionName:    "A",
		Capacity:       40,
	}).Error; err != nil {
		t.Fatalf("create section: %v", err)
	}

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/grades/grade-test", nil),
	)

	if response.Code != http.StatusConflict {
		t.Fatalf("delete status = %d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "linked sections") {
		t.Fatalf("delete response should explain linked sections: %s", response.Body.String())
	}
}
