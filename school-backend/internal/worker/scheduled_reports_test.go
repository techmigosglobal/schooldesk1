package worker

import (
	"strings"
	"testing"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
)

func TestScheduledDailyStaffAttendanceReportIsPrincipalOnlyAndIdempotent(t *testing.T) {
	seedScheduledReportFixture(t)
	now := time.Date(2026, 6, 22, 12, 30, 0, 0, time.UTC)

	if err := runScheduledPrincipalReports(now); err != nil {
		t.Fatalf("run daily reports: %v", err)
	}
	if err := runScheduledPrincipalReports(now); err != nil {
		t.Fatalf("rerun daily reports: %v", err)
	}

	var logs []models.NotificationLog
	if err := database.DB.
		Where("reference_type = ?", "staff_attendance_daily_report").
		Find(&logs).Error; err != nil {
		t.Fatalf("load daily report logs: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("daily report log count=%d, want 1", len(logs))
	}
	if logs[0].RecipientUserID != "principal-report-user" {
		t.Fatalf("daily report recipient=%q, want principal-report-user", logs[0].RecipientUserID)
	}
	if logs[0].Route != "/principal-attendance-screen" {
		t.Fatalf("daily report route=%q, want /principal-attendance-screen", logs[0].Route)
	}
	if logs[0].ReferenceID == nil || *logs[0].ReferenceID != "school-report:2026-06-22" {
		t.Fatalf("daily report reference_id=%v, want school-report:2026-06-22", logs[0].ReferenceID)
	}
	if !strings.Contains(logs[0].Body, "1 present") {
		t.Fatalf("daily report body should summarize present staff: %q", logs[0].Body)
	}
}

func TestScheduledMonthlyStaffAttendanceReportRunsOnLastDayOnly(t *testing.T) {
	seedScheduledReportFixture(t)
	notLastDay := time.Date(2026, 6, 29, 12, 45, 0, 0, time.UTC)
	lastDay := time.Date(2026, 6, 30, 12, 45, 0, 0, time.UTC)

	if err := runScheduledPrincipalReports(notLastDay); err != nil {
		t.Fatalf("run non-last-day monthly reports: %v", err)
	}
	var beforeCount int64
	if err := database.DB.Model(&models.NotificationLog{}).
		Where("reference_type = ?", "staff_attendance_monthly_report").
		Count(&beforeCount).Error; err != nil {
		t.Fatalf("count monthly reports before last day: %v", err)
	}
	if beforeCount != 0 {
		t.Fatalf("monthly report count before last day=%d, want 0", beforeCount)
	}

	if err := runScheduledPrincipalReports(lastDay); err != nil {
		t.Fatalf("run last-day monthly reports: %v", err)
	}
	if err := runScheduledPrincipalReports(lastDay); err != nil {
		t.Fatalf("rerun last-day monthly reports: %v", err)
	}
	var logs []models.NotificationLog
	if err := database.DB.
		Where("reference_type = ?", "staff_attendance_monthly_report").
		Find(&logs).Error; err != nil {
		t.Fatalf("load monthly report logs: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("monthly report log count=%d, want 1", len(logs))
	}
	if logs[0].ReferenceID == nil || *logs[0].ReferenceID != "school-report:2026-06" {
		t.Fatalf("monthly report reference_id=%v, want school-report:2026-06", logs[0].ReferenceID)
	}
}

func TestScheduledWeeklyLessonPlannerDigestIsIdempotent(t *testing.T) {
	seedScheduledReportFixture(t)
	friday := time.Date(2026, 6, 26, 13, 0, 0, 0, time.UTC)

	if err := runScheduledPrincipalReports(friday); err != nil {
		t.Fatalf("run weekly lesson planner digest: %v", err)
	}
	if err := runScheduledPrincipalReports(friday); err != nil {
		t.Fatalf("rerun weekly lesson planner digest: %v", err)
	}

	var logs []models.NotificationLog
	if err := database.DB.
		Where("reference_type = ?", "lesson_planner_weekly_digest").
		Find(&logs).Error; err != nil {
		t.Fatalf("load weekly lesson planner digest logs: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("weekly lesson planner digest count=%d, want 1", len(logs))
	}
	if logs[0].Route != "/principal-lesson-planner-screen" {
		t.Fatalf("weekly lesson planner route=%q, want /principal-lesson-planner-screen", logs[0].Route)
	}
	if !strings.Contains(logs[0].Body, "1 submitted") || !strings.Contains(logs[0].Body, "1 missing") {
		t.Fatalf("weekly lesson planner body should summarize submitted/missing: %q", logs[0].Body)
	}
}

func TestScheduledBirthdayWishesNotifyTeacherPrincipalAndParentForChild(t *testing.T) {
	seedScheduledReportFixture(t)
	birthdayRun := time.Date(2026, 6, 23, 2, 30, 0, 0, time.UTC) // 08:00 IST

	if err := runScheduledPrincipalReports(birthdayRun); err != nil {
		t.Fatalf("run birthday scheduler: %v", err)
	}
	if err := runScheduledPrincipalReports(birthdayRun); err != nil {
		t.Fatalf("rerun birthday scheduler: %v", err)
	}

	var staffLogs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refBirthdayWishStaff).Find(&staffLogs).Error; err != nil {
		t.Fatalf("load staff birthday logs: %v", err)
	}
	if len(staffLogs) != 2 {
		t.Fatalf("staff birthday logs=%d, want 2", len(staffLogs))
	}
	staffRecipients := map[string]bool{}
	for _, log := range staffLogs {
		staffRecipients[log.RecipientUserID] = true
	}
	if !staffRecipients["teacher-report-user"] || !staffRecipients["principal-report-user"] {
		t.Fatalf("staff birthday recipients=%v, want teacher-report-user and principal-report-user", staffRecipients)
	}

	var studentLogs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refBirthdayWishStudent).Find(&studentLogs).Error; err != nil {
		t.Fatalf("load student birthday logs: %v", err)
	}
	if len(studentLogs) != 1 {
		t.Fatalf("student birthday logs=%d, want 1", len(studentLogs))
	}
	if studentLogs[0].RecipientUserID != "parent-report-user" {
		t.Fatalf("student birthday recipient=%q, want parent-report-user", studentLogs[0].RecipientUserID)
	}
	if !strings.Contains(studentLogs[0].Body, "Birthday Child") {
		t.Fatalf("student birthday body should include child name: %q", studentLogs[0].Body)
	}
}

func TestScheduledStudentBirthdayNotifiesTeachers(t *testing.T) {
	seedBirthdayHealthFixture(t)
	birthdayRun := time.Date(2026, 6, 23, 2, 30, 0, 0, time.UTC) // 08:00 IST

	if err := runScheduledPrincipalReports(birthdayRun); err != nil {
		t.Fatalf("run birthday scheduler: %v", err)
	}

	var logs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refBirthdayWishStudentForTeachers).Find(&logs).Error; err != nil {
		t.Fatalf("load teacher birthday logs: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("teacher birthday logs=%d, want 1", len(logs))
	}
	if logs[0].RecipientUserID != "teacher-report-user" {
		t.Fatalf("teacher birthday recipient=%q, want teacher-report-user", logs[0].RecipientUserID)
	}
	if logs[0].Category != "birthday" {
		t.Fatalf("teacher birthday category=%q, want birthday", logs[0].Category)
	}
	if logs[0].Priority != "medium" {
		t.Fatalf("teacher birthday priority=%q, want medium", logs[0].Priority)
	}
	if !strings.Contains(logs[0].Body, "Birthday Child") {
		t.Fatalf("teacher birthday body should include student name: %q", logs[0].Body)
	}
	if logs[0].Route != routeTeacherDashboard {
		t.Fatalf("teacher birthday route=%q, want %q", logs[0].Route, routeTeacherDashboard)
	}
	if logs[0].ReferenceID == nil || !strings.Contains(*logs[0].ReferenceID, "student-report-birthday") {
		t.Fatalf("teacher birthday reference_id=%v, should contain student ID", logs[0].ReferenceID)
	}
}

func TestScheduledStudentBirthdayNotifiesPrincipal(t *testing.T) {
	seedBirthdayHealthFixture(t)
	birthdayRun := time.Date(2026, 6, 23, 2, 30, 0, 0, time.UTC) // 08:00 IST

	if err := runScheduledPrincipalReports(birthdayRun); err != nil {
		t.Fatalf("run birthday scheduler: %v", err)
	}

	var logs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refBirthdayWishStudentForPrincipal).Find(&logs).Error; err != nil {
		t.Fatalf("load principal birthday logs: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("principal birthday logs=%d, want 1", len(logs))
	}
	if logs[0].RecipientUserID != "principal-report-user" {
		t.Fatalf("principal birthday recipient=%q, want principal-report-user", logs[0].RecipientUserID)
	}
	if logs[0].Category != "birthday" {
		t.Fatalf("principal birthday category=%q, want birthday", logs[0].Category)
	}
	if !strings.Contains(logs[0].Body, "Birthday Child") {
		t.Fatalf("principal birthday body should include student name: %q", logs[0].Body)
	}
	if !strings.Contains(logs[0].Body, "Grade 2 A") {
		t.Fatalf("principal birthday body should include class name: %q", logs[0].Body)
	}
	if logs[0].Route != routePrincipalDashboard {
		t.Fatalf("principal birthday route=%q, want %q", logs[0].Route, routePrincipalDashboard)
	}
}

func TestScheduledStudentBirthdayForTeachersIsIdempotent(t *testing.T) {
	seedBirthdayHealthFixture(t)
	birthdayRun := time.Date(2026, 6, 23, 2, 30, 0, 0, time.UTC)

	if err := runScheduledPrincipalReports(birthdayRun); err != nil {
		t.Fatalf("first run: %v", err)
	}
	if err := runScheduledPrincipalReports(birthdayRun); err != nil {
		t.Fatalf("second run: %v", err)
	}

	var logs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refBirthdayWishStudentForTeachers).Find(&logs).Error; err != nil {
		t.Fatalf("load logs: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("teacher birthday logs after idempotent run=%d, want 1", len(logs))
	}

	var principalLogs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refBirthdayWishStudentForPrincipal).Find(&principalLogs).Error; err != nil {
		t.Fatalf("load principal logs: %v", err)
	}
	if len(principalLogs) != 1 {
		t.Fatalf("principal birthday logs after idempotent run=%d, want 1", len(principalLogs))
	}
}

func TestScheduledStudentBirthdayNoNotificationWhenNotBirthday(t *testing.T) {
	seedBirthdayHealthFixture(t)
	nonBirthday := time.Date(2026, 6, 22, 2, 30, 0, 0, time.UTC) // June 22, not June 23

	if err := runScheduledPrincipalReports(nonBirthday); err != nil {
		t.Fatalf("run scheduler: %v", err)
	}

	var teacherLogs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refBirthdayWishStudentForTeachers).Find(&teacherLogs).Error; err != nil {
		t.Fatalf("load logs: %v", err)
	}
	if len(teacherLogs) != 0 {
		t.Fatalf("teacher birthday logs on non-birthday=%d, want 0", len(teacherLogs))
	}

	var principalLogs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refBirthdayWishStudentForPrincipal).Find(&principalLogs).Error; err != nil {
		t.Fatalf("load logs: %v", err)
	}
	if len(principalLogs) != 0 {
		t.Fatalf("principal birthday logs on non-birthday=%d, want 0", len(principalLogs))
	}
}

func TestScheduledHealthReminderNotifiesTeachers(t *testing.T) {
	seedBirthdayHealthFixture(t)
	healthRun := time.Date(2026, 6, 22, 2, 0, 0, 0, time.UTC) // 07:30 IST

	if err := runScheduledPrincipalReports(healthRun); err != nil {
		t.Fatalf("run health scheduler: %v", err)
	}

	var logs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refHealthReminder).Find(&logs).Error; err != nil {
		t.Fatalf("load health reminder logs: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("health reminder logs=%d, want 1", len(logs))
	}
	if logs[0].RecipientUserID != "teacher-report-user" {
		t.Fatalf("health reminder recipient=%q, want teacher-report-user", logs[0].RecipientUserID)
	}
	if logs[0].Category != "health_alert" {
		t.Fatalf("health reminder category=%q, want health_alert", logs[0].Category)
	}
	if logs[0].Priority != "high" {
		t.Fatalf("health reminder priority=%q, want high", logs[0].Priority)
	}
	if !strings.Contains(logs[0].Body, "Asthma") {
		t.Fatalf("health reminder body should include condition: %q", logs[0].Body)
	}
	if !strings.Contains(logs[0].Body, "Birthday Child") {
		t.Fatalf("health reminder body should include student name: %q", logs[0].Body)
	}
	if !strings.Contains(logs[0].Body, "Inhaler") {
		t.Fatalf("health reminder body should include medications: %q", logs[0].Body)
	}
	if logs[0].Route != routeTeacherDashboard {
		t.Fatalf("health reminder route=%q, want %q", logs[0].Route, routeTeacherDashboard)
	}
	if logs[0].ReferenceID == nil || !strings.Contains(*logs[0].ReferenceID, "health") {
		t.Fatalf("health reminder reference_id=%v, should contain 'health'", logs[0].ReferenceID)
	}
}

func TestScheduledHealthReminderIsIdempotent(t *testing.T) {
	seedBirthdayHealthFixture(t)
	healthRun := time.Date(2026, 6, 22, 2, 0, 0, 0, time.UTC) // 07:30 IST

	if err := runScheduledPrincipalReports(healthRun); err != nil {
		t.Fatalf("first run: %v", err)
	}
	if err := runScheduledPrincipalReports(healthRun); err != nil {
		t.Fatalf("second run: %v", err)
	}

	var logs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refHealthReminder).Find(&logs).Error; err != nil {
		t.Fatalf("load logs: %v", err)
	}
	if len(logs) != 1 {
		t.Fatalf("health reminder logs after idempotent run=%d, want 1", len(logs))
	}
}

func TestScheduledHealthReminderSkipsEmptyConditions(t *testing.T) {
	seedBirthdayHealthFixture(t)
	// Create a second student with a medical record but empty conditions
	database.DB.Create(&models.Student{
		BaseModel:        models.BaseModel{ID: "student-no-health"},
		SchoolID:         "school-report",
		StudentCode:      "STU-REP-2",
		AdmissionNumber:  "ADM-REP-2",
		FirstName:        "Healthy",
		LastName:         "Student",
		DateOfBirth:      time.Date(2016, 3, 15, 0, 0, 0, 0, time.UTC),
		AdmissionDate:    time.Date(2026, 6, 22, 0, 0, 0, 0, time.UTC),
		CurrentSectionID: strPtr("section-report-health"),
		Status:           "active",
	})
	database.DB.Create(&models.MedicalRecord{
		BaseModel:  models.BaseModel{ID: "med-no-conditions"},
		StudentID:  "student-no-health",
		Conditions: "", // empty conditions — should be skipped
	})

	healthRun := time.Date(2026, 6, 22, 2, 0, 0, 0, time.UTC)
	if err := runScheduledPrincipalReports(healthRun); err != nil {
		t.Fatalf("run scheduler: %v", err)
	}

	var logs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refHealthReminder).Find(&logs).Error; err != nil {
		t.Fatalf("load logs: %v", err)
	}
	// Only the student with conditions (Birthday Child) should generate a notification
	if len(logs) != 1 {
		t.Fatalf("health reminder logs=%d, want 1 (student with empty conditions should be skipped)", len(logs))
	}
}

func TestScheduledHealthReminderOmitsMedicationsWhenEmpty(t *testing.T) {
	seedBirthdayHealthFixture(t)
	// Add a student with conditions but no medications
	database.DB.Create(&models.Student{
		BaseModel:        models.BaseModel{ID: "student-no-meds"},
		SchoolID:         "school-report",
		StudentCode:      "STU-REP-3",
		AdmissionNumber:  "ADM-REP-3",
		FirstName:        "Allergy",
		LastName:         "Only",
		DateOfBirth:      time.Date(2017, 1, 10, 0, 0, 0, 0, time.UTC),
		AdmissionDate:    time.Date(2026, 6, 22, 0, 0, 0, 0, time.UTC),
		CurrentSectionID: strPtr("section-report-health"),
		Status:           "active",
	})
	database.DB.Create(&models.MedicalRecord{
		BaseModel:  models.BaseModel{ID: "med-no-meds"},
		StudentID:  "student-no-meds",
		Conditions: "Seasonal allergies",
		Medications: "", // empty medications
	})

	healthRun := time.Date(2026, 6, 22, 2, 0, 0, 0, time.UTC)
	if err := runScheduledPrincipalReports(healthRun); err != nil {
		t.Fatalf("run scheduler: %v", err)
	}

	var logs []models.NotificationLog
	if err := database.DB.Where("reference_type = ?", refHealthReminder).Find(&logs).Error; err != nil {
		t.Fatalf("load logs: %v", err)
	}
	// Should have 2 health reminder logs: Birthday Child (Asthma) + Allergy Only (Seasonal allergies)
	if len(logs) != 2 {
		t.Fatalf("health reminder logs=%d, want 2", len(logs))
	}
	// Find the Allergy Only notification and verify medications are NOT included
	var allergyLog *models.NotificationLog
	for i := range logs {
		if strings.Contains(logs[i].Body, "Allergy Only") {
			allergyLog = &logs[i]
			break
		}
	}
	if allergyLog == nil {
		t.Fatalf("expected notification for Allergy Only student, not found in %d logs", len(logs))
	}
	if strings.Contains(allergyLog.Body, "Medications:") {
		t.Fatalf("notification body should omit medications when empty: %q", allergyLog.Body)
	}
	if !strings.Contains(allergyLog.Body, "Seasonal allergies") {
		t.Fatalf("notification body should include conditions: %q", allergyLog.Body)
	}
}

func strPtr(s string) *string { return &s }

// seedBirthdayHealthFixture sets up the database with school, users, staff,
// students (with birthday), timetable slots (teacher linked to section),
// medical records, parent links, and the base data needed for both birthday
// and health reminder tests.
func seedBirthdayHealthFixture(t *testing.T) {
	t.Helper()
	if err := database.SetupTestDB(); err != nil {
		t.Fatalf("setup db: %v", err)
	}
	schoolID := "school-report"
	principalRoleID := "role-report-principal"
	adminRoleID := "role-report-admin"
	teacherRoleID := "role-report-teacher"
	parentRoleID := "role-report-parent"
	principalStaffID := "staff-report-principal"
	teacherStaffID := "staff-report-teacher"
	missingStaffID := "staff-report-missing"
	now := time.Date(2026, 6, 22, 9, 0, 0, 0, time.UTC)
	birthdayDate := time.Date(2026, 6, 23, 0, 0, 0, 0, time.UTC)
	childSectionID := "section-report-health"
	birthdayStudentID := "student-report-birthday"
	seeds := []any{
		// School & roles
		&models.School{BaseModel: models.BaseModel{ID: schoolID}, Name: "Report School", SchoolType: "cbse"},
		&models.Role{BaseModel: models.BaseModel{ID: principalRoleID}, SchoolID: schoolID, RoleName: "Principal", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: adminRoleID}, SchoolID: schoolID, RoleName: "Admin", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: teacherRoleID}, SchoolID: schoolID, RoleName: "Teacher", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: parentRoleID}, SchoolID: schoolID, RoleName: "Parent", IsSystemRole: true},
		// Users
		&models.User{BaseModel: models.BaseModel{ID: "principal-report-user"}, SchoolID: schoolID, Name: "Principal", Email: "principal@report.test", RoleID: principalRoleID, RoleSlug: "principal", LinkedType: "staff", LinkedID: &principalStaffID, PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "admin-report-user"}, SchoolID: schoolID, Name: "Admin", Email: "admin@report.test", RoleID: adminRoleID, RoleSlug: "admin", PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "teacher-report-user"}, SchoolID: schoolID, Name: "Teacher", Email: "teacher@report.test", RoleID: teacherRoleID, RoleSlug: "teacher", LinkedType: "staff", LinkedID: &teacherStaffID, PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "teacher-report-missing-user"}, SchoolID: schoolID, Name: "Missing Teacher", Email: "missing@report.test", RoleID: teacherRoleID, RoleSlug: "teacher", LinkedType: "staff", LinkedID: &missingStaffID, PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "parent-report-user"}, SchoolID: schoolID, Name: "Parent", Email: "parent@report.test", RoleID: parentRoleID, RoleSlug: "parent", PasswordHash: "hash", IsActive: true, IsVerified: true},
		// Staff
		&models.Staff{BaseModel: models.BaseModel{ID: principalStaffID}, SchoolID: schoolID, StaffCode: "REP-P", FirstName: "Report", LastName: "Principal", Email: "principal@report.test", DateOfBirth: birthdayDate.AddDate(-40, 0, 0), Gender: "female", Designation: "Principal", EmploymentType: "full-time", JoinDate: now.AddDate(-6, 0, 0), Status: "active"},
		&models.Staff{BaseModel: models.BaseModel{ID: teacherStaffID}, SchoolID: schoolID, StaffCode: "REP-1", FirstName: "Report", LastName: "Teacher", Email: "teacher@report.test", DateOfBirth: birthdayDate.AddDate(-32, 0, 0), Gender: "female", Designation: "Teacher", EmploymentType: "full-time", JoinDate: now.AddDate(-5, 0, 0), Status: "active"},
		&models.Staff{BaseModel: models.BaseModel{ID: missingStaffID}, SchoolID: schoolID, StaffCode: "REP-2", FirstName: "Missing", LastName: "Teacher", Email: "missing@report.test", DateOfBirth: now.AddDate(-32, 0, 0), Gender: "female", Designation: "Teacher", EmploymentType: "full-time", JoinDate: now.AddDate(-5, 0, 0), Status: "active"},
		// Grade & section (section links teacher via class_teacher_id)
		&models.Grade{BaseModel: models.BaseModel{ID: "grade-report"}, SchoolID: schoolID, GradeName: "Grade 2", GradeNumber: 2},
		&models.Section{BaseModel: models.BaseModel{ID: childSectionID}, SchoolID: schoolID, AcademicYearID: "year-report", GradeID: "grade-report", SectionName: "A", ClassTeacherID: &teacherStaffID, Capacity: 30},
		// Birthday student
		&models.Student{BaseModel: models.BaseModel{ID: birthdayStudentID}, SchoolID: schoolID, StudentCode: "STU-REP-1", AdmissionNumber: "ADM-REP-1", FirstName: "Birthday", LastName: "Child", DateOfBirth: birthdayDate.AddDate(-10, 0, 0), AdmissionDate: now, CurrentSectionID: &childSectionID, Status: "active"},
		// Parent link
		&models.ParentStudentLink{BaseModel: models.BaseModel{ID: "link-report-parent-child"}, SchoolID: schoolID, ParentUserID: "parent-report-user", StudentID: birthdayStudentID, StudentAdmissionNumber: "ADM-REP-1"},
		// Staff attendance (for daily report tests)
		&models.StaffAttendance{StaffID: teacherStaffID, Date: time.Date(2026, 6, 22, 0, 0, 0, 0, time.UTC), CheckIn: &now, Status: "present", Source: "qr"},
		&models.StaffAttendance{StaffID: teacherStaffID, Date: time.Date(2026, 6, 3, 0, 0, 0, 0, time.UTC), CheckIn: &now, Status: "present", Source: "qr"},
		// Lesson planner (for weekly digest tests)
		&models.LessonPlanner{SchoolID: schoolID, TeacherID: teacherStaffID, GradeID: "grade-report", SectionID: "section-report", WeekStartDate: time.Date(2026, 6, 22, 0, 0, 0, 0, time.UTC), WeekEndDate: time.Date(2026, 6, 28, 23, 59, 0, 0, time.UTC), Status: models.LessonPlannerStatusUploaded},
		// Term (referenced by timetable slot)
		&models.Term{BaseModel: models.BaseModel{ID: "term-report"}, AcademicYearID: "year-report", TermNumber: 1, TermName: "Term 1", StartDate: now, EndDate: now.AddDate(0, 6, 0)},
		// Timetable slot linking teacher to the birthday student's section
		&models.TimetableSlot{BaseModel: models.BaseModel{ID: "slot-report-health-1"}, SectionID: childSectionID, AcademicYearID: "year-report", TermID: "term-report", DayOfWeek: int(time.Monday), PeriodNumber: 1, SubjectID: "sub-report", StaffID: teacherStaffID, SlotType: "regular"},
		// Medical record with conditions for the birthday student
		&models.MedicalRecord{BaseModel: models.BaseModel{ID: "med-report-1"}, StudentID: birthdayStudentID, Conditions: "Asthma", Medications: "Inhaler twice daily", Allergies: "Peanuts", DoctorName: "Dr. Smith", DoctorPhone: "1234567890"},
	}
	for _, seed := range seeds {
		if err := database.DB.Create(seed).Error; err != nil {
			t.Fatalf("seed %T: %v", seed, err)
		}
	}
}

func seedScheduledReportFixture(t *testing.T) {
	t.Helper()
	if err := database.SetupTestDB(); err != nil {
		t.Fatalf("setup db: %v", err)
	}
	schoolID := "school-report"
	principalRoleID := "role-report-principal"
	adminRoleID := "role-report-admin"
	teacherRoleID := "role-report-teacher"
	parentRoleID := "role-report-parent"
	principalStaffID := "staff-report-principal"
	teacherStaffID := "staff-report-teacher"
	missingStaffID := "staff-report-missing"
	now := time.Date(2026, 6, 22, 9, 0, 0, 0, time.UTC)
	birthdayDate := time.Date(2026, 6, 23, 0, 0, 0, 0, time.UTC)
	childSectionID := "section-report-student"
	birthdayStudentID := "student-report-birthday"
	seeds := []any{
		&models.School{BaseModel: models.BaseModel{ID: schoolID}, Name: "Report School", SchoolType: "cbse"},
		&models.Role{BaseModel: models.BaseModel{ID: principalRoleID}, SchoolID: schoolID, RoleName: "Principal", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: adminRoleID}, SchoolID: schoolID, RoleName: "Admin", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: teacherRoleID}, SchoolID: schoolID, RoleName: "Teacher", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: parentRoleID}, SchoolID: schoolID, RoleName: "Parent", IsSystemRole: true},
		&models.User{BaseModel: models.BaseModel{ID: "principal-report-user"}, SchoolID: schoolID, Name: "Principal", Email: "principal@report.test", RoleID: principalRoleID, RoleSlug: "principal", LinkedType: "staff", LinkedID: &principalStaffID, PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "admin-report-user"}, SchoolID: schoolID, Name: "Admin", Email: "admin@report.test", RoleID: adminRoleID, RoleSlug: "admin", PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "teacher-report-user"}, SchoolID: schoolID, Name: "Teacher", Email: "teacher@report.test", RoleID: teacherRoleID, RoleSlug: "teacher", LinkedType: "staff", LinkedID: &teacherStaffID, PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "teacher-report-missing-user"}, SchoolID: schoolID, Name: "Missing Teacher", Email: "missing@report.test", RoleID: teacherRoleID, RoleSlug: "teacher", LinkedType: "staff", LinkedID: &missingStaffID, PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "parent-report-user"}, SchoolID: schoolID, Name: "Parent", Email: "parent@report.test", RoleID: parentRoleID, RoleSlug: "parent", PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.Staff{BaseModel: models.BaseModel{ID: principalStaffID}, SchoolID: schoolID, StaffCode: "REP-P", FirstName: "Report", LastName: "Principal", Email: "principal@report.test", DateOfBirth: birthdayDate.AddDate(-40, 0, 0), Gender: "female", Designation: "Principal", EmploymentType: "full-time", JoinDate: now.AddDate(-6, 0, 0), Status: "active"},
		&models.Staff{BaseModel: models.BaseModel{ID: teacherStaffID}, SchoolID: schoolID, StaffCode: "REP-1", FirstName: "Report", LastName: "Teacher", Email: "teacher@report.test", DateOfBirth: birthdayDate.AddDate(-32, 0, 0), Gender: "female", Designation: "Teacher", EmploymentType: "full-time", JoinDate: now.AddDate(-5, 0, 0), Status: "active"},
		&models.Staff{BaseModel: models.BaseModel{ID: missingStaffID}, SchoolID: schoolID, StaffCode: "REP-2", FirstName: "Missing", LastName: "Teacher", Email: "missing@report.test", DateOfBirth: now.AddDate(-32, 0, 0), Gender: "female", Designation: "Teacher", EmploymentType: "full-time", JoinDate: now.AddDate(-5, 0, 0), Status: "active"},
		&models.Grade{BaseModel: models.BaseModel{ID: "grade-report"}, SchoolID: schoolID, GradeName: "Grade 2", GradeNumber: 2},
		&models.Section{BaseModel: models.BaseModel{ID: childSectionID}, SchoolID: schoolID, AcademicYearID: "year-report", GradeID: "grade-report", SectionName: "A", Capacity: 30},
		&models.Student{BaseModel: models.BaseModel{ID: birthdayStudentID}, SchoolID: schoolID, StudentCode: "STU-REP-1", AdmissionNumber: "ADM-REP-1", FirstName: "Birthday", LastName: "Child", DateOfBirth: birthdayDate.AddDate(-10, 0, 0), AdmissionDate: now, CurrentSectionID: &childSectionID, Status: "active"},
		&models.ParentStudentLink{BaseModel: models.BaseModel{ID: "link-report-parent-child"}, SchoolID: schoolID, ParentUserID: "parent-report-user", StudentID: birthdayStudentID, StudentAdmissionNumber: "ADM-REP-1"},
		&models.StaffAttendance{StaffID: teacherStaffID, Date: time.Date(2026, 6, 22, 0, 0, 0, 0, time.UTC), CheckIn: &now, Status: "present", Source: "qr"},
		&models.StaffAttendance{StaffID: teacherStaffID, Date: time.Date(2026, 6, 3, 0, 0, 0, 0, time.UTC), CheckIn: &now, Status: "present", Source: "qr"},
		&models.LessonPlanner{SchoolID: schoolID, TeacherID: teacherStaffID, GradeID: "grade-report", SectionID: "section-report", WeekStartDate: time.Date(2026, 6, 22, 0, 0, 0, 0, time.UTC), WeekEndDate: time.Date(2026, 6, 28, 23, 59, 0, 0, time.UTC), Status: models.LessonPlannerStatusUploaded},
	}
	for _, seed := range seeds {
		if err := database.DB.Create(seed).Error; err != nil {
			t.Fatalf("seed %T: %v", seed, err)
		}
	}
}
