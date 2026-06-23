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
		&models.FeeConcession{},
		&models.FeeInvoice{},
		&models.TimetableSlot{},
		&models.Substitution{},
		&models.ExamType{},
		&models.Exam{},
		&models.ExamSchedule{},
		&models.StudentMark{},
		&models.ReportCard{},
		&models.StaffSubject{},
		&models.EventCalendar{},
		&models.ParentTeacherMeeting{},
		&models.Homework{},
		&models.HomeworkSubmission{},
		&models.DiaryEntry{},
		&models.FeeInvoiceItem{},
		&models.Payment{},
		&models.ParentPaymentRequest{},
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
	router.POST("/academic-years", handler.CreateAcademicYear)
	router.GET("/academic-years/:id/terms", handler.GetTerms)
	router.PUT("/academic-years/:id", handler.UpdateAcademicYear)
	router.DELETE("/academic-years/:id", handler.DeleteAcademicYear)
	router.DELETE("/subjects/:id", handler.DeleteSubject)
	router.DELETE("/sections/:id", handler.DeleteSection)
	router.DELETE("/grades/:id", handler.DeleteGrade)
	return router
}

func TestCreateAcademicYearCurrentDeactivatesExistingCurrentYear(t *testing.T) {
	db := setupAcademicDeleteDB(t)
	if err := db.Create(&models.AcademicYear{
		BaseModel: models.BaseModel{ID: "year-existing"},
		SchoolID:  "school-test",
		YearLabel: "2025-2026",
		Year:      "2025-2026",
		StartDate: mustParseAcademicDeleteDate(t, "2025-04-01"),
		EndDate:   mustParseAcademicDeleteDate(t, "2026-03-31"),
		IsCurrent: true,
		Status:    "active",
	}).Error; err != nil {
		t.Fatalf("create existing year: %v", err)
	}

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/academic-years", strings.NewReader(`{"year_label":"2026-2027","start_date":"2026-04-01","end_date":"2027-03-31","is_current":true}`)),
	)

	if response.Code != http.StatusCreated {
		t.Fatalf("create status = %d body=%s", response.Code, response.Body.String())
	}
	var currentCount int64
	db.Model(&models.AcademicYear{}).Where("school_id = ? AND is_current = ?", "school-test", true).Count(&currentCount)
	if currentCount != 1 {
		t.Fatalf("current year count = %d, want 1", currentCount)
	}
	var existing models.AcademicYear
	if err := db.First(&existing, "id = ?", "year-existing").Error; err != nil {
		t.Fatalf("reload existing year: %v", err)
	}
	if existing.IsCurrent {
		t.Fatalf("existing year should have been deactivated")
	}
}

func TestCreateAcademicYearCreatesDefaultTerm(t *testing.T) {
	db := setupAcademicDeleteDB(t)

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/academic-years", strings.NewReader(`{"year_label":"2026-2027","start_date":"2026-04-01","end_date":"2027-03-31","is_current":true}`)),
	)

	if response.Code != http.StatusCreated {
		t.Fatalf("create status = %d body=%s", response.Code, response.Body.String())
	}
	var terms []models.Term
	if err := db.Find(&terms).Error; err != nil {
		t.Fatalf("load terms: %v", err)
	}
	if len(terms) != 1 {
		t.Fatalf("term count = %d, want 1", len(terms))
	}
	term := terms[0]
	if term.TermName != "Term 1" || term.TermNumber != 1 || !term.IsCurrent {
		t.Fatalf("default term = %+v, want current Term 1", term)
	}
	if !sameAcademicDate(term.StartDate, mustParseAcademicDeleteDate(t, "2026-04-01")) ||
		!sameAcademicDate(term.EndDate, mustParseAcademicDeleteDate(t, "2027-03-31")) {
		t.Fatalf("term dates = %s - %s, want academic year range", term.StartDate, term.EndDate)
	}
}

func TestGetTermsRepairsTermlessAcademicYear(t *testing.T) {
	db := setupAcademicDeleteDB(t)
	year := models.AcademicYear{
		BaseModel: models.BaseModel{ID: "year-termless"},
		SchoolID:  "school-test",
		YearLabel: "2026-2027",
		Year:      "2026-2027",
		StartDate: mustParseAcademicDeleteDate(t, "2026-04-01"),
		EndDate:   mustParseAcademicDeleteDate(t, "2027-03-31"),
		IsCurrent: true,
		Status:    "active",
	}
	if err := db.Create(&year).Error; err != nil {
		t.Fatalf("seed year: %v", err)
	}

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodGet, "/academic-years/year-termless/terms", nil),
	)

	if response.Code != http.StatusOK {
		t.Fatalf("terms status = %d body=%s", response.Code, response.Body.String())
	}
	var termCount int64
	db.Model(&models.Term{}).Where("academic_year_id = ?", year.ID).Count(&termCount)
	if termCount != 1 {
		t.Fatalf("term count = %d, want 1", termCount)
	}
	if !strings.Contains(response.Body.String(), "Term 1") {
		t.Fatalf("terms response should include generated default term: %s", response.Body.String())
	}
}

func TestCreateAcademicYearRejectsInvalidDateRange(t *testing.T) {
	setupAcademicDeleteDB(t)

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodPost, "/academic-years", strings.NewReader(`{"year_label":"2026-2027","start_date":"2027-04-01","end_date":"2026-03-31","is_current":true}`)),
	)

	if response.Code != http.StatusBadRequest {
		t.Fatalf("create status = %d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "end_date cannot be before start_date") {
		t.Fatalf("create response should explain date range: %s", response.Body.String())
	}
}

func TestDeleteAcademicYearCascadesLinkedRecords(t *testing.T) {
	db := setupAcademicDeleteDB(t)
	year := models.AcademicYear{
		BaseModel: models.BaseModel{ID: "year-test"},
		SchoolID:  "school-test",
		YearLabel: "2026-2027",
		StartDate: mustParseAcademicDeleteDate(t, "2026-04-01"),
		EndDate:   mustParseAcademicDeleteDate(t, "2027-03-31"),
		Status:    "active",
	}
	term := models.Term{
		BaseModel:      models.BaseModel{ID: "term-test"},
		AcademicYearID: year.ID,
		TermNumber:     1,
		TermName:       "Term 1",
		StartDate:      year.StartDate,
		EndDate:        year.EndDate,
	}
	holiday := models.Holiday{
		BaseModel:      models.BaseModel{ID: "holiday-test"},
		SchoolID:       "school-test",
		AcademicYearID: year.ID,
		HolidayName:    "Founders Day",
		FromDate:       mustParseAcademicDeleteDate(t, "2026-07-01"),
		ToDate:         mustParseAcademicDeleteDate(t, "2026-07-01"),
	}
	department := models.Department{
		BaseModel:      models.BaseModel{ID: "dept-test"},
		SchoolID:       "school-test",
		DepartmentName: "Activities",
	}
	grade := models.Grade{
		BaseModel:   models.BaseModel{ID: "grade-test"},
		SchoolID:    "school-test",
		GradeNumber: 1,
		GradeName:   "Nursery",
	}
	subject := models.Subject{
		BaseModel:    models.BaseModel{ID: "subject-test"},
		SchoolID:     "school-test",
		DepartmentID: "dept-test",
		SubjectName:  "Activity",
	}
	section := models.Section{
		BaseModel:      models.BaseModel{ID: "section-test"},
		SchoolID:       "school-test",
		GradeID:        grade.ID,
		AcademicYearID: year.ID,
		SectionName:    "A",
	}
	student := models.Student{
		BaseModel:       models.BaseModel{ID: "student-test"},
		SchoolID:        "school-test",
		StudentCode:     "ST-001",
		AdmissionNumber: "ADM-001",
		FirstName:       "Asha",
		LastName:        "Rao",
		Status:          "active",
	}
	enrollment := models.Enrollment{
		BaseModel:      models.BaseModel{ID: "enrollment-test"},
		StudentID:      student.ID,
		SectionID:      section.ID,
		AcademicYearID: year.ID,
		Status:         "enrolled",
	}
	gradeSubject := models.GradeSubject{
		BaseModel:      models.BaseModel{ID: "grade-subject-test"},
		SchoolID:       "school-test",
		AcademicYearID: year.ID,
		GradeID:        grade.ID,
		SubjectID:      subject.ID,
	}
	staffSubject := models.StaffSubject{
		BaseModel:      models.BaseModel{ID: "staff-subject-test"},
		SchoolID:       "school-test",
		AcademicYearID: year.ID,
		StaffID:        "staff-test",
		SubjectID:      subject.ID,
		GradeID:        grade.ID,
		SectionID:      &section.ID,
	}
	slot := models.TimetableSlot{
		BaseModel:      models.BaseModel{ID: "slot-test"},
		SectionID:      section.ID,
		AcademicYearID: year.ID,
		TermID:         term.ID,
		DayOfWeek:      1,
		PeriodNumber:   1,
		SubjectID:      subject.ID,
		StaffID:        "staff-test",
	}
	substitution := models.Substitution{
		BaseModel:         models.BaseModel{ID: "substitution-test"},
		TimetableSlotID:   slot.ID,
		Date:              mustParseAcademicDeleteDate(t, "2026-08-01"),
		OriginalStaffID:   "staff-test",
		SubstituteStaffID: "staff-substitute",
	}
	session := models.AttendanceSession{
		BaseModel:       models.BaseModel{ID: "attendance-session-test"},
		SectionID:       section.ID,
		AcademicYearID:  year.ID,
		TimetableSlotID: &slot.ID,
		SubjectID:       subject.ID,
		StaffID:         "staff-test",
		Date:            mustParseAcademicDeleteDate(t, "2026-08-01"),
		PeriodNumber:    1,
		TotalStudents:   1,
	}
	attendance := models.StudentAttendance{
		BaseModel:    models.BaseModel{ID: "student-attendance-test"},
		SessionID:    session.ID,
		StudentID:    student.ID,
		EnrollmentID: enrollment.ID,
		Status:       "present",
	}
	summary := models.AttendanceSummary{
		BaseModel:      models.BaseModel{ID: "attendance-summary-test"},
		StudentID:      student.ID,
		SectionID:      section.ID,
		AcademicYearID: year.ID,
		TermID:         &term.ID,
	}
	feeStructure := models.FeeStructure{
		BaseModel:        models.BaseModel{ID: "fee-structure-test"},
		SchoolID:         "school-test",
		AcademicYearID:   year.ID,
		GradeID:          grade.ID,
		FeeCategoryID:    "fee-category-test",
		Amount:           1000,
		InstallmentCount: 1,
	}
	invoice := models.FeeInvoice{
		BaseModel:      models.BaseModel{ID: "fee-invoice-test"},
		StudentID:      student.ID,
		AcademicYearID: year.ID,
		TermID:         &term.ID,
		InvoiceNumber:  "INV-YEAR-TEST",
		InvoiceDate:    year.StartDate,
		DueDate:        year.StartDate.AddDate(0, 1, 0),
		TotalAmount:    1000,
		PayableAmount:  1000,
		Balance:        1000,
	}
	invoiceItem := models.FeeInvoiceItem{
		BaseModel:     models.BaseModel{ID: "fee-invoice-item-test"},
		InvoiceID:     invoice.ID,
		FeeCategoryID: "fee-category-test",
		Amount:        1000,
	}
	examType := models.ExamType{
		BaseModel: models.BaseModel{ID: "exam-type-test"},
		SchoolID:  "school-test",
		Name:      "Midterm",
	}
	exam := models.Exam{
		BaseModel:      models.BaseModel{ID: "exam-test"},
		SchoolID:       "school-test",
		AcademicYearID: year.ID,
		TermID:         term.ID,
		ExamTypeID:     examType.ID,
		ExamName:       "Midterm",
		StartDate:      mustParseAcademicDeleteDate(t, "2026-08-01"),
		EndDate:        mustParseAcademicDeleteDate(t, "2026-08-03"),
	}
	schedule := models.ExamSchedule{
		BaseModel: models.BaseModel{ID: "exam-schedule-test"},
		ExamID:    exam.ID,
		GradeID:   grade.ID,
		SectionID: section.ID,
		SubjectID: subject.ID,
		ExamDate:  mustParseAcademicDeleteDate(t, "2026-08-01"),
	}
	mark := models.StudentMark{
		BaseModel:      models.BaseModel{ID: "student-mark-test"},
		ExamScheduleID: schedule.ID,
		StudentID:      student.ID,
		EnrollmentID:   enrollment.ID,
		MarksObtained:  85,
	}
	reportCard := models.ReportCard{
		BaseModel:    models.BaseModel{ID: "report-card-test"},
		StudentID:    student.ID,
		ExamID:       exam.ID,
		EnrollmentID: enrollment.ID,
		Percentage:   85,
	}
	event := models.EventCalendar{
		BaseModel:      models.BaseModel{ID: "event-test"},
		SchoolID:       "school-test",
		AcademicYearID: year.ID,
		EventTitle:     "PTM",
		EventType:      "meeting",
		StartDatetime:  mustParseAcademicDeleteDate(t, "2026-09-01"),
		EndDatetime:    mustParseAcademicDeleteDate(t, "2026-09-01"),
		CreatedBy:      "principal-user",
	}
	ptm := models.ParentTeacherMeeting{
		BaseModel:  models.BaseModel{ID: "ptm-test"},
		EventID:    event.ID,
		SectionID:  section.ID,
		SlotDate:   mustParseAcademicDeleteDate(t, "2026-09-01"),
		TeacherID:  "staff-test",
		GuardianID: "guardian-test",
		StudentID:  student.ID,
	}
	homework := models.Homework{
		BaseModel: models.BaseModel{ID: "homework-test"},
		SchoolID:  "school-test",
		Title:     "Practice",
		SectionID: section.ID,
		TeacherID: "staff-test",
	}
	submission := models.HomeworkSubmission{
		BaseModel:    models.BaseModel{ID: "homework-submission-test"},
		SchoolID:     "school-test",
		HomeworkID:   homework.ID,
		StudentID:    student.ID,
		ParentUserID: "parent-test",
	}
	diary := models.DiaryEntry{
		BaseModel: models.BaseModel{ID: "diary-test"},
		SchoolID:  "school-test",
		SectionID: section.ID,
		Title:     "Class notes",
	}
	for _, seed := range []any{
		&year, &term, &holiday, &department, &grade, &subject, &section, &student, &enrollment,
		&gradeSubject, &staffSubject, &slot, &substitution, &session, &attendance,
		&summary, &feeStructure, &invoice, &invoiceItem, &examType, &exam, &schedule,
		&mark, &reportCard, &event, &ptm, &homework, &submission, &diary,
	} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/academic-years/year-test?cascade=true", nil),
	)

	if response.Code != http.StatusOK {
		t.Fatalf("delete status = %d body=%s", response.Code, response.Body.String())
	}
	assertNoAcademicDeleteRows(t, db, &models.AcademicYear{}, "id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.Term{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.Holiday{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.Section{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.Enrollment{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.GradeSubject{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.StaffSubject{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.TimetableSlot{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.Substitution{}, "timetable_slot_id = ?", slot.ID)
	assertNoAcademicDeleteRows(t, db, &models.AttendanceSession{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.StudentAttendance{}, "session_id = ?", session.ID)
	assertNoAcademicDeleteRows(t, db, &models.AttendanceSummary{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.FeeStructure{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.FeeInvoice{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.FeeInvoiceItem{}, "invoice_id = ?", invoice.ID)
	assertNoAcademicDeleteRows(t, db, &models.Exam{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.ExamSchedule{}, "exam_id = ?", exam.ID)
	assertNoAcademicDeleteRows(t, db, &models.StudentMark{}, "exam_schedule_id = ?", schedule.ID)
	assertNoAcademicDeleteRows(t, db, &models.ReportCard{}, "exam_id = ?", exam.ID)
	assertNoAcademicDeleteRows(t, db, &models.EventCalendar{}, "academic_year_id = ?", year.ID)
	assertNoAcademicDeleteRows(t, db, &models.ParentTeacherMeeting{}, "event_id = ?", event.ID)
	assertNoAcademicDeleteRows(t, db, &models.Homework{}, "section_id = ?", section.ID)
	assertNoAcademicDeleteRows(t, db, &models.HomeworkSubmission{}, "homework_id = ?", homework.ID)
	assertNoAcademicDeleteRows(t, db, &models.DiaryEntry{}, "section_id = ?", section.ID)
}

func TestDeleteAcademicYearRequiresCascadeConfirmationForLinks(t *testing.T) {
	db := setupAcademicDeleteDB(t)
	year := models.AcademicYear{
		BaseModel: models.BaseModel{ID: "year-linked"},
		SchoolID:  "school-test",
		YearLabel: "2026-2027",
		StartDate: mustParseAcademicDeleteDate(t, "2026-04-01"),
		EndDate:   mustParseAcademicDeleteDate(t, "2027-03-31"),
		Status:    "active",
	}
	term := models.Term{
		BaseModel:      models.BaseModel{ID: "term-linked"},
		AcademicYearID: year.ID,
		TermNumber:     1,
		TermName:       "Term 1",
		StartDate:      year.StartDate,
		EndDate:        year.EndDate,
	}
	for _, seed := range []any{&year, &term} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/academic-years/year-linked", nil),
	)

	if response.Code != http.StatusConflict {
		t.Fatalf("delete status = %d body=%s", response.Code, response.Body.String())
	}
	if !strings.Contains(response.Body.String(), "Cascade confirmation") {
		t.Fatalf("delete response should require cascade confirmation: %s", response.Body.String())
	}
	var count int64
	db.Model(&models.AcademicYear{}).Where("id = ?", year.ID).Count(&count)
	if count != 1 {
		t.Fatalf("year should remain without cascade confirmation")
	}
}

func TestDeleteCurrentAcademicYearPromotesLatestRemainingYear(t *testing.T) {
	db := setupAcademicDeleteDB(t)
	current := models.AcademicYear{
		BaseModel: models.BaseModel{ID: "year-current"},
		SchoolID:  "school-test",
		YearLabel: "2026-2027",
		StartDate: mustParseAcademicDeleteDate(t, "2026-04-01"),
		EndDate:   mustParseAcademicDeleteDate(t, "2027-03-31"),
		IsCurrent: true,
		Status:    "active",
	}
	remaining := models.AcademicYear{
		BaseModel: models.BaseModel{ID: "year-remaining"},
		SchoolID:  "school-test",
		YearLabel: "2027-2028",
		StartDate: mustParseAcademicDeleteDate(t, "2027-04-01"),
		EndDate:   mustParseAcademicDeleteDate(t, "2028-03-31"),
		Status:    "active",
	}
	for _, seed := range []any{&current, &remaining} {
		if err := db.Create(seed).Error; err != nil {
			t.Fatalf("seed: %v", err)
		}
	}

	response := httptest.NewRecorder()
	academicDeleteRouter().ServeHTTP(
		response,
		httptest.NewRequest(http.MethodDelete, "/academic-years/year-current", nil),
	)

	if response.Code != http.StatusOK {
		t.Fatalf("delete status = %d body=%s", response.Code, response.Body.String())
	}
	var promoted models.AcademicYear
	if err := db.First(&promoted, "id = ?", "year-remaining").Error; err != nil {
		t.Fatalf("load remaining year: %v", err)
	}
	if !promoted.IsCurrent {
		t.Fatalf("remaining year should be promoted to current")
	}
}

func sameAcademicDate(a, b time.Time) bool {
	return a.Year() == b.Year() && a.Month() == b.Month() && a.Day() == b.Day()
}

func assertNoAcademicDeleteRows(t *testing.T, db *gorm.DB, model interface{}, query string, args ...interface{}) {
	t.Helper()
	var count int64
	if err := db.Model(model).Where(query, args...).Count(&count).Error; err != nil {
		t.Fatalf("count rows: %v", err)
	}
	if count != 0 {
		t.Fatalf("%T count = %d, want 0", model, count)
	}
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
		BaseModel:      models.BaseModel{ID: "attendance-session-test"},
		SectionID:      "section-test",
		AcademicYearID: "year-test",
		SubjectID:      "subject-test",
		StaffID:        "staff-test",
		Date:           mustParseAcademicDeleteDate(t, "2026-05-27"),
		PeriodNumber:   1,
		TotalStudents:  1,
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
