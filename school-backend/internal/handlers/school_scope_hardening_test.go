package handlers

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
)

type schoolScopeFixture struct {
	relationshipFixture
	currentExamID           string
	currentExamScheduleID   string
	currentReportCardID     string
	currentLeaveTypeID      string
	currentLeaveApplication string
	currentLeaveBalanceID   string
	externalSchoolID        string
	externalYearID          string
	externalTermID          string
	externalGradeID         string
	externalSectionID       string
	externalSubjectID       string
	externalStaffID         string
	externalStudentID       string
	externalEnrollmentID    string
	externalExamID          string
	externalExamScheduleID  string
	externalReportCardID    string
	externalLeaveTypeID     string
	externalLeaveAppID      string
	externalLeaveBalanceID  string
	externalTimetableSlotID string
}

func setupSchoolScopeFixture(t *testing.T) schoolScopeFixture {
	t.Helper()
	base := setupRelationshipPolicyFixture(t)
	now := time.Date(2026, 5, 16, 9, 0, 0, 0, time.UTC)
	f := schoolScopeFixture{
		relationshipFixture:     base,
		currentExamID:           "exam-scope-current",
		currentExamScheduleID:   "schedule-scope-current",
		currentReportCardID:     "report-scope-current",
		currentLeaveTypeID:      "leave-type-scope-current",
		currentLeaveApplication: "leave-application-scope-current",
		currentLeaveBalanceID:   "leave-balance-scope-current",
		externalSchoolID:        "school-scope-other",
		externalYearID:          "year-scope-other",
		externalTermID:          "term-scope-other",
		externalGradeID:         "grade-scope-other",
		externalSectionID:       "section-scope-other",
		externalSubjectID:       "subject-scope-other",
		externalStaffID:         "staff-scope-other",
		externalStudentID:       "student-scope-other",
		externalEnrollmentID:    "enrollment-scope-other",
		externalExamID:          "exam-scope-other",
		externalExamScheduleID:  "schedule-scope-other",
		externalReportCardID:    "report-scope-other",
		externalLeaveTypeID:     "leave-type-scope-other",
		externalLeaveAppID:      "leave-application-scope-other",
		externalLeaveBalanceID:  "leave-balance-scope-other",
		externalTimetableSlotID: "slot-scope-other",
	}
	otherDeptID := "dept-scope-other"
	otherExamTypeID := "exam-type-scope-other"
	currentExamTypeID := "exam-type-scope-current"
	currentOtherLeaveID := "leave-application-scope-current-other-staff"
	currentOtherBalanceID := "leave-balance-scope-current-other-staff"

	currentExamType := models.ExamType{BaseModel: models.BaseModel{ID: currentExamTypeID}, SchoolID: f.schoolID, Name: "Current Unit Test", WeightagePercent: 10}
	currentExam := models.Exam{BaseModel: models.BaseModel{ID: f.currentExamID}, SchoolID: f.schoolID, AcademicYearID: f.yearID, TermID: f.termID, ExamTypeID: currentExamType.ID, ExamName: "Current Exam", StartDate: now, EndDate: now.AddDate(0, 0, 1), IsPublished: true}
	currentSchedule := models.ExamSchedule{BaseModel: models.BaseModel{ID: f.currentExamScheduleID}, ExamID: currentExam.ID, GradeID: "grade-policy", SectionID: f.sectionID, SubjectID: f.subjectID, ExamDate: now, MaxMarks: 100, PassMarks: 35}
	currentReport := models.ReportCard{BaseModel: models.BaseModel{ID: f.currentReportCardID}, StudentID: f.studentID, EnrollmentID: f.enrollmentID, ExamID: currentExam.ID, TotalObtained: 89, Percentage: 89, OverallGrade: "A", PublishedAt: now}
	currentGradeA := models.GradingScale{BaseModel: models.BaseModel{ID: "grade-scale-scope-a"}, SchoolID: f.schoolID, GradeLabel: "A", MinPercent: 80, MaxPercent: 100, GPAPoints: 4}
	currentLeaveType := models.LeaveType{BaseModel: models.BaseModel{ID: f.currentLeaveTypeID}, SchoolID: f.schoolID, LeaveName: "Current Sick Leave", MaxDaysPerYear: 12, IsPaid: true, ApplicableTo: "teaching"}
	currentLeave := models.LeaveApplication{BaseModel: models.BaseModel{ID: f.currentLeaveApplication}, StaffID: f.teacherStaffID, LeaveTypeID: currentLeaveType.ID, FromDate: now, ToDate: now, TotalDays: 1, Reason: "Fever", Status: "pending", AppliedAt: now}
	currentOtherLeave := models.LeaveApplication{BaseModel: models.BaseModel{ID: currentOtherLeaveID}, StaffID: f.otherStaffID, LeaveTypeID: currentLeaveType.ID, FromDate: now, ToDate: now, TotalDays: 1, Reason: "Training", Status: "pending", AppliedAt: now}
	currentBalance := models.LeaveBalance{BaseModel: models.BaseModel{ID: f.currentLeaveBalanceID}, StaffID: f.teacherStaffID, LeaveTypeID: currentLeaveType.ID, AcademicYearID: f.yearID, TotalEntitled: 12, RemainingDays: 12}
	currentOtherBalance := models.LeaveBalance{BaseModel: models.BaseModel{ID: currentOtherBalanceID}, StaffID: f.otherStaffID, LeaveTypeID: currentLeaveType.ID, AcademicYearID: f.yearID, TotalEntitled: 12, RemainingDays: 12}

	otherSchool := models.School{BaseModel: models.BaseModel{ID: f.externalSchoolID}, Name: "Other School", SchoolType: "cbse"}
	otherYear := models.AcademicYear{BaseModel: models.BaseModel{ID: f.externalYearID}, SchoolID: otherSchool.ID, YearLabel: "2026-2027", StartDate: now, EndDate: now.AddDate(1, 0, 0), IsCurrent: true, Status: "active"}
	otherTerm := models.Term{BaseModel: models.BaseModel{ID: f.externalTermID}, AcademicYearID: otherYear.ID, TermNumber: 1, TermName: "Other Term", StartDate: now, EndDate: now.AddDate(0, 6, 0), IsCurrent: true}
	otherDept := models.Department{BaseModel: models.BaseModel{ID: otherDeptID}, SchoolID: otherSchool.ID, DepartmentName: "Other Academics"}
	otherGrade := models.Grade{BaseModel: models.BaseModel{ID: f.externalGradeID}, SchoolID: otherSchool.ID, GradeNumber: 9, GradeName: "Other Grade"}
	otherSection := models.Section{BaseModel: models.BaseModel{ID: f.externalSectionID}, GradeID: otherGrade.ID, AcademicYearID: otherYear.ID, SectionName: "O", Capacity: 40}
	otherSubject := models.Subject{BaseModel: models.BaseModel{ID: f.externalSubjectID}, SchoolID: otherSchool.ID, DepartmentID: otherDept.ID, SubjectName: "Other Maths", SubjectCode: "OMATH"}
	otherStaff := models.Staff{BaseModel: models.BaseModel{ID: f.externalStaffID}, SchoolID: otherSchool.ID, StaffCode: "OTHER-SCOPE", FirstName: "Other", LastName: "Teacher", Email: "other.scope@test.local", Status: "active"}
	otherStudentSection := f.externalSectionID
	otherStudent := models.Student{BaseModel: models.BaseModel{ID: f.externalStudentID}, SchoolID: otherSchool.ID, StudentCode: "SCOPE-OTHER", AdmissionNumber: "ADM-SCOPE-OTHER", FirstName: "Other", LastName: "Student", DateOfBirth: now.AddDate(-10, 0, 0), Gender: "female", AdmissionDate: now, CurrentSectionID: &otherStudentSection, Status: "active"}
	otherEnrollment := models.Enrollment{BaseModel: models.BaseModel{ID: f.externalEnrollmentID}, StudentID: otherStudent.ID, SectionID: otherSection.ID, AcademicYearID: otherYear.ID, RollNumber: "9", EnrollmentDate: now, Status: "enrolled"}
	otherExamType := models.ExamType{BaseModel: models.BaseModel{ID: otherExamTypeID}, SchoolID: otherSchool.ID, Name: "Other Unit Test", WeightagePercent: 10}
	otherExam := models.Exam{BaseModel: models.BaseModel{ID: f.externalExamID}, SchoolID: otherSchool.ID, AcademicYearID: otherYear.ID, TermID: otherTerm.ID, ExamTypeID: otherExamType.ID, ExamName: "Other Exam", StartDate: now, EndDate: now.AddDate(0, 0, 1), IsPublished: true}
	otherSchedule := models.ExamSchedule{BaseModel: models.BaseModel{ID: f.externalExamScheduleID}, ExamID: otherExam.ID, GradeID: otherGrade.ID, SectionID: otherSection.ID, SubjectID: otherSubject.ID, ExamDate: now, MaxMarks: 100, PassMarks: 35}
	otherReport := models.ReportCard{BaseModel: models.BaseModel{ID: f.externalReportCardID}, StudentID: otherStudent.ID, EnrollmentID: otherEnrollment.ID, ExamID: otherExam.ID, TotalObtained: 91, Percentage: 91, OverallGrade: "A", PublishedAt: now}
	otherLeaveType := models.LeaveType{BaseModel: models.BaseModel{ID: f.externalLeaveTypeID}, SchoolID: otherSchool.ID, LeaveName: "Other Sick Leave", MaxDaysPerYear: 12, IsPaid: true, ApplicableTo: "teaching"}
	otherLeave := models.LeaveApplication{BaseModel: models.BaseModel{ID: f.externalLeaveAppID}, StaffID: otherStaff.ID, LeaveTypeID: otherLeaveType.ID, FromDate: now, ToDate: now, TotalDays: 1, Reason: "Other", Status: "pending", AppliedAt: now}
	otherBalance := models.LeaveBalance{BaseModel: models.BaseModel{ID: f.externalLeaveBalanceID}, StaffID: otherStaff.ID, LeaveTypeID: otherLeaveType.ID, AcademicYearID: otherYear.ID, TotalEntitled: 12, RemainingDays: 12}
	otherSlot := models.TimetableSlot{BaseModel: models.BaseModel{ID: f.externalTimetableSlotID}, SectionID: otherSection.ID, AcademicYearID: otherYear.ID, TermID: otherTerm.ID, DayOfWeek: 3, PeriodNumber: 1, SubjectID: otherSubject.ID, StaffID: otherStaff.ID, StartTime: mustTimetableTestClock(t, "09:00"), EndTime: mustTimetableTestClock(t, "09:40"), SlotType: "regular"}

	for _, seed := range []any{
		&currentExamType, &currentExam, &currentSchedule, &currentReport, &currentGradeA, &currentLeaveType, &currentLeave, &currentOtherLeave, &currentBalance, &currentOtherBalance,
		&otherSchool, &otherYear, &otherTerm, &otherDept, &otherGrade, &otherSection, &otherSubject, &otherStaff, &otherStudent, &otherEnrollment, &otherExamType, &otherExam, &otherSchedule, &otherReport, &otherLeaveType, &otherLeave, &otherBalance, &otherSlot,
	} {
		if err := database.DB.Create(seed).Error; err != nil {
			t.Fatalf("seed %T: %v", seed, err)
		}
	}
	return f
}

func TestSchoolAcademicAndTermReadsAreSchoolScoped(t *testing.T) {
	f := setupSchoolScopeFixture(t)
	router := scopedPolicyRouter("Admin", "user-policy-admin", "", "", "admin@policy.test", f.schoolID)
	schoolHandler := NewSchoolHandler()
	router.GET("/schools", schoolHandler.GetSchools)
	router.GET("/schools/:id", schoolHandler.GetSchool)
	router.GET("/academic-years/:id", schoolHandler.GetAcademicYear)
	router.GET("/academic-years/:id/terms", schoolHandler.GetTerms)
	router.GET("/grades/:id", schoolHandler.GetGrade)
	termCRUD := NewCRUDHandler[models.Term]("terms", "terms", []string{"academic_year_id", "term_number", "term_name"}, false, "AcademicYear")
	router.GET("/terms", termCRUD.List)
	router.GET("/terms/:id", termCRUD.Get)

	listSchools := httptest.NewRecorder()
	router.ServeHTTP(listSchools, httptest.NewRequest(http.MethodGet, "/schools", nil))
	if listSchools.Code != http.StatusOK {
		t.Fatalf("schools status=%d body=%s", listSchools.Code, listSchools.Body.String())
	}
	schools := decodePolicyList(t, listSchools.Body.String())
	if len(schools) != 1 || schools[0]["id"] != f.schoolID {
		t.Fatalf("expected only scoped school, got %v", schools)
	}

	for _, tc := range []struct {
		path string
		name string
	}{
		{"/schools/" + f.externalSchoolID, "other school"},
		{"/academic-years/" + f.externalYearID, "other academic year"},
		{"/academic-years/" + f.externalYearID + "/terms", "other academic year terms"},
		{"/grades/" + f.externalGradeID, "other grade"},
		{"/terms/" + f.externalTermID, "compat other term"},
	} {
		resp := httptest.NewRecorder()
		router.ServeHTTP(resp, httptest.NewRequest(http.MethodGet, tc.path, nil))
		if resp.Code != http.StatusNotFound {
			t.Fatalf("%s should be hidden, status=%d body=%s", tc.name, resp.Code, resp.Body.String())
		}
	}

	listTerms := httptest.NewRecorder()
	router.ServeHTTP(listTerms, httptest.NewRequest(http.MethodGet, "/terms", nil))
	if listTerms.Code != http.StatusOK {
		t.Fatalf("terms status=%d body=%s", listTerms.Code, listTerms.Body.String())
	}
	terms := decodePolicyList(t, listTerms.Body.String())
	for _, row := range terms {
		if row["id"] == f.externalTermID || row["academic_year_id"] == f.externalYearID {
			t.Fatalf("compat terms leaked other school term: %v", terms)
		}
	}
}

func TestExamReportAndTimetableReadsAreSchoolScoped(t *testing.T) {
	f := setupSchoolScopeFixture(t)
	adminRouter := scopedPolicyRouter("Admin", "user-policy-admin", "", "", "admin@policy.test", f.schoolID)
	examHandler := NewExamHandler()
	timetableHandler := NewTimetableHandler()
	adminRouter.GET("/exams/report-cards", examHandler.GetReportCards)
	adminRouter.GET("/exams/:id", examHandler.GetExam)
	adminRouter.GET("/timetable/section/:section_id", timetableHandler.GetTimetableBySection)

	otherExam := httptest.NewRecorder()
	adminRouter.ServeHTTP(otherExam, httptest.NewRequest(http.MethodGet, "/exams/"+f.externalExamID, nil))
	if otherExam.Code != http.StatusNotFound {
		t.Fatalf("other exam should be hidden, status=%d body=%s", otherExam.Code, otherExam.Body.String())
	}

	reportCards := httptest.NewRecorder()
	adminRouter.ServeHTTP(reportCards, httptest.NewRequest(http.MethodGet, "/exams/report-cards", nil))
	if reportCards.Code != http.StatusOK {
		t.Fatalf("report cards status=%d body=%s", reportCards.Code, reportCards.Body.String())
	}
	rows := decodePolicyList(t, reportCards.Body.String())
	if len(rows) != 1 || rows[0]["id"] != f.currentReportCardID {
		t.Fatalf("report cards should include only current school, rows=%v", rows)
	}

	otherSectionTimetable := httptest.NewRecorder()
	adminRouter.ServeHTTP(otherSectionTimetable, httptest.NewRequest(http.MethodGet, "/timetable/section/"+f.externalSectionID, nil))
	if otherSectionTimetable.Code != http.StatusForbidden {
		t.Fatalf("other timetable section should be forbidden, status=%d body=%s", otherSectionTimetable.Code, otherSectionTimetable.Body.String())
	}
}

func TestStaffLeaveIsSchoolAndRoleScoped(t *testing.T) {
	f := setupSchoolScopeFixture(t)
	handler := NewLeaveHandler()
	adminRouter := scopedPolicyRouter("Admin", "user-policy-admin", "", "", "admin@policy.test", f.schoolID)
	adminRouter.GET("/leave/applications", handler.GetLeaveApplications)
	adminRouter.PUT("/leave/applications/:id/approve", handler.ApproveLeaveApplication)
	adminRouter.GET("/leave/balances", handler.GetLeaveBalances)
	adminRouter.POST("/leave/balances/initialize", handler.InitializeLeaveBalances)

	applications := httptest.NewRecorder()
	adminRouter.ServeHTTP(applications, httptest.NewRequest(http.MethodGet, "/leave/applications", nil))
	if applications.Code != http.StatusOK {
		t.Fatalf("admin applications status=%d body=%s", applications.Code, applications.Body.String())
	}
	rows := decodePolicyList(t, applications.Body.String())
	if len(rows) != 2 {
		t.Fatalf("admin should see current school leave applications only, rows=%v", rows)
	}
	for _, row := range rows {
		if row["id"] == f.externalLeaveAppID {
			t.Fatalf("admin leave list leaked other school application: %v", rows)
		}
	}

	approveOther := httptest.NewRecorder()
	adminRouter.ServeHTTP(approveOther, httptest.NewRequest(http.MethodPut, "/leave/applications/"+f.externalLeaveAppID+"/approve", strings.NewReader(`{"status":"approved"}`)))
	if approveOther.Code != http.StatusNotFound {
		t.Fatalf("admin should not approve other school leave, status=%d body=%s", approveOther.Code, approveOther.Body.String())
	}
	var otherLeave models.LeaveApplication
	if err := database.DB.First(&otherLeave, "id = ?", f.externalLeaveAppID).Error; err != nil {
		t.Fatalf("load other leave: %v", err)
	}
	if otherLeave.Status != "pending" {
		t.Fatalf("other school leave was mutated: %+v", otherLeave)
	}

	balances := httptest.NewRecorder()
	adminRouter.ServeHTTP(balances, httptest.NewRequest(http.MethodGet, "/leave/balances", nil))
	if balances.Code != http.StatusOK {
		t.Fatalf("admin balances status=%d body=%s", balances.Code, balances.Body.String())
	}
	balanceRows := decodePolicyList(t, balances.Body.String())
	if len(balanceRows) != 2 {
		t.Fatalf("admin should see current school leave balances only, rows=%v", balanceRows)
	}
	for _, row := range balanceRows {
		if row["id"] == f.externalLeaveBalanceID {
			t.Fatalf("admin balance list leaked other school balance: %v", balanceRows)
		}
	}

	rejectInit := httptest.NewRecorder()
	adminRouter.ServeHTTP(rejectInit, httptest.NewRequest(http.MethodPost, "/leave/balances/initialize", strings.NewReader(`{"staff_id":"`+f.externalStaffID+`","academic_year_id":"`+f.externalYearID+`","leave_type_id":"`+f.externalLeaveTypeID+`","total_entitled":12}`)))
	if rejectInit.Code != http.StatusForbidden {
		t.Fatalf("initialize should reject other school refs, status=%d body=%s", rejectInit.Code, rejectInit.Body.String())
	}

	teacherRouter := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	teacherRouter.GET("/leave/applications", handler.GetLeaveApplications)
	teacherRouter.POST("/leave/applications", handler.CreateLeaveApplication)
	teacherRouter.GET("/leave/balances", handler.GetLeaveBalances)

	teacherApps := httptest.NewRecorder()
	teacherRouter.ServeHTTP(teacherApps, httptest.NewRequest(http.MethodGet, "/leave/applications", nil))
	if teacherApps.Code != http.StatusOK {
		t.Fatalf("teacher applications status=%d body=%s", teacherApps.Code, teacherApps.Body.String())
	}
	teacherRows := decodePolicyList(t, teacherApps.Body.String())
	if len(teacherRows) != 1 || teacherRows[0]["id"] != f.currentLeaveApplication {
		t.Fatalf("teacher should see only own leave application, rows=%v", teacherRows)
	}

	createForOtherStaff := httptest.NewRecorder()
	teacherRouter.ServeHTTP(createForOtherStaff, httptest.NewRequest(http.MethodPost, "/leave/applications", strings.NewReader(`{"staff_id":"`+f.otherStaffID+`","leave_type_id":"`+f.currentLeaveTypeID+`","from_date":"2026-05-20","to_date":"2026-05-20","reason":"bad scope"}`)))
	if createForOtherStaff.Code != http.StatusForbidden {
		t.Fatalf("teacher should not submit for another staff, status=%d body=%s", createForOtherStaff.Code, createForOtherStaff.Body.String())
	}
}

func TestTeacherCannotEnterMarksForUnassignedSchedule(t *testing.T) {
	f := setupSchoolScopeFixture(t)
	router := scopedPolicyRouter("Teacher", "user-policy-teacher", "staff", f.teacherStaffID, "assigned.teacher@policy.test", f.schoolID)
	router.POST("/exams/schedules/:schedule_id/marks", NewExamHandler().EnterMarks)

	denied := httptest.NewRecorder()
	router.ServeHTTP(
		denied,
		httptest.NewRequest(http.MethodPost, "/exams/schedules/"+f.externalExamScheduleID+"/marks", strings.NewReader(`{"marks":[{"student_id":"`+f.externalStudentID+`","enrollment_id":"`+f.externalEnrollmentID+`","marks_obtained":74}]}`)),
	)
	if denied.Code != http.StatusNotFound {
		t.Fatalf("cross-school schedule should be hidden, status=%d body=%s", denied.Code, denied.Body.String())
	}

	unassignedSchedule := models.ExamSchedule{
		BaseModel: models.BaseModel{ID: "schedule-scope-unassigned-same-school"},
		ExamID:    f.currentExamID, GradeID: "grade-policy", SectionID: f.otherSectionID, SubjectID: f.otherSubjectID,
		ExamDate: time.Date(2026, 5, 17, 9, 0, 0, 0, time.UTC), MaxMarks: 100, PassMarks: 35,
	}
	if err := database.DB.Create(&unassignedSchedule).Error; err != nil {
		t.Fatalf("seed unassigned schedule: %v", err)
	}
	forbidden := httptest.NewRecorder()
	router.ServeHTTP(
		forbidden,
		httptest.NewRequest(http.MethodPost, "/exams/schedules/"+unassignedSchedule.ID+"/marks", strings.NewReader(`{"marks":[{"student_id":"`+f.otherStudentID+`","enrollment_id":"`+f.otherEnrollmentID+`","marks_obtained":74}]}`)),
	)
	if forbidden.Code != http.StatusForbidden {
		t.Fatalf("same-school unassigned schedule should be forbidden, status=%d body=%s", forbidden.Code, forbidden.Body.String())
	}
}

func TestAdminExamMarksAreUpsertedAndScheduleMarksReadable(t *testing.T) {
	f := setupSchoolScopeFixture(t)
	router := scopedPolicyRouter("Admin", "user-policy-admin", "", "", "admin@policy.test", f.schoolID)
	handler := NewExamHandler()
	router.GET("/exams/schedules/:schedule_id/marks", handler.GetScheduleMarks)
	router.POST("/exams/schedules/:schedule_id/marks", handler.EnterMarks)

	first := httptest.NewRecorder()
	router.ServeHTTP(
		first,
		httptest.NewRequest(http.MethodPost, "/exams/schedules/"+f.currentExamScheduleID+"/marks", strings.NewReader(`{"marks":[{"student_id":"`+f.studentID+`","enrollment_id":"`+f.enrollmentID+`","marks_obtained":74,"grade_label":"B+"}]}`)),
	)
	if first.Code != http.StatusOK {
		t.Fatalf("initial marks save status=%d body=%s", first.Code, first.Body.String())
	}

	second := httptest.NewRecorder()
	router.ServeHTTP(
		second,
		httptest.NewRequest(http.MethodPost, "/exams/schedules/"+f.currentExamScheduleID+"/marks", strings.NewReader(`{"marks":[{"student_id":"`+f.studentID+`","enrollment_id":"`+f.enrollmentID+`","marks_obtained":88,"grade_label":"A"}]}`)),
	)
	if second.Code != http.StatusOK {
		t.Fatalf("updated marks save status=%d body=%s", second.Code, second.Body.String())
	}

	var count int64
	if err := database.DB.Model(&models.StudentMark{}).
		Where("exam_schedule_id = ? AND student_id = ? AND enrollment_id = ?", f.currentExamScheduleID, f.studentID, f.enrollmentID).
		Count(&count).Error; err != nil {
		t.Fatalf("count marks: %v", err)
	}
	if count != 1 {
		t.Fatalf("expected mark update instead of duplicate rows, count=%d", count)
	}
	var mark models.StudentMark
	if err := database.DB.First(&mark, "exam_schedule_id = ? AND student_id = ?", f.currentExamScheduleID, f.studentID).Error; err != nil {
		t.Fatalf("load saved mark: %v", err)
	}
	if mark.MarksObtained != 88 || mark.GradeLabel != "A" {
		t.Fatalf("expected latest mark to be stored, got marks=%v grade=%q", mark.MarksObtained, mark.GradeLabel)
	}

	list := httptest.NewRecorder()
	router.ServeHTTP(list, httptest.NewRequest(http.MethodGet, "/exams/schedules/"+f.currentExamScheduleID+"/marks", nil))
	if list.Code != http.StatusOK {
		t.Fatalf("list marks status=%d body=%s", list.Code, list.Body.String())
	}
	rows := decodePolicyList(t, list.Body.String())
	if len(rows) != 1 || rows[0]["student_id"] != f.studentID {
		t.Fatalf("expected schedule marks to be readable and scoped, rows=%v", rows)
	}

	tooHigh := httptest.NewRecorder()
	router.ServeHTTP(
		tooHigh,
		httptest.NewRequest(http.MethodPost, "/exams/schedules/"+f.currentExamScheduleID+"/marks", strings.NewReader(`{"marks":[{"student_id":"`+f.studentID+`","enrollment_id":"`+f.enrollmentID+`","marks_obtained":101,"grade_label":"A+"}]}`)),
	)
	if tooHigh.Code != http.StatusUnprocessableEntity {
		t.Fatalf("marks above max should be rejected, status=%d body=%s", tooHigh.Code, tooHigh.Body.String())
	}
}
