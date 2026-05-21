package handlers

import (
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"school-backend/internal/database"
	"school-backend/internal/models"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type StudentHandler struct{}

func NewStudentHandler() *StudentHandler {
	return &StudentHandler{}
}

func (h *StudentHandler) GetStudents(c *gin.Context) {
	page, pageSize := parsePagination(c)
	schoolID := scopedSchoolID(c)
	sectionID := c.Query("section_id")
	status := c.Query("status")

	var students []models.Student
	var total int64

	query := database.DB.Model(&models.Student{})
	if schoolID != "" {
		query = query.Where("students.school_id = ?", schoolID)
	}
	if isParent(c) {
		query = query.Joins("JOIN parent_student_links ON parent_student_links.student_id = students.id").
			Where("parent_student_links.school_id = ? AND parent_student_links.parent_user_id = ?", schoolID, c.GetString("user_id"))
	}
	if currentRole(c) == "teacher" {
		staffID := currentStaffID(c)
		if staffID == "" {
			query = query.Where("1 = 0")
		} else {
			sections := teacherSectionSubquery(staffID, schoolID)
			query = query.Where(`
				(
				students.current_section_id IN (?)
				OR EXISTS (
					SELECT 1 FROM enrollments
					WHERE enrollments.student_id = students.id
						AND enrollments.section_id IN (?)
				)
				)
			`, sections, teacherSectionSubquery(staffID, schoolID))
		}
	}
	if sectionID != "" {
		query = query.Where("students.current_section_id = ?", sectionID)
	}
	if status != "" {
		// Caller explicitly requested a specific status (e.g. ?status=inactive
		// for admin views). Pass it through as-is.
		query = query.Where("students.status = ?", status)
	} else {
		// Default: exclude soft-deleted (inactive) students from all listings.
		// Use ?status=inactive to explicitly query deactivated records.
		query = query.Where("students.status != ?", "inactive")
	}

	query.Count(&total)
	query = query.Preload("Guardians").Preload("MedicalRecord").Preload("CurrentSection").Preload("Documents").Offset((page - 1) * pageSize).Limit(pageSize)
	query.Find(&students)

	c.JSON(http.StatusOK, paginationResult(page, pageSize, total, students))
}

func (h *StudentHandler) GetStudent(c *gin.Context) {
	id := c.Param("id")
	if !h.canAccessStudent(c, id) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var student models.Student
	if err := database.DB.Preload("Guardians").Preload("MedicalRecord").Preload("CurrentSection").Preload("CurrentSection.Grade").Preload("Documents").First(&student, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Student not found"})
		return
	}
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: student})
}

func (h *StudentHandler) CreateStudent(c *gin.Context) {
	var req models.CreateStudentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	student, status, err := createStudentForSchool(database.DB, scopedSchoolID(c), req)
	if err != nil {
		fail(c, status, err.Error())
		return
	}

	id := student.ID
	auditAction(c, "students", "create", "students", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: student})
}

func (h *StudentHandler) UpdateStudent(c *gin.Context) {
	id := c.Param("id")
	var student models.Student
	if err := database.DB.First(&student, "id = ? AND school_id = ?", id, scopedSchoolID(c)).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Student not found"})
		return
	}

	var req models.CreateStudentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	student, status, err := updateStudentForSchool(database.DB, scopedSchoolID(c), id, req)
	if err != nil {
		fail(c, status, err.Error())
		return
	}

	auditAction(c, "students", "update", "students", &id)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: student})
}

func (h *StudentHandler) DeleteStudent(c *gin.Context) {
	id := c.Param("id")

	// Soft-delete: mark the student inactive rather than removing the row.
	// This preserves attendance, fee invoice, exam, and audit records that
	// reference this student's ID.
	result := database.DB.Model(&models.Student{}).
		Where("id = ? AND school_id = ?", id, scopedSchoolID(c)).
		Update("status", "inactive")

	if result.Error != nil {
		c.JSON(http.StatusInternalServerError, models.APIResponse{
			Success: false,
			Error:   "Failed to deactivate student",
		})
		return
	}
	if result.RowsAffected == 0 {
		// Either the student does not exist or belongs to another school.
		c.JSON(http.StatusNotFound, models.APIResponse{
			Success: false,
			Error:   "Student not found",
		})
		return
	}

	auditAction(c, "students", "delete", "students", &id)
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Message: "Student deactivated successfully",
	})
}

func (h *StudentHandler) UploadStudentPhoto(c *gin.Context) {
	studentID := c.Param("id")
	schoolID := scopedSchoolID(c)

	var student models.Student
	if err := database.DB.First(&student, "id = ? AND school_id = ?", studentID, schoolID).Error; err != nil {
		c.JSON(http.StatusNotFound, models.APIResponse{
			Success: false,
			Error:   "Student not found",
		})
		return
	}

	file, err := c.FormFile("photo")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Photo file is required"})
		return
	}
	if file.Size > 3*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Photo file must be 3 MB or smaller"})
		return
	}
	ext := strings.ToLower(filepath.Ext(file.Filename))
	switch ext {
	case ".jpg", ".jpeg", ".png", ".webp":
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Photo must be a JPG, PNG, or WebP image"})
		return
	}

	dir := filepath.Join("uploads", "students", schoolID)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		log.Printf("student photo upload storage preparation failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to prepare upload storage"})
		return
	}
	filename := fmt.Sprintf("%s_photo_%d%s", studentID, time.Now().UnixNano(), ext)
	relativePath := filepath.ToSlash(filepath.Join(dir, filename))
	if err := c.SaveUploadedFile(file, relativePath); err != nil {
		log.Printf("student photo upload save failed for student %s: %v", studentID, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save student photo"})
		return
	}

	publicPath := "/" + relativePath
	now := time.Now().UTC()
	var document models.StudentDocument
	result := database.DB.Where("student_id = ? AND doc_type = ?", studentID, "profile_photo").First(&document)
	if result.Error == nil {
		if err := database.DB.Model(&document).Updates(map[string]interface{}{
			"file_url":    publicPath,
			"verified":    false,
			"uploaded_at": now,
			"updated_at":  now,
		}).Error; err != nil {
			log.Printf("student photo document update failed for student %s: %v", studentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update student photo"})
			return
		}
	} else if errors.Is(result.Error, gorm.ErrRecordNotFound) {
		document = models.StudentDocument{
			StudentID:  studentID,
			DocType:    "profile_photo",
			FileURL:    publicPath,
			Verified:   false,
			UploadedAt: now,
		}
		if err := database.DB.Create(&document).Error; err != nil {
			log.Printf("student photo document create failed for student %s: %v", studentID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save student photo"})
			return
		}
	} else {
		log.Printf("student photo document lookup failed for student %s: %v", studentID, result.Error)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update student photo"})
		return
	}

	auditAction(c, "student_documents", "create", "students", &studentID)
	c.JSON(http.StatusOK, models.APIResponse{
		Success: true,
		Data: gin.H{
			"photo":     publicPath,
			"photo_url": absoluteURL(c, publicPath),
		},
	})
}

func (h *StudentHandler) GetStudentEnrollments(c *gin.Context) {
	studentID := c.Param("id")
	if !h.canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var enrollments []models.Enrollment
	database.DB.Preload("Section").Preload("Section.Grade").Preload("AcademicYear").Where("student_id = ?", studentID).Find(&enrollments)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: enrollments})
}

func (h *StudentHandler) CreateEnrollment(c *gin.Context) {
	var req models.CreateEnrollmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	enrollDate := time.Now()
	if req.EnrollmentDate != "" {
		enrollDate, _ = time.Parse("2006-01-02", req.EnrollmentDate)
	}

	enrollment := models.Enrollment{
		StudentID:      req.StudentID,
		SectionID:      req.SectionID,
		AcademicYearID: req.AcademicYearID,
		RollNumber:     req.RollNumber,
		EnrollmentDate: enrollDate,
		Status:         "enrolled",
	}

	if err := validateEnrollmentSchoolScope(scopedSchoolID(c), enrollment); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}

	if err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&enrollment).Error; err != nil {
			return err
		}
		return tx.Model(&models.Student{}).
			Where("id = ? AND school_id = ?", enrollment.StudentID, scopedSchoolID(c)).
			Update("current_section_id", enrollment.SectionID).Error
	}); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create enrollment"})
		return
	}

	id := enrollment.ID
	auditAction(c, "enrollments", "create", "enrollments", &id)
	c.JSON(http.StatusCreated, models.APIResponse{Success: true, Data: enrollment})
}

func (h *StudentHandler) GetStudentAttendance(c *gin.Context) {
	studentID := c.Param("id")
	if !h.canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	month := c.Query("month")
	year := c.Query("year")

	var attendance []models.StudentAttendance
	query := database.DB.Where("student_id = ?", studentID).Preload("Session")
	if month != "" {
		start, end, ok := monthYearRange(month, year)
		if ok {
			query = query.Where("marked_at >= ? AND marked_at < ?", start, end)
		}
	} else if year != "" {
		start, _, ok := monthYearRange("01", year)
		if ok {
			query = query.Where("marked_at >= ? AND marked_at < ?", start, start.AddDate(1, 0, 0))
		}
	}
	query.Find(&attendance)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: attendance})
}

func (h *StudentHandler) GetStudentFees(c *gin.Context) {
	studentID := c.Param("id")
	if !h.canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var invoices []models.FeeInvoice
	database.DB.
		Where("student_id = ?", studentID).
		Preload("Student").
		Preload("Student.CurrentSection").
		Preload("Student.CurrentSection.Grade").
		Preload("AcademicYear").
		Preload("Items").
		Preload("Items.FeeCategory").
		Preload("Payments").
		Find(&invoices)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: invoices})
}

func (h *StudentHandler) GetStudentMarks(c *gin.Context) {
	studentID := c.Param("id")
	if !h.canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	examID := c.Query("exam_id")

	var marks []models.StudentMark
	query := database.DB.Where("student_id = ?", studentID).Preload("ExamSchedule").Preload("ExamSchedule.Subject")
	if examID != "" {
		query = query.Joins("JOIN exam_schedules ON exam_schedules.id = student_marks.exam_schedule_id").
			Where("exam_schedules.exam_id = ?", examID).
			Preload("ExamSchedule.Exam")
	}
	query.Find(&marks)

	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: marks})
}

func (h *StudentHandler) GetStudentTransport(c *gin.Context) {
	studentID := c.Param("id")
	if !h.canAccessStudent(c, studentID) {
		fail(c, http.StatusForbidden, "student access denied")
		return
	}
	var transports []models.StudentTransport
	database.DB.Where("student_id = ?", studentID).Preload("Route").Preload("Stop").Find(&transports)
	c.JSON(http.StatusOK, models.APIResponse{Success: true, Data: transports})
}

func (h *StudentHandler) canAccessStudent(c *gin.Context, studentID string) bool {
	return canAccessStudent(c, studentID)
}

func isParent(c *gin.Context) bool {
	return strings.EqualFold(strings.TrimSpace(c.GetString("role_name")), "parent")
}

func (h *StudentHandler) teacherStaffID(c *gin.Context) string {
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

func validateEnrollmentSchoolScope(schoolID string, enrollment models.Enrollment) error {
	if countRows(database.DB.Model(&models.Student{}).
		Where("id = ? AND school_id = ? AND status != ?", enrollment.StudentID, schoolID, "inactive")) == 0 {
		return fmt.Errorf("student does not belong to this school")
	}
	if !sectionBelongsToSchool(enrollment.SectionID, schoolID) {
		return fmt.Errorf("section does not belong to this school")
	}
	if countRows(database.DB.Model(&models.AcademicYear{}).
		Where("id = ? AND school_id = ?", enrollment.AcademicYearID, schoolID)) == 0 {
		return fmt.Errorf("academic year does not belong to this school")
	}
	return nil
}

func createStudentForSchool(db *gorm.DB, schoolID string, req models.CreateStudentRequest) (models.Student, int, error) {
	dob, err := parseRequiredStudentDate(req.DateOfBirth, "date_of_birth")
	if err != nil {
		return models.Student{}, http.StatusBadRequest, err
	}
	admDate := time.Now().UTC()
	if strings.TrimSpace(req.AdmissionDate) != "" {
		parsed, err := parseRequiredStudentDate(req.AdmissionDate, "admission_date")
		if err != nil {
			return models.Student{}, http.StatusBadRequest, err
		}
		admDate = parsed
	}
	sectionID := strings.TrimSpace(req.CurrentSectionID)
	if sectionID != "" && !sectionBelongsToSchoolDB(db, sectionID, schoolID) {
		return models.Student{}, http.StatusBadRequest, fmt.Errorf("section does not belong to this school")
	}
	studentCode := strings.TrimSpace(req.StudentCode)
	if studentCode == "" {
		studentCode = fmt.Sprintf("STU-%d", time.Now().UTC().UnixNano())
	}
	admissionNumber := strings.TrimSpace(req.AdmissionNumber)
	if admissionNumber == "" {
		admissionNumber = studentCode
	}
	if err := ensureStudentIdentifierAvailable(db, "student_code", studentCode, ""); err != nil {
		return models.Student{}, http.StatusBadRequest, err
	}
	if err := ensureStudentIdentifierAvailable(db, "admission_number", admissionNumber, ""); err != nil {
		return models.Student{}, http.StatusBadRequest, err
	}

	student := models.Student{
		SchoolID:        schoolID,
		StudentCode:     studentCode,
		AdmissionNumber: admissionNumber,
		FirstName:       strings.TrimSpace(req.FirstName),
		LastName:        strings.TrimSpace(req.LastName),
		DateOfBirth:     dob,
		Gender:          strings.ToLower(strings.TrimSpace(req.Gender)),
		AdmissionDate:   admDate,
		Status:          "active",
	}
	if sectionID != "" {
		student.CurrentSectionID = &sectionID
	}
	if strings.TrimSpace(req.Status) != "" {
		student.Status = strings.ToLower(strings.TrimSpace(req.Status))
	}

	if err := db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(&student).Error; err != nil {
			return err
		}
		if sectionID == "" {
			return nil
		}
		return upsertCurrentEnrollment(tx, schoolID, student.ID, sectionID, firstNonEmpty(student.AdmissionNumber, student.StudentCode), admDate)
	}); err != nil {
		return models.Student{}, http.StatusInternalServerError, fmt.Errorf("failed to create student")
	}
	return student, http.StatusCreated, nil
}

func updateStudentForSchool(db *gorm.DB, schoolID, studentID string, req models.CreateStudentRequest) (models.Student, int, error) {
	var student models.Student
	if err := db.First(&student, "id = ? AND school_id = ?", studentID, schoolID).Error; err != nil {
		return models.Student{}, http.StatusNotFound, fmt.Errorf("student not found")
	}
	sectionID := strings.TrimSpace(req.CurrentSectionID)
	if sectionID != "" && !sectionBelongsToSchoolDB(db, sectionID, schoolID) {
		return models.Student{}, http.StatusBadRequest, fmt.Errorf("section does not belong to this school")
	}
	studentCode := strings.TrimSpace(req.StudentCode)
	if studentCode == "" {
		studentCode = student.StudentCode
	}
	if studentCode == "" {
		studentCode = fmt.Sprintf("STU-%d", time.Now().UTC().UnixNano())
	}
	admissionNumber := strings.TrimSpace(req.AdmissionNumber)
	if admissionNumber == "" {
		admissionNumber = student.AdmissionNumber
	}
	if admissionNumber == "" {
		admissionNumber = studentCode
	}
	if err := ensureStudentIdentifierAvailable(db, "student_code", studentCode, studentID); err != nil {
		return models.Student{}, http.StatusBadRequest, err
	}
	if err := ensureStudentIdentifierAvailable(db, "admission_number", admissionNumber, studentID); err != nil {
		return models.Student{}, http.StatusBadRequest, err
	}

	student.FirstName = strings.TrimSpace(req.FirstName)
	student.LastName = strings.TrimSpace(req.LastName)
	student.StudentCode = studentCode
	student.AdmissionNumber = admissionNumber
	student.Gender = strings.ToLower(strings.TrimSpace(req.Gender))
	if strings.TrimSpace(req.DateOfBirth) != "" {
		dob, err := parseRequiredStudentDate(req.DateOfBirth, "date_of_birth")
		if err != nil {
			return models.Student{}, http.StatusBadRequest, err
		}
		student.DateOfBirth = dob
	}
	if strings.TrimSpace(req.AdmissionDate) != "" {
		admDate, err := parseRequiredStudentDate(req.AdmissionDate, "admission_date")
		if err != nil {
			return models.Student{}, http.StatusBadRequest, err
		}
		student.AdmissionDate = admDate
	}
	if sectionID != "" {
		student.CurrentSectionID = &sectionID
	}
	if strings.TrimSpace(req.Status) != "" {
		student.Status = strings.ToLower(strings.TrimSpace(req.Status))
	}

	if err := db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Save(&student).Error; err != nil {
			return err
		}
		if sectionID == "" {
			return nil
		}
		return upsertCurrentEnrollment(tx, schoolID, student.ID, sectionID, firstNonEmpty(student.AdmissionNumber, student.StudentCode), time.Now().UTC())
	}); err != nil {
		return models.Student{}, http.StatusInternalServerError, fmt.Errorf("failed to update student")
	}
	return student, http.StatusOK, nil
}

func ensureStudentIdentifierAvailable(db *gorm.DB, field, value, excludeID string) error {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	var column string
	switch field {
	case "student_code":
		column = "student_code"
	case "admission_number":
		column = "admission_number"
	default:
		return fmt.Errorf("invalid student identifier")
	}
	query := db.Model(&models.Student{}).Where(column+" = ?", value)
	if strings.TrimSpace(excludeID) != "" {
		query = query.Where("id <> ?", strings.TrimSpace(excludeID))
	}
	if countRows(query) > 0 {
		return fmt.Errorf("%s already exists", strings.ReplaceAll(column, "_", " "))
	}
	return nil
}

func parseRequiredStudentDate(value, field string) (time.Time, error) {
	parsed, err := time.Parse("2006-01-02", strings.TrimSpace(value))
	if err != nil {
		return time.Time{}, fmt.Errorf("invalid %s format. Use YYYY-MM-DD", field)
	}
	return parsed, nil
}

func upsertCurrentEnrollment(tx *gorm.DB, schoolID, studentID, sectionID, rollNumber string, enrollmentDate time.Time) error {
	yearID, err := currentAcademicYearID(tx, schoolID)
	if err != nil || yearID == "" {
		return err
	}
	var existing models.Enrollment
	err = tx.Where("student_id = ? AND academic_year_id = ?", studentID, yearID).First(&existing).Error
	if err == nil {
		return tx.Model(&existing).Updates(map[string]interface{}{
			"section_id":  sectionID,
			"roll_number": rollNumber,
			"status":      "enrolled",
		}).Error
	}
	if err != gorm.ErrRecordNotFound {
		return err
	}
	enrollment := models.Enrollment{
		StudentID:      studentID,
		SectionID:      sectionID,
		AcademicYearID: yearID,
		RollNumber:     rollNumber,
		EnrollmentDate: enrollmentDate,
		Status:         "enrolled",
	}
	return tx.Create(&enrollment).Error
}

func currentAcademicYearID(tx *gorm.DB, schoolID string) (string, error) {
	var year models.AcademicYear
	err := tx.Where("school_id = ? AND is_current = ?", schoolID, true).First(&year).Error
	if err == gorm.ErrRecordNotFound {
		err = tx.Where("school_id = ?", schoolID).Order("start_date DESC").First(&year).Error
	}
	if err == gorm.ErrRecordNotFound {
		return "", nil
	}
	if err != nil {
		return "", err
	}
	return year.ID, nil
}

func sectionBelongsToSchoolDB(db *gorm.DB, sectionID, schoolID string) bool {
	if strings.TrimSpace(sectionID) == "" || strings.TrimSpace(schoolID) == "" {
		return false
	}
	return countRows(db.Model(&models.Section{}).
		Joins("JOIN grades ON grades.id = sections.grade_id").
		Where("sections.id = ? AND grades.school_id = ?", sectionID, schoolID)) > 0
}
