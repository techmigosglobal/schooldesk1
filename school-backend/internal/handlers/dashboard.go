package handlers

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
)

type DashboardHandler struct{}

func NewDashboardHandler() *DashboardHandler {
	return &DashboardHandler{}
}

type feeSummary struct {
	TotalInvoiced float64 `json:"total_invoiced"`
	TotalPaid     float64 `json:"total_paid"`
	TotalBalance  float64 `json:"total_balance"`
	PendingCount  int64   `json:"pending_count"`
	PaidCount     int64   `json:"paid_count"`
	CollectionPct float64 `json:"collection_pct"`
}

type teacherClassSummary struct {
	ID          string `json:"id"`
	SectionName string `json:"section_name"`
	GradeName   string `json:"grade_name"`
}

type parentChildSummary struct {
	ID                string  `json:"id"`
	FirstName         string  `json:"first_name"`
	LastName          string  `json:"last_name"`
	AdmissionNumber   string  `json:"admission_number"`
	CurrentSectionID  *string `json:"current_section_id"`
	PendingFeeBalance float64 `json:"pending_fee_balance"`
	PendingInvoices   int64   `json:"pending_invoices"`
}

type principalOperationalGap struct {
	ID          string `json:"id"`
	Category    string `json:"category"`
	Severity    string `json:"severity"`
	Title       string `json:"title"`
	Message     string `json:"message"`
	ActionLabel string `json:"action_label"`
	Route       string `json:"route"`
	EntityType  string `json:"entity_type"`
	EntityID    string `json:"entity_id"`
	EntityLabel string `json:"entity_label"`
	Count       int64  `json:"count"`
}

func (h *DashboardHandler) Admin(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var row struct {
		TotalStudents     int64   `json:"total_students"`
		ActiveStudents    int64   `json:"active_students"`
		TotalStaff        int64   `json:"total_staff"`
		ActiveStaff       int64   `json:"active_staff"`
		TotalClasses      int64   `json:"total_classes"`
		PendingApprovals  int64   `json:"pending_approvals"`
		UnreadAlerts      int64   `json:"unread_alerts"`
		TotalInvoiced     float64 `json:"total_invoiced"`
		TotalPaid         float64 `json:"total_paid"`
		TotalBalance      float64 `json:"total_balance"`
		PendingInvoices   int64   `json:"pending_invoices"`
		PaidInvoices      int64   `json:"paid_invoices"`
		TodaySessions     int64   `json:"today_sessions"`
		TodayPresent      int64   `json:"today_present"`
		TodayMarked       int64   `json:"today_marked"`
		UpcomingExams     int64   `json:"upcoming_exams"`
		OpenConversations int64   `json:"open_conversations"`
	}
	todayStart, todayEnd := dayRange(time.Now())
	if err := database.DB.Raw(`
		SELECT
			(SELECT COUNT(*) FROM students WHERE school_id = ? AND status != 'inactive') AS total_students,
			(SELECT COUNT(*) FROM students WHERE school_id = ? AND status = 'active') AS active_students,
			(SELECT COUNT(*) FROM staffs WHERE school_id = ?) AS total_staff,
			(SELECT COUNT(*) FROM staffs WHERE school_id = ? AND status = 'active') AS active_staff,
			(SELECT COUNT(*) FROM sections JOIN grades ON grades.id = sections.grade_id WHERE grades.school_id = ?) AS total_classes,
			(SELECT COUNT(*) FROM leave_applications JOIN staffs ON staffs.id = leave_applications.staff_id WHERE staffs.school_id = ? AND leave_applications.status = 'pending') AS pending_approvals,
			(SELECT COUNT(*) FROM notification_logs WHERE school_id = ? AND is_read = false) AS unread_alerts,
			COALESCE((SELECT SUM(fee_invoices.net_amount) FROM fee_invoices JOIN students ON students.id = fee_invoices.student_id WHERE students.school_id = ? AND students.status != 'inactive'), 0) AS total_invoiced,
			COALESCE((SELECT SUM(fee_invoices.paid_amount) FROM fee_invoices JOIN students ON students.id = fee_invoices.student_id WHERE students.school_id = ? AND students.status != 'inactive'), 0) AS total_paid,
			COALESCE((SELECT SUM(fee_invoices.balance) FROM fee_invoices JOIN students ON students.id = fee_invoices.student_id WHERE students.school_id = ? AND students.status != 'inactive'), 0) AS total_balance,
			(SELECT COUNT(*) FROM fee_invoices JOIN students ON students.id = fee_invoices.student_id WHERE students.school_id = ? AND students.status != 'inactive' AND fee_invoices.status != 'paid') AS pending_invoices,
			(SELECT COUNT(*) FROM fee_invoices JOIN students ON students.id = fee_invoices.student_id WHERE students.school_id = ? AND students.status != 'inactive' AND fee_invoices.status = 'paid') AS paid_invoices,
			(SELECT COUNT(*) FROM attendance_sessions JOIN sections ON sections.id = attendance_sessions.section_id JOIN grades ON grades.id = sections.grade_id WHERE grades.school_id = ? AND attendance_sessions.date >= ? AND attendance_sessions.date < ?) AS today_sessions,
			COALESCE((SELECT SUM(attendance_sessions.present_count) FROM attendance_sessions JOIN sections ON sections.id = attendance_sessions.section_id JOIN grades ON grades.id = sections.grade_id WHERE grades.school_id = ? AND attendance_sessions.date >= ? AND attendance_sessions.date < ?), 0) AS today_present,
			COALESCE((SELECT SUM(attendance_sessions.total_students) FROM attendance_sessions JOIN sections ON sections.id = attendance_sessions.section_id JOIN grades ON grades.id = sections.grade_id WHERE grades.school_id = ? AND attendance_sessions.date >= ? AND attendance_sessions.date < ?), 0) AS today_marked,
			(SELECT COUNT(*) FROM exams WHERE school_id = ? AND start_date >= ?) AS upcoming_exams,
			(SELECT COUNT(*) FROM message_conversations WHERE school_id = ?) AS open_conversations
	`, schoolID, schoolID, schoolID, schoolID, schoolID, schoolID, schoolID, schoolID, schoolID, schoolID, schoolID, schoolID, schoolID, todayStart, todayEnd, schoolID, todayStart, todayEnd, schoolID, todayStart, todayEnd, schoolID, todayStart, schoolID).Scan(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load admin dashboard")
		return
	}
	success(c, http.StatusOK, gin.H{
		"role": "Admin",
		"metrics": gin.H{
			"students":           gin.H{"total": row.TotalStudents, "active": row.ActiveStudents},
			"staff":              gin.H{"total": row.TotalStaff, "active": row.ActiveStaff},
			"classes":            row.TotalClasses,
			"pending_approvals":  row.PendingApprovals,
			"unread_alerts":      row.UnreadAlerts,
			"upcoming_exams":     row.UpcomingExams,
			"open_conversations": row.OpenConversations,
		},
		"fees":             buildFeeSummary(row.TotalInvoiced, row.TotalPaid, row.TotalBalance, row.PendingInvoices, row.PaidInvoices),
		"today_attendance": buildAttendanceSummary(row.TodayPresent, row.TodayMarked, row.TodaySessions),
	}, "")
}

func (h *DashboardHandler) Principal(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var row struct {
		TotalStudents    int64   `json:"total_students"`
		TotalStaff       int64   `json:"total_staff"`
		TotalClasses     int64   `json:"total_classes"`
		PendingApprovals int64   `json:"pending_approvals"`
		UrgentNotices    int64   `json:"urgent_notices"`
		UpcomingEvents   int64   `json:"upcoming_events"`
		UpcomingExams    int64   `json:"upcoming_exams"`
		TotalInvoiced    float64 `json:"total_invoiced"`
		TotalPaid        float64 `json:"total_paid"`
		TotalBalance     float64 `json:"total_balance"`
		PendingInvoices  int64   `json:"pending_invoices"`
		PaidInvoices     int64   `json:"paid_invoices"`
		TodaySessions    int64   `json:"today_sessions"`
		TodayPresent     int64   `json:"today_present"`
		TodayMarked      int64   `json:"today_marked"`
	}
	todayStart, todayEnd := dayRange(time.Now())
	if err := database.DB.Raw(`
			SELECT
				(SELECT COUNT(*) FROM students WHERE school_id = ? AND status != 'inactive') AS total_students,
				(SELECT COUNT(*) FROM staffs WHERE school_id = ? AND status = 'active') AS total_staff,
				(SELECT COUNT(*) FROM sections JOIN grades ON grades.id = sections.grade_id WHERE grades.school_id = ?) AS total_classes,
				(SELECT COUNT(*) FROM announcements WHERE school_id = ? AND is_urgent = true) AS urgent_notices,
				(SELECT COUNT(*) FROM events WHERE school_id = ? AND start_date >= date(?)) AS upcoming_events,
				(SELECT COUNT(*) FROM exams WHERE school_id = ? AND start_date >= ?) AS upcoming_exams,
			COALESCE((SELECT SUM(fee_invoices.net_amount) FROM fee_invoices JOIN students ON students.id = fee_invoices.student_id WHERE students.school_id = ? AND students.status != 'inactive'), 0) AS total_invoiced,
			COALESCE((SELECT SUM(fee_invoices.paid_amount) FROM fee_invoices JOIN students ON students.id = fee_invoices.student_id WHERE students.school_id = ? AND students.status != 'inactive'), 0) AS total_paid,
			COALESCE((SELECT SUM(fee_invoices.balance) FROM fee_invoices JOIN students ON students.id = fee_invoices.student_id WHERE students.school_id = ? AND students.status != 'inactive'), 0) AS total_balance,
			(SELECT COUNT(*) FROM fee_invoices JOIN students ON students.id = fee_invoices.student_id WHERE students.school_id = ? AND students.status != 'inactive' AND fee_invoices.status != 'paid') AS pending_invoices,
			(SELECT COUNT(*) FROM fee_invoices JOIN students ON students.id = fee_invoices.student_id WHERE students.school_id = ? AND students.status != 'inactive' AND fee_invoices.status = 'paid') AS paid_invoices,
				(SELECT COUNT(*) FROM attendance_sessions JOIN sections ON sections.id = attendance_sessions.section_id JOIN grades ON grades.id = sections.grade_id WHERE grades.school_id = ? AND attendance_sessions.date >= ? AND attendance_sessions.date < ?) AS today_sessions,
				COALESCE((SELECT SUM(attendance_sessions.present_count) FROM attendance_sessions JOIN sections ON sections.id = attendance_sessions.section_id JOIN grades ON grades.id = sections.grade_id WHERE grades.school_id = ? AND attendance_sessions.date >= ? AND attendance_sessions.date < ?), 0) AS today_present,
				COALESCE((SELECT SUM(attendance_sessions.total_students) FROM attendance_sessions JOIN sections ON sections.id = attendance_sessions.section_id JOIN grades ON grades.id = sections.grade_id WHERE grades.school_id = ? AND attendance_sessions.date >= ? AND attendance_sessions.date < ?), 0) AS today_marked
		`, schoolID, schoolID, schoolID, schoolID, schoolID, todayStart, schoolID, todayStart, schoolID, schoolID, schoolID, schoolID, schoolID, schoolID, todayStart, todayEnd, schoolID, todayStart, todayEnd, schoolID, todayStart, todayEnd).Scan(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load principal dashboard")
		return
	}
	pendingApprovals, err := pendingPrincipalApprovalsCount(schoolID)
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load principal approvals")
		return
	}
	row.PendingApprovals = pendingApprovals
	operationalGaps, err := principalOperationalGaps(schoolID, todayStart, todayEnd)
	if err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load principal operational gaps")
		return
	}
	success(c, http.StatusOK, gin.H{
		"role": "Principal",
		"metrics": gin.H{
			"total_students":    row.TotalStudents,
			"total_staff":       row.TotalStaff,
			"total_classes":     row.TotalClasses,
			"pending_approvals": row.PendingApprovals,
			"operational_gaps":  len(operationalGaps),
			"urgent_notices":    row.UrgentNotices,
			"upcoming_events":   row.UpcomingEvents,
			"upcoming_exams":    row.UpcomingExams,
		},
		"fees":             buildFeeSummary(row.TotalInvoiced, row.TotalPaid, row.TotalBalance, row.PendingInvoices, row.PaidInvoices),
		"today_attendance": buildAttendanceSummary(row.TodayPresent, row.TodayMarked, row.TodaySessions),
		"operational_gaps": buildPrincipalOperationalGapSummary(operationalGaps),
	}, "")
}

func principalOperationalGaps(schoolID string, todayStart, todayEnd time.Time) ([]principalOperationalGap, error) {
	gaps := make([]principalOperationalGap, 0)
	if err := appendParentLinkGaps(&gaps, schoolID); err != nil {
		return nil, err
	}
	if err := appendClassTeacherGaps(&gaps, schoolID); err != nil {
		return nil, err
	}
	if err := appendFeeStructureGaps(&gaps, schoolID); err != nil {
		return nil, err
	}
	if err := appendSubjectCoverageGaps(&gaps, schoolID); err != nil {
		return nil, err
	}
	if err := appendSubjectTeacherGaps(&gaps, schoolID); err != nil {
		return nil, err
	}
	if err := appendTimetableGaps(&gaps, schoolID); err != nil {
		return nil, err
	}
	if err := appendUnassignedTeacherGaps(&gaps, schoolID); err != nil {
		return nil, err
	}
	if err := appendExamScheduleGaps(&gaps, schoolID, todayStart); err != nil {
		return nil, err
	}
	if err := appendTodayAttendanceGaps(&gaps, schoolID, todayStart, todayEnd); err != nil {
		return nil, err
	}
	if len(gaps) > 12 {
		gaps = gaps[:12]
	}
	return gaps, nil
}

func buildPrincipalOperationalGapSummary(gaps []principalOperationalGap) gin.H {
	critical := 0
	warning := 0
	info := 0
	for _, gap := range gaps {
		switch gap.Severity {
		case "critical":
			critical++
		case "info":
			info++
		default:
			warning++
		}
	}
	return gin.H{
		"total":    len(gaps),
		"critical": critical,
		"warning":  warning,
		"info":     info,
		"items":    gaps,
	}
}

type principalGapClassRow struct {
	SectionID   string
	GradeID     string
	GradeName   string
	SectionName string
	Count       int64
}

func appendParentLinkGaps(gaps *[]principalOperationalGap, schoolID string) error {
	var rows []principalGapClassRow
	if err := database.DB.Raw(`
		SELECT COALESCE(sections.id, '') AS section_id,
			COALESCE(grades.id, '') AS grade_id,
			COALESCE(grades.grade_name, 'Unassigned') AS grade_name,
			COALESCE(sections.section_name, 'No section') AS section_name,
			COUNT(students.id) AS count
		FROM students
		LEFT JOIN sections ON sections.id = students.current_section_id
		LEFT JOIN grades ON grades.id = sections.grade_id
		LEFT JOIN parent_student_links
			ON parent_student_links.student_id = students.id
			AND parent_student_links.school_id = students.school_id
		WHERE students.school_id = ?
			AND students.status != 'inactive'
			AND parent_student_links.id IS NULL
		GROUP BY sections.id, grades.id, grades.grade_name, sections.section_name
		ORDER BY count DESC, grades.grade_name ASC, sections.section_name ASC
		LIMIT 6
	`, schoolID).Scan(&rows).Error; err != nil {
		return err
	}
	for _, row := range rows {
		label := principalGapClassLabel(row.GradeName, row.SectionName)
		*gaps = append(*gaps, principalOperationalGap{
			ID:          "missing-parent-link:" + firstNonEmpty(row.SectionID, "unassigned"),
			Category:    "Guardians",
			Severity:    "critical",
			Title:       "Parent account link missing",
			Message:     pluralize(row.Count, "student") + " in " + label + " " + pluralVerb(row.Count, "has", "have") + " no linked parent login.",
			ActionLabel: "Link parent",
			Route:       "guardianDirectory",
			EntityType:  "section",
			EntityID:    row.SectionID,
			EntityLabel: label,
			Count:       row.Count,
		})
	}
	return nil
}

func appendClassTeacherGaps(gaps *[]principalOperationalGap, schoolID string) error {
	var rows []principalGapClassRow
	if err := database.DB.Raw(`
		SELECT sections.id AS section_id,
			grades.id AS grade_id,
			grades.grade_name AS grade_name,
			sections.section_name AS section_name,
			1 AS count
		FROM sections
		JOIN grades ON grades.id = sections.grade_id
		LEFT JOIN staffs
			ON staffs.id = sections.class_teacher_id
			AND staffs.school_id = grades.school_id
			AND (staffs.status = '' OR LOWER(staffs.status) = 'active')
		WHERE grades.school_id = ?
			AND (sections.class_teacher_id IS NULL OR sections.class_teacher_id = '' OR staffs.id IS NULL)
		ORDER BY grades.grade_number ASC, sections.section_name ASC
		LIMIT 6
	`, schoolID).Scan(&rows).Error; err != nil {
		return err
	}
	for _, row := range rows {
		label := principalGapClassLabel(row.GradeName, row.SectionName)
		*gaps = append(*gaps, principalOperationalGap{
			ID:          "missing-class-teacher:" + row.SectionID,
			Category:    "Classes",
			Severity:    "critical",
			Title:       "Class teacher not assigned",
			Message:     label + " has no active class teacher linked.",
			ActionLabel: "Assign teacher",
			Route:       "principalClasses",
			EntityType:  "section",
			EntityID:    row.SectionID,
			EntityLabel: label,
			Count:       1,
		})
	}
	return nil
}

func appendFeeStructureGaps(gaps *[]principalOperationalGap, schoolID string) error {
	var rows []principalGapClassRow
	if err := database.DB.Raw(`
		SELECT sections.id AS section_id,
			grades.id AS grade_id,
			grades.grade_name AS grade_name,
			sections.section_name AS section_name,
			1 AS count
		FROM sections
		JOIN grades ON grades.id = sections.grade_id
		LEFT JOIN fee_structures
			ON fee_structures.school_id = grades.school_id
			AND fee_structures.grade_id = sections.grade_id
			AND fee_structures.academic_year_id = sections.academic_year_id
		WHERE grades.school_id = ?
			AND fee_structures.id IS NULL
		GROUP BY sections.id, grades.id, grades.grade_name, sections.section_name, grades.grade_number
		ORDER BY grades.grade_number ASC, sections.section_name ASC
		LIMIT 6
	`, schoolID).Scan(&rows).Error; err != nil {
		return err
	}
	for _, row := range rows {
		label := principalGapClassLabel(row.GradeName, row.SectionName)
		*gaps = append(*gaps, principalOperationalGap{
			ID:          "missing-fee-structure:" + row.SectionID,
			Category:    "Fees",
			Severity:    "critical",
			Title:       "Fee structure missing",
			Message:     label + " has no fee structure for its academic year.",
			ActionLabel: "Create fees",
			Route:       "feeMonitoring",
			EntityType:  "section",
			EntityID:    row.SectionID,
			EntityLabel: label,
			Count:       1,
		})
	}
	return nil
}

func appendSubjectCoverageGaps(gaps *[]principalOperationalGap, schoolID string) error {
	var rows []principalGapClassRow
	if err := database.DB.Raw(`
		SELECT sections.id AS section_id,
			grades.id AS grade_id,
			grades.grade_name AS grade_name,
			sections.section_name AS section_name,
			1 AS count
		FROM sections
		JOIN grades ON grades.id = sections.grade_id
		WHERE grades.school_id = ?
			AND NOT EXISTS (
				SELECT 1 FROM grade_subjects
				WHERE grade_subjects.grade_id = grades.id
			)
		ORDER BY grades.grade_number ASC, sections.section_name ASC
		LIMIT 6
	`, schoolID).Scan(&rows).Error; err != nil {
		return err
	}
	for _, row := range rows {
		label := principalGapClassLabel(row.GradeName, row.SectionName)
		*gaps = append(*gaps, principalOperationalGap{
			ID:          "missing-subject-coverage:" + row.SectionID,
			Category:    "Subjects",
			Severity:    "warning",
			Title:       "Subject coverage missing",
			Message:     label + " has no subjects mapped to its grade.",
			ActionLabel: "Map subjects",
			Route:       "principalSubjects",
			EntityType:  "section",
			EntityID:    row.SectionID,
			EntityLabel: label,
			Count:       1,
		})
	}
	return nil
}

func appendSubjectTeacherGaps(gaps *[]principalOperationalGap, schoolID string) error {
	var rows []principalGapClassRow
	if err := database.DB.Raw(`
		SELECT sections.id AS section_id,
			grades.id AS grade_id,
			grades.grade_name AS grade_name,
			sections.section_name AS section_name,
			COUNT(DISTINCT grade_subjects.subject_id) AS count
		FROM sections
		JOIN grades ON grades.id = sections.grade_id
		JOIN grade_subjects ON grade_subjects.grade_id = grades.id
		WHERE grades.school_id = ?
			AND NOT EXISTS (
				SELECT 1
				FROM staff_subjects
				JOIN staffs ON staffs.id = staff_subjects.staff_id
				WHERE staffs.school_id = grades.school_id
					AND (staffs.status = '' OR LOWER(staffs.status) = 'active')
					AND staff_subjects.grade_id = grades.id
					AND staff_subjects.subject_id = grade_subjects.subject_id
					AND (
						staff_subjects.section_id IS NULL
						OR staff_subjects.section_id = ''
						OR staff_subjects.section_id = sections.id
					)
			)
		GROUP BY sections.id, grades.id, grades.grade_name, sections.section_name, grades.grade_number
		HAVING COUNT(DISTINCT grade_subjects.subject_id) > 0
		ORDER BY count DESC, grades.grade_number ASC, sections.section_name ASC
		LIMIT 6
	`, schoolID).Scan(&rows).Error; err != nil {
		return err
	}
	for _, row := range rows {
		label := principalGapClassLabel(row.GradeName, row.SectionName)
		*gaps = append(*gaps, principalOperationalGap{
			ID:          "missing-subject-teachers:" + row.SectionID,
			Category:    "Subjects",
			Severity:    "warning",
			Title:       "Subject teachers missing",
			Message:     pluralize(row.Count, "subject") + " in " + label + " " + pluralVerb(row.Count, "needs", "need") + " a teacher assignment.",
			ActionLabel: "Assign teachers",
			Route:       "principalSubjects",
			EntityType:  "section",
			EntityID:    row.SectionID,
			EntityLabel: label,
			Count:       row.Count,
		})
	}
	return nil
}

func appendTimetableGaps(gaps *[]principalOperationalGap, schoolID string) error {
	var rows []principalGapClassRow
	if err := database.DB.Raw(`
		SELECT sections.id AS section_id,
			grades.id AS grade_id,
			grades.grade_name AS grade_name,
			sections.section_name AS section_name,
			1 AS count
		FROM sections
		JOIN grades ON grades.id = sections.grade_id
		WHERE grades.school_id = ?
			AND NOT EXISTS (
				SELECT 1 FROM timetable_slots
				WHERE timetable_slots.section_id = sections.id
					AND timetable_slots.academic_year_id = sections.academic_year_id
			)
		ORDER BY grades.grade_number ASC, sections.section_name ASC
		LIMIT 6
	`, schoolID).Scan(&rows).Error; err != nil {
		return err
	}
	for _, row := range rows {
		label := principalGapClassLabel(row.GradeName, row.SectionName)
		*gaps = append(*gaps, principalOperationalGap{
			ID:          "missing-timetable:" + row.SectionID,
			Category:    "Timetable",
			Severity:    "warning",
			Title:       "Timetable not created",
			Message:     label + " has no timetable slots for its academic year.",
			ActionLabel: "Build timetable",
			Route:       "principalTimetable",
			EntityType:  "section",
			EntityID:    row.SectionID,
			EntityLabel: label,
			Count:       1,
		})
	}
	return nil
}

func appendUnassignedTeacherGaps(gaps *[]principalOperationalGap, schoolID string) error {
	var count int64
	if err := database.DB.Raw(`
		SELECT COUNT(*) AS count
		FROM staffs
		WHERE staffs.school_id = ?
			AND (staffs.status = '' OR LOWER(staffs.status) = 'active')
			AND LOWER(COALESCE(staffs.designation, '')) LIKE '%teacher%'
			AND NOT EXISTS (SELECT 1 FROM sections WHERE sections.class_teacher_id = staffs.id)
			AND NOT EXISTS (SELECT 1 FROM staff_subjects WHERE staff_subjects.staff_id = staffs.id)
			AND NOT EXISTS (SELECT 1 FROM timetable_slots WHERE timetable_slots.staff_id = staffs.id)
	`, schoolID).Scan(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		*gaps = append(*gaps, principalOperationalGap{
			ID:          "unassigned-teachers",
			Category:    "Staff",
			Severity:    "warning",
			Title:       "Teachers without assignments",
			Message:     pluralize(count, "active teacher") + " " + pluralVerb(count, "is", "are") + " not linked to a class, subject, or timetable.",
			ActionLabel: "Review staff",
			Route:       "staffManagement",
			EntityType:  "staff",
			EntityLabel: "Active teachers",
			Count:       count,
		})
	}
	return nil
}

func appendExamScheduleGaps(gaps *[]principalOperationalGap, schoolID string, todayStart time.Time) error {
	var rows []struct {
		ExamID   string
		ExamName string
		Count    int64
	}
	if err := database.DB.Raw(`
		SELECT exams.id AS exam_id,
			exams.exam_name AS exam_name,
			1 AS count
		FROM exams
		WHERE exams.school_id = ?
			AND exams.start_date >= ?
			AND NOT EXISTS (
				SELECT 1 FROM exam_schedules
				WHERE exam_schedules.exam_id = exams.id
			)
		ORDER BY exams.start_date ASC
		LIMIT 4
	`, schoolID, todayStart).Scan(&rows).Error; err != nil {
		return err
	}
	for _, row := range rows {
		label := firstNonEmpty(strings.TrimSpace(row.ExamName), "Upcoming exam")
		*gaps = append(*gaps, principalOperationalGap{
			ID:          "missing-exam-schedule:" + row.ExamID,
			Category:    "Exams",
			Severity:    "warning",
			Title:       "Exam schedule incomplete",
			Message:     label + " has no subject schedule yet.",
			ActionLabel: "Review exams",
			Route:       "principalExams",
			EntityType:  "exam",
			EntityID:    row.ExamID,
			EntityLabel: label,
			Count:       1,
		})
	}
	return nil
}

func appendTodayAttendanceGaps(gaps *[]principalOperationalGap, schoolID string, todayStart, todayEnd time.Time) error {
	dayOfWeek := int(todayStart.Weekday())
	if dayOfWeek == 0 {
		dayOfWeek = 7
	}
	var rows []principalGapClassRow
	if err := database.DB.Raw(`
		SELECT sections.id AS section_id,
			grades.id AS grade_id,
			grades.grade_name AS grade_name,
			sections.section_name AS section_name,
			COUNT(DISTINCT timetable_slots.id) AS count
		FROM sections
		JOIN grades ON grades.id = sections.grade_id
		JOIN timetable_slots
			ON timetable_slots.section_id = sections.id
			AND timetable_slots.academic_year_id = sections.academic_year_id
			AND timetable_slots.day_of_week = ?
		WHERE grades.school_id = ?
			AND EXISTS (
				SELECT 1 FROM students
				WHERE students.current_section_id = sections.id
					AND students.school_id = grades.school_id
					AND students.status != 'inactive'
			)
			AND NOT EXISTS (
				SELECT 1 FROM attendance_sessions
				WHERE attendance_sessions.section_id = sections.id
					AND attendance_sessions.date >= ?
					AND attendance_sessions.date < ?
			)
		GROUP BY sections.id, grades.id, grades.grade_name, sections.section_name, grades.grade_number
		ORDER BY count DESC, grades.grade_number ASC, sections.section_name ASC
		LIMIT 4
	`, dayOfWeek, schoolID, todayStart, todayEnd).Scan(&rows).Error; err != nil {
		return err
	}
	for _, row := range rows {
		label := principalGapClassLabel(row.GradeName, row.SectionName)
		*gaps = append(*gaps, principalOperationalGap{
			ID:          "attendance-unmarked:" + row.SectionID,
			Category:    "Attendance",
			Severity:    "info",
			Title:       "Attendance not marked today",
			Message:     label + " has scheduled classes today but no attendance session.",
			ActionLabel: "Check attendance",
			Route:       "principalAttendance",
			EntityType:  "section",
			EntityID:    row.SectionID,
			EntityLabel: label,
			Count:       row.Count,
		})
	}
	return nil
}

func principalGapClassLabel(gradeName, sectionName string) string {
	grade := strings.TrimSpace(gradeName)
	section := strings.TrimSpace(sectionName)
	if grade == "" {
		grade = "Class"
	}
	if section == "" || strings.EqualFold(section, "No section") {
		return grade
	}
	return grade + " " + section
}

func pluralize(count int64, singular string) string {
	if count == 1 {
		return "1 " + singular
	}
	label := strings.TrimSpace(strings.TrimSuffix(strings.TrimSpace(singular), "s")) + "s"
	return strconv.FormatInt(count, 10) + " " + label
}

func pluralVerb(count int64, singular, plural string) string {
	if count == 1 {
		return singular
	}
	return plural
}

var principalApprovalResources = []string{
	"account-approvals",
	"admissions/applications",
	"fees/concessions",
	"certificates/transfer-requests",
	"class-approvals",
	"student-approvals",
	"events/approvals",
	"timetable/approvals",
}

func pendingPrincipalApprovalsCount(schoolID string) (int64, error) {
	var leaveCount int64
	if err := database.DB.Model(&models.LeaveApplication{}).
		Joins("JOIN staffs ON staffs.id = leave_applications.staff_id").
		Where("staffs.school_id = ? AND leave_applications.status = ?", schoolID, "pending").
		Count(&leaveCount).Error; err != nil {
		return 0, err
	}

	var records []models.FrontendRecord
	if err := database.DB.
		Where("school_id = ? AND resource IN ?", schoolID, principalApprovalResources).
		Find(&records).Error; err != nil {
		return 0, err
	}

	total := leaveCount
	for _, row := range records {
		status := strings.ToLower(strings.TrimSpace(stringMapValue(frontendPayload(row.Payload)["status"])))
		if status == "" || status == "pending" {
			total++
		}
	}
	return total, nil
}

func (h *DashboardHandler) Teacher(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	staffID := dashboardStaffID(c)
	if staffID == "" {
		fail(c, http.StatusForbidden, "teacher staff linkage missing")
		return
	}
	todayStart, todayEnd := dayRange(time.Now())
	var row struct {
		AssignedClasses  int64 `json:"assigned_classes"`
		AssignedStudents int64 `json:"assigned_students"`
		TodaySessions    int64 `json:"today_sessions"`
		TodayPresent     int64 `json:"today_present"`
		TodayMarked      int64 `json:"today_marked"`
		HomeworkTotal    int64 `json:"homework_total"`
		HomeworkDue      int64 `json:"homework_due"`
		DiaryToday       int64 `json:"diary_today"`
		UnreadMessages   int64 `json:"unread_messages"`
	}
	if err := database.DB.Raw(`
		WITH assigned_sections AS (
			SELECT DISTINCT sections.id
			FROM sections
			JOIN grades ON grades.id = sections.grade_id
			LEFT JOIN timetable_slots ON timetable_slots.section_id = sections.id
			WHERE grades.school_id = ? AND (sections.class_teacher_id = ? OR timetable_slots.staff_id = ?)
		)
		SELECT
			(SELECT COUNT(*) FROM assigned_sections) AS assigned_classes,
			(SELECT COUNT(*) FROM students WHERE school_id = ? AND current_section_id IN (SELECT id FROM assigned_sections) AND status != 'inactive') AS assigned_students,
			(SELECT COUNT(*) FROM attendance_sessions WHERE staff_id = ? AND date >= ? AND date < ?) AS today_sessions,
			COALESCE((SELECT SUM(present_count) FROM attendance_sessions WHERE staff_id = ? AND date >= ? AND date < ?), 0) AS today_present,
			COALESCE((SELECT SUM(total_students) FROM attendance_sessions WHERE staff_id = ? AND date >= ? AND date < ?), 0) AS today_marked,
			(SELECT COUNT(*) FROM homework WHERE school_id = ? AND staff_id = ?) AS homework_total,
			(SELECT COUNT(*) FROM homework WHERE school_id = ? AND staff_id = ? AND submission_date >= ? AND status NOT IN ('completed', 'closed')) AS homework_due,
			(SELECT COUNT(*) FROM diary_entries WHERE school_id = ? AND teacher_id = ? AND entry_date >= ? AND entry_date < ?) AS diary_today,
			(SELECT COUNT(*) FROM messages JOIN message_conversations ON message_conversations.id = messages.conversation_id WHERE message_conversations.school_id = ? AND message_conversations.teacher_id = ? AND messages.sender_role = 'parent' AND messages.is_read = false) AS unread_messages
	`, schoolID, staffID, staffID, schoolID, staffID, todayStart, todayEnd, staffID, todayStart, todayEnd, staffID, todayStart, todayEnd, schoolID, staffID, schoolID, staffID, todayStart, schoolID, staffID, todayStart, todayEnd, schoolID, staffID).Scan(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load teacher dashboard")
		return
	}
	var classes []teacherClassSummary
	if err := database.DB.Raw(teacherAssignedClassesSQL(), schoolID, staffID, staffID).Scan(&classes).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load assigned classes")
		return
	}
	success(c, http.StatusOK, gin.H{
		"role":     "Teacher",
		"staff_id": staffID,
		"metrics": gin.H{
			"assigned_classes":    row.AssignedClasses,
			"assigned_students":   row.AssignedStudents,
			"homework_total":      row.HomeworkTotal,
			"homework_due":        row.HomeworkDue,
			"diary_entries_today": row.DiaryToday,
			"unread_messages":     row.UnreadMessages,
		},
		"today_attendance": buildAttendanceSummary(row.TodayPresent, row.TodayMarked, row.TodaySessions),
		"assigned_classes": classes,
	}, "")
}

func teacherAssignedClassesSQL() string {
	return `
		SELECT id, section_name, grade_name
		FROM (
			SELECT DISTINCT
				sections.id,
				sections.section_name,
				grades.grade_name,
				grades.grade_number
			FROM sections
			JOIN grades ON grades.id = sections.grade_id
			LEFT JOIN timetable_slots ON timetable_slots.section_id = sections.id
			WHERE grades.school_id = ? AND (sections.class_teacher_id = ? OR timetable_slots.staff_id = ?)
		) AS assigned_classes
		ORDER BY grade_number, section_name
	`
}

func (h *DashboardHandler) Parent(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	userID := c.GetString("user_id")
	var row struct {
		LinkedChildren    int64   `json:"linked_children"`
		AttendancePresent int64   `json:"attendance_present"`
		AttendanceMarked  int64   `json:"attendance_marked"`
		PendingFees       float64 `json:"pending_fees"`
		PendingInvoices   int64   `json:"pending_invoices"`
		HomeworkOpen      int64   `json:"homework_open"`
		UnreadMessages    int64   `json:"unread_messages"`
	}
	if err := database.DB.Raw(`
		WITH linked_students AS (
			SELECT parent_student_links.student_id
			FROM parent_student_links
			JOIN students ON students.id = parent_student_links.student_id
			WHERE parent_student_links.school_id = ? AND parent_student_links.parent_user_id = ?
				AND students.status != 'inactive'
		)
		SELECT
			(SELECT COUNT(*) FROM linked_students) AS linked_children,
			(SELECT COUNT(*) FROM student_attendances WHERE student_id IN (SELECT student_id FROM linked_students) AND LOWER(status) IN ('present', 'late')) AS attendance_present,
			(SELECT COUNT(*) FROM student_attendances WHERE student_id IN (SELECT student_id FROM linked_students)) AS attendance_marked,
			COALESCE((SELECT SUM(balance) FROM fee_invoices WHERE student_id IN (SELECT student_id FROM linked_students) AND status != 'paid'), 0) AS pending_fees,
			(SELECT COUNT(*) FROM fee_invoices WHERE student_id IN (SELECT student_id FROM linked_students) AND status != 'paid') AS pending_invoices,
			(SELECT COUNT(*) FROM homework WHERE school_id = ? AND section_id IN (
				SELECT current_section_id FROM students WHERE id IN (SELECT student_id FROM linked_students)
			) AND status NOT IN ('completed', 'closed')) AS homework_open,
			(SELECT COUNT(*) FROM messages JOIN message_conversations ON message_conversations.id = messages.conversation_id WHERE message_conversations.school_id = ? AND message_conversations.parent_id = ? AND messages.sender_role = 'teacher' AND messages.is_read = false) AS unread_messages
	`, schoolID, userID, schoolID, schoolID, userID).Scan(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load parent dashboard")
		return
	}
	var children []parentChildSummary
	if err := database.DB.Raw(`
		SELECT
			students.id,
			students.first_name,
			students.last_name,
			students.admission_number,
			students.current_section_id,
			COALESCE(SUM(CASE WHEN fee_invoices.status != 'paid' THEN fee_invoices.balance ELSE 0 END), 0) AS pending_fee_balance,
			COUNT(CASE WHEN fee_invoices.status != 'paid' THEN 1 END) AS pending_invoices
		FROM parent_student_links
		JOIN students ON students.id = parent_student_links.student_id
		LEFT JOIN fee_invoices ON fee_invoices.student_id = students.id
		WHERE parent_student_links.school_id = ? AND parent_student_links.parent_user_id = ? AND students.status != 'inactive'
		GROUP BY students.id, students.first_name, students.last_name, students.admission_number, students.current_section_id
		ORDER BY students.first_name, students.last_name
	`, schoolID, userID).Scan(&children).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load child summaries")
		return
	}
	success(c, http.StatusOK, gin.H{
		"role": "Parent",
		"metrics": gin.H{
			"linked_children":     row.LinkedChildren,
			"pending_fee_balance": row.PendingFees,
			"pending_invoices":    row.PendingInvoices,
			"open_homework":       row.HomeworkOpen,
			"unread_messages":     row.UnreadMessages,
		},
		"attendance": buildAttendanceSummary(row.AttendancePresent, row.AttendanceMarked, 0),
		"children":   children,
	}, "")
}

func buildFeeSummary(total, paid, balance float64, pendingCount, paidCount int64) feeSummary {
	pct := 0.0
	if total > 0 {
		pct = paid * 100 / total
	}
	return feeSummary{
		TotalInvoiced: total,
		TotalPaid:     paid,
		TotalBalance:  balance,
		PendingCount:  pendingCount,
		PaidCount:     paidCount,
		CollectionPct: pct,
	}
}

func buildAttendanceSummary(present, marked, sessions int64) gin.H {
	pct := 0.0
	if marked > 0 {
		pct = float64(present) * 100 / float64(marked)
	}
	return gin.H{
		"sessions":       sessions,
		"present":        present,
		"marked":         marked,
		"attendance_pct": pct,
	}
}

func dashboardStaffID(c *gin.Context) string {
	if !strings.EqualFold(strings.TrimSpace(c.GetString("linked_type")), "staff") {
		return ""
	}
	if linkedID := strings.TrimSpace(c.GetString("linked_id")); linkedID != "" {
		return linkedID
	}
	var user models.User
	if err := database.DB.First(&user, "id = ? AND school_id = ?", c.GetString("user_id"), scopedSchoolID(c)).Error; err != nil {
		return ""
	}
	if user.LinkedID != nil && strings.TrimSpace(*user.LinkedID) != "" {
		return strings.TrimSpace(*user.LinkedID)
	}
	var staff models.Staff
	if err := database.DB.First(&staff, "school_id = ? AND email = ?", scopedSchoolID(c), c.GetString("email")).Error; err != nil {
		return ""
	}
	return staff.ID
}

func dayRange(t time.Time) (time.Time, time.Time) {
	utc := t.UTC()
	start := time.Date(utc.Year(), utc.Month(), utc.Day(), 0, 0, 0, 0, time.UTC)
	return start, start.AddDate(0, 0, 1)
}
