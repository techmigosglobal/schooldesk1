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
		if !homeworkRecordMatchesStudent(homework, studentID) {
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
	if !homeworkRecordMatchesStudent(homework, req.StudentID) {
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

func (h *HomeworkSubmissionHandler) loadAccessibleHomework(c *gin.Context) (HomeworkRecord, bool) {
	homework, err := loadHomeworkRecord(scopedSchoolID(c), c.Param("id"))
	if err != nil {
		fail(c, http.StatusNotFound, "Homework not found")
		return homework, false
	}
	if !canAccessHomeworkRecord(c, homework) {
		fail(c, http.StatusForbidden, "Homework access denied")
		return homework, false
	}
	return homework, true
}

func (h *HomeworkSubmissionHandler) scopedSubmissionQuery(c *gin.Context, homework HomeworkRecord) *gorm.DB {
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

func (h *HomeworkSubmissionHandler) submissionSummary(homework HomeworkRecord) gin.H {
	total := homeworkRecordStudentCount(homework)
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
		Preload("Student").
		Preload("ParentUser").
		Preload("Reviewer")
}
