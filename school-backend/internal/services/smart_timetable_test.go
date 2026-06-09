package services

import (
	"context"
	"testing"
	"time"

	"school-backend/internal/models"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

func TestSmartTimetableGenerateRegenerateScopeDeletesExistingSlotsSafely(t *testing.T) {
	db, err := gorm.Open(sqlite.Open(":memory:"), &gorm.Config{})
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
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
		&models.TimetableGenerationJob{},
		&models.TimetableGenerationLog{},
	); err != nil {
		t.Fatalf("migrate: %v", err)
	}

	start := time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC)
	school := models.School{BaseModel: models.BaseModel{ID: "school-smart-regenerate"}, Name: "Smart School", SchoolType: "private"}
	year := models.AcademicYear{BaseModel: models.BaseModel{ID: "year-smart-regenerate"}, SchoolID: school.ID, YearLabel: "2026-2027", StartDate: start, EndDate: start.AddDate(1, 0, -1), IsCurrent: true}
	term := models.Term{BaseModel: models.BaseModel{ID: "term-smart-regenerate"}, AcademicYearID: year.ID, TermNumber: 1, TermName: "Term 1", StartDate: start, EndDate: start.AddDate(0, 6, 0), IsCurrent: true}
	grade := models.Grade{BaseModel: models.BaseModel{ID: "grade-smart-regenerate"}, SchoolID: school.ID, GradeNumber: 1, GradeName: "Play Group"}
	teacherID := "staff-smart-regenerate"
	section := models.Section{BaseModel: models.BaseModel{ID: "section-smart-regenerate"}, SchoolID: school.ID, GradeID: grade.ID, AcademicYearID: year.ID, SectionName: "A", Capacity: 20, ClassTeacherID: &teacherID}
	department := models.Department{BaseModel: models.BaseModel{ID: "dept-smart-regenerate"}, SchoolID: school.ID, DepartmentName: "Academics"}
	subject := models.Subject{BaseModel: models.BaseModel{ID: "subject-smart-regenerate"}, SchoolID: school.ID, DepartmentID: department.ID, SubjectName: "Mathematics", SubjectCode: "MATH", SubjectType: "core"}
	teacher := models.Staff{BaseModel: models.BaseModel{ID: teacherID}, SchoolID: school.ID, StaffCode: "TE-101", FirstName: "Teacher", LastName: "TE-101", Status: "active"}
	existingStart := smartTimetableTestClock(t, "09:00")
	existingEnd := smartTimetableTestClock(t, "09:40")
	seeds := []any{
		&school, &year, &term, &grade, &section, &department, &subject, &teacher,
		&models.GradeSubject{BaseModel: models.BaseModel{ID: "grade-subject-smart-regenerate"}, SchoolID: school.ID, AcademicYearID: year.ID, GradeID: grade.ID, SubjectID: subject.ID, PeriodsPerWeek: 5, IsMandatory: true},
		&models.StaffSubject{BaseModel: models.BaseModel{ID: "staff-subject-smart-regenerate"}, SchoolID: school.ID, AcademicYearID: year.ID, StaffID: teacher.ID, SubjectID: subject.ID, GradeID: grade.ID, SectionID: &section.ID, IsPrimary: true},
		&models.TimetableSlot{BaseModel: models.BaseModel{ID: "old-slot-smart-regenerate"}, SectionID: section.ID, AcademicYearID: year.ID, TermID: term.ID, DayOfWeek: 1, PeriodNumber: 1, SubjectID: subject.ID, StaffID: teacher.ID, StartTime: existingStart, EndTime: existingEnd, SlotType: "regular"},
	}
	for _, seed := range seeds {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}

	result, err := NewSmartTimetableEngine(db).Generate(context.Background(), school.ID, "principal-smart", "Principal", SmartTimetableRequest{
		SectionID:             section.ID,
		AcademicYearID:        year.ID,
		TermID:                term.ID,
		Mode:                  "regenerate_scope",
		Days:                  []int{1},
		PeriodsPerDay:         2,
		StartTime:             "09:00",
		PeriodDurationMinutes: 40,
		GapMinutes:            5,
		Breaks: []map[string]interface{}{
			{"label": "Lunch Break", "days": []int{1}, "periods": []int{2}, "start_time": "10:30", "end_time": "10:45"},
		},
		RegenerateScope: true,
	})
	if err != nil {
		t.Fatalf("generate failed: %v", err)
	}
	if result.Summary.CreatedSlots != 2 {
		t.Fatalf("created slots = %d, want 2", result.Summary.CreatedSlots)
	}
	if result.Summary.ReservedBreaks != 1 {
		t.Fatalf("reserved breaks = %d, want 1", result.Summary.ReservedBreaks)
	}
	var oldCount int64
	if err := db.Model(&models.TimetableSlot{}).Where("id = ?", "old-slot-smart-regenerate").Count(&oldCount).Error; err != nil {
		t.Fatalf("count old slot: %v", err)
	}
	if oldCount != 0 {
		t.Fatalf("old scoped slot was not deleted")
	}
	var breakSlot models.TimetableSlot
	if err := db.First(&breakSlot, "section_id = ? AND day_of_week = ? AND period_number = ?", section.ID, 1, 2).Error; err != nil {
		t.Fatalf("load break slot: %v", err)
	}
	if breakSlot.SlotType != "break:Lunch Break" {
		t.Fatalf("break slot type = %q, want break:Lunch Break", breakSlot.SlotType)
	}
	if breakSlot.StaffID != "" || breakSlot.RoomID != nil {
		t.Fatalf("break slot should not reserve staff or room, got staff=%q room=%v", breakSlot.StaffID, breakSlot.RoomID)
	}
	if breakSlot.StartTime == nil || breakSlot.StartTime.Format("15:04") != "10:30" {
		t.Fatalf("break start time = %v, want 10:30", breakSlot.StartTime)
	}
	if breakSlot.EndTime == nil || breakSlot.EndTime.Format("15:04") != "10:45" {
		t.Fatalf("break end time = %v, want 10:45", breakSlot.EndTime)
	}
}

func smartTimetableTestClock(t *testing.T, value string) *time.Time {
	t.Helper()
	parsed, err := time.Parse("15:04", value)
	if err != nil {
		t.Fatalf("parse clock: %v", err)
	}
	clock := time.Date(2000, 1, 1, parsed.Hour(), parsed.Minute(), 0, 0, time.UTC)
	return &clock
}
