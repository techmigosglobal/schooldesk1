package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"sort"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

const principalSubjectActionsResource = "principal/subject-actions"

type PrincipalSubjectsHandler struct{}

func NewPrincipalSubjectsHandler() *PrincipalSubjectsHandler {
	return &PrincipalSubjectsHandler{}
}

type principalSubjectScoreMetric struct {
	SubjectID    string  `json:"subject_id"`
	AverageScore float64 `json:"average_score"`
	MarksCount   int64   `json:"marks_count"`
	WeakCount    int64   `json:"weak_count"`
}

type principalSubjectHomeworkMetric struct {
	SubjectKey string `json:"subject_key"`
	Total      int64  `json:"total"`
	Completed  int64  `json:"completed"`
	Pending    int64  `json:"pending"`
}

type principalSubjectTopperRow struct {
	SubjectID    string  `json:"subject_id"`
	StudentID    string  `json:"student_id"`
	FirstName    string  `json:"first_name"`
	LastName     string  `json:"last_name"`
	Marks        float64 `json:"marks"`
	MaxMarks     float64 `json:"max_marks"`
	GradeName    string  `json:"grade_name"`
	SectionName  string  `json:"section_name"`
	ExamName     string  `json:"exam_name"`
	ExamSchedule string  `json:"exam_schedule_id"`
}

type principalSubjectCoverage struct {
	SubjectID string
	GradeID   string
	Label     string
}

type principalSubjectTeacher struct {
	SubjectID   string
	GradeID     string
	GradeName   string
	SectionID   string
	SectionName string
	StaffID     string
	Name        string
	Email       string
	IsPrimary   bool
}

type principalSubjectSyllabusMetric struct {
	Total     int64
	Completed int64
}

func (h *PrincipalSubjectsHandler) Overview(c *gin.Context) {
	schoolID := scopedSchoolID(c)

	var subjects []models.Subject
	if err := database.DB.
		Preload("Department").
		Where("school_id = ?", schoolID).
		Order("subject_name ASC").
		Find(&subjects).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load principal subjects")
		return
	}

	coverage := subjectCoverageMap(schoolID)
	teachers := subjectTeacherMap(schoolID)
	scores := subjectScoreMap(schoolID)
	homework := subjectHomeworkMap(schoolID)
	syllabus := subjectSyllabusMap(schoolID, subjects)
	latestActions := recentSubjectActions(schoolID)

	subjectCards := make([]gin.H, 0, len(subjects))
	totalTeacherIDs := map[string]bool{}
	totalClasses := map[string]bool{}
	totalPendingSyllabus := 0.0
	weakSubjects := int64(0)
	for _, subject := range subjects {
		subjectID := subject.ID
		subjectName := strings.TrimSpace(subject.SubjectName)
		subjectKey := normalizedSubjectKey(subjectName)
		subjectCoverage := coverage[subjectID]
		subjectTeachers := teachers[subjectID]
		score := scores[subjectID]
		homeworkMetric := homework[subjectKey]
		syllabusMetric := syllabus[subjectID]
		pendingSyllabus := subjectPendingSyllabusPercent(syllabusMetric)
		if len(subjects) > 0 {
			totalPendingSyllabus += pendingSyllabus
		}
		if score.WeakCount > 0 || pendingSyllabus >= 50 {
			weakSubjects++
		}

		teacherRows := make([]gin.H, 0, len(subjectTeachers))
		for _, teacher := range subjectTeachers {
			totalTeacherIDs[teacher.StaffID] = true
			teacherRows = append(teacherRows, gin.H{
				"id":           teacher.StaffID,
				"name":         firstNonEmpty(teacher.Name, teacher.Email, "Teacher"),
				"email":        teacher.Email,
				"grade_id":     teacher.GradeID,
				"grade_name":   teacher.GradeName,
				"section_id":   teacher.SectionID,
				"section_name": teacher.SectionName,
				"is_primary":   teacher.IsPrimary,
			})
		}
		teacherCoverageRows := principalSubjectTeacherCoverageRows(subjectTeachers)

		classRows := make([]gin.H, 0, len(subjectCoverage))
		for _, row := range subjectCoverage {
			totalClasses[row.GradeID] = true
			classRows = append(classRows, gin.H{
				"grade_id": row.GradeID,
				"name":     row.Label,
			})
		}

		subjectCards = append(subjectCards, gin.H{
			"subject_id":                  subjectID,
			"subject_name":                subjectName,
			"subject_code":                subject.SubjectCode,
			"subject_type":                subject.SubjectType,
			"subject_color":               subject.SubjectColor,
			"department":                  principalDepartmentName(subject.Department),
			"assigned_teachers":           teacherRows,
			"assigned_teacher_count":      len(teacherRows),
			"teacher_class_coverage":      teacherCoverageRows,
			"classes_covered":             classRows,
			"classes_covered_count":       len(classRows),
			"average_student_score":       score.AverageScore,
			"marks_count":                 score.MarksCount,
			"weak_student_count":          score.WeakCount,
			"pending_syllabus_percent":    pendingSyllabus,
			"syllabus_completion_percent": 100 - pendingSyllabus,
			"syllabus_topics_total":       syllabusMetric.Total,
			"syllabus_topics_completed":   syllabusMetric.Completed,
			"homework_consistency":        subjectHomeworkConsistency(homeworkMetric),
			"homework_total":              homeworkMetric.Total,
			"homework_pending":            homeworkMetric.Pending,
			"latest_action":               latestActions[subjectID],
		})
	}

	sort.SliceStable(subjectCards, func(i, j int) bool {
		leftWeak := subjectCards[i]["weak_student_count"].(int64)
		rightWeak := subjectCards[j]["weak_student_count"].(int64)
		if leftWeak != rightWeak {
			return leftWeak > rightWeak
		}
		leftPending := subjectCards[i]["pending_syllabus_percent"].(float64)
		rightPending := subjectCards[j]["pending_syllabus_percent"].(float64)
		if leftPending != rightPending {
			return leftPending > rightPending
		}
		return subjectCards[i]["subject_name"].(string) < subjectCards[j]["subject_name"].(string)
	})

	avgPending := 0.0
	if len(subjects) > 0 {
		avgPending = totalPendingSyllabus / float64(len(subjects))
	}

	success(c, http.StatusOK, gin.H{
		"summary": gin.H{
			"total_subjects":           len(subjects),
			"assigned_teacher_count":   len(totalTeacherIDs),
			"classes_covered_count":    len(totalClasses),
			"average_pending_syllabus": avgPending,
			"weak_subjects":            weakSubjects,
		},
		"subjects":        subjectCards,
		"teacher_options": principalSubjectTeacherOptions(schoolID),
		"grade_options":   principalSubjectGradeOptions(schoolID),
		"analytics": gin.H{
			"subject_toppers":             subjectToppers(schoolID),
			"weak_subjects":               topSubjectMetric(subjectCards, "weak_student_count"),
			"syllabus_completion_tracker": syllabusTracker(subjectCards),
			"teacher_performance":         teacherPerformance(subjectCards),
			"teacher_class_coverage":      subjectTeacherCoverageAnalytics(subjectCards),
			"homework_consistency":        homeworkConsistencyRows(subjectCards),
		},
	}, "")
}

func (h *PrincipalSubjectsHandler) CreateAction(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	subjectID := strings.TrimSpace(c.Param("subject_id"))
	if subjectID == "" {
		fail(c, http.StatusBadRequest, "subject_id is required")
		return
	}

	var subject models.Subject
	if err := database.DB.First(&subject, "id = ? AND school_id = ?", subjectID, schoolID).Error; err != nil {
		fail(c, http.StatusNotFound, "Subject not found")
		return
	}

	var req struct {
		ActionType string `json:"action_type"`
		Title      string `json:"title"`
		Message    string `json:"message" binding:"required"`
		Priority   string `json:"priority"`
		TeacherID  string `json:"teacher_id"`
		GradeID    string `json:"grade_id"`
		DueDate    string `json:"due_date"`
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

	actionType := firstNonEmpty(strings.TrimSpace(req.ActionType), "corrective_action")
	priority := firstNonEmpty(strings.TrimSpace(req.Priority), "normal")
	payload := gin.H{
		"subject_id":     subject.ID,
		"subject_name":   subject.SubjectName,
		"action_type":    actionType,
		"title":          firstNonEmpty(strings.TrimSpace(req.Title), principalSubjectActionTitle(actionType)),
		"message":        message,
		"priority":       priority,
		"teacher_id":     strings.TrimSpace(req.TeacherID),
		"grade_id":       strings.TrimSpace(req.GradeID),
		"due_date":       strings.TrimSpace(req.DueDate),
		"status":         "open",
		"created_by":     c.GetString("user_id"),
		"created_at":     time.Now().UTC().Format(time.RFC3339),
		"target_route":   "/principal-subjects-screen",
		"principal_role": "subject_supervision",
	}

	if strings.EqualFold(actionType, "assign_teacher") && strings.TrimSpace(req.TeacherID) != "" && strings.TrimSpace(req.GradeID) != "" {
		assignment, err := upsertSubjectTeacherAssignment(schoolID, subject.ID, strings.TrimSpace(req.TeacherID), strings.TrimSpace(req.GradeID))
		if err != nil {
			fail(c, http.StatusBadRequest, err.Error())
			return
		}
		payload["assignment_id"] = assignment.ID
		payload["assignment_applied"] = true
	}

	encoded, err := json.Marshal(payload)
	if err != nil {
		fail(c, http.StatusBadRequest, "Invalid subject action payload")
		return
	}
	record := models.FrontendRecord{
		SchoolID:  schoolID,
		Resource:  principalSubjectActionsResource,
		Payload:   string(encoded),
		CreatedBy: c.GetString("user_id"),
	}
	if err := database.DB.Create(&record).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save subject action")
		return
	}

	auditAction(c, "principal/subjects", actionType, "frontend_records", &record.ID)
	response := frontendRecordResponse(record)
	for key, value := range payload {
		response[key] = value
	}
	success(c, http.StatusCreated, response, "Subject action saved")
}

func (h *PrincipalSubjectsHandler) SaveMapping(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	subjectID := strings.TrimSpace(c.Param("subject_id"))
	if subjectID == "" {
		fail(c, http.StatusBadRequest, "subject_id is required")
		return
	}

	var req struct {
		AcademicYearID string `json:"academic_year_id" binding:"required"`
		AssignmentID   string `json:"assignment_id"`
		GradeID        string `json:"grade_id" binding:"required"`
		SectionID      string `json:"section_id"`
		TeacherID      string `json:"teacher_id"`
		PeriodsPerWeek int    `json:"periods_per_week"`
		MaxMarks       int    `json:"max_marks"`
		PassMarks      int    `json:"pass_marks"`
		IsMandatory    *bool  `json:"is_mandatory"`
		IsPrimary      *bool  `json:"is_primary"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	gradeID := strings.TrimSpace(req.GradeID)
	academicYearID := strings.TrimSpace(req.AcademicYearID)
	sectionID := strings.TrimSpace(req.SectionID)
	teacherID := strings.TrimSpace(req.TeacherID)
	assignmentID := strings.TrimSpace(req.AssignmentID)
	if teacherID == "" && assignmentID != "" {
		fail(c, http.StatusBadRequest, "Select teacher for an existing assignment")
		return
	}
	if req.PeriodsPerWeek < 0 {
		fail(c, http.StatusBadRequest, "periods_per_week cannot be negative")
		return
	}
	maxMarks := req.MaxMarks
	if maxMarks <= 0 {
		maxMarks = 100
	}
	passMarks := req.PassMarks
	if passMarks <= 0 {
		passMarks = 35
	}
	isMandatory := true
	if req.IsMandatory != nil {
		isMandatory = *req.IsMandatory
	}
	isPrimary := true
	if req.IsPrimary != nil {
		isPrimary = *req.IsPrimary
	}

	var gradeSubject models.GradeSubject
	var assignment *models.StaffSubject
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		var subject models.Subject
		if err := tx.First(&subject, "id = ? AND school_id = ?", subjectID, schoolID).Error; err != nil {
			return errors.New("Subject not found")
		}
		var grade models.Grade
		if err := tx.First(&grade, "id = ? AND school_id = ?", gradeID, schoolID).Error; err != nil {
			return errors.New("Grade must belong to this school")
		}
		if sectionID != "" {
			var section models.Section
			if err := tx.
				Joins("JOIN grades ON grades.id = sections.grade_id").
				First(&section, "sections.id = ? AND sections.academic_year_id = ? AND sections.grade_id = ? AND grades.school_id = ?", sectionID, academicYearID, gradeID, schoolID).Error; err != nil {
				return errors.New("Section must belong to the selected grade")
			}
		}
		if teacherID != "" {
			var staff models.Staff
			if err := tx.First(&staff, "id = ? AND school_id = ? AND status = ?", teacherID, schoolID, "active").Error; err != nil {
				return errors.New("Teacher must be active staff in this school")
			}
		}

		err := tx.
			Joins("JOIN grades ON grades.id = grade_subjects.grade_id").
			Where("grades.school_id = ? AND grade_subjects.academic_year_id = ? AND grade_subjects.subject_id = ? AND grade_subjects.grade_id = ?", schoolID, academicYearID, subjectID, gradeID).
			First(&gradeSubject).Error
		if err == gorm.ErrRecordNotFound {
			gradeSubject = models.GradeSubject{
				SchoolID:       schoolID,
				AcademicYearID: academicYearID,
				GradeID:        gradeID,
				SubjectID:      subjectID,
				PeriodsPerWeek: req.PeriodsPerWeek,
				MaxMarks:       maxMarks,
				PassMarks:      passMarks,
				IsMandatory:    isMandatory,
			}
			if err := tx.Create(&gradeSubject).Error; err != nil {
				return err
			}
		} else if err != nil {
			return err
		} else {
			gradeSubject.SchoolID = schoolID
			gradeSubject.AcademicYearID = academicYearID
			gradeSubject.PeriodsPerWeek = req.PeriodsPerWeek
			gradeSubject.MaxMarks = maxMarks
			gradeSubject.PassMarks = passMarks
			gradeSubject.IsMandatory = isMandatory
			if err := tx.Save(&gradeSubject).Error; err != nil {
				return err
			}
		}

		if teacherID == "" {
			return nil
		}
		sectionPtr := optionalString(sectionID)
		var row models.StaffSubject
		if assignmentID != "" {
			if err := tx.
				Joins("JOIN staffs ON staffs.id = staff_subjects.staff_id").
				First(&row, "staff_subjects.id = ? AND staffs.school_id = ?", assignmentID, schoolID).Error; err != nil {
				return errors.New("Subject assignment not found")
			}
		} else {
			query := tx.
				Joins("JOIN staffs ON staffs.id = staff_subjects.staff_id").
				Where("staffs.school_id = ? AND staff_subjects.academic_year_id = ? AND staff_subjects.subject_id = ? AND staff_subjects.grade_id = ?", schoolID, academicYearID, subjectID, gradeID)
			if sectionID == "" {
				query = query.Where("staff_subjects.section_id IS NULL OR staff_subjects.section_id = ''")
			} else {
				query = query.Where("staff_subjects.section_id = ?", sectionID)
			}
			err := query.First(&row).Error
			if err != nil && err != gorm.ErrRecordNotFound {
				return err
			}
		}
		row.StaffID = teacherID
		row.SchoolID = schoolID
		row.AcademicYearID = academicYearID
		row.SubjectID = subjectID
		row.GradeID = gradeID
		row.SectionID = sectionPtr
		row.IsPrimary = isPrimary
		if row.ID == "" {
			if err := tx.Create(&row).Error; err != nil {
				return err
			}
		} else if err := tx.Save(&row).Error; err != nil {
			return err
		}
		assignment = &row
		return nil
	}); err != nil {
		status := http.StatusInternalServerError
		if strings.Contains(err.Error(), "not found") || strings.Contains(err.Error(), "belong") || strings.Contains(err.Error(), "Teacher") {
			status = http.StatusBadRequest
		}
		fail(c, status, err.Error())
		return
	}

	auditAction(c, "principal/subjects", "save_mapping", "grade_subjects", &gradeSubject.ID)
	response := gin.H{"grade_subject": gradeSubject}
	if assignment != nil {
		response["assignment"] = *assignment
	}
	success(c, http.StatusOK, response, "Subject mapping saved")
}

func subjectCoverageMap(schoolID string) map[string][]principalSubjectCoverage {
	var rows []models.GradeSubject
	_ = database.DB.
		Preload("Grade").
		Joins("JOIN grades ON grades.id = grade_subjects.grade_id").
		Where("grades.school_id = ?", schoolID).
		Find(&rows).Error
	result := map[string][]principalSubjectCoverage{}
	for _, row := range rows {
		result[row.SubjectID] = append(result[row.SubjectID], principalSubjectCoverage{
			SubjectID: row.SubjectID,
			GradeID:   row.GradeID,
			Label:     principalGradeName(row.Grade),
		})
	}
	return result
}

func subjectTeacherMap(schoolID string) map[string][]principalSubjectTeacher {
	var rows []models.StaffSubject
	_ = database.DB.
		Preload("Staff").
		Preload("Grade").
		Preload("Section").
		Joins("JOIN subjects ON subjects.id = staff_subjects.subject_id").
		Where("subjects.school_id = ?", schoolID).
		Find(&rows).Error
	result := map[string][]principalSubjectTeacher{}
	seen := map[string]bool{}
	for _, row := range rows {
		sectionID := ""
		if row.SectionID != nil {
			sectionID = strings.TrimSpace(*row.SectionID)
		}
		key := row.SubjectID + "|" + row.StaffID + "|" + row.GradeID + "|" + sectionID
		if seen[key] {
			continue
		}
		seen[key] = true
		result[row.SubjectID] = append(result[row.SubjectID], principalSubjectTeacher{
			SubjectID:   row.SubjectID,
			GradeID:     row.GradeID,
			GradeName:   principalGradeName(row.Grade),
			SectionID:   sectionID,
			SectionName: principalSectionName(row.Section),
			StaffID:     row.StaffID,
			Name:        principalTeacherName(row.Staff),
			Email:       principalStaffEmail(row.Staff),
			IsPrimary:   row.IsPrimary,
		})
	}
	return result
}

func principalSubjectTeacherCoverageRows(teachers []principalSubjectTeacher) []gin.H {
	type coverage struct {
		TeacherID   string
		TeacherName string
		Email       string
		Classes     []gin.H
		Seen        map[string]bool
		IsPrimary   bool
	}
	grouped := map[string]*coverage{}
	order := []string{}
	for _, teacher := range teachers {
		key := firstNonEmpty(teacher.StaffID, teacher.Email, teacher.Name)
		if key == "" {
			continue
		}
		row := grouped[key]
		if row == nil {
			row = &coverage{
				TeacherID:   teacher.StaffID,
				TeacherName: firstNonEmpty(teacher.Name, teacher.Email, "Teacher"),
				Email:       teacher.Email,
				Seen:        map[string]bool{},
			}
			grouped[key] = row
			order = append(order, key)
		}
		classKey := firstNonEmpty(teacher.GradeID, teacher.GradeName) + "|" + teacher.SectionID
		if classKey != "" && !row.Seen[classKey] {
			row.Seen[classKey] = true
			row.Classes = append(row.Classes, gin.H{
				"grade_id":     teacher.GradeID,
				"class_name":   firstNonEmpty(teacher.GradeName, "Class"),
				"section_id":   teacher.SectionID,
				"section_name": teacher.SectionName,
				"class_label":  principalClassSectionLabel(teacher.GradeName, teacher.SectionName),
			})
		}
		if teacher.IsPrimary {
			row.IsPrimary = true
		}
	}
	result := make([]gin.H, 0, len(order))
	for _, key := range order {
		row := grouped[key]
		classNames := make([]string, 0, len(row.Classes))
		for _, classRow := range row.Classes {
			classNames = append(classNames, firstNonEmpty(
				stringMapValue(classRow["class_label"]),
				stringMapValue(classRow["class_name"]),
			))
		}
		result = append(result, gin.H{
			"teacher_id":    row.TeacherID,
			"teacher_name":  row.TeacherName,
			"email":         row.Email,
			"class_count":   len(row.Classes),
			"classes":       row.Classes,
			"class_names":   classNames,
			"class_summary": strings.Join(classNames, ", "),
			"is_primary":    row.IsPrimary,
		})
	}
	sort.SliceStable(result, func(i, j int) bool {
		left := strings.ToLower(stringMapValue(result[i]["teacher_name"]))
		right := strings.ToLower(stringMapValue(result[j]["teacher_name"]))
		return left < right
	})
	return result
}

func subjectScoreMap(schoolID string) map[string]principalSubjectScoreMetric {
	var rows []principalSubjectScoreMetric
	_ = database.DB.Raw(`
		SELECT exam_schedules.subject_id AS subject_id,
			COALESCE(AVG(CASE
				WHEN exam_schedules.max_marks > 0 THEN (student_marks.marks_obtained / exam_schedules.max_marks) * 100
				ELSE student_marks.marks_obtained
			END), 0) AS average_score,
			COUNT(*) AS marks_count,
			COALESCE(SUM(CASE
				WHEN exam_schedules.max_marks > 0 AND (student_marks.marks_obtained / exam_schedules.max_marks) * 100 < 40 THEN 1
				WHEN exam_schedules.max_marks <= 0 AND student_marks.marks_obtained < 40 THEN 1
				ELSE 0
			END), 0) AS weak_count
		FROM student_marks
		JOIN exam_schedules ON exam_schedules.id = student_marks.exam_schedule_id
		JOIN exams ON exams.id = exam_schedules.exam_id
		WHERE exams.school_id = ? AND student_marks.is_absent = false AND student_marks.is_exempted = false
		GROUP BY exam_schedules.subject_id
	`, schoolID).Scan(&rows).Error
	result := map[string]principalSubjectScoreMetric{}
	for _, row := range rows {
		result[row.SubjectID] = row
	}
	return result
}

func subjectHomeworkMap(schoolID string) map[string]principalSubjectHomeworkMetric {
	var rows []principalSubjectHomeworkMetric
	_ = database.DB.Raw(`
		SELECT LOWER(TRIM(subject_id)) AS subject_key,
			COUNT(*) AS total,
			COALESCE(SUM(CASE WHEN LOWER(status) IN ('completed', 'reviewed', 'closed') THEN 1 ELSE 0 END), 0) AS completed,
			COALESCE(SUM(CASE WHEN LOWER(status) NOT IN ('completed', 'reviewed', 'closed') THEN 1 ELSE 0 END), 0) AS pending
		FROM homework
		WHERE school_id = ? AND TRIM(subject_id) <> ''
		GROUP BY LOWER(TRIM(subject_id))
	`, schoolID).Scan(&rows).Error
	result := map[string]principalSubjectHomeworkMetric{}
	for _, row := range rows {
		result[row.SubjectKey] = row
	}
	return result
}

func subjectSyllabusMap(schoolID string, subjects []models.Subject) map[string]principalSubjectSyllabusMetric {
	byID := map[string]string{}
	byName := map[string]string{}
	result := map[string]principalSubjectSyllabusMetric{}
	for _, subject := range subjects {
		byID[subject.ID] = subject.ID
		byName[normalizedSubjectKey(subject.SubjectName)] = subject.ID
		result[subject.ID] = principalSubjectSyllabusMetric{}
	}
	var rows []models.FrontendRecord
	_ = database.DB.
		Where("school_id = ? AND resource = ?", schoolID, "curriculum").
		Find(&rows).Error
	for _, row := range rows {
		payload := frontendPayload(row.Payload)
		subjectID := firstNonEmpty(
			stringMapValue(payload["subject_id"]),
			stringMapValue(payload["subjectId"]),
		)
		if subjectID == "" {
			subjectID = byName[normalizedSubjectKey(firstNonEmpty(
				stringMapValue(payload["subject"]),
				stringMapValue(payload["subject_name"]),
				stringMapValue(payload["name"]),
			))]
		}
		if subjectID == "" || byID[subjectID] == "" {
			continue
		}
		total, completed := syllabusTopicCounts(payload)
		metric := result[subjectID]
		metric.Total += total
		metric.Completed += completed
		result[subjectID] = metric
	}
	return result
}

func syllabusTopicCounts(payload gin.H) (int64, int64) {
	total := int64FromAny(payload["totalTopics"])
	if total == 0 {
		total = int64FromAny(payload["total_topics"])
	}
	completed := int64FromAny(payload["completed"])
	if completed == 0 {
		completed = int64FromAny(payload["completedTopics"])
	}
	topics, ok := payload["topics"].([]interface{})
	if ok && len(topics) > 0 {
		total = int64(len(topics))
		completed = 0
		for _, item := range topics {
			topic, ok := item.(map[string]interface{})
			if !ok {
				if typed, ok := item.(gin.H); ok {
					topic = map[string]interface{}(typed)
				}
			}
			if strings.EqualFold(stringMapValue(topic["status"]), "completed") {
				completed++
			}
		}
	}
	return total, completed
}

func subjectToppers(schoolID string) []gin.H {
	var rows []principalSubjectTopperRow
	_ = database.DB.Raw(`
		SELECT exam_schedules.subject_id AS subject_id,
			student_marks.student_id AS student_id,
			students.first_name AS first_name,
			students.last_name AS last_name,
			student_marks.marks_obtained AS marks,
			exam_schedules.max_marks AS max_marks,
			grades.grade_name AS grade_name,
			sections.section_name AS section_name,
			exams.exam_name AS exam_name,
			exam_schedules.id AS exam_schedule_id
		FROM student_marks
		JOIN students ON students.id = student_marks.student_id
		JOIN exam_schedules ON exam_schedules.id = student_marks.exam_schedule_id
		JOIN exams ON exams.id = exam_schedules.exam_id
		LEFT JOIN sections ON sections.id = exam_schedules.section_id
		LEFT JOIN grades ON grades.id = exam_schedules.grade_id
		WHERE exams.school_id = ? AND student_marks.is_absent = false AND student_marks.is_exempted = false
	`, schoolID).Scan(&rows).Error
	bySubject := map[string]principalSubjectTopperRow{}
	for _, row := range rows {
		if current, exists := bySubject[row.SubjectID]; !exists || subjectTopperScore(row) > subjectTopperScore(current) {
			bySubject[row.SubjectID] = row
		}
	}
	result := make([]gin.H, 0, len(bySubject))
	for _, row := range bySubject {
		result = append(result, gin.H{
			"subject_id":    row.SubjectID,
			"student_id":    row.StudentID,
			"student_name":  firstNonEmpty(strings.TrimSpace(row.FirstName+" "+row.LastName), "Student"),
			"score":         subjectTopperScore(row),
			"class_name":    firstNonEmpty(strings.TrimSpace(row.GradeName+" - "+row.SectionName), row.GradeName),
			"exam_name":     row.ExamName,
			"schedule_id":   row.ExamSchedule,
			"marks":         row.Marks,
			"maximum_marks": row.MaxMarks,
		})
	}
	sort.SliceStable(result, func(i, j int) bool {
		return result[i]["score"].(float64) > result[j]["score"].(float64)
	})
	if len(result) > 8 {
		return result[:8]
	}
	return result
}

func recentSubjectActions(schoolID string) map[string]gin.H {
	var rows []models.FrontendRecord
	_ = database.DB.
		Where("school_id = ? AND resource = ?", schoolID, principalSubjectActionsResource).
		Order("created_at DESC").
		Limit(100).
		Find(&rows).Error
	result := map[string]gin.H{}
	for _, row := range rows {
		payload := frontendRecordResponse(row)
		subjectID := stringMapValue(payload["subject_id"])
		if subjectID == "" {
			continue
		}
		if _, exists := result[subjectID]; !exists {
			result[subjectID] = payload
		}
	}
	return result
}

func principalSubjectTeacherOptions(schoolID string) []gin.H {
	var staff []models.Staff
	_ = database.DB.
		Where("school_id = ? AND (status = '' OR LOWER(status) = ?)", schoolID, "active").
		Order("first_name ASC, last_name ASC").
		Find(&staff).Error
	result := make([]gin.H, 0, len(staff))
	for _, row := range staff {
		result = append(result, gin.H{
			"id":          row.ID,
			"name":        firstNonEmpty(strings.TrimSpace(row.FirstName+" "+row.LastName), row.Email, "Staff"),
			"email":       row.Email,
			"designation": row.Designation,
		})
	}
	return result
}

func principalSubjectGradeOptions(schoolID string) []gin.H {
	var grades []models.Grade
	_ = database.DB.
		Where("school_id = ?", schoolID).
		Order("grade_number ASC, grade_name ASC").
		Find(&grades).Error
	result := make([]gin.H, 0, len(grades))
	for _, row := range grades {
		result = append(result, gin.H{
			"id":   row.ID,
			"name": principalGradeName(&row),
		})
	}
	return result
}

func topSubjectMetric(cards []gin.H, key string) []gin.H {
	rows := make([]gin.H, 0, len(cards))
	for _, card := range cards {
		value := float64FromAny(card[key])
		if value <= 0 {
			continue
		}
		rows = append(rows, gin.H{
			"subject_id":   card["subject_id"],
			"subject_name": card["subject_name"],
			"value":        value,
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return rows[i]["value"].(float64) > rows[j]["value"].(float64)
	})
	if len(rows) > 5 {
		return rows[:5]
	}
	return rows
}

func syllabusTracker(cards []gin.H) []gin.H {
	rows := make([]gin.H, 0, len(cards))
	for _, card := range cards {
		rows = append(rows, gin.H{
			"subject_id":             card["subject_id"],
			"subject_name":           card["subject_name"],
			"completion_percent":     card["syllabus_completion_percent"],
			"pending_percent":        card["pending_syllabus_percent"],
			"topics_total":           card["syllabus_topics_total"],
			"topics_completed":       card["syllabus_topics_completed"],
			"assigned_teacher_count": card["assigned_teacher_count"],
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return float64FromAny(rows[i]["pending_percent"]) > float64FromAny(rows[j]["pending_percent"])
	})
	return rows
}

func teacherPerformance(cards []gin.H) []gin.H {
	rows := []gin.H{}
	for _, card := range cards {
		teachers, _ := card["assigned_teachers"].([]gin.H)
		if teachers == nil {
			if list, ok := card["assigned_teachers"].([]interface{}); ok {
				for _, item := range list {
					if m, ok := item.(gin.H); ok {
						teachers = append(teachers, m)
					}
				}
			}
		}
		for _, teacher := range teachers {
			rows = append(rows, gin.H{
				"teacher_id":            teacher["id"],
				"teacher_name":          teacher["name"],
				"subject_id":            card["subject_id"],
				"subject_name":          card["subject_name"],
				"class_name":            teacher["grade_name"],
				"average_student_score": card["average_student_score"],
				"homework_consistency":  card["homework_consistency"],
			})
		}
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return float64FromAny(rows[i]["average_student_score"]) < float64FromAny(rows[j]["average_student_score"])
	})
	if len(rows) > 8 {
		return rows[:8]
	}
	return rows
}

func subjectTeacherCoverageAnalytics(cards []gin.H) []gin.H {
	rows := []gin.H{}
	for _, card := range cards {
		coverage, _ := card["teacher_class_coverage"].([]gin.H)
		if coverage == nil {
			if list, ok := card["teacher_class_coverage"].([]interface{}); ok {
				for _, item := range list {
					if m, ok := item.(gin.H); ok {
						coverage = append(coverage, m)
					}
				}
			}
		}
		for _, teacher := range coverage {
			rows = append(rows, gin.H{
				"subject_id":      card["subject_id"],
				"subject_name":    card["subject_name"],
				"teacher_id":      teacher["teacher_id"],
				"teacher_name":    teacher["teacher_name"],
				"class_count":     int64FromAny(teacher["class_count"]),
				"class_summary":   teacher["class_summary"],
				"average_score":   card["average_student_score"],
				"pending_percent": card["pending_syllabus_percent"],
			})
		}
	}
	sort.SliceStable(rows, func(i, j int) bool {
		left := int64FromAny(rows[i]["class_count"])
		right := int64FromAny(rows[j]["class_count"])
		if left != right {
			return left > right
		}
		return stringMapValue(rows[i]["teacher_name"]) < stringMapValue(rows[j]["teacher_name"])
	})
	if len(rows) > 8 {
		return rows[:8]
	}
	return rows
}

func homeworkConsistencyRows(cards []gin.H) []gin.H {
	rows := make([]gin.H, 0, len(cards))
	for _, card := range cards {
		if int64FromAny(card["homework_total"]) == 0 {
			continue
		}
		rows = append(rows, gin.H{
			"subject_id":       card["subject_id"],
			"subject_name":     card["subject_name"],
			"consistency":      card["homework_consistency"],
			"homework_total":   card["homework_total"],
			"homework_pending": card["homework_pending"],
		})
	}
	sort.SliceStable(rows, func(i, j int) bool {
		return float64FromAny(rows[i]["consistency"]) < float64FromAny(rows[j]["consistency"])
	})
	if len(rows) > 8 {
		return rows[:8]
	}
	return rows
}

func optionalString(value string) *string {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return nil
	}
	return &trimmed
}

func upsertSubjectTeacherAssignment(schoolID, subjectID, teacherID, gradeID string) (models.StaffSubject, error) {
	var assignment models.StaffSubject
	err := database.DB.Transaction(func(tx *gorm.DB) error {
		var year models.AcademicYear
		if err := tx.First(&year, "school_id = ? AND is_current = ?", schoolID, true).Error; err != nil {
			return errors.New("current academic year is required")
		}
		var staff models.Staff
		if err := tx.First(&staff, "id = ? AND school_id = ? AND status = ?", teacherID, schoolID, "active").Error; err != nil {
			return err
		}
		var grade models.Grade
		if err := tx.First(&grade, "id = ? AND school_id = ?", gradeID, schoolID).Error; err != nil {
			return err
		}
		var subject models.Subject
		if err := tx.First(&subject, "id = ? AND school_id = ?", subjectID, schoolID).Error; err != nil {
			return err
		}
		var gradeSubject models.GradeSubject
		err := tx.
			Joins("JOIN grades ON grades.id = grade_subjects.grade_id").
			Where("grades.school_id = ? AND grade_subjects.academic_year_id = ? AND grade_subjects.subject_id = ? AND grade_subjects.grade_id = ?", schoolID, year.ID, subjectID, gradeID).
			First(&gradeSubject).Error
		if err == gorm.ErrRecordNotFound {
			gradeSubject = models.GradeSubject{
				SchoolID:       schoolID,
				AcademicYearID: year.ID,
				GradeID:        gradeID,
				SubjectID:      subjectID,
				PeriodsPerWeek: 0,
				MaxMarks:       100,
				PassMarks:      35,
				IsMandatory:    true,
			}
			if err := tx.Create(&gradeSubject).Error; err != nil {
				return err
			}
		} else if err != nil {
			return err
		}
		err = tx.
			Joins("JOIN staffs ON staffs.id = staff_subjects.staff_id").
			Where("staffs.school_id = ? AND staff_subjects.academic_year_id = ? AND staff_subjects.subject_id = ? AND staff_subjects.grade_id = ? AND (staff_subjects.section_id IS NULL OR staff_subjects.section_id = '')", schoolID, year.ID, subjectID, gradeID).
			First(&assignment).Error
		if err == nil {
			assignment.SchoolID = schoolID
			assignment.AcademicYearID = year.ID
			assignment.StaffID = teacherID
			assignment.IsPrimary = true
			return tx.Save(&assignment).Error
		}
		if err != gorm.ErrRecordNotFound {
			return err
		}
		assignment = models.StaffSubject{
			SchoolID:       schoolID,
			AcademicYearID: year.ID,
			StaffID:        teacherID,
			SubjectID:      subjectID,
			GradeID:        gradeID,
			IsPrimary:      true,
		}
		return tx.Create(&assignment).Error
	})
	return assignment, err
}

func principalSubjectActionTitle(actionType string) string {
	switch strings.ToLower(strings.TrimSpace(actionType)) {
	case "assign_teacher":
		return "Assign or reassign teacher"
	case "review_reports":
		return "Review subject reports"
	case "schedule_meeting":
		return "Schedule subject meeting"
	case "view_materials":
		return "Review teaching materials"
	default:
		return "Subject corrective action"
	}
}

func principalDepartmentName(department *models.Department) string {
	if department == nil {
		return "General"
	}
	return firstNonEmpty(department.DepartmentName, "General")
}

func principalSectionName(section *models.Section) string {
	if section == nil {
		return ""
	}
	return strings.TrimSpace(section.SectionName)
}

func principalClassSectionLabel(gradeName, sectionName string) string {
	gradeName = strings.TrimSpace(gradeName)
	sectionName = strings.TrimSpace(sectionName)
	if gradeName == "" {
		gradeName = "Class"
	}
	if sectionName == "" {
		return gradeName
	}
	return gradeName + " - " + sectionName
}

func principalStaffEmail(staff *models.Staff) string {
	if staff == nil {
		return ""
	}
	return strings.TrimSpace(staff.Email)
}

func normalizedSubjectKey(value string) string {
	return strings.ToLower(strings.TrimSpace(value))
}

func subjectPendingSyllabusPercent(metric principalSubjectSyllabusMetric) float64 {
	if metric.Total <= 0 {
		return 100
	}
	completed := float64(metric.Completed)
	total := float64(metric.Total)
	if completed > total {
		completed = total
	}
	return 100 - ((completed / total) * 100)
}

func subjectHomeworkConsistency(metric principalSubjectHomeworkMetric) float64 {
	if metric.Total <= 0 {
		return 0
	}
	return (float64(metric.Completed) / float64(metric.Total)) * 100
}

func subjectTopperScore(row principalSubjectTopperRow) float64 {
	if row.MaxMarks <= 0 {
		return row.Marks
	}
	return (row.Marks / row.MaxMarks) * 100
}

func int64FromAny(value interface{}) int64 {
	switch typed := value.(type) {
	case int:
		return int64(typed)
	case int64:
		return typed
	case int32:
		return int64(typed)
	case float64:
		return int64(typed)
	case float32:
		return int64(typed)
	case json.Number:
		v, _ := typed.Int64()
		return v
	default:
		return 0
	}
}

func float64FromAny(value interface{}) float64 {
	switch typed := value.(type) {
	case float64:
		return typed
	case float32:
		return float64(typed)
	case int:
		return float64(typed)
	case int64:
		return float64(typed)
	case int32:
		return float64(typed)
	case json.Number:
		v, _ := typed.Float64()
		return v
	default:
		return 0
	}
}
