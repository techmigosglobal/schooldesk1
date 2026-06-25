package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
)

func TestTeacherPTMSlotsUseCanonicalEventsTable(t *testing.T) {
	gin.SetMode(gin.TestMode)
	if err := database.SetupTestDB(); err != nil {
		t.Fatalf("setup db: %v", err)
	}

	const (
		schoolID  = "school-ptm"
		yearID    = "year-ptm"
		teacherID = "staff-ptm-teacher"
		sectionID = "section-ptm"
		eventID   = "event-ptm"
		slotID    = "slot-ptm"
	)
	now := time.Date(2026, 6, 25, 9, 0, 0, 0, time.UTC)
	seedTeacherPTMFixture(t, schoolID, yearID, teacherID, sectionID, eventID, now)
	if err := database.DB.Create(&models.ParentTeacherMeeting{
		BaseModel:   models.BaseModel{ID: slotID},
		EventID:     eventID,
		SectionID:   sectionID,
		SlotDate:    now,
		SlotTime:    "16:00",
		DurationMin: 15,
		TeacherID:   teacherID,
		Status:      "scheduled",
	}).Error; err != nil {
		t.Fatalf("seed ptm slot: %v", err)
	}

	router := teacherSelfTestRouter(schoolID, teacherID)
	resp := httptest.NewRecorder()
	router.ServeHTTP(resp, httptest.NewRequest(http.MethodGet, "/teacher/ptm-slots", nil))

	if resp.Code != http.StatusOK {
		t.Fatalf("GET /teacher/ptm-slots status=%d body=%s", resp.Code, resp.Body.String())
	}
	var body struct {
		Success bool                     `json:"success"`
		Data    []map[string]interface{} `json:"data"`
	}
	if err := json.Unmarshal(resp.Body.Bytes(), &body); err != nil {
		t.Fatalf("decode response: %v", err)
	}
	if !body.Success || len(body.Data) != 1 || body.Data[0]["id"] != slotID {
		t.Fatalf("unexpected body: %+v", body)
	}
}

func TestTeacherCreatePTMSlotUsesCanonicalEventsTable(t *testing.T) {
	gin.SetMode(gin.TestMode)
	if err := database.SetupTestDB(); err != nil {
		t.Fatalf("setup db: %v", err)
	}

	const (
		schoolID  = "school-ptm-create"
		yearID    = "year-ptm-create"
		teacherID = "staff-ptm-create"
		sectionID = "section-ptm-create"
		eventID   = "event-ptm-create"
	)
	now := time.Date(2026, 6, 25, 9, 0, 0, 0, time.UTC)
	seedTeacherPTMFixture(t, schoolID, yearID, teacherID, sectionID, eventID, now)

	router := teacherSelfTestRouter(schoolID, teacherID)
	resp := httptest.NewRecorder()
	req := httptest.NewRequest(
		http.MethodPost,
		"/teacher/ptm-slots",
		bytes.NewBufferString(`{"section_id":"`+sectionID+`","slot_date":"2026-06-26","slot_time":"16:00","duration_min":15}`),
	)
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(resp, req)

	if resp.Code != http.StatusCreated {
		t.Fatalf("POST /teacher/ptm-slots status=%d body=%s", resp.Code, resp.Body.String())
	}
	var saved models.ParentTeacherMeeting
	if err := database.DB.First(&saved, "teacher_id = ? AND section_id = ? AND slot_time = ?", teacherID, sectionID, "16:00").Error; err != nil {
		t.Fatalf("load created slot: %v", err)
	}
	if saved.EventID != eventID {
		t.Fatalf("event_id=%q, want %q", saved.EventID, eventID)
	}
}

func seedTeacherPTMFixture(t *testing.T, schoolID, yearID, teacherID, sectionID, eventID string, now time.Time) {
	t.Helper()
	deptID := schoolID + "-dept"
	gradeID := schoolID + "-grade"
	seeds := []any{
		&models.School{BaseModel: models.BaseModel{ID: schoolID}, Name: "PTM School", SchoolType: "cbse"},
		&models.AcademicYear{BaseModel: models.BaseModel{ID: yearID}, SchoolID: schoolID, YearLabel: "2026-2027", StartDate: now, EndDate: now.AddDate(1, 0, 0), IsCurrent: true, Status: "active"},
		&models.Department{BaseModel: models.BaseModel{ID: deptID}, SchoolID: schoolID, DepartmentName: "Academics"},
		&models.Grade{BaseModel: models.BaseModel{ID: gradeID}, SchoolID: schoolID, GradeNumber: 8, GradeName: "Grade 8"},
		&models.Staff{BaseModel: models.BaseModel{ID: teacherID}, SchoolID: schoolID, StaffCode: teacherID, FirstName: "PTM", LastName: "Teacher", Email: teacherID + "@example.test", DateOfBirth: now.AddDate(-30, 0, 0), Gender: "female", Designation: "Teacher", EmploymentType: "full-time", JoinDate: now.AddDate(-5, 0, 0), Status: "active"},
		&models.Section{BaseModel: models.BaseModel{ID: sectionID}, SchoolID: schoolID, GradeID: gradeID, AcademicYearID: yearID, SectionName: "A", ClassTeacherID: &teacherID, Capacity: 40},
	}
	for _, seed := range seeds {
		if err := database.DB.Create(seed).Error; err != nil {
			t.Fatalf("seed %T: %v", seed, err)
		}
	}
	eventRow := map[string]interface{}{
		"event_id": eventID, "school_id": schoolID, "academic_year_id": yearID,
		"event_name": "Parent-Teacher Meetings", "event_type": "PTM",
		"start_date": now.Format("2006-01-02"), "end_date": now.AddDate(0, 0, 30).Format("2006-01-02"),
		"organizer_id": teacherID, "status": "scheduled", "is_holiday": false,
	}
	if err := database.DB.Table("events").Create(eventRow).Error; err != nil {
		t.Fatalf("seed canonical event: %v", err)
	}
}

func teacherSelfTestRouter(schoolID, teacherID string) *gin.Engine {
	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", schoolID)
		c.Set("role_name", "Teacher")
		c.Set("linked_type", "staff")
		c.Set("linked_id", teacherID)
		c.Next()
	})
	handler := NewTeacherSelfHandler()
	router.GET("/teacher/ptm-slots", handler.GetMyPTMSlots)
	router.POST("/teacher/ptm-slots", handler.CreateMyPTMSlot)
	return router
}
