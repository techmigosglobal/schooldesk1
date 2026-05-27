package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type ExamHandler struct{}

func NewExamHandler() *ExamHandler {
	return &ExamHandler{}
}

func (h *ExamHandler) GetExamTypes(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var examTypes []models.ExamType
	query := database.DB.Preload("School")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	query.Find(&examTypes)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: examTypes})
}

func (h *ExamHandler) CreateExamType(c *gin.Context) {
	var req struct {
		SchoolID         string  `json:"school_id"`
		Name             string  `json:"name" binding:"required"`
		WeightagePercent float64 `json:"weightage_percent"`
		IsBoardExam      bool    `json:"is_board_exam"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	examType := models.ExamType{
		SchoolID:         scopedSchoolID(c),
		Name:             req.Name,
		WeightagePercent: req.WeightagePercent,
		IsBoardExam:      req.IsBoardExam,
	}

	if err := database.DB.Create(&examType).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create exam type"})
		return
	}

	id := examType.ID
	auditAction(c, "exams", "create", "exam_types", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: examType})
}

func (h *ExamHandler) GetExams(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	yearID := c.Query("academic_year_id")
	termID := c.Query("term_id")

	var exams []models.Exam
	query := database.DB.Preload("ExamType").Preload("AcademicYear").Preload("Term")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	if yearID != "" {
		query = query.Where("academic_year_id = ?", yearID)
	}
	if termID != "" {
		query = query.Where("term_id = ?", termID)
	}
	query.Find(&exams)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: exams})
}

func (h *ExamHandler) GetExam(c *gin.Context) {
	id := c.Param("id")
	var exam models.Exam
	if err := database.DB.Preload("ExamType").Preload("AcademicYear").Preload("Term").Preload("Schedules").Preload("Schedules.Subject").First(&exam, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Exam not found"})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: exam})
}

func (h *ExamHandler) CreateExam(c *gin.Context) {
	var req models.CreateExamRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	startDate, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "start_date must use YYYY-MM-DD")
		return
	}
	endDate, err := time.Parse("2006-01-02", req.EndDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "end_date must use YYYY-MM-DD")
		return
	}
	if endDate.Before(startDate) {
		fail(c, http.StatusBadRequest, "end_date cannot be before start_date")
		return
	}
	if err := validateExamRefs(c, req.AcademicYearID, req.TermID, req.ExamTypeID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	exam := models.Exam{
		SchoolID:       scopedSchoolID(c),
		AcademicYearID: req.AcademicYearID,
		TermID:         req.TermID,
		ExamTypeID:     req.ExamTypeID,
		ExamName:       req.ExamName,
		StartDate:      startDate,
		EndDate:        endDate,
		IsPublished:    false,
	}

	if err := database.DB.Create(&exam).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create exam"})
		return
	}

	id := exam.ID
	auditAction(c, "exams", "create", "exams", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: exam})
}

func (h *ExamHandler) UpdateExam(c *gin.Context) {
	id := c.Param("id")
	var exam models.Exam
	if err := database.DB.First(&exam, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "Exam not found")
		return
	}

	var req models.CreateExamRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	startDate, err := time.Parse("2006-01-02", req.StartDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "start_date must use YYYY-MM-DD")
		return
	}
	endDate, err := time.Parse("2006-01-02", req.EndDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "end_date must use YYYY-MM-DD")
		return
	}
	if endDate.Before(startDate) {
		fail(c, http.StatusBadRequest, "end_date cannot be before start_date")
		return
	}
	if err := validateExamRefs(c, req.AcademicYearID, req.TermID, req.ExamTypeID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	exam.AcademicYearID = req.AcademicYearID
	exam.TermID = req.TermID
	exam.ExamTypeID = req.ExamTypeID
	exam.ExamName = req.ExamName
	exam.StartDate = startDate
	exam.EndDate = endDate
	if err := database.DB.Save(&exam).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update exam")
		return
	}

	auditAction(c, "exams", "update", "exams", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: exam})
}

func (h *ExamHandler) PublishExam(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		IsPublished bool `json:"is_published"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	var exam models.Exam
	if err := database.DB.First(&exam, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		fail(c, http.StatusNotFound, "Exam not found")
		return
	}
	exam.IsPublished = req.IsPublished
	if err := database.DB.Save(&exam).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to update exam publish status")
		return
	}

	auditAction(c, "exams", "publish", "exams", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: exam})
}

func (h *ExamHandler) DeleteExam(c *gin.Context) {
	id := c.Param("id")
	schoolID := scopedSchoolID(c)
	var exam models.Exam
	if err := database.DB.First(&exam, "id = ? AND school_id = ?", id, schoolID).Error; err != nil {
		fail(c, http.StatusNotFound, "Exam not found")
		return
	}

	var schedCount int64
	database.DB.Model(&models.ExamSchedule{}).Where("exam_id = ?", id).Count(&schedCount)

	var markCount int64
	database.DB.Model(&models.StudentMark{}).
		Joins("JOIN exam_schedules es ON es.id = student_marks.exam_schedule_id").
		Where("es.exam_id = ?", id).
		Count(&markCount)
	if markCount > 0 {
		c.JSON(http.StatusConflict, gin.H{"error": fmt.Sprintf("Cannot delete: %d mark entries exist.", markCount)})
		return
	}

	var rcCount int64
	database.DB.Model(&models.ReportCard{}).Where("exam_id = ?", id).Count(&rcCount)
	if rcCount > 0 {
		c.JSON(http.StatusConflict, gin.H{"error": fmt.Sprintf("Cannot delete: %d report cards generated.", rcCount)})
		return
	}

	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if schedCount > 0 {
			if err := tx.Delete(&models.ExamSchedule{}, "exam_id = ?", id).Error; err != nil {
				return err
			}
		}
		return tx.Delete(&exam).Error
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete exam"})
		return
	}
	auditAction(c, "exams", "delete", "exams", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Exam and empty schedules deleted successfully", Data: gin.H{"id": id, "deleted_schedules": schedCount}})
}

func (h *ExamHandler) CreateExamSchedule(c *gin.Context) {
	var req struct {
		ExamID    string `json:"exam_id" binding:"required"`
		GradeID   string `json:"grade_id" binding:"required"`
		SectionID string `json:"section_id" binding:"required"`
		SubjectID string `json:"subject_id" binding:"required"`
		ExamDate  string `json:"exam_date" binding:"required"`
		StartTime string `json:"start_time"`
		EndTime   string `json:"end_time"`
		MaxMarks  int    `json:"max_marks" binding:"required"`
		PassMarks int    `json:"pass_marks" binding:"required"`
		RoomID    string `json:"room_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	examDate, err := time.Parse("2006-01-02", req.ExamDate)
	if err != nil {
		fail(c, http.StatusBadRequest, "exam_date must use YYYY-MM-DD")
		return
	}
	if req.MaxMarks <= 0 {
		fail(c, http.StatusBadRequest, "max_marks must be greater than zero")
		return
	}
	if req.PassMarks < 0 || req.PassMarks > req.MaxMarks {
		fail(c, http.StatusBadRequest, "pass_marks must be between zero and max_marks")
		return
	}
	if err := validateExamScheduleRefs(c, req.ExamID, req.GradeID, req.SectionID, req.SubjectID); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	schedule := models.ExamSchedule{
		ExamID:    req.ExamID,
		GradeID:   req.GradeID,
		SectionID: req.SectionID,
		SubjectID: req.SubjectID,
		ExamDate:  examDate,
		StartTime: req.StartTime,
		EndTime:   req.EndTime,
		MaxMarks:  req.MaxMarks,
		PassMarks: req.PassMarks,
	}

	if req.RoomID != "" {
		schedule.RoomID = &req.RoomID
	}

	if err := database.DB.Create(&schedule).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create exam schedule"})
		return
	}

	id := schedule.ID
	auditAction(c, "exams", "create", "exam_schedules", &id)
	createExamScheduleNotifications(schedule)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: schedule})
}

func computeGradeFromScale(db *gorm.DB, schoolID string, scheduleID string, marksObtained float64) (gradeLabel string, gpaPoints float64) {
	var schedule models.ExamSchedule
	if err := db.First(&schedule, "id = ?", scheduleID).Error; err != nil || schedule.MaxMarks == 0 {
		return "N/A", 0
	}
	pct := (marksObtained / float64(schedule.MaxMarks)) * 100
	var scale models.GradingScale
	if err := db.Where("school_id = ? AND min_percent <= ? AND max_percent >= ?", schoolID, pct, pct).
		First(&scale).Error; err != nil {
		return "N/A", 0
	}
	return scale.GradeLabel, scale.GPAPoints
}

func computeGradeLabel(db *gorm.DB, schoolID string, scheduleID string, marksObtained float64) string {
	gradeLabel, _ := computeGradeFromScale(db, schoolID, scheduleID, marksObtained)
	return gradeLabel
}

func regenerateReportCard(tx *gorm.DB, schoolID, studentID, examID, enrollmentID string) error {
	type markSummary struct {
		TotalObtained float64
		TotalMax      float64
	}

	var summary markSummary
	if err := tx.Raw(`
		SELECT
			COALESCE(SUM(sm.marks_obtained), 0) AS total_obtained,
			COALESCE(SUM(es.max_marks), 0)      AS total_max
		FROM student_marks sm
		JOIN exam_schedules es ON es.id = sm.exam_schedule_id
		WHERE sm.student_id = ? AND es.exam_id = ? AND sm.is_absent = false AND sm.is_exempted = false
	`, studentID, examID).Scan(&summary).Error; err != nil {
		return err
	}

	pct := 0.0
	if summary.TotalMax > 0 {
		pct = (summary.TotalObtained / summary.TotalMax) * 100
	}

	scale := models.GradingScale{GradeLabel: "N/A"}
	_ = tx.Where("school_id = ? AND min_percent <= ? AND max_percent >= ?", schoolID, pct, pct).
		First(&scale).Error

	now := time.Now().UTC()
	rc := models.ReportCard{
		StudentID:     studentID,
		ExamID:        examID,
		EnrollmentID:  enrollmentID,
		TotalObtained: summary.TotalObtained,
		Percentage:    pct,
		OverallGrade:  scale.GradeLabel,
		OverallGPA:    scale.GPAPoints,
		PublishedAt:   now,
	}
	return tx.Where("student_id = ? AND exam_id = ?", studentID, examID).
		Assign(rc).
		FirstOrCreate(&rc).Error
}

func (h *ExamHandler) EnterMarks(c *gin.Context) {
	scheduleID := c.Param("schedule_id")
	var schedule models.ExamSchedule
	if err := scopedExamScheduleQuery(c).First(&schedule, "exam_schedules.id = ?", scheduleID).Error; err != nil {
		fail(c, http.StatusNotFound, "Exam schedule not found")
		return
	}
	if currentRole(c) == "teacher" && !canTeachSectionSubject(c, currentStaffID(c), schedule.SectionID, schedule.SubjectID, "") {
		fail(c, http.StatusForbidden, "teacher is not assigned to this exam schedule")
		return
	}
	var req struct {
		Marks []struct {
			StudentID     string  `json:"student_id" binding:"required"`
			EnrollmentID  string  `json:"enrollment_id" binding:"required"`
			MarksObtained float64 `json:"marks_obtained"`
			GradeLabel    string  `json:"grade_label"`
			IsAbsent      bool    `json:"is_absent"`
			IsExempted    bool    `json:"is_exempted"`
		} `json:"marks" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	schoolID := scopedSchoolID(c)
	enteredBy := currentUserID(c)
	type markAudit struct {
		action string
		id     string
	}
	audits := make([]markAudit, 0, len(req.Marks))
	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		for _, m := range req.Marks {
			if err := validateMarkStudentScope(tx, schoolID, schedule, m.StudentID, m.EnrollmentID); err != nil {
				return err
			}
			if err := validateMarkValue(schedule, m.MarksObtained, m.IsAbsent, m.IsExempted); err != nil {
				return err
			}
			gradeLabel, gpaPoints := computeGradeFromScale(tx, schoolID, scheduleID, m.MarksObtained)
			if m.IsAbsent || m.IsExempted {
				gradeLabel = "N/A"
				gpaPoints = 0
			}
			updates := map[string]interface{}{
				"marks_obtained": m.MarksObtained,
				"grade_label":    gradeLabel,
				"gpa_points":     gpaPoints,
				"is_absent":      m.IsAbsent,
				"is_exempted":    m.IsExempted,
				"entered_by":     &enteredBy,
			}
			var existing models.StudentMark
			err := tx.
				Where("exam_schedule_id = ? AND student_id = ? AND enrollment_id = ?", scheduleID, m.StudentID, m.EnrollmentID).
				First(&existing).Error
			if err == nil {
				if err := tx.Model(&existing).Updates(updates).Error; err != nil {
					return fmt.Errorf("failed to update marks: %w", err)
				}
				audits = append(audits, markAudit{action: "update", id: existing.ID})
				if err := regenerateReportCard(tx, schoolID, m.StudentID, schedule.ExamID, m.EnrollmentID); err != nil {
					return fmt.Errorf("report card regeneration failed for student %s: %w", m.StudentID, err)
				}
				continue
			}
			if !errors.Is(err, gorm.ErrRecordNotFound) {
				return fmt.Errorf("failed to save marks: %w", err)
			}
			mark := models.StudentMark{
				ExamScheduleID: scheduleID,
				StudentID:      m.StudentID,
				EnrollmentID:   m.EnrollmentID,
				MarksObtained:  m.MarksObtained,
				GradeLabel:     gradeLabel,
				GPAPoints:      gpaPoints,
				IsAbsent:       m.IsAbsent,
				IsExempted:     m.IsExempted,
				EnteredBy:      &enteredBy,
			}
			if err := tx.Create(&mark).Error; err != nil {
				return fmt.Errorf("failed to save marks: %w", err)
			}
			audits = append(audits, markAudit{action: "create", id: mark.ID})
			if err := regenerateReportCard(tx, schoolID, m.StudentID, schedule.ExamID, m.EnrollmentID); err != nil {
				return fmt.Errorf("report card regeneration failed for student %s: %w", m.StudentID, err)
			}
		}
		return nil
	}); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"error": err.Error()})
		return
	}

	for _, audit := range audits {
		id := audit.id
		auditAction(c, "exams", audit.action, "student_marks", &id)
	}

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Message: "Marks entered successfully"})
}

func (h *ExamHandler) GetScheduleMarks(c *gin.Context) {
	scheduleID := c.Param("schedule_id")
	var schedule models.ExamSchedule
	if err := scopedExamScheduleQuery(c).First(&schedule, "exam_schedules.id = ?", scheduleID).Error; err != nil {
		fail(c, http.StatusNotFound, "Exam schedule not found")
		return
	}
	if currentRole(c) == "teacher" && !canTeachSectionSubject(c, currentStaffID(c), schedule.SectionID, schedule.SubjectID, "") {
		fail(c, http.StatusForbidden, "teacher is not assigned to this exam schedule")
		return
	}

	var marks []models.StudentMark
	if err := database.DB.
		Where("exam_schedule_id = ?", scheduleID).
		Preload("Student").
		Preload("Enrollment").
		Preload("ExamSchedule").
		Order("student_marks.created_at ASC").
		Find(&marks).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load marks")
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: marks})
}

func (h *ExamHandler) GetReportCards(c *gin.Context) {
	studentID := c.Query("student_id")
	examID := c.Query("exam_id")

	var reportCards []models.ReportCard
	query := database.DB.
		Model(&models.ReportCard{}).
		Joins("JOIN students ON students.id = report_cards.student_id").
		Joins("JOIN exams ON exams.id = report_cards.exam_id").
		Where("students.school_id = ? AND exams.school_id = ?", scopedSchoolID(c), scopedSchoolID(c)).
		Preload("Student").
		Preload("Exam")
	switch currentRole(c) {
	case "admin", "principal":
	case "parent", "teacher":
		if studentID == "" {
			query = query.Where("1 = 0")
		}
	default:
		query = query.Where("1 = 0")
	}
	if studentID != "" {
		if !canAccessStudent(c, studentID) {
			fail(c, http.StatusForbidden, "student access denied")
			return
		}
		query = query.Where("student_id = ?", studentID)
	}
	if examID != "" {
		query = query.Where("exam_id = ?", examID)
	}
	query.Find(&reportCards)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: reportCards})
}

func (h *ExamHandler) GetClassRanking(c *gin.Context) {
	examID := c.Param("id")
	schoolID := currentSchoolID(c)
	sectionID := strings.TrimSpace(c.Query("section_id"))

	type RankRow struct {
		StudentID  string  `json:"student_id"`
		FirstName  string  `json:"first_name"`
		LastName   string  `json:"last_name"`
		Obtained   float64 `json:"marks_obtained"`
		TotalMax   float64 `json:"total_marks"`
		Percentage float64 `json:"percentage"`
		Grade      string  `json:"grade"`
		ClassRank  int     `json:"rank"`
	}
	var rows []RankRow
	sectionFilter := ""
	args := []interface{}{examID, schoolID}
	if sectionID != "" {
		sectionFilter = "AND en.section_id = ?"
		args = append(args, sectionID)
	}

	if err := database.DB.Raw(`
		SELECT
			s.id AS student_id,
			s.first_name,
			s.last_name,
			rc.total_obtained AS obtained,
			sm_max.total_max AS total_max,
			ROUND(CAST(
				CASE WHEN sm_max.total_max > 0
					THEN (rc.total_obtained / sm_max.total_max) * 100
					ELSE 0 END AS numeric
			), 1) AS percentage,
			rc.overall_grade AS grade,
			DENSE_RANK() OVER (
				ORDER BY CASE WHEN sm_max.total_max > 0
					THEN (rc.total_obtained / sm_max.total_max)
					ELSE 0 END DESC
			) AS class_rank
		FROM report_cards rc
		JOIN students s ON s.id = rc.student_id
		JOIN enrollments en ON en.id = rc.enrollment_id
		JOIN (
			SELECT es.exam_id, SUM(es.max_marks) AS total_max
			FROM exam_schedules es GROUP BY es.exam_id
		) sm_max ON sm_max.exam_id = rc.exam_id
		WHERE rc.exam_id = ? AND s.school_id = ?
		`+sectionFilter+`
		ORDER BY class_rank ASC
	`, args...).Scan(&rows).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load rankings"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"exam_id": examID, "rankings": rows})
}

func (h *ExamHandler) GetGradingScale(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	var scales []models.GradingScale
	query := database.DB.Preload("School")
	if schoolID != "" {
		query = query.Where("school_id = ?", schoolID)
	}
	query.Find(&scales)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: scales})
}

func validateExamRefs(c *gin.Context, academicYearID, termID, examTypeID string) error {
	schoolID := scopedSchoolID(c)
	if countRows(database.DB.Model(&models.AcademicYear{}).Where("id = ? AND school_id = ?", academicYearID, schoolID)) == 0 {
		return fmt.Errorf("academic year must belong to this school")
	}
	if countRows(database.DB.Model(&models.Term{}).
		Joins("JOIN academic_years ON academic_years.id = terms.academic_year_id").
		Where("terms.id = ? AND terms.academic_year_id = ? AND academic_years.school_id = ?", termID, academicYearID, schoolID)) == 0 {
		return fmt.Errorf("term must belong to this academic year")
	}
	if countRows(database.DB.Model(&models.ExamType{}).Where("id = ? AND school_id = ?", examTypeID, schoolID)) == 0 {
		return fmt.Errorf("exam type must belong to this school")
	}
	return nil
}

func validateExamScheduleRefs(c *gin.Context, examID, gradeID, sectionID, subjectID string) error {
	schoolID := scopedSchoolID(c)
	if countRows(database.DB.Model(&models.Exam{}).Where("id = ? AND school_id = ?", examID, schoolID)) == 0 {
		return fmt.Errorf("exam must belong to this school")
	}
	if !sectionBelongsToSchool(sectionID, schoolID) {
		return fmt.Errorf("section must belong to this school")
	}
	if countRows(database.DB.Model(&models.Section{}).Where("id = ? AND grade_id = ?", sectionID, gradeID)) == 0 {
		return fmt.Errorf("section must belong to the selected grade")
	}
	if countRows(database.DB.Model(&models.Grade{}).Where("id = ? AND school_id = ?", gradeID, schoolID)) == 0 {
		return fmt.Errorf("grade must belong to this school")
	}
	if !subjectBelongsToSchool(subjectID, schoolID) {
		return fmt.Errorf("subject must belong to this school")
	}
	return nil
}

func scopedExamScheduleQuery(c *gin.Context) *gorm.DB {
	return database.DB.Model(&models.ExamSchedule{}).
		Joins("JOIN exams ON exams.id = exam_schedules.exam_id").
		Where("exams.school_id = ?", scopedSchoolID(c))
}

func validateMarkStudentScope(db *gorm.DB, schoolID string, schedule models.ExamSchedule, studentID, enrollmentID string) error {
	if countRows(db.Model(&models.Enrollment{}).
		Joins("JOIN students ON students.id = enrollments.student_id").
		Where("enrollments.id = ? AND enrollments.student_id = ? AND enrollments.section_id = ?", enrollmentID, studentID, schedule.SectionID).
		Where("students.school_id = ? AND students.status != ?", schoolID, "inactive")) == 0 {
		return fmt.Errorf("student enrollment does not belong to this exam schedule")
	}
	return nil
}

func validateMarkValue(schedule models.ExamSchedule, marks float64, absent, exempted bool) error {
	if marks < 0 {
		return fmt.Errorf("marks_obtained cannot be negative")
	}
	if !absent && !exempted && schedule.MaxMarks > 0 && marks > float64(schedule.MaxMarks) {
		return fmt.Errorf("marks_obtained cannot exceed max_marks")
	}
	if (absent || exempted) && marks != 0 {
		return fmt.Errorf("absent or exempted entries must have zero marks")
	}
	return nil
}
