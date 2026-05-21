package handlers

import (
	"net/http"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type HomeworkSubmissionHandler struct{}

func NewHomeworkSubmissionHandler() *HomeworkSubmissionHandler {
	return &HomeworkSubmissionHandler{}
}

func (h *HomeworkSubmissionHandler) List(c *gin.Context) {
	homework, ok := h.loadAccessibleHomework(c)
	if !ok {
		return
	}

	query := h.scopedSubmissionQuery(c, homework)
	if studentID := strings.TrimSpace(c.Query("student_id")); studentID != "" {
		if !canAccessStudent(c, studentID) {
			fail(c, http.StatusForbidden, "Student access denied")
			return
		}
		if !homeworkMatchesStudent(homework, studentID) {
			fail(c, http.StatusForbidden, "Student is not assigned this homework")
			return
		}
		query = query.Where("homework_submissions.student_id = ?", studentID)
	}

	var rows []models.HomeworkSubmission
	if err := preloadHomeworkSubmissionDetails(query).
		Order("homework_submissions.submitted_at DESC").
		Find(&rows).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to load homework submissions")
		return
	}

	success(c, http.StatusOK, gin.H{
		"homework":    homework,
		"submissions": rows,
		"summary":     h.submissionSummary(homework),
	}, "")
}

func (h *HomeworkSubmissionHandler) Submit(c *gin.Context) {
	if currentRole(c) != "parent" {
		fail(c, http.StatusForbidden, "Only parents can submit homework")
		return
	}
	homework, ok := h.loadAccessibleHomework(c)
	if !ok {
		return
	}

	var req models.HomeworkSubmissionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	req.StudentID = strings.TrimSpace(req.StudentID)
	req.AnswerText = strings.TrimSpace(req.AnswerText)
	req.AttachmentURL = strings.TrimSpace(req.AttachmentURL)
	if req.StudentID == "" && strings.TrimSpace(homework.StudentID) != "" {
		req.StudentID = strings.TrimSpace(homework.StudentID)
	}
	if req.StudentID == "" {
		fail(c, http.StatusBadRequest, "student_id is required")
		return
	}
	if req.AnswerText == "" && req.AttachmentURL == "" {
		fail(c, http.StatusBadRequest, "answer_text or attachment_url is required")
		return
	}
	if !canAccessStudent(c, req.StudentID) {
		fail(c, http.StatusForbidden, "Parent is not linked to this student")
		return
	}
	if !homeworkMatchesStudent(homework, req.StudentID) {
		fail(c, http.StatusForbidden, "Student is not assigned this homework")
		return
	}

	now := time.Now().UTC()
	var row models.HomeworkSubmission
	err := database.DB.First(
		&row,
		"school_id = ? AND homework_id = ? AND student_id = ?",
		scopedSchoolID(c),
		homework.ID,
		req.StudentID,
	).Error
	if err != nil && err != gorm.ErrRecordNotFound {
		fail(c, http.StatusInternalServerError, "Failed to load homework submission")
		return
	}
	action := "submit"
	if err == gorm.ErrRecordNotFound {
		row = models.HomeworkSubmission{
			SchoolID:     scopedSchoolID(c),
			HomeworkID:   homework.ID,
			StudentID:    req.StudentID,
			ParentUserID: currentUserID(c),
		}
	} else {
		if row.Status == "reviewed" {
			fail(c, http.StatusBadRequest, "Reviewed homework cannot be resubmitted")
			return
		}
		action = "resubmit"
		row.ParentUserID = currentUserID(c)
	}
	row.AnswerText = req.AnswerText
	row.AttachmentURL = req.AttachmentURL
	row.Status = "submitted"
	row.SubmittedAt = now
	row.ReviewedBy = ""
	row.ReviewedAt = nil
	row.Grade = ""
	row.Remarks = ""

	if err := database.DB.Save(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to save homework submission")
		return
	}
	id := row.ID
	auditAction(c, "homework_submissions", action, "homework_submissions", &id)
	if err := preloadHomeworkSubmissionDetails(database.DB).First(&row, "id = ?", row.ID).Error; err != nil {
		success(c, http.StatusCreated, row, "Homework submitted")
		return
	}
	success(c, http.StatusCreated, row, "Homework submitted")
}

func (h *HomeworkSubmissionHandler) Review(c *gin.Context) {
	if currentRole(c) != "teacher" && currentRole(c) != "admin" && currentRole(c) != "principal" {
		fail(c, http.StatusForbidden, "Only school staff can review homework submissions")
		return
	}
	homework, ok := h.loadAccessibleHomework(c)
	if !ok {
		return
	}

	var row models.HomeworkSubmission
	if err := h.scopedSubmissionQuery(c, homework).
		First(&row, "homework_submissions.id = ?", c.Param("submission_id")).Error; err != nil {
		fail(c, http.StatusNotFound, "Homework submission not found")
		return
	}

	var req models.HomeworkSubmissionReviewRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	status := strings.ToLower(strings.TrimSpace(req.Status))
	if status != "reviewed" && status != "needs_revision" {
		fail(c, http.StatusBadRequest, "status must be reviewed or needs_revision")
		return
	}
	req.Grade = strings.TrimSpace(req.Grade)
	req.Remarks = strings.TrimSpace(req.Remarks)
	if status == "needs_revision" && req.Remarks == "" {
		fail(c, http.StatusBadRequest, "remarks are required when requesting revision")
		return
	}

	now := time.Now().UTC()
	row.Status = status
	row.Grade = req.Grade
	row.Remarks = req.Remarks
	row.ReviewedBy = currentUserID(c)
	row.ReviewedAt = &now
	if err := database.DB.Save(&row).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to review homework submission")
		return
	}
	id := row.ID
	auditAction(c, "homework_submissions", status, "homework_submissions", &id)
	if err := preloadHomeworkSubmissionDetails(database.DB).First(&row, "id = ?", row.ID).Error; err != nil {
		success(c, http.StatusOK, row, "Homework submission reviewed")
		return
	}
	success(c, http.StatusOK, row, "Homework submission reviewed")
}

func (h *HomeworkSubmissionHandler) loadAccessibleHomework(c *gin.Context) (models.Homework, bool) {
	var homework models.Homework
	if err := database.DB.First(
		&homework,
		"id = ? AND school_id = ?",
		c.Param("id"),
		scopedSchoolID(c),
	).Error; err != nil {
		fail(c, http.StatusNotFound, "Homework not found")
		return homework, false
	}
	if !canAccessHomework(c, homework) {
		fail(c, http.StatusForbidden, "Homework access denied")
		return homework, false
	}
	return homework, true
}

func (h *HomeworkSubmissionHandler) scopedSubmissionQuery(c *gin.Context, homework models.Homework) *gorm.DB {
	query := database.DB.Model(&models.HomeworkSubmission{}).
		Where("homework_submissions.school_id = ? AND homework_submissions.homework_id = ?", scopedSchoolID(c), homework.ID)
	switch currentRole(c) {
	case "admin", "principal", "teacher":
		return query
	case "parent":
		return query.Where(
			"(homework_submissions.parent_user_id = ? OR homework_submissions.student_id IN (?))",
			currentUserID(c),
			linkedStudentSubquery(c),
		)
	default:
		return query.Where("1 = 0")
	}
}

func (h *HomeworkSubmissionHandler) submissionSummary(homework models.Homework) gin.H {
	total := homeworkStudentCount(homework)
	var submitted int64
	database.DB.Model(&models.HomeworkSubmission{}).
		Where("school_id = ? AND homework_id = ?", homework.SchoolID, homework.ID).
		Count(&submitted)
	pending := total - submitted
	if pending < 0 {
		pending = 0
	}
	return gin.H{
		"total":     total,
		"submitted": submitted,
		"pending":   pending,
	}
}

func canAccessHomework(c *gin.Context, homework models.Homework) bool {
	if homework.SchoolID != scopedSchoolID(c) {
		return false
	}
	switch currentRole(c) {
	case "admin", "principal":
		return true
	case "teacher":
		staffID := currentStaffID(c)
		if staffID == "" {
			return false
		}
		if strings.TrimSpace(homework.TeacherID) == staffID {
			return true
		}
		if strings.TrimSpace(homework.SectionID) != "" && canAccessSection(c, homework.SectionID) {
			return true
		}
		return strings.TrimSpace(homework.StudentID) != "" && canAccessStudent(c, homework.StudentID)
	case "parent":
		if strings.TrimSpace(homework.StudentID) != "" && canAccessStudent(c, homework.StudentID) {
			return true
		}
		return strings.TrimSpace(homework.SectionID) != "" && canAccessSection(c, homework.SectionID)
	default:
		return false
	}
}

func homeworkMatchesStudent(homework models.Homework, studentID string) bool {
	studentID = strings.TrimSpace(studentID)
	if studentID == "" {
		return false
	}
	if strings.TrimSpace(homework.StudentID) != "" {
		return strings.TrimSpace(homework.StudentID) == studentID
	}
	sectionID := strings.TrimSpace(homework.SectionID)
	if sectionID == "" {
		return true
	}
	return studentInSection(homework.SchoolID, studentID, sectionID)
}

func homeworkStudentCount(homework models.Homework) int64 {
	if strings.TrimSpace(homework.StudentID) != "" {
		return 1
	}
	sectionID := strings.TrimSpace(homework.SectionID)
	if sectionID == "" {
		return 0
	}
	var total int64
	database.DB.Model(&models.Student{}).
		Where("students.school_id = ?", homework.SchoolID).
		Where(`
		(
			students.current_section_id = ?
			OR EXISTS (
				SELECT 1 FROM enrollments
				WHERE enrollments.student_id = students.id
					AND enrollments.section_id = ?
			)
		)
	`, sectionID, sectionID).
		Distinct("students.id").
		Count(&total)
	return total
}

func studentInSection(schoolID, studentID, sectionID string) bool {
	return countRows(database.DB.Model(&models.Student{}).
		Where("students.id = ? AND students.school_id = ?", studentID, schoolID).
		Where(`
		(
			students.current_section_id = ?
			OR EXISTS (
				SELECT 1 FROM enrollments
				WHERE enrollments.student_id = students.id
					AND enrollments.section_id = ?
			)
		)
	`, sectionID, sectionID)) > 0
}

func preloadHomeworkSubmissionDetails(query *gorm.DB) *gorm.DB {
	return query.
		Preload("Homework").
		Preload("Student").
		Preload("ParentUser").
		Preload("Reviewer")
}
