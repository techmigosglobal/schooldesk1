package handlers

import (
	"fmt"
	"net/http"
	"strings"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type ParentLinkHandler struct{}

func NewParentLinkHandler() *ParentLinkHandler {
	return &ParentLinkHandler{}
}

func (h *ParentLinkHandler) AssignParentStudents(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	parentUserID := strings.TrimSpace(c.Param("parent_user_id"))
	if parentUserID == "" {
		fail(c, http.StatusBadRequest, "parent_user_id is required")
		return
	}

	var req struct {
		AdmissionNumbers []string `json:"admission_numbers"`
		StudentIDs       []string `json:"student_ids"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	var parent models.User
	if err := database.DB.Preload("Role").
		Where("id = ? AND school_id = ?", parentUserID, schoolID).
		First(&parent).Error; err != nil {
		fail(c, http.StatusNotFound, "Parent user not found")
		return
	}
	if parent.Role == nil || strings.ToLower(strings.TrimSpace(parent.Role.RoleName)) != "parent" {
		fail(c, http.StatusBadRequest, "Provided user is not a parent")
		return
	}

	cleanAdmissionNumbers := make([]string, 0, len(req.AdmissionNumbers))
	cleanAdmissionKeys := make([]string, 0, len(req.AdmissionNumbers))
	seenAdmissions := map[string]struct{}{}
	for _, admissionNo := range req.AdmissionNumbers {
		clean := strings.TrimSpace(admissionNo)
		if clean == "" {
			continue
		}
		key := strings.ToLower(clean)
		if _, ok := seenAdmissions[key]; ok {
			continue
		}
		seenAdmissions[key] = struct{}{}
		cleanAdmissionNumbers = append(cleanAdmissionNumbers, clean)
		cleanAdmissionKeys = append(cleanAdmissionKeys, key)
	}

	cleanStudentIDs := make([]string, 0, len(req.StudentIDs))
	seenStudentIDs := map[string]struct{}{}
	for _, studentID := range req.StudentIDs {
		clean := strings.TrimSpace(studentID)
		if clean == "" {
			continue
		}
		if _, ok := seenStudentIDs[clean]; ok {
			continue
		}
		seenStudentIDs[clean] = struct{}{}
		cleanStudentIDs = append(cleanStudentIDs, clean)
	}

	if len(cleanAdmissionNumbers) == 0 && len(cleanStudentIDs) == 0 {
		fail(c, http.StatusBadRequest, "At least one student id or admission number is required")
		return
	}

	var students []models.Student
	clauses := make([]string, 0, 2)
	args := make([]interface{}, 0, 3)
	if len(cleanStudentIDs) > 0 {
		clauses = append(clauses, "id IN ?")
		args = append(args, cleanStudentIDs)
	}
	if len(cleanAdmissionKeys) > 0 {
		clauses = append(clauses, "(LOWER(admission_number) IN ? OR LOWER(student_code) IN ?)")
		args = append(args, cleanAdmissionKeys, cleanAdmissionKeys)
	}
	if err := database.DB.
		Where("school_id = ?", schoolID).
		Where(strings.Join(clauses, " OR "), args...).
		Find(&students).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to resolve students")
		return
	}

	foundAdmissionKeys := map[string]struct{}{}
	foundStudentIDs := map[string]struct{}{}
	for _, s := range students {
		foundStudentIDs[s.ID] = struct{}{}
		if admission := strings.ToLower(strings.TrimSpace(s.AdmissionNumber)); admission != "" {
			foundAdmissionKeys[admission] = struct{}{}
		}
		if code := strings.ToLower(strings.TrimSpace(s.StudentCode)); code != "" {
			foundAdmissionKeys[code] = struct{}{}
		}
	}
	missingAdmissions := make([]string, 0)
	for _, admission := range cleanAdmissionNumbers {
		if _, ok := foundAdmissionKeys[strings.ToLower(strings.TrimSpace(admission))]; !ok {
			missingAdmissions = append(missingAdmissions, admission)
		}
	}
	missingStudentIDs := make([]string, 0)
	for _, studentID := range cleanStudentIDs {
		if _, ok := foundStudentIDs[studentID]; !ok {
			missingStudentIDs = append(missingStudentIDs, studentID)
		}
	}
	if len(missingAdmissions) > 0 || len(missingStudentIDs) > 0 {
		c.JSON(http.StatusBadRequest, models.APIResponse{
			Success: false,
			Error:   "Some students were not found for this school",
			Details: gin.H{
				"missing_admission_numbers": missingAdmissions,
				"missing_student_ids":       missingStudentIDs,
			},
		})
		return
	}

	tx := database.DB.Begin()
	if err := tx.Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to start transaction")
		return
	}

	if err := tx.Where("school_id = ? AND parent_user_id = ?", schoolID, parentUserID).
		Delete(&models.ParentStudentLink{}).Error; err != nil {
		tx.Rollback()
		fail(c, http.StatusInternalServerError, "Failed to clear existing parent-student links")
		return
	}

	links := make([]models.ParentStudentLink, 0, len(students))
	for _, s := range students {
		links = append(links, models.ParentStudentLink{
			SchoolID:               schoolID,
			ParentUserID:           parentUserID,
			StudentID:              s.ID,
			StudentAdmissionNumber: firstNonEmpty(s.AdmissionNumber, s.StudentCode),
		})
	}
	if err := tx.Create(&links).Error; err != nil {
		tx.Rollback()
		fail(c, http.StatusInternalServerError, "Failed to save parent-student links")
		return
	}

	if err := tx.Commit().Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to commit parent-student links")
		return
	}

	auditAction(c, "parent_student_links", "update", "parent_student_links", &parentUserID)
	success(c, http.StatusOK, gin.H{
		"parent_user_id":    parentUserID,
		"assigned_students": len(links),
		"admission_numbers": cleanAdmissionNumbers,
	}, "Parent-student assignments updated")
}

func (h *ParentLinkHandler) GetParentStudents(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	parentUserID := strings.TrimSpace(c.Param("parent_user_id"))
	if parentUserID == "" {
		fail(c, http.StatusBadRequest, "parent_user_id is required")
		return
	}

	var links []models.ParentStudentLink
	if err := database.DB.
		Where("school_id = ? AND parent_user_id = ?", schoolID, parentUserID).
		Preload("Student").
		Find(&links).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch parent-student links")
		return
	}

	result := make([]gin.H, 0, len(links))
	for _, link := range links {
		if link.Student == nil {
			continue
		}
		if strings.EqualFold(strings.TrimSpace(link.Student.Status), "inactive") {
			continue
		}
		result = append(result, gin.H{
			"student_id":               link.StudentID,
			"student_admission_number": link.StudentAdmissionNumber,
			"student_first_name":       link.Student.FirstName,
			"student_last_name":        link.Student.LastName,
			"student_status":           link.Student.Status,
			"linked_at":                link.CreatedAt,
		})
	}

	success(c, http.StatusOK, gin.H{
		"parent_user_id": parentUserID,
		"students":       result,
	}, "")
}

func (h *ParentLinkHandler) GetMyStudents(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	parentUserID := strings.TrimSpace(c.GetString("user_id"))
	if parentUserID == "" {
		fail(c, http.StatusUnauthorized, "Unauthenticated user")
		return
	}

	var links []models.ParentStudentLink
	if err := database.DB.
		Where("school_id = ? AND parent_user_id = ?", schoolID, parentUserID).
		Preload("Student").
		Preload("Student.Guardians").
		Preload("Student.MedicalRecord").
		Preload("Student.Documents").
		Preload("Student.CurrentSection").
		Preload("Student.CurrentSection.Grade").
		Preload("Student.CurrentSection.ClassTeacher").
		Find(&links).Error; err != nil {
		fail(c, http.StatusInternalServerError, "Failed to fetch linked students")
		return
	}

	students := make([]models.Student, 0, len(links))
	for _, link := range links {
		if link.Student == nil {
			continue
		}
		if strings.EqualFold(strings.TrimSpace(link.Student.Status), "inactive") {
			continue
		}
		students = append(students, *link.Student)
	}

	success(c, http.StatusOK, studentResponseRows(database.DB, schoolID, students), "")
}

func (h *ParentLinkHandler) SetStudentParent(c *gin.Context) {
	schoolID := scopedSchoolID(c)
	studentID := strings.TrimSpace(c.Param("id"))
	if studentID == "" {
		fail(c, http.StatusBadRequest, "student id is required")
		return
	}
	var req struct {
		ParentUserID string `json:"parent_user_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	var student models.Student
	if err := database.DB.First(&student, "id = ? AND school_id = ?", studentID, schoolID).Error; err != nil {
		fail(c, http.StatusNotFound, "Student not found")
		return
	}

	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		return replaceStudentParentLink(tx, schoolID, student, req.ParentUserID)
	}); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	auditAction(c, "parent_student_links", "update", "parent_student_links", &studentID)
	success(c, http.StatusOK, gin.H{
		"student_id":       studentID,
		"parent_user_id":   strings.TrimSpace(req.ParentUserID),
		"admission_number": firstNonEmpty(student.AdmissionNumber, student.StudentCode),
	}, "Student parent assignment updated")
}

func replaceStudentParentLink(tx *gorm.DB, schoolID string, student models.Student, parentUserID string) error {
	if strings.TrimSpace(student.ID) == "" {
		return fmt.Errorf("student is required")
	}
	if err := tx.Where("school_id = ? AND student_id = ?", schoolID, student.ID).
		Delete(&models.ParentStudentLink{}).Error; err != nil {
		return fmt.Errorf("failed to clear existing student parent links")
	}
	parentUserID = strings.TrimSpace(parentUserID)
	if parentUserID == "" {
		return nil
	}
	var parent models.User
	if err := tx.Preload("Role").
		Where("id = ? AND school_id = ?", parentUserID, schoolID).
		First(&parent).Error; err != nil {
		return fmt.Errorf("parent user not found")
	}
	if parent.Role == nil || !strings.EqualFold(strings.TrimSpace(parent.Role.RoleName), "parent") {
		return fmt.Errorf("provided user is not a parent")
	}
	link := models.ParentStudentLink{
		SchoolID:               schoolID,
		ParentUserID:           parentUserID,
		StudentID:              student.ID,
		StudentAdmissionNumber: firstNonEmpty(student.AdmissionNumber, student.StudentCode),
	}
	if err := tx.Create(&link).Error; err != nil {
		return fmt.Errorf("failed to save parent-student link")
	}
	return nil
}
