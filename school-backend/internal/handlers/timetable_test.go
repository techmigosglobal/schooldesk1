package handlers

import (
	"bytes"
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
	"github.com/stretchr/testify/assert"
	"gorm.io/gorm"
)

func TestCreateSubstitution(t *testing.T) {
	gin.SetMode(gin.TestMode)
	assert.NoError(t, database.SetupTestDB())
	now := time.Date(2026, 5, 16, 9, 0, 0, 0, time.UTC)
	school := models.School{BaseModel: models.BaseModel{ID: "school-substitution-test"}, Name: "Substitution School", SchoolType: "cbse"}
	year := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-substitution-test"}, SchoolID: school.ID, YearLabel: "2026-2027", StartDate: now, EndDate: now.AddDate(1, 0, 0), IsCurrent: true}
	term := models.Term{BaseModel: models.BaseModel{ID: "term-substitution-test"}, AcademicYearID: year.ID, TermNumber: 1, TermName: "Term 1", StartDate: now, EndDate: now.AddDate(0, 6, 0)}
	grade := models.Grade{BaseModel: models.BaseModel{ID: "grade-substitution-test"}, SchoolID: school.ID, GradeName: "Class 8", GradeNumber: 8}
	section := models.Section{BaseModel: models.BaseModel{ID: "section-substitution-test"}, GradeID: grade.ID, AcademicYearID: year.ID, SectionName: "A", Capacity: 40}
	department := models.Department{BaseModel: models.BaseModel{ID: "dept-substitution-test"}, SchoolID: school.ID, DepartmentName: "Academics"}
	subject := models.Subject{BaseModel: models.BaseModel{ID: "subject-substitution-test"}, SchoolID: school.ID, DepartmentID: department.ID, SubjectName: "Mathematics"}
	originalStaff := models.Staff{BaseModel: models.BaseModel{ID: "original-staff-id"}, SchoolID: school.ID, StaffCode: "SUB-1", FirstName: "Original", LastName: "Teacher", Status: "active"}
	substituteStaff := models.Staff{BaseModel: models.BaseModel{ID: "sub-staff-id"}, SchoolID: school.ID, StaffCode: "SUB-2", FirstName: "Substitute", LastName: "Teacher", Status: "active"}
	slot := models.TimetableSlot{BaseModel: models.BaseModel{ID: "test-slot-id"}, SectionID: section.ID, AcademicYearID: year.ID, TermID: term.ID, DayOfWeek: 2, PeriodNumber: 1, SubjectID: subject.ID, StaffID: originalStaff.ID, StartTime: mustTimetableTestClock(t, "09:00"), EndTime: mustTimetableTestClock(t, "09:40"), SlotType: "regular"}
	for _, seed := range []any{&school, &year, &term, &grade, &section, &department, &subject, &originalStaff, &substituteStaff, &slot} {
		assert.NoError(t, database.DB.Create(seed).Error)
	}

	reqBody := map[string]interface{}{
		"timetable_slot_id":   "test-slot-id",
		"date":                "2024-04-30",
		"original_staff_id":   "original-staff-id",
		"substitute_staff_id": "sub-staff-id",
		"reason":              "Sick leave",
		"approved_by":         "principal-id",
	}
	body, _ := json.Marshal(reqBody)

	req, _ := http.NewRequest("POST", "/timetable/substitutions", bytes.NewBuffer(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()

	r := gin.Default()
	r.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("role_name", "Admin")
		c.Set("user_id", "admin-substitution-test")
		c.Next()
	})
	r.POST("/timetable/substitutions", func(c *gin.Context) {
		h := NewTimetableHandler()
		h.CreateSubstitution(c)
	})

	r.ServeHTTP(w, req)

	assert.Equal(t, http.StatusCreated, w.Code)

	var response models.APIResponse
	json.Unmarshal(w.Body.Bytes(), &response)
	assert.True(t, response.Success)

	sub := response.Data.(map[string]interface{})
	assert.Equal(t, "test-slot-id", sub["timetable_slot_id"])
	assert.Equal(t, "2024-04-30T00:00:00Z", sub["date"])
}

func TestCreateTimetableSlotRejectsRoomOverlap(t *testing.T) {
	gin.SetMode(gin.TestMode)
	assert.NoError(t, database.SetupTestDB())
	now := time.Date(2026, 6, 1, 9, 0, 0, 0, time.UTC)
	school := models.School{BaseModel: models.BaseModel{ID: "school-room-overlap"}, Name: "Room Overlap School", SchoolType: "cbse"}
	year := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-room-overlap"}, SchoolID: school.ID, YearLabel: "2026-2027", StartDate: now, EndDate: now.AddDate(1, 0, 0), IsCurrent: true, Status: "active"}
	term := models.Term{BaseModel: models.BaseModel{ID: "term-room-overlap"}, AcademicYearID: year.ID, TermNumber: 1, TermName: "Term 1", StartDate: now, EndDate: now.AddDate(0, 6, 0), IsCurrent: true}
	gradeA := models.Grade{BaseModel: models.BaseModel{ID: "grade-room-a"}, SchoolID: school.ID, GradeName: "Class 5", GradeNumber: 5}
	gradeB := models.Grade{BaseModel: models.BaseModel{ID: "grade-room-b"}, SchoolID: school.ID, GradeName: "Class 6", GradeNumber: 6}
	room := models.Room{BaseModel: models.BaseModel{ID: "room-overlap"}, SchoolID: school.ID, RoomNumber: "101", RoomType: "classroom", Capacity: 40}
	sectionA := models.Section{BaseModel: models.BaseModel{ID: "section-room-a"}, SchoolID: school.ID, GradeID: gradeA.ID, AcademicYearID: year.ID, SectionName: "A", Capacity: 40}
	sectionB := models.Section{BaseModel: models.BaseModel{ID: "section-room-b"}, SchoolID: school.ID, GradeID: gradeB.ID, AcademicYearID: year.ID, SectionName: "A", Capacity: 40}
	department := models.Department{BaseModel: models.BaseModel{ID: "dept-room-overlap"}, SchoolID: school.ID, DepartmentName: "Academics"}
	subjectA := models.Subject{BaseModel: models.BaseModel{ID: "subject-room-a"}, SchoolID: school.ID, DepartmentID: department.ID, SubjectName: "Mathematics"}
	subjectB := models.Subject{BaseModel: models.BaseModel{ID: "subject-room-b"}, SchoolID: school.ID, DepartmentID: department.ID, SubjectName: "Science"}
	staffA := models.Staff{BaseModel: models.BaseModel{ID: "staff-room-a"}, SchoolID: school.ID, StaffCode: "R-A", FirstName: "A", LastName: "Teacher", Status: "active"}
	staffB := models.Staff{BaseModel: models.BaseModel{ID: "staff-room-b"}, SchoolID: school.ID, StaffCode: "R-B", FirstName: "B", LastName: "Teacher", Status: "active"}
	sectionAID := sectionA.ID
	sectionBID := sectionB.ID
	gradeSubjectA := models.GradeSubject{BaseModel: models.BaseModel{ID: "grade-subject-room-a"}, SchoolID: school.ID, AcademicYearID: year.ID, GradeID: gradeA.ID, SubjectID: subjectA.ID, PeriodsPerWeek: 5, IsMandatory: true}
	gradeSubjectB := models.GradeSubject{BaseModel: models.BaseModel{ID: "grade-subject-room-b"}, SchoolID: school.ID, AcademicYearID: year.ID, GradeID: gradeB.ID, SubjectID: subjectB.ID, PeriodsPerWeek: 5, IsMandatory: true}
	staffSubjectA := models.StaffSubject{BaseModel: models.BaseModel{ID: "staff-subject-room-a"}, SchoolID: school.ID, AcademicYearID: year.ID, StaffID: staffA.ID, SubjectID: subjectA.ID, GradeID: gradeA.ID, SectionID: &sectionAID, IsPrimary: true}
	staffSubjectB := models.StaffSubject{BaseModel: models.BaseModel{ID: "staff-subject-room-b"}, SchoolID: school.ID, AcademicYearID: year.ID, StaffID: staffB.ID, SubjectID: subjectB.ID, GradeID: gradeB.ID, SectionID: &sectionBID, IsPrimary: true}
	roomID := room.ID
	existing := models.TimetableSlot{BaseModel: models.BaseModel{ID: "slot-room-existing"}, SectionID: sectionA.ID, AcademicYearID: year.ID, TermID: term.ID, DayOfWeek: 1, PeriodNumber: 1, SubjectID: subjectA.ID, StaffID: staffA.ID, RoomID: &roomID, StartTime: mustTimetableTestClock(t, "09:00"), EndTime: mustTimetableTestClock(t, "09:40"), SlotType: "regular"}
	for _, seed := range []any{&school, &year, &term, &gradeA, &gradeB, &room, &sectionA, &sectionB, &department, &subjectA, &subjectB, &staffA, &staffB, &gradeSubjectA, &gradeSubjectB, &staffSubjectA, &staffSubjectB, &existing} {
		assert.NoError(t, database.DB.Create(seed).Error)
	}

	body, _ := json.Marshal(map[string]any{
		"section_id":       sectionB.ID,
		"academic_year_id": year.ID,
		"term_id":          term.ID,
		"day_of_week":      1,
		"period_number":    1,
		"subject_id":       subjectB.ID,
		"staff_id":         staffB.ID,
		"room_id":          room.ID,
		"start_time":       "09:00",
		"end_time":         "09:40",
	})
	req := httptest.NewRequest(http.MethodPost, "/timetable/slots", bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	w := httptest.NewRecorder()
	r := gin.New()
	r.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("role_name", "Admin")
		c.Set("user_id", "admin-room-overlap")
		c.Next()
	})
	r.POST("/timetable/slots", NewTimetableHandler().CreateTimetableSlot)
	r.ServeHTTP(w, req)

	if w.Code != http.StatusConflict {
		t.Fatalf("expected room conflict, status=%d body=%s", w.Code, w.Body.String())
	}
	if !strings.Contains(w.Body.String(), "room is already booked") {
		t.Fatalf("expected room conflict message, body=%s", w.Body.String())
	}
}

func TestSuggestAndGenerateTimetableSlotsUsesBackendRelationships(t *testing.T) {
	gin.SetMode(gin.TestMode)
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	database.DB = db
	if err := db.AutoMigrate(
		&models.School{},
		&models.AcademicYear{},
		&models.Term{},
		&models.Grade{},
		&models.Section{},
		&models.Department{},
		&models.Subject{},
		&models.GradeSubject{},
		&models.Staff{},
		&models.StaffSubject{},
		&models.Room{},
		&models.TimetableSlot{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	school := models.School{BaseModel: models.BaseModel{ID: "school-timetable"}, Name: "Timetable School", SchoolType: "cbse"}
	year := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-timetable"}, SchoolID: school.ID, YearLabel: "2026-2027", StartDate: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), EndDate: time.Date(2027, 3, 31, 0, 0, 0, 0, time.UTC), IsCurrent: true}
	term := models.Term{BaseModel: models.BaseModel{ID: "term-timetable"}, AcademicYearID: year.ID, TermNumber: 1, TermName: "Term 1", StartDate: year.StartDate, EndDate: year.EndDate, IsCurrent: true}
	grade := models.Grade{BaseModel: models.BaseModel{ID: "grade-timetable"}, SchoolID: school.ID, GradeName: "Class 5", GradeNumber: 5}
	room := models.Room{BaseModel: models.BaseModel{ID: "room-timetable"}, SchoolID: school.ID, RoomNumber: "5-A", RoomType: "classroom", Capacity: 40}
	roomID := room.ID
	section := models.Section{BaseModel: models.BaseModel{ID: "section-timetable"}, GradeID: grade.ID, AcademicYearID: year.ID, SectionName: "A", Capacity: 40, RoomID: &roomID}
	department := models.Department{BaseModel: models.BaseModel{ID: "dept-timetable"}, SchoolID: school.ID, DepartmentName: "Academics"}
	math := models.Subject{BaseModel: models.BaseModel{ID: "subject-math"}, SchoolID: school.ID, DepartmentID: department.ID, SubjectName: "Mathematics"}
	science := models.Subject{BaseModel: models.BaseModel{ID: "subject-science"}, SchoolID: school.ID, DepartmentID: department.ID, SubjectName: "Science"}
	mathTeacher := models.Staff{BaseModel: models.BaseModel{ID: "staff-math"}, SchoolID: school.ID, StaffCode: "T-MATH", FirstName: "Meera", LastName: "Math", Status: "active"}
	scienceTeacher := models.Staff{BaseModel: models.BaseModel{ID: "staff-science"}, SchoolID: school.ID, StaffCode: "T-SCI", FirstName: "Sanjay", LastName: "Science", Status: "active"}
	seeds := []any{&school, &year, &term, &grade, &room, &section, &department, &math, &science, &mathTeacher, &scienceTeacher}
	for _, seed := range seeds {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}
	for _, seed := range []any{
		&models.GradeSubject{BaseModel: models.BaseModel{ID: "grade-math"}, SchoolID: school.ID, AcademicYearID: year.ID, GradeID: grade.ID, SubjectID: math.ID, PeriodsPerWeek: 2, IsMandatory: true},
		&models.GradeSubject{BaseModel: models.BaseModel{ID: "grade-science"}, SchoolID: school.ID, AcademicYearID: year.ID, GradeID: grade.ID, SubjectID: science.ID, PeriodsPerWeek: 1, IsMandatory: true},
		&models.StaffSubject{BaseModel: models.BaseModel{ID: "staff-subject-math"}, SchoolID: school.ID, AcademicYearID: year.ID, StaffID: mathTeacher.ID, SubjectID: math.ID, GradeID: grade.ID, IsPrimary: true},
		&models.StaffSubject{BaseModel: models.BaseModel{ID: "staff-subject-science"}, SchoolID: school.ID, AcademicYearID: year.ID, StaffID: scienceTeacher.ID, SubjectID: science.ID, GradeID: grade.ID, IsPrimary: true},
	} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed relation: %v", err)
		}
	}

	router := gin.New()
	router.Use(func(c *gin.Context) {
		c.Set("school_id", school.ID)
		c.Set("user_id", "admin-timetable")
		c.Set("role_name", "Admin")
		c.Next()
	})
	handler := NewTimetableHandler()
	router.POST("/timetable/suggestions", handler.SuggestTimetableSlots)
	router.POST("/timetable/slots/generate", handler.GenerateTimetableSlots)

	payload := `{"section_id":"section-timetable","academic_year_id":"year-timetable","term_id":"term-timetable","day_of_week":1,"period_count":3,"start_time":"09:00","period_duration_minutes":40,"gap_minutes":5}`
	suggest := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, "/timetable/suggestions", strings.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(suggest, req)
	if suggest.Code != http.StatusOK {
		t.Fatalf("suggest status=%d body=%s", suggest.Code, suggest.Body.String())
	}
	var suggestionBody struct {
		Data struct {
			Suggestions []map[string]any `json:"suggestions"`
			Summary     struct {
				CreatablePeriods int `json:"creatable_periods"`
				BlockedPeriods   int `json:"blocked_periods"`
			} `json:"summary"`
		} `json:"data"`
	}
	if err := json.Unmarshal(suggest.Body.Bytes(), &suggestionBody); err != nil {
		t.Fatalf("decode suggestions: %v", err)
	}
	if len(suggestionBody.Data.Suggestions) != 3 || suggestionBody.Data.Summary.CreatablePeriods != 3 || suggestionBody.Data.Summary.BlockedPeriods != 0 {
		t.Fatalf("unexpected suggestion plan: %+v", suggestionBody.Data)
	}
	if suggestionBody.Data.Suggestions[0]["subject_id"] != math.ID || suggestionBody.Data.Suggestions[0]["staff_id"] != mathTeacher.ID {
		t.Fatalf("expected first suggestion to use math mapping, got %+v", suggestionBody.Data.Suggestions[0])
	}
	if suggestionBody.Data.Suggestions[0]["room_id"] != room.ID {
		t.Fatalf("expected first suggestion to use class room, got %+v", suggestionBody.Data.Suggestions[0])
	}

	generate := httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/timetable/slots/generate", strings.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(generate, req)
	if generate.Code != http.StatusCreated {
		t.Fatalf("generate status=%d body=%s", generate.Code, generate.Body.String())
	}
	var generatedBody struct {
		Data struct {
			Created int `json:"created"`
			Skipped int `json:"skipped"`
		} `json:"data"`
	}
	if err := json.Unmarshal(generate.Body.Bytes(), &generatedBody); err != nil {
		t.Fatalf("decode generate: %v", err)
	}
	if generatedBody.Data.Created != 3 || generatedBody.Data.Skipped != 0 {
		t.Fatalf("expected 3 created slots, got %+v", generatedBody.Data)
	}
	var slotCount int64
	db.Model(&models.TimetableSlot{}).Where("section_id = ?", section.ID).Count(&slotCount)
	if slotCount != 3 {
		t.Fatalf("expected generated slots in database, got %d", slotCount)
	}
	var roomSlotCount int64
	db.Model(&models.TimetableSlot{}).Where("section_id = ? AND room_id = ?", section.ID, room.ID).Count(&roomSlotCount)
	if roomSlotCount != 3 {
		t.Fatalf("expected generated slots to use class room, got %d", roomSlotCount)
	}

	duplicate := httptest.NewRecorder()
	req = httptest.NewRequest(http.MethodPost, "/timetable/slots/generate", strings.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	router.ServeHTTP(duplicate, req)
	if duplicate.Code != http.StatusCreated {
		t.Fatalf("duplicate status=%d body=%s", duplicate.Code, duplicate.Body.String())
	}
	if err := json.Unmarshal(duplicate.Body.Bytes(), &generatedBody); err != nil {
		t.Fatalf("decode duplicate: %v", err)
	}
	if generatedBody.Data.Created != 0 || generatedBody.Data.Skipped != 3 {
		t.Fatalf("expected duplicate generation to skip existing periods, got %+v", generatedBody.Data)
	}
}
