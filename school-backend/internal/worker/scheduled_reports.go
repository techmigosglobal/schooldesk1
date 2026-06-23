package worker

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"
	"school-backend/internal/services"

	"gorm.io/gorm"
)

const (
	reportTimezone = "Asia/Kolkata"

	refStaffAttendanceDailyReport   = "staff_attendance_daily_report"
	refStaffAttendanceMonthlyReport = "staff_attendance_monthly_report"
	refLessonPlannerWeeklyDigest    = "lesson_planner_weekly_digest"

	routePrincipalAttendance    = "/principal-attendance-screen"
	routePrincipalLessonPlanner = "/principal-lesson-planner-screen"
)

func startScheduledPrincipalReportScheduler() {
	go func() {
		ticker := time.NewTicker(time.Minute)
		defer ticker.Stop()
		for {
			if err := runScheduledPrincipalReports(time.Now().UTC()); err != nil {
				log.Printf("scheduled principal report notification failed: %v", err)
			}
			<-ticker.C
		}
	}()
}

func runScheduledPrincipalReports(now time.Time) error {
	location, err := time.LoadLocation(reportTimezone)
	if err != nil {
		location = time.UTC
	}
	local := now.In(location)
	if local.Hour() == 18 && local.Minute() == 0 {
		if err := createDailyStaffAttendanceReportNotifications(local); err != nil {
			return err
		}
	}
	if local.Hour() == 18 && local.Minute() == 15 && isLastDayOfMonth(local) {
		if err := createMonthlyStaffAttendanceReportNotifications(local); err != nil {
			return err
		}
	}
	if local.Weekday() == time.Friday && local.Hour() == 18 && local.Minute() == 30 {
		if err := createWeeklyLessonPlannerDigestNotifications(local); err != nil {
			return err
		}
	}
	return nil
}

func createDailyStaffAttendanceReportNotifications(local time.Time) error {
	date := time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, time.UTC)
	dateText := date.Format("2006-01-02")
	start, end := date, date.AddDate(0, 0, 1)
	return forEachSchool(func(school models.School) error {
		totalStaff, presentStaff, err := staffAttendanceDailyCounts(school.ID, start, end)
		if err != nil {
			return err
		}
		title := "Daily staff attendance report"
		body := fmt.Sprintf("Staff attendance for %s: %d present, %d missing out of %d active staff.", date.Format("2 Jan 2006"), presentStaff, maxInt(totalStaff-presentStaff, 0), totalStaff)
		refID := school.ID + ":" + dateText
		return createPrincipalReportNotifications(
			school.ID,
			title,
			body,
			"attendance",
			refStaffAttendanceDailyReport,
			refID,
			routePrincipalAttendance,
		)
	})
}

func createMonthlyStaffAttendanceReportNotifications(local time.Time) error {
	monthStart := time.Date(local.Year(), local.Month(), 1, 0, 0, 0, 0, time.UTC)
	monthEnd := monthStart.AddDate(0, 1, 0)
	monthText := monthStart.Format("2006-01")
	return forEachSchool(func(school models.School) error {
		totalStaff, attendanceRecords, activeStaffWithRecords, err := staffAttendanceMonthlyCounts(school.ID, monthStart, monthEnd)
		if err != nil {
			return err
		}
		title := "Monthly staff attendance report"
		body := fmt.Sprintf("Staff attendance for %s: %d attendance records across %d of %d active staff.", monthStart.Format("January 2006"), attendanceRecords, activeStaffWithRecords, totalStaff)
		refID := school.ID + ":" + monthText
		return createPrincipalReportNotifications(
			school.ID,
			title,
			body,
			"attendance",
			refStaffAttendanceMonthlyReport,
			refID,
			routePrincipalAttendance,
		)
	})
}

func createWeeklyLessonPlannerDigestNotifications(local time.Time) error {
	weekStartLocal := startOfWeek(local)
	weekEndLocal := weekStartLocal.AddDate(0, 0, 7)
	weekStart := time.Date(weekStartLocal.Year(), weekStartLocal.Month(), weekStartLocal.Day(), 0, 0, 0, 0, time.UTC)
	weekEnd := time.Date(weekEndLocal.Year(), weekEndLocal.Month(), weekEndLocal.Day(), 0, 0, 0, 0, time.UTC)
	year, week := weekStartLocal.ISOWeek()
	return forEachSchool(func(school models.School) error {
		totalTeachers, submittedTeachers, err := weeklyLessonPlannerCounts(school.ID, weekStart, weekEnd)
		if err != nil {
			return err
		}
		title := "Weekly lesson planner summary"
		body := fmt.Sprintf("Lesson planners for week %d: %d submitted, %d missing out of %d teachers.", week, submittedTeachers, maxInt(totalTeachers-submittedTeachers, 0), totalTeachers)
		refID := fmt.Sprintf("%s:%04d-%02d", school.ID, year, week)
		return createPrincipalReportNotifications(
			school.ID,
			title,
			body,
			"academic",
			refLessonPlannerWeeklyDigest,
			refID,
			routePrincipalLessonPlanner,
		)
	})
}

func forEachSchool(fn func(models.School) error) error {
	var schools []models.School
	if err := database.DB.Find(&schools).Error; err != nil {
		return err
	}
	for _, school := range schools {
		if strings.TrimSpace(school.ID) == "" {
			continue
		}
		if err := fn(school); err != nil {
			return err
		}
	}
	return nil
}

func staffAttendanceDailyCounts(schoolID string, start, end time.Time) (int, int, error) {
	totalStaff, err := activeStaffCount(schoolID)
	if err != nil {
		return 0, 0, err
	}
	var rows []models.StaffAttendance
	if err := database.DB.Model(&models.StaffAttendance{}).
		Joins("JOIN staffs ON staffs.id = staff_attendances.staff_id").
		Where("staffs.school_id = ? AND staff_attendances.date >= ? AND staff_attendances.date < ?", schoolID, start, end).
		Find(&rows).Error; err != nil {
		return 0, 0, err
	}
	present := map[string]bool{}
	for _, row := range rows {
		if row.CheckIn != nil || strings.EqualFold(strings.TrimSpace(row.Status), "present") {
			present[row.StaffID] = true
		}
	}
	return totalStaff, len(present), nil
}

func staffAttendanceMonthlyCounts(schoolID string, start, end time.Time) (int, int, int, error) {
	totalStaff, err := activeStaffCount(schoolID)
	if err != nil {
		return 0, 0, 0, err
	}
	var rows []models.StaffAttendance
	if err := database.DB.Model(&models.StaffAttendance{}).
		Joins("JOIN staffs ON staffs.id = staff_attendances.staff_id").
		Where("staffs.school_id = ? AND staff_attendances.date >= ? AND staff_attendances.date < ?", schoolID, start, end).
		Find(&rows).Error; err != nil {
		return 0, 0, 0, err
	}
	staffWithRecords := map[string]bool{}
	for _, row := range rows {
		staffWithRecords[row.StaffID] = true
	}
	return totalStaff, len(rows), len(staffWithRecords), nil
}

func weeklyLessonPlannerCounts(schoolID string, start, end time.Time) (int, int, error) {
	teacherIDs, err := activeTeacherStaffIDs(schoolID)
	if err != nil {
		return 0, 0, err
	}
	if len(teacherIDs) == 0 {
		return 0, 0, nil
	}
	var planners []models.LessonPlanner
	if err := database.DB.
		Where("school_id = ? AND teacher_id IN ? AND week_start_date < ? AND week_end_date >= ?", schoolID, teacherIDs, end, start).
		Find(&planners).Error; err != nil {
		return 0, 0, err
	}
	submitted := map[string]bool{}
	for _, planner := range planners {
		submitted[planner.TeacherID] = true
	}
	return len(teacherIDs), len(submitted), nil
}

func activeStaffCount(schoolID string) (int, error) {
	var count int64
	err := database.DB.Model(&models.Staff{}).
		Where("school_id = ? AND LOWER(status) = ?", schoolID, "active").
		Count(&count).Error
	return int(count), err
}

func activeTeacherStaffIDs(schoolID string) ([]string, error) {
	var users []models.User
	if err := database.DB.Model(&models.User{}).
		Joins("LEFT JOIN roles ON roles.id = users.role_id").
		Where("users.school_id = ? AND users.is_active = ? AND users.linked_type = ?", schoolID, true, "staff").
		Where("(LOWER(users.role) = ? OR LOWER(roles.role_name) = ?)", "teacher", "teacher").
		Find(&users).Error; err != nil {
		return nil, err
	}
	ids := make([]string, 0, len(users))
	seen := map[string]bool{}
	for _, user := range users {
		if user.LinkedID == nil {
			continue
		}
		id := strings.TrimSpace(*user.LinkedID)
		if id == "" || seen[id] {
			continue
		}
		seen[id] = true
		ids = append(ids, id)
	}
	return ids, nil
}

func createPrincipalReportNotifications(schoolID, title, body, category, referenceType, referenceID, route string) error {
	users, err := principalUsers(schoolID)
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	for _, user := range users {
		if strings.TrimSpace(user.ID) == "" {
			continue
		}
		log, created, err := createIdempotentNotificationLog(database.DB, models.NotificationLog{
			SchoolID:        schoolID,
			RecipientUserID: user.ID,
			Channel:         "in_app",
			Title:           title,
			Body:            body,
			Category:        category,
			Priority:        "medium",
			Route:           route,
			ReferenceType:   referenceType,
			ReferenceID:     &referenceID,
			IsRead:          false,
			SentAt:          now,
			DeliveryStatus:  "delivered",
			PushStatus:      "pending",
		})
		if err != nil {
			return err
		}
		if created {
			enqueueScheduledPushNotification(log)
		}
	}
	return nil
}

func createIdempotentNotificationLog(tx *gorm.DB, log models.NotificationLog) (models.NotificationLog, bool, error) {
	if strings.TrimSpace(log.SchoolID) == "" ||
		strings.TrimSpace(log.RecipientUserID) == "" ||
		strings.TrimSpace(log.ReferenceType) == "" ||
		log.ReferenceID == nil ||
		strings.TrimSpace(*log.ReferenceID) == "" {
		return models.NotificationLog{}, false, nil
	}
	var existing models.NotificationLog
	err := tx.
		Where("school_id = ? AND recipient_user_id = ? AND reference_type = ? AND reference_id = ?", log.SchoolID, log.RecipientUserID, log.ReferenceType, *log.ReferenceID).
		First(&existing).Error
	if err == nil {
		return existing, false, nil
	}
	if err != nil && err != gorm.ErrRecordNotFound {
		return models.NotificationLog{}, false, err
	}
	if err := tx.Create(&log).Error; err != nil {
		return models.NotificationLog{}, false, err
	}
	return log, true, nil
}

func principalUsers(schoolID string) ([]models.User, error) {
	var users []models.User
	err := database.DB.Model(&models.User{}).
		Joins("LEFT JOIN roles ON roles.id = users.role_id").
		Where("users.school_id = ? AND users.is_active = ?", schoolID, true).
		Where("(LOWER(users.role) = ? OR LOWER(roles.role_name) = ?)", "principal", "principal").
		Find(&users).Error
	return users, err
}

func enqueueScheduledPushNotification(log models.NotificationLog) {
	if services.Queue == nil || strings.TrimSpace(log.ID) == "" {
		return
	}
	_ = services.Queue.Enqueue(context.Background(), "notifications", map[string]interface{}{
		"type":              "notification_push",
		"notification_id":   log.ID,
		"school_id":         log.SchoolID,
		"recipient_user_id": log.RecipientUserID,
	})
}

func startOfWeek(local time.Time) time.Time {
	dayOffset := (int(local.Weekday()) + 6) % 7
	start := local.AddDate(0, 0, -dayOffset)
	return time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, local.Location())
}

func isLastDayOfMonth(local time.Time) bool {
	return local.AddDate(0, 0, 1).Day() == 1
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}
