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

	refStaffAttendanceDailyReport      = "staff_attendance_daily_report"
	refStaffAttendanceMonthlyReport    = "staff_attendance_monthly_report"
	refLessonPlannerWeeklyDigest       = "lesson_planner_weekly_digest"
	refBirthdayWishStaff               = "birthday_wish_staff"
	refBirthdayWishStudent             = "birthday_wish_student"
	refBirthdayWishStudentForTeachers  = "birthday_wish_student_for_teachers"
	refBirthdayWishStudentForPrincipal = "birthday_wish_student_for_principal"
	refHealthReminder                  = "health_reminder"

	routePrincipalAttendance    = "/principal-attendance-screen"
	routePrincipalLessonPlanner = "/principal-lesson-planner-screen"
	routeTeacherDashboard       = "/teacher-dashboard-screen"
	routePrincipalDashboard     = "/principal-dashboard-screen"
	routeParentHome             = "/parent-home-screen"
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
	if local.Hour() == 8 && local.Minute() == 0 {
		if err := createBirthdayWishNotifications(local); err != nil {
			return err
		}
	}
	// Run health reminder notifications at 7:30 AM
	if local.Hour() == 7 && local.Minute() == 30 {
		if err := createHealthReminderNotifications(local); err != nil {
			return err
		}
	}
	return nil
}

func createBirthdayWishNotifications(local time.Time) error {
	date := time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, time.UTC)
	dateText := date.Format("2006-01-02")
	month := int(date.Month())
	day := date.Day()
	return forEachSchool(func(school models.School) error {
		if err := createStaffBirthdayWishNotifications(school.ID, month, day, dateText); err != nil {
			return err
		}
		if err := createStudentBirthdayWishNotifications(school.ID, month, day, dateText); err != nil {
			return err
		}
		if err := createStudentBirthdayForTeachersNotifications(school.ID, month, day, dateText, local); err != nil {
			return err
		}
		if err := createStudentBirthdayForPrincipalNotifications(school.ID, month, day, dateText); err != nil {
			return err
		}
		return nil
	})
}

func createStaffBirthdayWishNotifications(schoolID string, month, day int, dateText string) error {
	var recipients []struct {
		UserID      string
		Role        string
		Name        string
		DateOfBirth time.Time
	}
	err := database.DB.Table("users").
		Select("users.id as user_id, LOWER(users.role) as role, TRIM(COALESCE(staffs.first_name, '') || ' ' || COALESCE(staffs.last_name, '')) as name, staffs.date_of_birth as date_of_birth").
		Joins("JOIN staffs ON staffs.id = users.linked_id").
		Joins("LEFT JOIN roles ON roles.id = users.role_id").
		Where("users.school_id = ? AND users.is_active = ? AND users.linked_type = ?", schoolID, true, "staff").
		Where("LOWER(staffs.status) = ?", "active").
		Where("(LOWER(COALESCE(users.role, '')) IN (?, ?) OR LOWER(COALESCE(roles.role_name, '')) IN (?, ?))", "teacher", "principal", "teacher", "principal").
		Scan(&recipients).Error
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	for _, recipient := range recipients {
		if recipient.DateOfBirth.IsZero() || int(recipient.DateOfBirth.Month()) != month || recipient.DateOfBirth.Day() != day {
			continue
		}
		role := strings.ToLower(strings.TrimSpace(recipient.Role))
		if role != "principal" {
			role = "teacher"
		}
		name := strings.TrimSpace(recipient.Name)
		if name == "" {
			if role == "principal" {
				name = "Principal"
			} else {
				name = "Teacher"
			}
		}
		title := "Happy Birthday!"
		body := fmt.Sprintf("Warm birthday wishes, %s! Have a wonderful day.", name)
		route := routeTeacherDashboard
		if role == "principal" {
			route = routePrincipalDashboard
		}
		refID := schoolID + ":" + recipient.UserID + ":" + dateText
		log, created, err := createIdempotentNotificationLog(database.DB, models.NotificationLog{
			SchoolID:        schoolID,
			RecipientUserID: recipient.UserID,
			Channel:         "in_app",
			Title:           title,
			Body:            body,
			Category:        "event",
			Priority:        "medium",
			Route:           route,
			ReferenceType:   refBirthdayWishStaff,
			ReferenceID:     &refID,
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

func createStudentBirthdayWishNotifications(schoolID string, month, day int, dateText string) error {
	var rows []struct {
		UserID       string
		StudentID    string
		StudentName  string
		DateOfBirth  time.Time
	}
	err := database.DB.Table("parent_student_links").
		Select("parent_student_links.parent_user_id as user_id, students.id as student_id, TRIM(COALESCE(students.first_name, '') || ' ' || COALESCE(students.last_name, '')) as student_name, students.date_of_birth as date_of_birth").
		Joins("JOIN students ON students.id = parent_student_links.student_id").
		Joins("JOIN users ON users.id = parent_student_links.parent_user_id").
		Where("parent_student_links.school_id = ?", schoolID).
		Where("users.is_active = ?", true).
		Where("LOWER(COALESCE(students.status, 'active')) != ?", "inactive").
		Scan(&rows).Error
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	for _, row := range rows {
		if row.DateOfBirth.IsZero() || int(row.DateOfBirth.Month()) != month || row.DateOfBirth.Day() != day {
			continue
		}
		studentName := strings.TrimSpace(row.StudentName)
		if studentName == "" {
			studentName = "your child"
		}
		title := "Birthday wishes"
		body := fmt.Sprintf("Today is %s's birthday. Wishing a joyful day!", studentName)
		refID := schoolID + ":" + row.UserID + ":" + row.StudentID + ":" + dateText
		log, created, err := createIdempotentNotificationLog(database.DB, models.NotificationLog{
			SchoolID:        schoolID,
			RecipientUserID: row.UserID,
			Channel:         "in_app",
			Title:           title,
			Body:            body,
			Category:        "event",
			Priority:        "medium",
			Route:           routeParentHome,
			ReferenceType:   refBirthdayWishStudent,
			ReferenceID:     &refID,
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

func createStudentBirthdayForTeachersNotifications(schoolID string, month, day int, dateText string, local time.Time) error {
	var rows []struct {
		StudentID     string
		StudentName   string
		SectionID     string
		DateOfBirth   time.Time
	}
	err := database.DB.Table("students").
		Select("students.id as student_id, TRIM(COALESCE(students.first_name, '') || ' ' || COALESCE(students.last_name, '')) as student_name, students.current_section_id as section_id, students.date_of_birth as date_of_birth").
		Where("students.school_id = ? AND LOWER(COALESCE(students.status, 'active')) != ?", schoolID, "inactive").
		Scan(&rows).Error
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	seen := map[string]bool{}
	for _, row := range rows {
		if row.DateOfBirth.IsZero() || int(row.DateOfBirth.Month()) != month || row.DateOfBirth.Day() != day {
			continue
		}
		sectionID := strings.TrimSpace(row.SectionID)
		if sectionID == "" {
			continue
		}
		studentName := strings.TrimSpace(row.StudentName)
		if studentName == "" {
			studentName = "a student"
		}
		// Find all teacher users assigned to this section
		var teacherUsers []models.User
		err := database.DB.Model(&models.User{}).
			Joins("LEFT JOIN roles ON roles.id = users.role_id").
			Joins("LEFT JOIN timetable_slots ON timetable_slots.staff_id = users.linked_id AND timetable_slots.section_id = ?", sectionID).
			Joins("LEFT JOIN sections ON sections.class_teacher_id = users.linked_id AND sections.id = ?", sectionID).
			Where("users.school_id = ? AND users.is_active = ? AND users.linked_type = ?", schoolID, true, "staff").
			Where("(LOWER(users.role) = ? OR LOWER(roles.role_name) = ?)", "teacher", "teacher").
			Where("(timetable_slots.id IS NOT NULL OR sections.id IS NOT NULL)").
			Find(&teacherUsers).Error
		if err != nil {
			continue
		}
		age := 0
		if !row.DateOfBirth.IsZero() {
			age = local.Year() - row.DateOfBirth.Year()
		}
		ageText := ""
		if age > 0 {
			ageText = fmt.Sprintf(" turning %d", age)
		}
		for _, teacher := range teacherUsers {
			if strings.TrimSpace(teacher.ID) == "" {
				continue
			}
			key := teacher.ID + ":" + row.StudentID + ":" + dateText
			if seen[key] {
				continue
			}
			seen[key] = true
			title := "🎂 Student Birthday Today"
			body := fmt.Sprintf("Today is %s's birthday%s! Send your wishes and make their day special.", studentName, ageText)
			refID := schoolID + ":" + teacher.ID + ":" + row.StudentID + ":" + dateText
			nlog, created, err := createIdempotentNotificationLog(database.DB, models.NotificationLog{
				SchoolID:        schoolID,
				RecipientUserID: teacher.ID,
				Channel:         "in_app",
				Title:           title,
				Body:            body,
				Category:        "birthday",
				Priority:        "medium",
				Route:           routeTeacherDashboard,
				ReferenceType:   refBirthdayWishStudentForTeachers,
				ReferenceID:     &refID,
				IsRead:          false,
				SentAt:          now,
				DeliveryStatus:  "delivered",
				PushStatus:      "pending",
			})
			if err != nil {
				continue
			}
			if created {
				enqueueScheduledPushNotification(nlog)
			}
		}
	}
	return nil
}

func createStudentBirthdayForPrincipalNotifications(schoolID string, month, day int, dateText string) error {
	var rows []struct {
		StudentID    string
		StudentName  string
		ClassName    string
		DateOfBirth  time.Time
	}
	err := database.DB.Table("students").
		Select("students.id as student_id, TRIM(COALESCE(students.first_name, '') || ' ' || COALESCE(students.last_name, '')) as student_name, COALESCE(grades.grade_name || ' ' || sections.section_name, '') as class_name, students.date_of_birth as date_of_birth").
		Joins("LEFT JOIN sections ON sections.id = students.current_section_id").
		Joins("LEFT JOIN grades ON grades.id = sections.grade_id").
		Where("students.school_id = ? AND LOWER(COALESCE(students.status, 'active')) != ?", schoolID, "inactive").
		Scan(&rows).Error
	if err != nil {
		return err
	}
	now := time.Now().UTC()
	birthdayStudents := make([]struct {
		Name      string
		ClassName string
	}, 0)
	for _, row := range rows {
		if row.DateOfBirth.IsZero() || int(row.DateOfBirth.Month()) != month || row.DateOfBirth.Day() != day {
			continue
		}
		name := strings.TrimSpace(row.StudentName)
		if name == "" {
			continue
		}
		birthdayStudents = append(birthdayStudents, struct {
			Name      string
			ClassName string
		}{Name: name, ClassName: strings.TrimSpace(row.ClassName)})
	}
	if len(birthdayStudents) == 0 {
		return nil
	}
	var summary string
	if len(birthdayStudents) == 1 {
		cls := birthdayStudents[0].ClassName
		if cls != "" {
			summary = fmt.Sprintf("Today is %s's birthday (%s).", birthdayStudents[0].Name, cls)
		} else {
			summary = fmt.Sprintf("Today is %s's birthday.", birthdayStudents[0].Name)
		}
	} else {
		names := make([]string, 0, len(birthdayStudents))
		for _, s := range birthdayStudents {
			if len(names) >= 5 {
				names = append(names, fmt.Sprintf("and %d more", len(birthdayStudents)-5))
				break
			}
			names = append(names, s.Name)
		}
		summary = fmt.Sprintf("🎂 %d students have birthdays today: %s.", len(birthdayStudents), strings.Join(names, ", "))
	}
	principalUsers, err := principalUsers(schoolID)
	if err != nil {
		return err
	}
	for _, user := range principalUsers {
		if strings.TrimSpace(user.ID) == "" {
			continue
		}
		refID := schoolID + ":" + user.ID + ":" + dateText
		title := "🎂 Student Birthdays Today"
		nlog, created, err := createIdempotentNotificationLog(database.DB, models.NotificationLog{
			SchoolID:        schoolID,
			RecipientUserID: user.ID,
			Channel:         "in_app",
			Title:           title,
			Body:            summary,
			Category:        "birthday",
			Priority:        "medium",
			Route:           routePrincipalDashboard,
			ReferenceType:   refBirthdayWishStudentForPrincipal,
			ReferenceID:     &refID,
			IsRead:          false,
			SentAt:          now,
			DeliveryStatus:  "delivered",
			PushStatus:      "pending",
		})
		if err != nil {
			continue
		}
		if created {
			enqueueScheduledPushNotification(nlog)
		}
	}
	return nil
}

func createHealthReminderNotifications(local time.Time) error {
	return forEachSchool(func(school models.School) error {
		var records []models.MedicalRecord
		if err := database.DB.Joins("JOIN students ON students.id = medical_records.student_id").Where("students.school_id = ?", school.ID).Find(&records).Error; err != nil {
			return err
		}
		now := time.Now().UTC()
		seen := map[string]bool{}
		for _, record := range records {
			if strings.TrimSpace(record.StudentID) == "" {
				continue
			}
			conditions := strings.TrimSpace(record.Conditions)
			if conditions == "" {
				continue
			}
			// Find the student info
			var student models.Student
			if err := database.DB.Where("id = ? AND school_id = ?", record.StudentID, school.ID).First(&student).Error; err != nil {
				continue
			}
			studentName := strings.TrimSpace(student.FirstName + " " + student.LastName)
			if studentName == "" {
				continue
			}
			sectionID := ""
			if student.CurrentSectionID != nil {
				sectionID = strings.TrimSpace(*student.CurrentSectionID)
			}
			// Find teachers for this section
			var teacherUsers []models.User
			if sectionID != "" {
				err := database.DB.Model(&models.User{}).
					Joins("LEFT JOIN roles ON roles.id = users.role_id").
					Joins("LEFT JOIN timetable_slots ON timetable_slots.staff_id = users.linked_id AND timetable_slots.section_id = ?", sectionID).
					Joins("LEFT JOIN sections ON sections.class_teacher_id = users.linked_id AND sections.id = ?", sectionID).
					Where("users.school_id = ? AND users.is_active = ? AND users.linked_type = ?", school.ID, true, "staff").
					Where("(LOWER(users.role) = ? OR LOWER(roles.role_name) = ?)", "teacher", "teacher").
					Where("(timetable_slots.id IS NOT NULL OR sections.id IS NOT NULL)").
					Find(&teacherUsers).Error
				if err != nil {
					continue
				}
			}
			for _, teacher := range teacherUsers {
				if strings.TrimSpace(teacher.ID) == "" {
					continue
				}
				key := teacher.ID + ":health:" + record.StudentID + ":" + now.Format("2006-01-02")
				if seen[key] {
					continue
				}
				seen[key] = true
				title := "🏥 Health Alert: " + studentName
				body := fmt.Sprintf("Health condition reported for %s: %s", studentName, conditions)
				if strings.TrimSpace(record.Medications) != "" {
					body += fmt.Sprintf(". Medications: %s", strings.TrimSpace(record.Medications))
				}
				refID := school.ID + ":" + teacher.ID + ":health:" + record.StudentID + ":" + now.Format("2006-01-02")
				nlog, created, err := createIdempotentNotificationLog(database.DB, models.NotificationLog{
					SchoolID:        school.ID,
					RecipientUserID: teacher.ID,
					Channel:         "in_app",
					Title:           title,
					Body:            body,
					Category:        "health_alert",
					Priority:        "high",
					Route:           routeTeacherDashboard,
					ReferenceType:   refHealthReminder,
					ReferenceID:     &refID,
					IsRead:          false,
					SentAt:          now,
					DeliveryStatus:  "delivered",
					PushStatus:      "pending",
				})
				if err != nil {
					continue
				}
				if created {
					enqueueScheduledPushNotification(nlog)
				}
			}
		}
		return nil
	})
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
