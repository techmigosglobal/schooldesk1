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

func seedScheduledReportFixture(t *testing.T) {
	t.Helper()
	if err := database.SetupTestDB(); err != nil {
		t.Fatalf("setup db: %v", err)
	}
	schoolID := "school-report"
	principalRoleID := "role-report-principal"
	adminRoleID := "role-report-admin"
	teacherRoleID := "role-report-teacher"
	teacherStaffID := "staff-report-teacher"
	missingStaffID := "staff-report-missing"
	now := time.Date(2026, 6, 22, 9, 0, 0, 0, time.UTC)
	seeds := []any{
		&models.School{BaseModel: models.BaseModel{ID: schoolID}, Name: "Report School", SchoolType: "cbse"},
		&models.Role{BaseModel: models.BaseModel{ID: principalRoleID}, SchoolID: schoolID, RoleName: "Principal", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: adminRoleID}, SchoolID: schoolID, RoleName: "Admin", IsSystemRole: true},
		&models.Role{BaseModel: models.BaseModel{ID: teacherRoleID}, SchoolID: schoolID, RoleName: "Teacher", IsSystemRole: true},
		&models.User{BaseModel: models.BaseModel{ID: "principal-report-user"}, SchoolID: schoolID, Name: "Principal", Email: "principal@report.test", RoleID: principalRoleID, RoleSlug: "principal", PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "admin-report-user"}, SchoolID: schoolID, Name: "Admin", Email: "admin@report.test", RoleID: adminRoleID, RoleSlug: "admin", PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "teacher-report-user"}, SchoolID: schoolID, Name: "Teacher", Email: "teacher@report.test", RoleID: teacherRoleID, RoleSlug: "teacher", LinkedType: "staff", LinkedID: &teacherStaffID, PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.User{BaseModel: models.BaseModel{ID: "teacher-report-missing-user"}, SchoolID: schoolID, Name: "Missing Teacher", Email: "missing@report.test", RoleID: teacherRoleID, RoleSlug: "teacher", LinkedType: "staff", LinkedID: &missingStaffID, PasswordHash: "hash", IsActive: true, IsVerified: true},
		&models.Staff{BaseModel: models.BaseModel{ID: teacherStaffID}, SchoolID: schoolID, StaffCode: "REP-1", FirstName: "Report", LastName: "Teacher", Email: "teacher@report.test", DateOfBirth: now.AddDate(-32, 0, 0), Gender: "female", Designation: "Teacher", EmploymentType: "full-time", JoinDate: now.AddDate(-5, 0, 0), Status: "active"},
		&models.Staff{BaseModel: models.BaseModel{ID: missingStaffID}, SchoolID: schoolID, StaffCode: "REP-2", FirstName: "Missing", LastName: "Teacher", Email: "missing@report.test", DateOfBirth: now.AddDate(-32, 0, 0), Gender: "female", Designation: "Teacher", EmploymentType: "full-time", JoinDate: now.AddDate(-5, 0, 0), Status: "active"},
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
