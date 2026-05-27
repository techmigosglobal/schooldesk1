package handlers

import (
	"encoding/json"
	"net/http"
	"sort"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

const principalClassInstructionsResource = "principal/class-instructions"

type PrincipalClassesHandler struct{}

func NewPrincipalClassesHandler() *PrincipalClassesHandler {
	return &PrincipalClassesHandler{}
}

type principalSectionCount struct {
	SectionID string `json:"section_id"`
	Count     int64  `json:"count"`
}

type principalAttendanceMetric struct {
	SectionID string  `json:"section_id"`
	Present   float64 `json:"present"`
	Marked    float64 `json:"marked"`
	Sessions  int64   `json:"sessions"`
}

type principalFeeDueMetric struct {
	SectionID string  `json:"section_id"`
	Students  int64   `json:"students"`
	Balance   float64 `json:"balance"`
}

type principalTrendMetric struct {
	Day      string  `json:"day"`
	Present  float64 `json:"present"`
	Marked   float64 `json:"marked"`
	Sessions int64   `json:"sessions"`
}

func (h *PrincipalClassesHandler) Overview(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	now := time.Now()
	todayStart, todayEnd := dayRange(now)
	trendStart := todayStart.AddDate(0, 0, -6)

	var sections []models.Section
	if err := database.DB.
		Preload("Grade").
		Preload("ClassTeacher").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("grades.school_id = ?", schoolID).
		Order("grades.grade_number ASC, sections.section_name ASC").
		Find(&sections).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load principal classes")
		return
	}

	studentCounts := sectionCountMap(`
		SELECT current_section_id AS section_id, COUNT(*) AS count
		FROM students
		WHERE school_id = ? AND status != 'inactive' AND current_section_id IS NOT NULL
		GROUP BY current_section_id
	`, schoolID)

	todayAttendance := attendanceMetricMap(todayStart, todayEnd, schoolID)
	recentAttendance := attendanceMetricMap(trendStart, todayEnd, schoolID)
	homeworkPending := sectionCountMap(`
		SELECT section_id, COUNT(*) AS count
		FROM homework
		WHERE school_id = ? AND status NOT IN ('completed', 'reviewed', 'closed')
		GROUP BY section_id
	`, schoolID)
	weakPerformance := sectionCountMap(`
		SELECT enrollments.section_id AS section_id, COUNT(DISTINCT student_marks.student_id) AS count
		FROM student_marks
		JOIN enrollments ON enrollments.id = student_marks.enrollment_id
		JOIN students ON students.id = student_marks.student_id
		WHERE students.school_id = ? AND student_marks.is_absent = false AND student_marks.marks_obtained < 40
		GROUP BY enrollments.section_id
	`, schoolID)
	feeDues := feeDueMetricMap(schoolID)
	disciplineCounts, complaintCounts := issueCountsFromFrontendRecords(schoolID)
	recentInstructions := recentClassInstructions(schoolID)

	classCards := make([]gin.H, 0, len(sections))
	totalStudents := int64(0)
	totalIssues := int64(0)
	for _, section := range sections {
		sectionID := section.ID
		className := principalClassLabel(section)
		teacherName := principalTeacherName(section.ClassTeacher)
		students := studentCounts[sectionID]
		totalStudents += students
		today := todayAttendance[sectionID]
		recent := recentAttendance[sectionID]
		fees := feeDues[sectionID]
		discipline := disciplineCounts[sectionID]
		complaints := complaintCounts[sectionID]
		pendingIssues := homeworkPending[sectionID] + fees.Students + discipline + complaints
		totalIssues += pendingIssues

		classCards = append(classCards, gin.H{
			"section_id":             sectionID,
			"grade_id":               section.GradeID,
			"academic_year_id":       section.AcademicYearID,
			"class_name":             className,
			"section_name":           section.SectionName,
			"grade_name":             principalGradeName(section.Grade),
			"class_teacher_id":       section.ClassTeacherID,
			"class_teacher":          teacherName,
			"total_students":         students,
			"capacity":               section.Capacity,
			"attendance_percent":     attendancePercent(recent.Present, recent.Marked),
			"today_attendance_pct":   attendancePercent(today.Present, today.Marked),
			"today_status":           todayStatus(today),
			"today_present":          today.Present,
			"today_marked":           today.Marked,
			"attendance_sessions":    today.Sessions,
			"homework_pending":       homeworkPending[sectionID],
			"fees_due_students":      fees.Students,
			"fees_due_amount":        fees.Balance,
			"weak_performance_count": weakPerformance[sectionID],
			"discipline_issues":      discipline,
			"complaints_open":        complaints,
			"pending_issues":         pendingIssues,
			"latest_instruction":     recentInstructions[sectionID],
		})
	}

	sort.SliceStable(classCards, func(i, j int) bool {
		left := classCards[i]["pending_issues"].(int64)
		right := classCards[j]["pending_issues"].(int64)
		if left == right {
			return classCards[i]["class_name"].(string) < classCards[j]["class_name"].(string)
		}
		return left > right
	})

	success(c, http.StatusOK, gin.H{
		"summary": gin.H{
			"total_classes":       len(sections),
			"total_students":      totalStudents,
			"average_attendance":  averageAttendance(recentAttendance),
			"classes_with_issues": countClassesWithIssues(classCards),
			"pending_issues":      totalIssues,
		},
		"classes": classCards,
		"analytics": gin.H{
			"attendance_trend":          attendanceTrend(trendStart, todayEnd, schoolID),
			"weak_performing_classes":   topClassMetric(classCards, "weak_performance_count"),
			"discipline_issues":         topClassMetric(classCards, "discipline_issues"),
			"fee_defaulters_by_class":   topClassMetric(classCards, "fees_due_students"),
			"homework_pending_by_class": topClassMetric(classCards, "homework_pending"),
		},
	}, "")
}

func (h *PrincipalClassesHandler) CreateClass(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var req struct {
		GradeID        string `json:"grade_id"`
		GradeName      string `json:"grade_name"`
		GradeNumber    int    `json:"grade_number"`
		AcademicYearID string `json:"academic_year_id" binding:"required"`
		SectionName    string `json:"section_name" binding:"required"`
		Capacity       int    `json:"capacity" binding:"required"`
		ClassTeacherID string `json:"class_teacher_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	gradeID := strings.TrimSpace(req.GradeID)
	gradeName := strings.TrimSpace(req.GradeName)
	sectionName := strings.TrimSpace(req.SectionName)
	academicYearID := strings.TrimSpace(req.AcademicYearID)
	classTeacherIDValue := strings.TrimSpace(req.ClassTeacherID)
	if gradeID == "" && (gradeName == "" || req.GradeNumber <= 0) {
		fail(c, http.StatusBadRequest, "grade_name and grade_number are required for a new grade")
		return
	}
	if req.Capacity <= 0 {
		fail(c, http.StatusBadRequest, "capacity must be greater than zero")
		return
	}

	if !academicYearBelongsToSchool(academicYearID, schoolID) {
		fail(c, http.StatusBadRequest, "Academic year must belong to this school")
		return
	}
	var classTeacherID *string
	if classTeacherIDValue != "" {
		var staff models.Staff
		if err := database.DB.First(&staff, "id = ? AND school_id = ? AND status = ?", classTeacherIDValue, schoolID, "active").Error; err != nil {
			fail(c, http.StatusBadRequest, "Class teacher must be active staff in this school")
			return
		}
		classTeacherID = &classTeacherIDValue
	}

	var grade models.Grade
	if gradeID != "" {
		if err := database.DB.First(&grade, "id = ? AND school_id = ?", gradeID, schoolID).Error; err != nil {
			fail(c, http.StatusBadRequest, "Grade must belong to this school")
			return
		}
	} else {
		grade = models.Grade{
			SchoolID:    schoolID,
			GradeNumber: req.GradeNumber,
			GradeName:   gradeName,
		}
	}

	var section models.Section
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if grade.ID == "" {
			if err := tx.Create(&grade).Error; err != nil {
				return err
			}
		}
		section = models.Section{
			GradeID:        grade.ID,
			AcademicYearID: academicYearID,
			SectionName:    sectionName,
			Capacity:       req.Capacity,
			ClassTeacherID: classTeacherID,
		}
		if err := tx.Create(&section).Error; err != nil {
			return err
		}
		return tx.Preload("Grade").Preload("ClassTeacher").First(&section, "id = ?", section.ID).Error
	}); err != nil {
		fail(c, http.StatusInternalServerError, "Failed to create principal class")
		return
	}

	auditAction(c, "principal/classes", "create", "sections", &section.ID)
	success(c, http.StatusCreated, gin.H{
		"grade":   grade,
		"section": section,
	}, "Class created successfully")
}

func (h *PrincipalClassesHandler) CreateInstruction(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	sectionID := strings.TrimSpace(c.Param("section_id"))
	if sectionID == "" {
		fail(c, http.StatusBadRequest, "section_id is required")
		return
	}

	var section models.Section
	if err := database.DB.
		Preload("Grade").
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("sections.id = ? AND grades.school_id = ?", sectionID, schoolID).
		First(&section).Error; err != nil {
		fail(c, http.StatusNotFound, "Class section not found")
		return
	}

	var req struct {
		Title       string `json:"title"`
		Message     string `json:"message" binding:"required"`
		Type        string `json:"type"`
		Priority    string `json:"priority"`
		SendNotice  bool   `json:"send_notice"`
		TargetRoute string `json:"target_route"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	message := strings.TrimSpace(req.Message)
	if message == "" {
		fail(c, http.StatusBadRequest, "message is required")
		return
	}
	instructionType := firstNonEmpty(strings.TrimSpace(req.Type), "instruction")
	priority := firstNonEmpty(strings.TrimSpace(req.Priority), "normal")
	title := firstNonEmpty(strings.TrimSpace(req.Title), "Principal instruction")
	className := principalClassLabel(section)
	payload := gin.H{
		"title":          title,
		"message":        message,
		"type":           instructionType,
		"priority":       priority,
		"status":         "open",
		"section_id":     section.ID,
		"grade_id":       section.GradeID,
		"class_name":     className,
		"created_by":     c.GetString("user_id"),
		"created_at":     time.Now().UTC().Format(time.RFC3339),
		"target_route":   firstNonEmpty(strings.TrimSpace(req.TargetRoute), "/principal-classes-screen"),
		"notice_sent":    req.SendNotice,
		"principal_role": "supervision",
	}
	encoded, err := json.Marshal(payload)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid instruction payload")
		return
	}

	record := models.FrontendRecord{
		SchoolID:  schoolID,
		Resource:  principalClassInstructionsResource,
		Payload:   string(encoded),
		CreatedBy: c.GetString("user_id"),
	}
	if err := database.DB.Create(&record).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save class instruction")
		return
	}

	if req.SendNotice {
		announcement := models.Announcement{
			SchoolID:        schoolID,
			Title:           title,
			Content:         message,
			TargetAudience:  "class",
			TargetGradeID:   &section.GradeID,
			TargetSectionID: &section.ID,
			IsUrgent:        strings.EqualFold(priority, "urgent"),
			CreatedBy:       c.GetString("user_id"),
			PublishedAt:     time.Now(),
		}
		if err := database.DB.Create(&announcement).Error; err != nil {
			fail(c, http.StatusInternalServerError, "Instruction saved but notice could not be published")
			return
		}
		payload["announcement_id"] = announcement.ID
	}

	auditAction(c, "principal/classes", "instruction", "frontend_records", &record.ID)
	response := frontendRecordResponse(record)
	for key, value := range payload {
		response[key] = value
	}
	success(c, http.StatusCreated, response, "Class instruction saved")
}

func sectionCountMap(query string, schoolID string) map[string]int64 {
	var rows []principalSectionCount
	_ = database.DB.Raw(query, schoolID).Scan(&rows).Error
	result := map[string]int64{}
	for _, row := range rows {
		if strings.TrimSpace(row.SectionID) == "" {
			continue
		}
		result[row.SectionID] = row.Count
	}
	return result
}

func attendanceMetricMap(start, end time.Time, schoolID string) map[string]principalAttendanceMetric {
	var rows []principalAttendanceMetric
	_ = database.DB.Raw(`
		SELECT attendance_sessions.section_id AS section_id,
			COALESCE(SUM(attendance_sessions.present_count), 0) AS present,
			COALESCE(SUM(attendance_sessions.total_students), 0) AS marked,
			COUNT(*) AS sessions
		FROM attendance_sessions
		JOIN sections ON sections.id = attendance_sessions.section_id
		JOIN grades ON grades.id = sections.grade_id
		WHERE grades.school_id = ? AND attendance_sessions.date >= ? AND attendance_sessions.date < ?
		GROUP BY attendance_sessions.section_id
	`, schoolID, start, end).Scan(&rows).Error
	result := map[string]principalAttendanceMetric{}
	for _, row := range rows {
		result[row.SectionID] = row
	}
	return result
}

func feeDueMetricMap(schoolID string) map[string]principalFeeDueMetric {
	var rows []principalFeeDueMetric
	_ = database.DB.Raw(`
		SELECT students.current_section_id AS section_id,
			COUNT(DISTINCT students.id) AS students,
			COALESCE(SUM(fee_invoices.balance), 0) AS balance
		FROM fee_invoices
		JOIN students ON students.id = fee_invoices.student_id
		WHERE students.school_id = ? AND students.current_section_id IS NOT NULL AND fee_invoices.balance > 0
		GROUP BY students.current_section_id
	`, schoolID).Scan(&rows).Error
	result := map[string]principalFeeDueMetric{}
	for _, row := range rows {
		result[row.SectionID] = row
	}
	return result
}

func issueCountsFromFrontendRecords(schoolID string) (map[string]int64, map[string]int64) {
	discipline := map[string]int64{}
	complaints := map[string]int64{}
	var rows []models.FrontendRecord
	_ = database.DB.
		Where("school_id = ? AND resource IN ?", schoolID, []string{"discipline-incidents", "complaints"}).
		Find(&rows).Error
	for _, row := range rows {
		payload := frontendPayload(row.Payload)
		status := strings.ToLower(firstNonEmpty(stringMapValue(payload["status"]), "open"))
		if status == "closed" || status == "resolved" || status == "dismissed" {
			continue
		}
		sectionID := firstNonEmpty(
			stringMapValue(payload["section_id"]),
			stringMapValue(payload["class_section_id"]),
			stringMapValue(payload["target_section_id"]),
		)
		if strings.TrimSpace(sectionID) == "" {
			continue
		}
		if row.Resource == "discipline-incidents" {
			discipline[sectionID]++
		} else {
			complaints[sectionID]++
		}
	}
	return discipline, complaints
}

func recentClassInstructions(schoolID string) map[string]gin.H {
	var rows []models.FrontendRecord
	_ = database.DB.
		Where("school_id = ? AND resource = ?", schoolID, principalClassInstructionsResource).
		Order("created_at DESC").
		Limit(100).
		Find(&rows).Error
	result := map[string]gin.H{}
	for _, row := range rows {
		payload := frontendRecordResponse(row)
		sectionID := stringMapValue(payload["section_id"])
		if sectionID == "" {
			continue
		}
		if _, exists := result[sectionID]; !exists {
			result[sectionID] = payload
		}
	}
	return result
}

func attendanceTrend(start, end time.Time, schoolID string) []gin.H {
	var rows []principalTrendMetric
	_ = database.DB.Raw(`
		SELECT DATE(attendance_sessions.date) AS day,
			COALESCE(SUM(attendance_sessions.present_count), 0) AS present,
			COALESCE(SUM(attendance_sessions.total_students), 0) AS marked,
			COUNT(*) AS sessions
		FROM attendance_sessions
		JOIN sections ON sections.id = attendance_sessions.section_id
		JOIN grades ON grades.id = sections.grade_id
		WHERE grades.school_id = ? AND attendance_sessions.date >= ? AND attendance_sessions.date < ?
		GROUP BY DATE(attendance_sessions.date)
		ORDER BY DATE(attendance_sessions.date) ASC
	`, schoolID, start, end).Scan(&rows).Error
	byDay := map[string]principalTrendMetric{}
	for _, row := range rows {
		byDay[row.Day] = row
	}
	result := make([]gin.H, 0, 7)
	for cursor := start; cursor.Before(end); cursor = cursor.AddDate(0, 0, 1) {
		key := cursor.Format("2006-01-02")
		row := byDay[key]
		result = append(result, gin.H{
			"label":      cursor.Format("Mon"),
			"date":       key,
			"percentage": attendancePercent(row.Present, row.Marked),
			"sessions":   row.Sessions,
		})
	}
	return result
}

func topClassMetric(classCards []gin.H, key string) []gin.H {
	rows := make([]gin.H, 0, len(classCards))
	for _, card := range classCards {
		value, ok := card[key].(int64)
		if !ok || value <= 0 {
			continue
		}
		rows = append(rows, gin.H{
			"class_name": card["class_name"],
			"value":      value,
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return rows[i]["value"].(int64) > rows[j]["value"].(int64)
	})
	if len(rows) > 5 {
		return rows[:5]
	}
	return rows
}

func principalClassLabel(section models.Section) string {
	gradeName := principalGradeName(section.Grade)
	sectionName := strings.TrimSpace(section.SectionName)
	if gradeName == "" {
		gradeName = "Class"
	}
	if sectionName == "" {
		return gradeName
	}
	return gradeName + " - " + sectionName
}

func principalGradeName(grade *models.Grade) string {
	if grade == nil {
		return ""
	}
	return firstNonEmpty(strings.TrimSpace(grade.GradeName), "Grade")
}

func principalTeacherName(staff *models.Staff) string {
	if staff == nil {
		return "Not assigned"
	}
	name := strings.TrimSpace(staff.FirstName + " " + staff.LastName)
	return firstNonEmpty(name, strings.TrimSpace(staff.Email), "Not assigned")
}

func attendancePercent(present, marked float64) float64 {
	if marked <= 0 {
		return 0
	}
	return (present / marked) * 100
}

func todayStatus(metric principalAttendanceMetric) string {
	if metric.Sessions == 0 {
		return "Not marked"
	}
	pct := attendancePercent(metric.Present, metric.Marked)
	if metric.Marked <= 0 {
		return "No students marked"
	}
	if pct < 75 {
		return "Needs attention"
	}
	if pct < 90 {
		return "Review absentees"
	}
	return "On track"
}

func averageAttendance(metrics map[string]principalAttendanceMetric) float64 {
	var present float64
	var marked float64
	for _, row := range metrics {
		present += row.Present
		marked += row.Marked
	}
	return attendancePercent(present, marked)
}

func countClassesWithIssues(classCards []gin.H) int {
	count := 0
	for _, card := range classCards {
		if value, ok := card["pending_issues"].(int64); ok && value > 0 {
			count++
		}
	}
	return count
}
